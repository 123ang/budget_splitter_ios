# Budget Splitter API Reference

Server deployed at **https://splitx.suntzutechnologies.com** (port 3012).

For full API docs, see [budget_splitter_web/API.md](../budget_splitter_web/API.md).

---

## Base URL & Auth

| Item | Value |
|------|-------|
| **Base URL** | `https://splitx.suntzutechnologies.com` |
| **Auth (VPS)** | JWT: `Authorization: Bearer <token>` |
| **Content-Type** | `application/json` |

---

## Quick Endpoint List

### VPS Mode (Cloud sync – deployed)

| Method | Path | Auth | Description |
|--------|------|------|-------------|
| POST | `/auth/register` | No | Register |
| POST | `/auth/login` | No | Login |
| GET | `/auth/me` | Bearer | Current user |
| POST | `/auth/logout` | Bearer | Logout |
| GET | `/api/groups` | Bearer | List groups |
| GET | `/api/groups/:groupId/members` | Bearer | List members |
| GET | `/api/groups/:groupId/expenses` | Bearer | List expenses |
| POST | `/api/expenses` | Bearer | Add expense |
| DELETE | `/api/expenses/:expenseId` | Bearer | Delete expense |
| PATCH | `/api/expense-splits/:splitId/payment` | Bearer | Mark paid/unpaid |
| GET | `/api/expense-splits/:splitId/history` | Bearer | Payment history |

### Local Mode (No auth – dev/staging)

| Method | Path | Description |
|--------|------|-------------|
| GET | `/api/members` | List members |
| POST | `/api/members` | Add member |
| DELETE | `/api/members/:id` | Remove member |
| POST | `/api/members/reset` | Reset to defaults |
| GET | `/api/expenses` | List expenses |
| POST | `/api/expenses` | Add expense |
| DELETE | `/api/expenses/:id` | Delete expense |
| GET | `/api/summary` | Summary stats |

### Common

| Method | Path | Description |
|--------|------|-------------|
| GET | `/health` | Health check |

---

## iOS App Config

Set `API_BASE_URL` to `https://splitx.suntzutechnologies.com` in `AppConfig.swift` or Info.plist for cloud mode.
