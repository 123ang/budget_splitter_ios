# Swift iOS App Developer Guide
## Budget Splitter - Japan Trip 2026

This guide covers how to build a native iOS Swift app that connects to your VPS PostgreSQL database with user authentication and secure expense management.

---

## Table of Contents

1. [Database Schema](#1-database-schema)
2. [API Authentication Setup](#2-api-authentication-setup)
3. [Swift Project Setup](#3-swift-project-setup)
4. [Models](#4-models)
5. [Network Layer](#5-network-layer)
6. [Authentication Service](#6-authentication-service)
7. [Budget Service](#7-budget-service)
8. [Security & Access Control](#8-security--access-control)
9. [Views & UI](#9-views--ui)
10. [Testing & Deployment](#10-testing--deployment)

---

## 1. Database Schema

### New Tables Required

Run these SQL commands on your VPS PostgreSQL database to add user authentication:

```sql
-- Connect to your database
sudo -u postgres psql -d budget_splitter

-- =============================================
-- 1. USERS TABLE (for authentication)
-- =============================================
CREATE TABLE users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    email VARCHAR(255) UNIQUE,
    phone VARCHAR(20) UNIQUE,
    password_hash VARCHAR(255) NOT NULL,
    display_name VARCHAR(100) NOT NULL,
    avatar_url VARCHAR(500),
    is_active BOOLEAN DEFAULT TRUE,
    last_login_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    
    -- At least one of email or phone must be provided
    CONSTRAINT email_or_phone_required CHECK (
        email IS NOT NULL OR phone IS NOT NULL
    )
);

-- Index for faster lookups
CREATE INDEX idx_users_email ON users(email) WHERE email IS NOT NULL;
CREATE INDEX idx_users_phone ON users(phone) WHERE phone IS NOT NULL;

-- =============================================
-- 2. AUTH TOKENS TABLE (session management)
-- =============================================
CREATE TABLE auth_tokens (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    token VARCHAR(500) NOT NULL UNIQUE,
    device_name VARCHAR(100),
    device_id VARCHAR(255),
    expires_at TIMESTAMP WITH TIME ZONE NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    last_used_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX idx_auth_tokens_token ON auth_tokens(token);
CREATE INDEX idx_auth_tokens_user_id ON auth_tokens(user_id);
CREATE INDEX idx_auth_tokens_expires ON auth_tokens(expires_at);

-- =============================================
-- 3. TRIP GROUPS TABLE (organize members by trip)
-- =============================================
CREATE TABLE trip_groups (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(100) NOT NULL,
    description TEXT,
    owner_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    invite_code VARCHAR(10) UNIQUE,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX idx_trip_groups_owner ON trip_groups(owner_id);
CREATE INDEX idx_trip_groups_invite ON trip_groups(invite_code);

-- =============================================
-- 4. GROUP MEMBERS TABLE (users in a trip)
-- =============================================
CREATE TABLE group_members (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    group_id UUID NOT NULL REFERENCES trip_groups(id) ON DELETE CASCADE,
    user_id UUID REFERENCES users(id) ON DELETE SET NULL,
    member_name VARCHAR(100) NOT NULL,
    role VARCHAR(20) DEFAULT 'member' CHECK (role IN ('owner', 'admin', 'member', 'viewer')),
    can_add_expenses BOOLEAN DEFAULT TRUE,
    can_edit_own_expenses BOOLEAN DEFAULT TRUE,
    can_edit_all_expenses BOOLEAN DEFAULT FALSE,
    can_mark_paid BOOLEAN DEFAULT TRUE,
    joined_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    
    UNIQUE(group_id, user_id)
);

CREATE INDEX idx_group_members_group ON group_members(group_id);
CREATE INDEX idx_group_members_user ON group_members(user_id);

-- =============================================
-- 5. UPDATE MEMBERS TABLE (add user link)
-- =============================================
-- Drop old members table if exists and recreate with proper structure
DROP TABLE IF EXISTS members CASCADE;

CREATE TABLE members (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    group_id UUID NOT NULL REFERENCES trip_groups(id) ON DELETE CASCADE,
    user_id UUID REFERENCES users(id) ON DELETE SET NULL,
    name VARCHAR(100) NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX idx_members_group ON members(group_id);
CREATE INDEX idx_members_user ON members(user_id);

-- =============================================
-- 6. UPDATE EXPENSES TABLE (add security fields)
-- =============================================
DROP TABLE IF EXISTS expenses CASCADE;

CREATE TABLE expenses (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    group_id UUID NOT NULL REFERENCES trip_groups(id) ON DELETE CASCADE,
    description TEXT,
    amount DECIMAL(12,2) NOT NULL CHECK (amount > 0),
    currency VARCHAR(3) DEFAULT 'JPY' CHECK (currency IN ('JPY', 'MYR', 'SGD', 'USD')),
    category VARCHAR(50) NOT NULL CHECK (category IN ('Meal', 'Transport', 'Tickets', 'Shopping', 'Hotel', 'Other')),
    paid_by_member_id UUID NOT NULL REFERENCES members(id) ON DELETE CASCADE,
    expense_date DATE NOT NULL,
    
    -- Audit fields
    created_by_user_id UUID REFERENCES users(id),
    updated_by_user_id UUID REFERENCES users(id),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    
    -- Soft delete
    is_deleted BOOLEAN DEFAULT FALSE,
    deleted_at TIMESTAMP WITH TIME ZONE,
    deleted_by_user_id UUID REFERENCES users(id)
);

CREATE INDEX idx_expenses_group ON expenses(group_id);
CREATE INDEX idx_expenses_paid_by ON expenses(paid_by_member_id);
CREATE INDEX idx_expenses_date ON expenses(expense_date);
CREATE INDEX idx_expenses_not_deleted ON expenses(group_id) WHERE is_deleted = FALSE;

-- =============================================
-- 7. EXPENSE SPLITS TABLE (who owes what)
-- =============================================
CREATE TABLE expense_splits (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    expense_id UUID NOT NULL REFERENCES expenses(id) ON DELETE CASCADE,
    member_id UUID NOT NULL REFERENCES members(id) ON DELETE CASCADE,
    amount DECIMAL(12,2) NOT NULL CHECK (amount >= 0),
    is_paid BOOLEAN DEFAULT FALSE,
    paid_at TIMESTAMP WITH TIME ZONE,
    marked_paid_by_user_id UUID REFERENCES users(id),
    notes TEXT,
    
    UNIQUE(expense_id, member_id)
);

CREATE INDEX idx_expense_splits_expense ON expense_splits(expense_id);
CREATE INDEX idx_expense_splits_member ON expense_splits(member_id);
CREATE INDEX idx_expense_splits_unpaid ON expense_splits(member_id) WHERE is_paid = FALSE;

-- =============================================
-- 8. PAYMENT HISTORY TABLE (audit trail)
-- =============================================
CREATE TABLE payment_history (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    expense_split_id UUID NOT NULL REFERENCES expense_splits(id) ON DELETE CASCADE,
    action VARCHAR(20) NOT NULL CHECK (action IN ('marked_paid', 'marked_unpaid')),
    performed_by_user_id UUID NOT NULL REFERENCES users(id),
    performed_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    reason TEXT,
    ip_address INET,
    device_info TEXT
);

CREATE INDEX idx_payment_history_split ON payment_history(expense_split_id);
CREATE INDEX idx_payment_history_user ON payment_history(performed_by_user_id);
CREATE INDEX idx_payment_history_time ON payment_history(performed_at);

-- =============================================
-- 9. AUTO-UPDATE TRIGGER
-- =============================================
CREATE OR REPLACE FUNCTION update_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Apply trigger to all tables with updated_at
CREATE TRIGGER trigger_users_updated_at
    BEFORE UPDATE ON users
    FOR EACH ROW EXECUTE FUNCTION update_updated_at();

CREATE TRIGGER trigger_trip_groups_updated_at
    BEFORE UPDATE ON trip_groups
    FOR EACH ROW EXECUTE FUNCTION update_updated_at();

CREATE TRIGGER trigger_members_updated_at
    BEFORE UPDATE ON members
    FOR EACH ROW EXECUTE FUNCTION update_updated_at();

CREATE TRIGGER trigger_expenses_updated_at
    BEFORE UPDATE ON expenses
    FOR EACH ROW EXECUTE FUNCTION update_updated_at();

-- =============================================
-- 10. GRANT PERMISSIONS
-- =============================================
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO budget_user;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO budget_user;
```

---

## 2. API Authentication Setup

### Option A: Custom Node.js/Express API (Recommended)

Create a custom API server for authentication. Add this to your VPS:

#### Install Node.js API Server

```bash
# On your VPS
mkdir -p /var/www/budget-api
cd /var/www/budget-api
npm init -y
npm install express pg bcryptjs jsonwebtoken cors helmet express-rate-limit dotenv
```

#### Create API Server (`server.js`)

```javascript
// /var/www/budget-api/server.js
require('dotenv').config();
const express = require('express');
const { Pool } = require('pg');
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const cors = require('cors');
const helmet = require('helmet');
const rateLimit = require('express-rate-limit');

const app = express();

// Security middleware
app.use(helmet());
app.use(cors({
    origin: ['https://linkup-event.com', 'capacitor://localhost', 'ionic://localhost'],
    credentials: true
}));
app.use(express.json());

// Rate limiting
const authLimiter = rateLimit({
    windowMs: 15 * 60 * 1000, // 15 minutes
    max: 10, // 10 requests per window
    message: { error: 'Too many login attempts, please try again later' }
});

const apiLimiter = rateLimit({
    windowMs: 1 * 60 * 1000, // 1 minute
    max: 100 // 100 requests per minute
});

app.use('/auth', authLimiter);
app.use('/api', apiLimiter);

// Database connection
const pool = new Pool({
    host: process.env.DB_HOST || 'localhost',
    port: process.env.DB_PORT || 5432,
    database: process.env.DB_NAME || 'budget_splitter',
    user: process.env.DB_USER || 'budget_user',
    password: process.env.DB_PASSWORD,
    ssl: false
});

const JWT_SECRET = process.env.JWT_SECRET || 'your-super-secret-key-change-this';
const JWT_EXPIRES_IN = '30d';

// ==================== AUTH MIDDLEWARE ====================

const authenticateToken = async (req, res, next) => {
    const authHeader = req.headers['authorization'];
    const token = authHeader && authHeader.split(' ')[1];
    
    if (!token) {
        return res.status(401).json({ error: 'Access token required' });
    }
    
    try {
        const decoded = jwt.verify(token, JWT_SECRET);
        
        // Verify token exists in database and not expired
        const result = await pool.query(
            `SELECT at.*, u.display_name, u.email, u.phone 
             FROM auth_tokens at 
             JOIN users u ON at.user_id = u.id 
             WHERE at.token = $1 AND at.expires_at > NOW()`,
            [token]
        );
        
        if (result.rows.length === 0) {
            return res.status(401).json({ error: 'Invalid or expired token' });
        }
        
        // Update last used
        await pool.query(
            'UPDATE auth_tokens SET last_used_at = NOW() WHERE token = $1',
            [token]
        );
        
        req.user = {
            id: decoded.userId,
            displayName: result.rows[0].display_name,
            email: result.rows[0].email,
            phone: result.rows[0].phone
        };
        req.token = token;
        
        next();
    } catch (err) {
        return res.status(403).json({ error: 'Invalid token' });
    }
};

// ==================== AUTH ROUTES ====================

// Register
app.post('/auth/register', async (req, res) => {
    try {
        const { email, phone, password, displayName } = req.body;
        
        // Validation
        if (!password || password.length < 8) {
            return res.status(400).json({ error: 'Password must be at least 8 characters' });
        }
        
        if (!email && !phone) {
            return res.status(400).json({ error: 'Email or phone number required' });
        }
        
        if (!displayName || displayName.length < 2) {
            return res.status(400).json({ error: 'Display name required' });
        }
        
        // Normalize inputs
        const normalizedEmail = email?.toLowerCase().trim() || null;
        const normalizedPhone = phone?.replace(/\D/g, '') || null;
        
        // Check if user exists
        const existingUser = await pool.query(
            'SELECT id FROM users WHERE email = $1 OR phone = $2',
            [normalizedEmail, normalizedPhone]
        );
        
        if (existingUser.rows.length > 0) {
            return res.status(409).json({ error: 'User already exists with this email or phone' });
        }
        
        // Hash password
        const passwordHash = await bcrypt.hash(password, 12);
        
        // Create user
        const result = await pool.query(
            `INSERT INTO users (email, phone, password_hash, display_name)
             VALUES ($1, $2, $3, $4)
             RETURNING id, email, phone, display_name, created_at`,
            [normalizedEmail, normalizedPhone, passwordHash, displayName]
        );
        
        const user = result.rows[0];
        
        // Generate token
        const token = jwt.sign({ userId: user.id }, JWT_SECRET, { expiresIn: JWT_EXPIRES_IN });
        
        // Store token
        await pool.query(
            `INSERT INTO auth_tokens (user_id, token, device_name, expires_at)
             VALUES ($1, $2, $3, NOW() + INTERVAL '30 days')`,
            [user.id, token, req.headers['user-agent']]
        );
        
        res.status(201).json({
            user: {
                id: user.id,
                email: user.email,
                phone: user.phone,
                displayName: user.display_name
            },
            token
        });
        
    } catch (err) {
        console.error('Register error:', err);
        res.status(500).json({ error: 'Registration failed' });
    }
});

// Login
app.post('/auth/login', async (req, res) => {
    try {
        const { emailOrPhone, password, deviceId, deviceName } = req.body;
        
        if (!emailOrPhone || !password) {
            return res.status(400).json({ error: 'Email/phone and password required' });
        }
        
        // Normalize input
        const normalizedInput = emailOrPhone.toLowerCase().trim();
        const isEmail = normalizedInput.includes('@');
        
        // Find user
        const result = await pool.query(
            `SELECT id, email, phone, password_hash, display_name, is_active
             FROM users 
             WHERE ${isEmail ? 'email' : 'phone'} = $1`,
            [isEmail ? normalizedInput : normalizedInput.replace(/\D/g, '')]
        );
        
        if (result.rows.length === 0) {
            return res.status(401).json({ error: 'Invalid credentials' });
        }
        
        const user = result.rows[0];
        
        if (!user.is_active) {
            return res.status(403).json({ error: 'Account is deactivated' });
        }
        
        // Verify password
        const isValidPassword = await bcrypt.compare(password, user.password_hash);
        
        if (!isValidPassword) {
            return res.status(401).json({ error: 'Invalid credentials' });
        }
        
        // Generate token
        const token = jwt.sign({ userId: user.id }, JWT_SECRET, { expiresIn: JWT_EXPIRES_IN });
        
        // Store token
        await pool.query(
            `INSERT INTO auth_tokens (user_id, token, device_id, device_name, expires_at)
             VALUES ($1, $2, $3, $4, NOW() + INTERVAL '30 days')`,
            [user.id, token, deviceId, deviceName || req.headers['user-agent']]
        );
        
        // Update last login
        await pool.query(
            'UPDATE users SET last_login_at = NOW() WHERE id = $1',
            [user.id]
        );
        
        res.json({
            user: {
                id: user.id,
                email: user.email,
                phone: user.phone,
                displayName: user.display_name
            },
            token
        });
        
    } catch (err) {
        console.error('Login error:', err);
        res.status(500).json({ error: 'Login failed' });
    }
});

// Logout
app.post('/auth/logout', authenticateToken, async (req, res) => {
    try {
        await pool.query('DELETE FROM auth_tokens WHERE token = $1', [req.token]);
        res.json({ message: 'Logged out successfully' });
    } catch (err) {
        res.status(500).json({ error: 'Logout failed' });
    }
});

// Get current user
app.get('/auth/me', authenticateToken, (req, res) => {
    res.json({ user: req.user });
});

// ==================== EXPENSE ROUTES (Protected) ====================

// Mark expense split as paid/unpaid
app.patch('/api/expense-splits/:splitId/payment', authenticateToken, async (req, res) => {
    const client = await pool.connect();
    
    try {
        await client.query('BEGIN');
        
        const { splitId } = req.params;
        const { isPaid, reason } = req.body;
        
        // Get the split and verify user has permission
        const splitResult = await client.query(
            `SELECT es.*, e.group_id, e.paid_by_member_id,
                    m.user_id as split_member_user_id,
                    pm.user_id as payer_user_id,
                    gm.role, gm.can_mark_paid
             FROM expense_splits es
             JOIN expenses e ON es.expense_id = e.id
             JOIN members m ON es.member_id = m.id
             JOIN members pm ON e.paid_by_member_id = pm.id
             LEFT JOIN group_members gm ON gm.group_id = e.group_id AND gm.user_id = $2
             WHERE es.id = $1 AND e.is_deleted = FALSE`,
            [splitId, req.user.id]
        );
        
        if (splitResult.rows.length === 0) {
            await client.query('ROLLBACK');
            return res.status(404).json({ error: 'Expense split not found' });
        }
        
        const split = splitResult.rows[0];
        
        // SECURITY CHECK: Who can mark as paid?
        // 1. The person who owes the money (split_member_user_id)
        // 2. The person who paid (payer_user_id)
        // 3. Group owner/admin with can_mark_paid permission
        const canMarkPaid = 
            split.split_member_user_id === req.user.id ||
            split.payer_user_id === req.user.id ||
            (split.role === 'owner') ||
            (split.role === 'admin' && split.can_mark_paid);
        
        if (!canMarkPaid) {
            await client.query('ROLLBACK');
            return res.status(403).json({ 
                error: 'You do not have permission to modify this payment status' 
            });
        }
        
        // Update the split
        await client.query(
            `UPDATE expense_splits 
             SET is_paid = $1, 
                 paid_at = CASE WHEN $1 THEN NOW() ELSE NULL END,
                 marked_paid_by_user_id = $2,
                 notes = COALESCE($3, notes)
             WHERE id = $4`,
            [isPaid, req.user.id, reason, splitId]
        );
        
        // Record in payment history
        await client.query(
            `INSERT INTO payment_history 
             (expense_split_id, action, performed_by_user_id, reason, ip_address, device_info)
             VALUES ($1, $2, $3, $4, $5, $6)`,
            [
                splitId,
                isPaid ? 'marked_paid' : 'marked_unpaid',
                req.user.id,
                reason,
                req.ip,
                req.headers['user-agent']
            ]
        );
        
        await client.query('COMMIT');
        
        res.json({ 
            success: true, 
            message: isPaid ? 'Marked as paid' : 'Marked as unpaid' 
        });
        
    } catch (err) {
        await client.query('ROLLBACK');
        console.error('Payment update error:', err);
        res.status(500).json({ error: 'Failed to update payment status' });
    } finally {
        client.release();
    }
});

// Get payment history for an expense
app.get('/api/expense-splits/:splitId/history', authenticateToken, async (req, res) => {
    try {
        const { splitId } = req.params;
        
        const result = await pool.query(
            `SELECT ph.*, u.display_name as performed_by_name
             FROM payment_history ph
             JOIN users u ON ph.performed_by_user_id = u.id
             WHERE ph.expense_split_id = $1
             ORDER BY ph.performed_at DESC`,
            [splitId]
        );
        
        res.json({ history: result.rows });
        
    } catch (err) {
        res.status(500).json({ error: 'Failed to fetch history' });
    }
});

// Add expense with authorization
app.post('/api/expenses', authenticateToken, async (req, res) => {
    const client = await pool.connect();
    
    try {
        await client.query('BEGIN');
        
        const { groupId, description, amount, currency, category, paidByMemberId, expenseDate, splits } = req.body;
        
        // Verify user is member of group with add permission
        const memberCheck = await client.query(
            `SELECT role, can_add_expenses FROM group_members 
             WHERE group_id = $1 AND user_id = $2`,
            [groupId, req.user.id]
        );
        
        if (memberCheck.rows.length === 0) {
            await client.query('ROLLBACK');
            return res.status(403).json({ error: 'You are not a member of this group' });
        }
        
        if (!memberCheck.rows[0].can_add_expenses && memberCheck.rows[0].role !== 'owner') {
            await client.query('ROLLBACK');
            return res.status(403).json({ error: 'You do not have permission to add expenses' });
        }
        
        // Create expense
        const expenseResult = await client.query(
            `INSERT INTO expenses 
             (group_id, description, amount, currency, category, paid_by_member_id, expense_date, created_by_user_id)
             VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
             RETURNING id`,
            [groupId, description, amount, currency, category, paidByMemberId, expenseDate, req.user.id]
        );
        
        const expenseId = expenseResult.rows[0].id;
        
        // Create splits
        for (const split of splits) {
            await client.query(
                `INSERT INTO expense_splits (expense_id, member_id, amount)
                 VALUES ($1, $2, $3)`,
                [expenseId, split.memberId, split.amount]
            );
        }
        
        await client.query('COMMIT');
        
        res.status(201).json({ 
            success: true, 
            expenseId 
        });
        
    } catch (err) {
        await client.query('ROLLBACK');
        console.error('Add expense error:', err);
        res.status(500).json({ error: 'Failed to add expense' });
    } finally {
        client.release();
    }
});

// Delete expense (soft delete)
app.delete('/api/expenses/:expenseId', authenticateToken, async (req, res) => {
    try {
        const { expenseId } = req.params;
        
        // Verify permission
        const expenseCheck = await pool.query(
            `SELECT e.*, gm.role, gm.can_edit_all_expenses
             FROM expenses e
             JOIN group_members gm ON gm.group_id = e.group_id AND gm.user_id = $2
             WHERE e.id = $1 AND e.is_deleted = FALSE`,
            [expenseId, req.user.id]
        );
        
        if (expenseCheck.rows.length === 0) {
            return res.status(404).json({ error: 'Expense not found' });
        }
        
        const expense = expenseCheck.rows[0];
        
        // Can delete if: owner, admin with edit_all, or the person who created it
        const canDelete = 
            expense.role === 'owner' ||
            expense.can_edit_all_expenses ||
            expense.created_by_user_id === req.user.id;
        
        if (!canDelete) {
            return res.status(403).json({ error: 'You cannot delete this expense' });
        }
        
        // Soft delete
        await pool.query(
            `UPDATE expenses 
             SET is_deleted = TRUE, deleted_at = NOW(), deleted_by_user_id = $2
             WHERE id = $1`,
            [expenseId, req.user.id]
        );
        
        res.json({ success: true, message: 'Expense deleted' });
        
    } catch (err) {
        res.status(500).json({ error: 'Failed to delete expense' });
    }
});

// Start server
const PORT = process.env.PORT || 3012;
app.listen(PORT, '127.0.0.1', () => {
    console.log(`Budget API running on port ${PORT}`);
});
```

#### Create `.env` file

```bash
# /var/www/budget-api/.env
DB_HOST=localhost
DB_PORT=5432
DB_NAME=budget_splitter
DB_USER=budget_user
DB_PASSWORD=your_secure_password_here
JWT_SECRET=your-very-long-random-secret-key-minimum-32-characters
PORT=3012
```

#### Create systemd service

```bash
sudo nano /etc/systemd/system/budget-api.service
```

```ini
[Unit]
Description=Budget Splitter API
After=postgresql.service

[Service]
Type=simple
User=www-data
WorkingDirectory=/var/www/budget-api
ExecStart=/usr/bin/node server.js
Restart=on-failure
RestartSec=10
Environment=NODE_ENV=production

[Install]
WantedBy=multi-user.target
```

```bash
sudo systemctl daemon-reload
sudo systemctl start budget-api
sudo systemctl enable budget-api
```

#### Update Nginx

Add to your Nginx config:

```nginx
location /budget-api/ {
    proxy_pass http://127.0.0.1:3012/;
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;
}
```

---

## 3. Swift Project Setup

### Create new Xcode Project

1. Open Xcode → Create New Project
2. Choose iOS → App
3. Product Name: `BudgetSplitter`
4. Interface: SwiftUI
5. Language: Swift
6. Minimum Deployment: iOS 15.0

### Add Dependencies (Swift Package Manager)

Add these packages via File → Add Packages:

- `https://github.com/Alamofire/Alamofire.git` (5.8+)
- `https://github.com/kishikawakatsumi/KeychainAccess.git` (4.2+)

---

## 4. Models

### Create Models/User.swift

```swift
import Foundation

struct User: Codable, Identifiable {
    let id: UUID
    let email: String?
    let phone: String?
    let displayName: String
    
    enum CodingKeys: String, CodingKey {
        case id
        case email
        case phone
        case displayName = "display_name"
    }
}

struct AuthResponse: Codable {
    let user: User
    let token: String
}

struct LoginRequest: Codable {
    let emailOrPhone: String
    let password: String
    let deviceId: String?
    let deviceName: String?
}

struct RegisterRequest: Codable {
    let email: String?
    let phone: String?
    let password: String
    let displayName: String
}
```

### Create Models/Expense.swift

```swift
import Foundation

struct Member: Codable, Identifiable, Hashable {
    let id: UUID
    let groupId: UUID
    let userId: UUID?
    let name: String
    let createdAt: Date?
    
    enum CodingKeys: String, CodingKey {
        case id
        case groupId = "group_id"
        case userId = "user_id"
        case name
        case createdAt = "created_at"
    }
}

struct Expense: Codable, Identifiable {
    let id: UUID
    let groupId: UUID
    let description: String?
    let amount: Decimal
    let currency: String
    let category: ExpenseCategory
    let paidByMemberId: UUID
    let expenseDate: Date
    let createdByUserId: UUID?
    let createdAt: Date?
    let isDeleted: Bool
    var splits: [ExpenseSplit]?
    
    enum CodingKeys: String, CodingKey {
        case id
        case groupId = "group_id"
        case description
        case amount
        case currency
        case category
        case paidByMemberId = "paid_by_member_id"
        case expenseDate = "expense_date"
        case createdByUserId = "created_by_user_id"
        case createdAt = "created_at"
        case isDeleted = "is_deleted"
        case splits
    }
}

struct ExpenseSplit: Codable, Identifiable {
    let id: UUID
    let expenseId: UUID
    let memberId: UUID
    let amount: Decimal
    var isPaid: Bool
    let paidAt: Date?
    let markedPaidByUserId: UUID?
    let notes: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case expenseId = "expense_id"
        case memberId = "member_id"
        case amount
        case isPaid = "is_paid"
        case paidAt = "paid_at"
        case markedPaidByUserId = "marked_paid_by_user_id"
        case notes
    }
}

struct PaymentHistory: Codable, Identifiable {
    let id: UUID
    let expenseSplitId: UUID
    let action: String
    let performedByUserId: UUID
    let performedByName: String?
    let performedAt: Date
    let reason: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case expenseSplitId = "expense_split_id"
        case action
        case performedByUserId = "performed_by_user_id"
        case performedByName = "performed_by_name"
        case performedAt = "performed_at"
        case reason
    }
}

enum ExpenseCategory: String, Codable, CaseIterable {
    case meal = "Meal"
    case transport = "Transport"
    case tickets = "Tickets"
    case shopping = "Shopping"
    case hotel = "Hotel"
    case other = "Other"
    
    var icon: String {
        switch self {
        case .meal: return "🍜"
        case .transport: return "🚆"
        case .tickets: return "🎫"
        case .shopping: return "🛍️"
        case .hotel: return "🏨"
        case .other: return "📦"
        }
    }
}

struct TripGroup: Codable, Identifiable {
    let id: UUID
    let name: String
    let description: String?
    let ownerId: UUID
    let inviteCode: String?
    let isActive: Bool
    
    enum CodingKeys: String, CodingKey {
        case id
        case name
        case description
        case ownerId = "owner_id"
        case inviteCode = "invite_code"
        case isActive = "is_active"
    }
}

struct GroupMember: Codable {
    let id: UUID
    let groupId: UUID
    let userId: UUID?
    let memberName: String
    let role: GroupRole
    let canAddExpenses: Bool
    let canEditOwnExpenses: Bool
    let canEditAllExpenses: Bool
    let canMarkPaid: Bool
    
    enum CodingKeys: String, CodingKey {
        case id
        case groupId = "group_id"
        case userId = "user_id"
        case memberName = "member_name"
        case role
        case canAddExpenses = "can_add_expenses"
        case canEditOwnExpenses = "can_edit_own_expenses"
        case canEditAllExpenses = "can_edit_all_expenses"
        case canMarkPaid = "can_mark_paid"
    }
}

enum GroupRole: String, Codable {
    case owner
    case admin
    case member
    case viewer
}
```

---

## 5. Network Layer

### Create Services/APIClient.swift

```swift
import Foundation
import Alamofire

class APIClient {
    static let shared = APIClient()
    
    private let baseURL = "https://linkup-event.com/budget-api"
    
    private var session: Session
    
    private init() {
        let configuration = URLSessionConfiguration.af.default
        configuration.timeoutIntervalForRequest = 30
        configuration.timeoutIntervalForResource = 60
        
        session = Session(configuration: configuration)
    }
    
    // MARK: - Headers
    
    private var authHeaders: HTTPHeaders {
        var headers = HTTPHeaders()
        headers.add(.contentType("application/json"))
        headers.add(.accept("application/json"))
        
        if let token = AuthService.shared.getToken() {
            headers.add(.authorization(bearerToken: token))
        }
        
        return headers
    }
    
    // MARK: - Generic Request
    
    func request<T: Decodable>(
        endpoint: String,
        method: HTTPMethod,
        parameters: Parameters? = nil,
        encoding: ParameterEncoding = JSONEncoding.default
    ) async throws -> T {
        let url = "\(baseURL)\(endpoint)"
        
        return try await withCheckedThrowingContinuation { continuation in
            session.request(
                url,
                method: method,
                parameters: parameters,
                encoding: encoding,
                headers: authHeaders
            )
            .validate(statusCode: 200..<300)
            .responseDecodable(of: T.self, decoder: JSONDecoder.apiDecoder) { response in
                switch response.result {
                case .success(let value):
                    continuation.resume(returning: value)
                case .failure(let error):
                    // Check for auth errors
                    if response.response?.statusCode == 401 {
                        AuthService.shared.logout()
                    }
                    continuation.resume(throwing: self.parseError(response: response, error: error))
                }
            }
        }
    }
    
    func requestNoResponse(
        endpoint: String,
        method: HTTPMethod,
        parameters: Parameters? = nil
    ) async throws {
        let url = "\(baseURL)\(endpoint)"
        
        return try await withCheckedThrowingContinuation { continuation in
            session.request(
                url,
                method: method,
                parameters: parameters,
                encoding: JSONEncoding.default,
                headers: authHeaders
            )
            .validate(statusCode: 200..<300)
            .response { response in
                switch response.result {
                case .success:
                    continuation.resume()
                case .failure(let error):
                    if response.response?.statusCode == 401 {
                        AuthService.shared.logout()
                    }
                    continuation.resume(throwing: self.parseError(response: response, error: error))
                }
            }
        }
    }
    
    // MARK: - Error Handling
    
    private func parseError(response: AFDataResponse<some Any>, error: AFError) -> APIError {
        if let data = response.data,
           let apiError = try? JSONDecoder().decode(APIErrorResponse.self, from: data) {
            return .serverError(apiError.error)
        }
        
        switch response.response?.statusCode {
        case 401:
            return .unauthorized
        case 403:
            return .forbidden
        case 404:
            return .notFound
        case 429:
            return .rateLimited
        default:
            return .networkError(error.localizedDescription)
        }
    }
}

// MARK: - API Error Types

enum APIError: LocalizedError {
    case unauthorized
    case forbidden
    case notFound
    case rateLimited
    case serverError(String)
    case networkError(String)
    case decodingError
    
    var errorDescription: String? {
        switch self {
        case .unauthorized:
            return "Please log in again"
        case .forbidden:
            return "You don't have permission to perform this action"
        case .notFound:
            return "Resource not found"
        case .rateLimited:
            return "Too many requests. Please wait a moment."
        case .serverError(let message):
            return message
        case .networkError(let message):
            return "Network error: \(message)"
        case .decodingError:
            return "Failed to parse response"
        }
    }
}

struct APIErrorResponse: Codable {
    let error: String
}

// MARK: - JSON Decoder Extension

extension JSONDecoder {
    static var apiDecoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let dateString = try container.decode(String.self)
            
            // Try ISO8601 with fractional seconds
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = formatter.date(from: dateString) {
                return date
            }
            
            // Try without fractional seconds
            formatter.formatOptions = [.withInternetDateTime]
            if let date = formatter.date(from: dateString) {
                return date
            }
            
            // Try date only
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd"
            if let date = dateFormatter.date(from: dateString) {
                return date
            }
            
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Cannot decode date")
        }
        return decoder
    }
}
```

---

## 6. Authentication Service

### Create Services/AuthService.swift

```swift
import Foundation
import KeychainAccess
import UIKit

@MainActor
class AuthService: ObservableObject {
    static let shared = AuthService()
    
    private let keychain = Keychain(service: "com.japantrip.budgetsplitter")
    private let tokenKey = "auth_token"
    private let userKey = "current_user"
    
    @Published var currentUser: User?
    @Published var isAuthenticated = false
    @Published var isLoading = false
    
    private init() {
        loadStoredUser()
    }
    
    // MARK: - Token Management
    
    func getToken() -> String? {
        try? keychain.get(tokenKey)
    }
    
    private func saveToken(_ token: String) {
        try? keychain.set(token, key: tokenKey)
    }
    
    private func removeToken() {
        try? keychain.remove(tokenKey)
    }
    
    // MARK: - User Management
    
    private func loadStoredUser() {
        if let userData = UserDefaults.standard.data(forKey: userKey),
           let user = try? JSONDecoder().decode(User.self, from: userData) {
            self.currentUser = user
            self.isAuthenticated = getToken() != nil
        }
    }
    
    private func saveUser(_ user: User) {
        if let userData = try? JSONEncoder().encode(user) {
            UserDefaults.standard.set(userData, forKey: userKey)
        }
        self.currentUser = user
        self.isAuthenticated = true
    }
    
    private func clearUser() {
        UserDefaults.standard.removeObject(forKey: userKey)
        self.currentUser = nil
        self.isAuthenticated = false
    }
    
    // MARK: - Login
    
    func login(emailOrPhone: String, password: String) async throws {
        isLoading = true
        defer { isLoading = false }
        
        let deviceId = UIDevice.current.identifierForVendor?.uuidString
        let deviceName = UIDevice.current.name
        
        let response: AuthResponse = try await APIClient.shared.request(
            endpoint: "/auth/login",
            method: .post,
            parameters: [
                "emailOrPhone": emailOrPhone,
                "password": password,
                "deviceId": deviceId ?? "",
                "deviceName": deviceName
            ]
        )
        
        saveToken(response.token)
        saveUser(response.user)
    }
    
    // MARK: - Register
    
    func register(email: String?, phone: String?, password: String, displayName: String) async throws {
        isLoading = true
        defer { isLoading = false }
        
        var params: [String: Any] = [
            "password": password,
            "displayName": displayName
        ]
        
        if let email = email, !email.isEmpty {
            params["email"] = email
        }
        
        if let phone = phone, !phone.isEmpty {
            params["phone"] = phone
        }
        
        let response: AuthResponse = try await APIClient.shared.request(
            endpoint: "/auth/register",
            method: .post,
            parameters: params
        )
        
        saveToken(response.token)
        saveUser(response.user)
    }
    
    // MARK: - Logout
    
    func logout() {
        Task {
            // Try to invalidate token on server (ignore errors)
            try? await APIClient.shared.requestNoResponse(
                endpoint: "/auth/logout",
                method: .post
            )
        }
        
        removeToken()
        clearUser()
    }
    
    // MARK: - Refresh User
    
    func refreshCurrentUser() async throws {
        struct MeResponse: Codable {
            let user: User
        }
        
        let response: MeResponse = try await APIClient.shared.request(
            endpoint: "/auth/me",
            method: .get
        )
        
        saveUser(response.user)
    }
}
```

---

## 7. Budget Service

### Create Services/BudgetService.swift

```swift
import Foundation

@MainActor
class BudgetService: ObservableObject {
    static let shared = BudgetService()
    
    @Published var groups: [TripGroup] = []
    @Published var currentGroup: TripGroup?
    @Published var members: [Member] = []
    @Published var expenses: [Expense] = []
    @Published var isLoading = false
    @Published var error: String?
    
    private init() {}
    
    // MARK: - Groups
    
    func fetchGroups() async throws {
        isLoading = true
        defer { isLoading = false }
        
        struct GroupsResponse: Codable {
            let groups: [TripGroup]
        }
        
        let response: GroupsResponse = try await APIClient.shared.request(
            endpoint: "/api/groups",
            method: .get
        )
        
        groups = response.groups
    }
    
    func selectGroup(_ group: TripGroup) async throws {
        currentGroup = group
        try await fetchMembers()
        try await fetchExpenses()
    }
    
    // MARK: - Members
    
    func fetchMembers() async throws {
        guard let groupId = currentGroup?.id else { return }
        
        struct MembersResponse: Codable {
            let members: [Member]
        }
        
        let response: MembersResponse = try await APIClient.shared.request(
            endpoint: "/api/groups/\(groupId)/members",
            method: .get
        )
        
        members = response.members
    }
    
    // MARK: - Expenses
    
    func fetchExpenses() async throws {
        guard let groupId = currentGroup?.id else { return }
        
        isLoading = true
        defer { isLoading = false }
        
        struct ExpensesResponse: Codable {
            let expenses: [Expense]
        }
        
        let response: ExpensesResponse = try await APIClient.shared.request(
            endpoint: "/api/groups/\(groupId)/expenses",
            method: .get
        )
        
        expenses = response.expenses
    }
    
    func addExpense(
        description: String,
        amount: Decimal,
        currency: String,
        category: ExpenseCategory,
        paidByMemberId: UUID,
        expenseDate: Date,
        splits: [(memberId: UUID, amount: Decimal)]
    ) async throws {
        guard let groupId = currentGroup?.id else {
            throw APIError.serverError("No group selected")
        }
        
        isLoading = true
        defer { isLoading = false }
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        
        let splitParams = splits.map { split in
            ["memberId": split.memberId.uuidString, "amount": "\(split.amount)"]
        }
        
        try await APIClient.shared.requestNoResponse(
            endpoint: "/api/expenses",
            method: .post,
            parameters: [
                "groupId": groupId.uuidString,
                "description": description,
                "amount": "\(amount)",
                "currency": currency,
                "category": category.rawValue,
                "paidByMemberId": paidByMemberId.uuidString,
                "expenseDate": dateFormatter.string(from: expenseDate),
                "splits": splitParams
            ]
        )
        
        // Refresh expenses
        try await fetchExpenses()
    }
    
    func deleteExpense(_ expenseId: UUID) async throws {
        isLoading = true
        defer { isLoading = false }
        
        try await APIClient.shared.requestNoResponse(
            endpoint: "/api/expenses/\(expenseId)",
            method: .delete
        )
        
        // Remove from local list
        expenses.removeAll { $0.id == expenseId }
    }
    
    // MARK: - Payment Status
    
    /// Mark a split as paid or unpaid
    /// - Parameters:
    ///   - splitId: The expense split ID
    ///   - isPaid: Whether it's paid or not
    ///   - reason: Optional reason for the change (for audit)
    func updatePaymentStatus(
        splitId: UUID,
        isPaid: Bool,
        reason: String? = nil
    ) async throws {
        isLoading = true
        defer { isLoading = false }
        
        var params: [String: Any] = ["isPaid": isPaid]
        if let reason = reason {
            params["reason"] = reason
        }
        
        try await APIClient.shared.requestNoResponse(
            endpoint: "/api/expense-splits/\(splitId)/payment",
            method: .patch,
            parameters: params
        )
        
        // Refresh expenses to get updated status
        try await fetchExpenses()
    }
    
    /// Get payment history for a split
    func getPaymentHistory(splitId: UUID) async throws -> [PaymentHistory] {
        struct HistoryResponse: Codable {
            let history: [PaymentHistory]
        }
        
        let response: HistoryResponse = try await APIClient.shared.request(
            endpoint: "/api/expense-splits/\(splitId)/history",
            method: .get
        )
        
        return response.history
    }
    
    // MARK: - Calculations
    
    func calculateMemberTotals() -> [UUID: Decimal] {
        var totals: [UUID: Decimal] = [:]
        
        for expense in expenses where !expense.isDeleted {
            if let splits = expense.splits {
                for split in splits {
                    totals[split.memberId, default: 0] += split.amount
                }
            }
        }
        
        return totals
    }
    
    func calculateCategoryTotals() -> [ExpenseCategory: Decimal] {
        var totals: [ExpenseCategory: Decimal] = [:]
        
        for expense in expenses where !expense.isDeleted {
            totals[expense.category, default: 0] += expense.amount
        }
        
        return totals
    }
    
    func getUnpaidSplits(for memberId: UUID) -> [ExpenseSplit] {
        expenses.flatMap { $0.splits ?? [] }
            .filter { $0.memberId == memberId && !$0.isPaid }
    }
}
```

---

## 8. Security & Access Control

### Key Security Features Implemented

#### 1. Authentication
- JWT tokens stored securely in iOS Keychain
- Tokens expire after 30 days
- Rate limiting on login attempts (10 per 15 minutes)
- Password hashing with bcrypt (12 rounds)

#### 2. Authorization - Who Can Mark Paid/Unpaid

```
┌─────────────────────────────────────────────────────────────────┐
│                     PAYMENT PERMISSION MATRIX                    │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  WHO CAN MARK AS PAID:                                          │
│                                                                  │
│  ✅ The person who OWES the money (split_member_user)           │
│     → "I paid my share"                                         │
│                                                                  │
│  ✅ The person who PAID the expense (payer_user)                │
│     → "They gave me their share"                                │
│                                                                  │
│  ✅ Group OWNER                                                  │
│     → Full control                                              │
│                                                                  │
│  ✅ Group ADMIN with can_mark_paid=true                         │
│     → Delegated permission                                      │
│                                                                  │
│  ❌ Regular members (for others' payments)                      │
│  ❌ Viewers                                                      │
│  ❌ Non-group members                                           │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

#### 3. Audit Trail

Every payment status change is logged with:
- Who made the change
- When it was made
- What the change was (paid → unpaid or unpaid → paid)
- Optional reason
- IP address
- Device info

This prevents disputes and allows reversing malicious changes.

#### 4. Role-Based Access Control

```sql
-- Roles and their default permissions
-- owner:  Full control, cannot be removed
-- admin:  Can manage most things, configurable permissions
-- member: Can add expenses, mark own payments
-- viewer: Read-only access
```

### Create a Permission Helper

### Create Helpers/PermissionHelper.swift

```swift
import Foundation

struct PermissionHelper {
    
    /// Check if current user can mark a payment as paid/unpaid
    static func canMarkPayment(
        split: ExpenseSplit,
        expense: Expense,
        members: [Member],
        currentUser: User?,
        groupMember: GroupMember?
    ) -> Bool {
        guard let currentUserId = currentUser?.id else { return false }
        
        // Get the member who owes this split
        let splitMember = members.first { $0.id == split.memberId }
        
        // Get the member who paid the expense
        let payerMember = members.first { $0.id == expense.paidByMemberId }
        
        // User is the one who owes
        if splitMember?.userId == currentUserId {
            return true
        }
        
        // User is the one who paid
        if payerMember?.userId == currentUserId {
            return true
        }
        
        // User is owner
        if groupMember?.role == .owner {
            return true
        }
        
        // User is admin with permission
        if groupMember?.role == .admin && groupMember?.canMarkPaid == true {
            return true
        }
        
        return false
    }
    
    /// Check if current user can edit an expense
    static func canEditExpense(
        expense: Expense,
        currentUser: User?,
        groupMember: GroupMember?
    ) -> Bool {
        guard let currentUserId = currentUser?.id else { return false }
        
        // Owner can edit all
        if groupMember?.role == .owner {
            return true
        }
        
        // Admin with edit_all permission
        if groupMember?.canEditAllExpenses == true {
            return true
        }
        
        // Creator can edit their own
        if expense.createdByUserId == currentUserId && groupMember?.canEditOwnExpenses == true {
            return true
        }
        
        return false
    }
    
    /// Check if current user can delete an expense
    static func canDeleteExpense(
        expense: Expense,
        currentUser: User?,
        groupMember: GroupMember?
    ) -> Bool {
        // Same rules as editing
        return canEditExpense(expense: expense, currentUser: currentUser, groupMember: groupMember)
    }
    
    /// Check if current user can add expenses
    static func canAddExpense(groupMember: GroupMember?) -> Bool {
        guard let member = groupMember else { return false }
        
        return member.role == .owner || 
               member.role == .admin || 
               member.canAddExpenses
    }
}
```

---

## 9. Views & UI

### Create Views/LoginView.swift

```swift
import SwiftUI

struct LoginView: View {
    @StateObject private var authService = AuthService.shared
    
    @State private var emailOrPhone = ""
    @State private var password = ""
    @State private var isShowingRegister = false
    @State private var errorMessage: String?
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()
                
                VStack(spacing: 24) {
                    // Logo
                    VStack(spacing: 8) {
                        Text("💰")
                            .font(.system(size: 64))
                        Text("Budget Splitter")
                            .font(.title)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                        Text("Japan Trip 2026")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                    }
                    .padding(.top, 60)
                    
                    Spacer()
                    
                    // Login Form
                    VStack(spacing: 16) {
                        TextField("Email or Phone Number", text: $emailOrPhone)
                            .textFieldStyle(DarkTextFieldStyle())
                            .textContentType(.username)
                            .autocapitalization(.none)
                            .keyboardType(.emailAddress)
                        
                        SecureField("Password", text: $password)
                            .textFieldStyle(DarkTextFieldStyle())
                            .textContentType(.password)
                        
                        if let error = errorMessage {
                            Text(error)
                                .font(.caption)
                                .foregroundColor(.red)
                                .multilineTextAlignment(.center)
                        }
                        
                        Button(action: login) {
                            HStack {
                                if authService.isLoading {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                } else {
                                    Text("Log In")
                                        .fontWeight(.semibold)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                        }
                        .disabled(authService.isLoading || emailOrPhone.isEmpty || password.isEmpty)
                        
                        Button(action: { isShowingRegister = true }) {
                            Text("Don't have an account? Register")
                                .font(.subheadline)
                                .foregroundColor(.blue)
                        }
                    }
                    .padding(.horizontal, 24)
                    
                    Spacer()
                }
            }
            .sheet(isPresented: $isShowingRegister) {
                RegisterView()
            }
        }
    }
    
    private func login() {
        errorMessage = nil
        
        Task {
            do {
                try await authService.login(
                    emailOrPhone: emailOrPhone,
                    password: password
                )
            } catch let error as APIError {
                errorMessage = error.localizedDescription
            } catch {
                errorMessage = "Login failed. Please try again."
            }
        }
    }
}

struct DarkTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .padding(16)
            .background(Color(white: 0.15))
            .cornerRadius(12)
            .foregroundColor(.white)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color(white: 0.25), lineWidth: 1)
            )
    }
}
```

### Create Views/RegisterView.swift

```swift
import SwiftUI

struct RegisterView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var authService = AuthService.shared
    
    @State private var useEmail = true
    @State private var email = ""
    @State private var phone = ""
    @State private var displayName = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var errorMessage: String?
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Toggle between email and phone
                        Picker("Login Method", selection: $useEmail) {
                            Text("Email").tag(true)
                            Text("Phone").tag(false)
                        }
                        .pickerStyle(SegmentedPickerStyle())
                        
                        VStack(spacing: 16) {
                            TextField("Display Name", text: $displayName)
                                .textFieldStyle(DarkTextFieldStyle())
                                .textContentType(.name)
                            
                            if useEmail {
                                TextField("Email", text: $email)
                                    .textFieldStyle(DarkTextFieldStyle())
                                    .textContentType(.emailAddress)
                                    .autocapitalization(.none)
                                    .keyboardType(.emailAddress)
                            } else {
                                TextField("Phone Number", text: $phone)
                                    .textFieldStyle(DarkTextFieldStyle())
                                    .textContentType(.telephoneNumber)
                                    .keyboardType(.phonePad)
                            }
                            
                            SecureField("Password (min 8 chars)", text: $password)
                                .textFieldStyle(DarkTextFieldStyle())
                                .textContentType(.newPassword)
                            
                            SecureField("Confirm Password", text: $confirmPassword)
                                .textFieldStyle(DarkTextFieldStyle())
                                .textContentType(.newPassword)
                            
                            if let error = errorMessage {
                                Text(error)
                                    .font(.caption)
                                    .foregroundColor(.red)
                                    .multilineTextAlignment(.center)
                            }
                            
                            Button(action: register) {
                                HStack {
                                    if authService.isLoading {
                                        ProgressView()
                                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    } else {
                                        Text("Create Account")
                                            .fontWeight(.semibold)
                                    }
                                }
                                .frame(maxWidth: .infinity)
                                .frame(height: 50)
                                .background(Color.green)
                                .foregroundColor(.white)
                                .cornerRadius(12)
                            }
                            .disabled(authService.isLoading || !isFormValid)
                        }
                    }
                    .padding(24)
                }
            }
            .navigationTitle("Register")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(.blue)
                }
            }
        }
    }
    
    private var isFormValid: Bool {
        !displayName.isEmpty &&
        (useEmail ? !email.isEmpty : !phone.isEmpty) &&
        password.count >= 8 &&
        password == confirmPassword
    }
    
    private func register() {
        errorMessage = nil
        
        if password != confirmPassword {
            errorMessage = "Passwords do not match"
            return
        }
        
        Task {
            do {
                try await authService.register(
                    email: useEmail ? email : nil,
                    phone: useEmail ? nil : phone,
                    password: password,
                    displayName: displayName
                )
                dismiss()
            } catch let error as APIError {
                errorMessage = error.localizedDescription
            } catch {
                errorMessage = "Registration failed. Please try again."
            }
        }
    }
}
```

### Create Views/ExpenseSplitRow.swift

```swift
import SwiftUI

