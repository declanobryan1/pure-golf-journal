# Build 12 — Setup + Test Guide

Last meaningful build before App Store push.

What's new since build 10:
- **Video uploads** on every rating + score flow (build 11)
- **Refine reset fix** — "Complete" no longer lingers after Reset Ratings
- **Manual override slider** on H2H rating result

---

## ⚠️ One-time setup BEFORE installing build 12

Build 12 won't work end-to-end until both of these are done.

### Setup 1 — Run the migration (1 min)

Open Terminal:
```bash
cat /Users/declanobryan/Claude/supabase/011_video_support.sql | pbcopy
```

Then in https://supabase.com/dashboard → your Pure project → SQL Editor → paste → **Run**.

Verify: Table Editor → `ratings` table should now have a `videos` column. Same for `imported_rounds`.

### Setup 2 — Create the Storage bucket + 3 RLS policies (5 min)

This is the critical one. Without it, video uploads will fail with a silent 403.

**Open** https://supabase.com/dashboard → your Pure project → **Storage** (left sidebar, database icon with a folder).

#### Step 2a — Create the bucket

Top-right → **New bucket**:
- **Name:** `pure-media` (exact, lowercase, with the hyphen)
- **Public bucket:** ✅ ON
- **File size limit:** `25 MB`
- **Allowed MIME types:** paste this exactly:
  ```
  image/jpeg, image/png, image/heic, image/webp, video/mp4, video/quicktime, video/x-m4v
  ```
- Click **Create bucket**

#### Step 2b — Add 3 RLS policies

Click into the bucket → **Policies** tab (top tabs).

You'll be adding 3 policies on the `objects` table. For each:
1. Click **New policy** → **For full customization** (skip the templates)
2. Fill in the fields below
3. Click **Review** → **Save policy**

**Policy 1 of 3** — Upload to own folder:
- **Policy name:** `Authenticated users can upload to own folder`
- **Allowed operation:** ✅ `INSERT` (only this one)
- **Target roles:** `authenticated`
- **WITH CHECK expression:**
  ```sql
  bucket_id = 'pure-media' AND (storage.foldername(name))[1] = auth.uid()::text
  ```

**Policy 2 of 3** — Delete own files:
- **Policy name:** `Authenticated users can delete own files`
- **Allowed operation:** ✅ `DELETE` (only this one)
- **Target roles:** `authenticated`
- **USING expression:**
  ```sql
  bucket_id = 'pure-media' AND (storage.foldername(name))[1] = auth.uid()::text
  ```

**Policy 3 of 3** — Public read:
- **Policy name:** `Public read pure-media`
- **Allowed operation:** ✅ `SELECT` (only this one)
- **Target roles:** `anon, authenticated`
- **USING expression:**
  ```sql
  bucket_id = 'pure-media'
  ```

#### Step 2c — Verify

Back in SQL Editor, run:
```sql
select id, public, file_size_limit
from storage.buckets
where id = 'pure-media';

select policyname, cmd
from pg_policies
where tablename = 'objects' and qual like '%pure-media%';
```

Should return: 1 bucket row + 3 policy rows (INSERT, DELETE, SELECT).

If you get fewer or different policies, re-do step 2b for the missing ones.

---

## Ship build 12

### 1. Sync the iOS bundle (~30 sec)

```bash
cd /Users/declanobryan/Claude && PATH="/opt/homebrew/bin:$PATH" npm run cap:sync
```

End with "Sync finished".

### 2. Open Xcode

```bash
open /Users/declanobryan/Claude/ios/App/App.xcworkspace
```

Wait for indexing (~10 sec).

### 3. Archive + upload

1. Click blue **App** icon (left sidebar top) → **General** tab → confirm **Build = 12**
2. Top device selector → make sure it says **"Any iOS Device (arm64)"** (not a simulator)
3. **Product → Clean Build Folder** (⇧⌘K)
4. **Product → Archive** (~3-5 min)
5. Organizer auto-opens → **Distribute App** → **App Store Connect** → **Upload**
6. Keep all defaults → click **Upload**
7. Wait for "Upload Successful" → **Done**

### 4. After Apple processing (~30-60 min)

You'll get an email when it's ready.

1. App Store Connect → TestFlight tab → build 12 will say **"Missing Compliance"**
2. Click into build 12 → answer encryption: **No** → **Save**
3. TestFlight auto-distributes to your Family and Friends group
4. Your phone gets the update notification

---

## What to test on build 12

### NEW: Video uploads (highest priority)

