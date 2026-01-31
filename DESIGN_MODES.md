# Budget Splitter — Design Modes

Two deployment modes with different storage and auth requirements.

## Overview

| Aspect | Local Mode | VPS Mode |
|--------|------------|----------|
| **Login** | Not required | Required |
| **Storage** | Device (UserDefaults) or SQLite | PostgreSQL on VPS |
| **Server** | Optional (local server at port 3012) | Required |
| **Sync** | None (device only) | Cloud sync |

## Local Version

- **Target**: Standalone use, development, offline.
- **Data**: Stored on device (UserDefaults). Can be upgraded to SQLite.
- **Flow**: App opens directly to main tabs (Overview, Add, Expenses, Members, Settings).
- **Settings**: Shows "Local Mode" indicator.
- **Build**: Set `USE_REMOTE_API=0` or omit.

### Optional: Local Server

Run the API in `MODE=local` for a dev/staging setup:

```bash
cd server && MODE=local npm start
```

The local server uses SQLite and exposes `/api/members`, `/api/expenses` with no auth. The iOS app can be configured to point at `http://<dev-machine-ip>:3012` when testing against the server.

## VPS Version

- **Target**: Production, multi-user, cloud sync.
- **Data**: PostgreSQL database `budget_splitter` on VPS.
- **Flow**: Login/Register → Main tabs → Logout in Settings.
- **Auth**: JWT tokens, bcrypt passwords.
- **Build**: Set `USE_REMOTE_API=1` and `API_BASE_URL=https://your-vps.com/budget-api`.

### Server Setup

```bash
# VPS
cd server
npm install
cp .env.example .env
# Edit: MODE=vps, DB_*, JWT_SECRET
pm2 start ecosystem.config.js --env vps
```

### Database

- Name: `budget_splitter`
- Port: 3012 (API)
- Schema: `server/database/schema.sql`

## Switching Modes

In Xcode, add a User-Defined Setting or Environment Variable:

- `USE_REMOTE_API` = `0` (Local) or `1` (VPS)
- `API_BASE_URL` = your VPS API URL (VPS only)

Or in `AppConfig.swift`, change the default for `useRemoteAPI`.