struct ExpenseSplitRow: View {
    let split: ExpenseSplit
    let expense: Expense
    let member: Member?
    let canMarkPaid: Bool
    let onTogglePaid: (Bool) -> Void
    let onViewHistory: () -> Void
    
    @State private var showingConfirmation = false
    @State private var showingReason = false
    @State private var reason = ""
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(member?.name ?? "Unknown")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text(formatCurrency(split.amount, currency: expense.currency))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Payment status badge
            HStack(spacing: 8) {
                if split.isPaid {
                    Label("Paid", systemImage: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundColor(.green)
                } else {
                    Label("Unpaid", systemImage: "clock")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
                
                if canMarkPaid {
                    Menu {
                        Button(action: {
                            showingReason = true
                        }) {
                            Label(
                                split.isPaid ? "Mark as Unpaid" : "Mark as Paid",
                                systemImage: split.isPaid ? "xmark.circle" : "checkmark.circle"
                            )
                        }
                        
                        Button(action: onViewHistory) {
                            Label("View History", systemImage: "clock.arrow.circlepath")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .foregroundColor(.blue)
                    }
                }
            }
        }
        .padding(.vertical, 8)
        .alert("Add a reason (optional)", isPresented: $showingReason) {
            TextField("Reason", text: $reason)
            Button("Cancel", role: .cancel) {
                reason = ""
            }
            Button(split.isPaid ? "Mark Unpaid" : "Mark Paid") {
                onTogglePaid(!split.isPaid)
                reason = ""
            }
        } message: {
            Text("This will be recorded in the payment history.")
        }
    }
    
    private func formatCurrency(_ amount: Decimal, currency: String) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currency
        return formatter.string(from: amount as NSDecimalNumber) ?? "\(amount)"
    }
}
```

### Create Views/PaymentHistoryView.swift

```swift
import SwiftUI