#### Test 1 — Upload a video on a new rating
1. **Rate any course** (any of: First Impression, Baseline, Head-to-Head)
2. On the result screen, scroll down to **Photos & Videos** section
3. Tap **"Add a photo or video"** → pick a video from your camera roll
4. **Expected:** "Uploading video..." spinner shows while it uploads (~3-15 sec)
5. **Expected:** Video tile appears with play icon overlay + duration badge ("12s")
6. Tap **Save** → reopen the rating → video tile still there
7. Tap the tile → fullscreen player opens with controls + autoplay

#### Test 2 — Upload a video on Quick Log
1. **+ Score** → pick a course → fill score → scroll to **Photos & Videos**
2. Same flow as above — video should upload + persist + play

#### Test 3 — Size cap
1. Try to upload a video > 25MB
2. **Expected:** red toast: "Video too large. Max 25MB — try trimming it in Photos first."

#### Test 4 — Cleanup on rating delete
1. Rate a course with a video → save
2. Set status to "Haven't played" (removes the rating)
3. **Expected (manual check):** in Supabase Storage → `pure-media` → your user folder → that video file is gone

#### Test 5 — Cleanup on Reset Ratings
1. Make sure you have a few ratings with videos
2. Settings → Reset my data → **Reset ratings + start over**
3. Confirm twice
4. **Expected (manual check):** Storage → `pure-media/${your-uid}` folder → empty

#### Test 6 — Friend sees your video
1. Have a friend rate a course → add a video → save
2. Open their friend profile or your activity feed
3. **Expected:** video tile appears with play overlay; tap to play
4. Both phones must be on build 12 for this to work

---

### Fix: Refine reset

1. Make sure refine is showing as "Complete" in Settings (you mentioned this happened)
2. Settings → Reset my data → **Reset ratings + start over** → confirm
3. After reload: Settings → Refine row
4. **Expected:** "No early ratings to refine" (NOT "Complete — your early ratings are refined")
5. Rate 15+ courses → refine prompt should appear normally

---

### NEW: Manual override slider

1. **Rate any course via Head-to-Head** (need 3+ already rated to unlock H2H)
2. On the result screen showing your score, scroll down past the comparison chips
3. Tap **"Adjust this rating"** button
4. **Expected:** slider appears pre-filled with the calculated score
5. Drag the slider — number above updates live
6. **Expected:** caption changes to "Pure suggested X.X — you adjusted to Y.Y"
7. Tap **"Reset"** → slider snaps back to calculated score
8. Save → the rating uses whatever value was on the slider when you saved
9. Reopen the rating → confirm it shows your adjusted number

#### Test 11 — Override during refine
1. Settings → Refine early ratings → start
2. After comparisons finish, you'll see the same result screen
3. **Adjust this rating** button works the same way
4. Save updated rating → check the rating actually got the adjusted value

---

## Known limitations / heads up

- **Video upload speed:** Depends on connection. 5MB video over LTE ≈ 5-10 sec, same on WiFi ≈ 2-4 sec.
- **First-time iOS video picker may ask for Photos permission:** Pure already has the descriptor in Info.plist, so the prompt should be the standard one.
- **HEVC videos from iPhone:** Safari/WKWebView handles MP4 + MOV natively. If a tester has an iPhone set to "Most Compatible" (Settings → Camera → Formats), videos are MP4 (works perfectly). If set to "High Efficiency" (HEIC/HEVC), uploads usually still work but playback may stutter on some Android browsers. iOS is fine.
- **Storage costs:** Supabase free tier = 1GB total. At 5MB avg per video, that's ~200 videos across ALL users before you'd hit the limit. Monitor in Dashboard → Storage → Usage. If approaching, set lower MIME limits or compress before upload.
- **Old builds won't see new fields:** Testers on build ≤10 will get build 12 via TestFlight; they won't see videos on rating cards from other build-10 users (you all need to update).

---

## If anything breaks

**Video upload fails silently** → 99% it's Setup 2 (Storage bucket / RLS policies). Double-check all 3 policies exist with the EXACT SQL above.

**Upload works but video doesn't play after save** → Policy 3 (SELECT / Public read) probably missing. Without it even the uploader can't read their own file back.

**Refine still says "Complete" after reset** → Quit the app completely (swipe up from app switcher) and reopen. The hotfix needed a fresh hydration.

**Override slider doesn't appear** → Make sure you're in Head-to-Head (rates 4+). First Impression + Baseline have their own sliders built-in already.

---

## After build 12 stabilizes

You're then in good shape for App Store submission. Pre-submission still-pending items:
- Custom domain + email forwarding setup (for `noreply@puregolfjournal.com` etc.)
- App Store screenshots
- Privacy policy hosted publicly (URL goes in App Store Connect)
- Final pre-launch QA pass on a fresh device

But the core app loop is complete: rate, score, refine, share, friend, video. Build 12 is the feature-complete v1.0 candidate.
