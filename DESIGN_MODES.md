# Budget Splitter — Design Modes

Two modes with different storage. **Mode is switchable in Settings.** Cloud mode requires subscription.

## Overview

| Aspect | Local Mode | Cloud Mode |
|--------|------------|------------|
| **Login** | Not required | Required |
| **Storage** | Device (UserDefaults) | PostgreSQL on VPS |
| **Subscription** | Free | Required (paywall) |
| **Switch** | Settings → Switch to Local | Settings → Upgrade to Cloud |

## Switching in Settings

- **Local → Cloud**: Settings → "Upgrade to Cloud Sync" → Paywall (if not subscribed) → Login
- **Cloud → Local**: Settings → "Switch to Local Mode" → Free, no paywall

## Subscription Enforcement

Cloud mode is gated by `SubscriptionManager`:

```swift
// Services/SubscriptionManager.swift
static let debugBypassPaywall = true  // Set false to enforce paywall
```

- `true`: Cloud mode always allowed (testing)
- `false`: User must subscribe before using cloud

**StoreKit integration**: Replace `grantSubscription()` and `canUseCloudMode()` with your purchase/restore logic. See `PaywallView` and `SubscriptionManager`.

## Server

- **Local mode**: No server needed (device storage)
- **Cloud mode**: API at port 3012, database `budget_splitter`