struct PaymentHistoryView: View {
    let splitId: UUID
    @StateObject private var budgetService = BudgetService.shared
    
    @State private var history: [PaymentHistory] = []
    @State private var isLoading = true
    @State private var error: String?
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()
                
                if isLoading {
                    ProgressView()
                } else if let error = error {
                    Text(error)
                        .foregroundColor(.red)
                } else if history.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "clock.arrow.circlepath")
                            .font(.largeTitle)
                            .foregroundColor(.gray)
                        Text("No payment history")
                            .foregroundColor(.secondary)
                    }
                } else {
                    List(history) { item in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Image(systemName: item.action == "marked_paid" ? "checkmark.circle.fill" : "xmark.circle.fill")
                                    .foregroundColor(item.action == "marked_paid" ? .green : .orange)
                                
                                Text(item.action == "marked_paid" ? "Marked as Paid" : "Marked as Unpaid")
                                    .fontWeight(.medium)
                            }
                            
                            Text("by \(item.performedByName ?? "Unknown")")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Text(formatDate(item.performedAt))
                                .font(.caption2)
                                .foregroundColor(.gray)
                            
                            if let reason = item.reason, !reason.isEmpty {
                                Text("Reason: \(reason)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .padding(.top, 4)
                            }
                        }
                        .padding(.vertical, 4)
                        .listRowBackground(Color(white: 0.1))
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Payment History")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                loadHistory()
            }
        }
    }
    
    private func loadHistory() {
        Task {
            do {
                history = try await budgetService.getPaymentHistory(splitId: splitId)
                isLoading = false
            } catch {
                self.error = error.localizedDescription
                isLoading = false
            }
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}
```

### Create Views/ContentView.swift (Main App)

```swift
import SwiftUI

struct ContentView: View {
    @StateObject private var authService = AuthService.shared
    
    var body: some View {
        Group {
            if authService.isAuthenticated {
                MainTabView()
            } else {
                LoginView()
            }
        }
        .animation(.easeInOut, value: authService.isAuthenticated)
    }
}

struct MainTabView: View {
    var body: some View {
        TabView {
            OverviewView()
                .tabItem {
                    Label("Overview", systemImage: "chart.pie")
                }
            
            AddExpenseView()
                .tabItem {
                    Label("Add", systemImage: "plus.circle")
                }
            
            ExpensesListView()
                .tabItem {
                    Label("Expenses", systemImage: "list.bullet.rectangle")
                }
            
            MembersView()
                .tabItem {
                    Label("Members", systemImage: "person.3")
                }
            
            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }
        }
        .accentColor(.blue)
    }
}
```

---

## 10. Testing & Deployment

### Test API Endpoints

```bash
# Test registration
curl -X POST https://linkup-event.com/budget-api/auth/register \
  -H "Content-Type: application/json" \
  -d '{"email":"test@example.com","password":"password123","displayName":"Test User"}'

