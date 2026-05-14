# Push Notifications & Notifications Setup

This document covers everything that needs to be done **outside the codebase** to make the notifications + push system actually fire end-to-end.

The code (client-side registration, edge function, in-app inbox, triggers) is all written and committed. The remaining steps are configuration in Apple Developer portal, Xcode, and Supabase.

---

## 1. Run the database migration

In the Supabase Dashboard → SQL Editor (or via `supabase db push` locally):

```sql
-- Paste the contents of supabase/002_notifications_and_push.sql
```

This creates:
- `public.notifications` (the inbox)
- `public.device_tokens` (per-device APNs tokens)
- Three triggers that auto-create notifications on follow / reaction / tag

Verify in Studio → Table Editor that both tables exist with RLS enabled.

---

## 2. Enable Push Notifications capability on the bundle ID

Apple Developer portal → Certificates, IDs & Profiles → Identifiers → `com.declanobryan.puregolfjournal`:

1. Tick **Push Notifications** in the Capabilities list.
2. Save.

---

## 3. Generate an APNs Auth Key (.p8)

Apple Developer portal → Keys → "+" (Create a key):

1. Name: `Pure APNs Key` (or anything).
2. Tick **Apple Push Notifications service (APNs)**.
3. Continue → Register.
4. **Download the .p8 file immediately** — Apple only shows it once. Store securely (1Password / a vault).
5. Note the **Key ID** (10 chars, e.g. `K4F69888L9`).
6. Note your **Team ID** from the top-right of the portal (e.g. `L95DKW9826`).

---

## 4. Add Push Notifications to the Xcode project

In Xcode (`npm run cap:open`):

1. Click the **App** target → **Signing & Capabilities** tab.
2. Click **+ Capability** → search "Push Notifications" → add it.
3. Click **+ Capability** → search "Background Modes" → add it. Tick **Remote notifications**.
4. Save (Cmd+S).

(The `Info.plist` already includes `UIBackgroundModes` with `remote-notification` and `NSContactsUsageDescription` — no manual edits needed.)

---

## 5. Set the Edge Function secrets in Supabase

In the Supabase Dashboard → Edge Functions → Secrets (or via CLI):

```bash
supabase secrets set APNS_KEY_ID=K4F69888L9
supabase secrets set APNS_TEAM_ID=L95DKW9826
supabase secrets set APNS_BUNDLE_ID=com.declanobryan.puregolfjournal
supabase secrets set APNS_USE_SANDBOX=true   # while running from Xcode debug builds
# Paste the entire .p8 file contents (including BEGIN/END lines):
supabase secrets set APNS_KEY_P8="$(cat /path/to/AuthKey_K4F69888L9.p8)"
```

When you ship to TestFlight / App Store, set `APNS_USE_SANDBOX=false`.

The function also needs the standard Supabase env vars (`SUPABASE_URL`, `SUPABASE_SERVICE_ROLE_KEY`) — those are auto-populated by Supabase.

---

## 6. Deploy the Edge Function

From the repo root:

```bash
supabase functions deploy push-notify --no-verify-jwt
```

(`--no-verify-jwt` because the database webhook calls the function directly, not via an end-user JWT.)

---

## 7. Wire the database webhook → edge function

In the Supabase Dashboard → Database → Webhooks → Create:

- **Name:** `push-on-notification-insert`
- **Table:** `public.notifications`
- **Events:** ✓ Insert (only)
- **HTTP request type:** POST
- **URL:** `https://<your-project>.functions.supabase.co/push-notify`
- **HTTP headers:** `Authorization: Bearer <SUPABASE_SERVICE_ROLE_KEY>`
- **Payload:** Default (full row)

Save. Now every notification row inserted by the triggers will fire a push to the recipient's iOS devices.

---

## 8. Test the flow end-to-end

1. Sign in to Pure on a real iPhone (push doesn't work in the simulator).
2. The iOS prompt should ask for notification permission on first launch — accept.
3. Confirm in Supabase Studio → `device_tokens` table that a row appeared for your user.
4. From a **second** account (web is fine), follow your account.
5. Within a few seconds, your iPhone should receive a "New follower" push, and the bell icon in Pure should show the unread dot.

If push doesn't arrive but the in-app notification did:
- Edge Function logs (`supabase functions logs push-notify`) will show the APNs response.
- Common causes: `APNS_USE_SANDBOX` mismatched (sandbox=Xcode debug, prod=TestFlight/App Store), expired/revoked .p8, wrong Team ID, push capability not actually enabled in Xcode signing.

---

## What the code already does (no further setup needed)

- ✅ Captures the device token on first launch via `@capacitor/push-notifications` and writes it to `device_tokens`.
- ✅ Listens for tapped pushes from lockscreen → opens the inbox.
- ✅ Renders the bell icon in the top-right of every tab with unread dot.
- ✅ Realtime subscription updates the inbox + dot live (works even without push being fully wired — useful for testing in-app first).
- ✅ Marks all visible notifications read on inbox open.
- ✅ Per-row dismiss button.
- ✅ DB triggers fan out notifications on follow / reaction / comment / tag (sub_name-aware).