# Test login with email
curl -X POST https://linkup-event.com/budget-api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"emailOrPhone":"test@example.com","password":"password123"}'

# Test login with phone
curl -X POST https://linkup-event.com/budget-api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"emailOrPhone":"60123456789","password":"password123"}'
```

### Xcode Build Settings

1. Set deployment target to iOS 15.0+
2. Add `NSAppTransportSecurity` exceptions if needed for testing
3. Configure signing for App Store distribution

### App Store Submission Checklist

- [ ] Privacy Policy URL configured
- [ ] App icon in all required sizes
- [ ] Launch screen configured
- [ ] Keychain sharing entitlement added
- [ ] Network usage description added to Info.plist

---

## Summary

### Database Tables Added

| Table | Purpose |
|-------|---------|
| `users` | User accounts with email/phone login |
| `auth_tokens` | JWT session management |
| `trip_groups` | Group trips together |
| `group_members` | Users in groups with roles |
| `members` | Trip members (linked to users) |
| `expenses` | Expense records with audit fields |
| `expense_splits` | Who owes what |
| `payment_history` | Audit trail for payments |

### Security Features

1. **Authentication**: JWT tokens, secure password hashing
2. **Authorization**: Role-based permissions (owner/admin/member/viewer)
3. **Audit Trail**: All payment changes logged
4. **Rate Limiting**: Prevents brute force attacks
5. **Permission Checks**: Only authorized users can mark payments

### API Endpoints

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/auth/register` | POST | Register new user |
| `/auth/login` | POST | Login (email or phone) |
| `/auth/logout` | POST | Logout (invalidate token) |
| `/auth/me` | GET | Get current user |
| `/api/expenses` | POST | Add expense |
| `/api/expenses/:id` | DELETE | Delete expense |
| `/api/expense-splits/:id/payment` | PATCH | Mark paid/unpaid |
| `/api/expense-splits/:id/history` | GET | View payment history |

---

## Need Help?

If you encounter issues:

1. Check API logs: `sudo journalctl -u budget-api -f`
2. Check PostgreSQL logs: `sudo journalctl -u postgresql -f`
3. Verify database tables: `sudo -u postgres psql -d budget_splitter -c "\dt"`
4. Test API locally: `curl http://localhost:3012/auth/me`
