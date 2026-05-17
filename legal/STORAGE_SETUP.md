# Supabase Storage Setup — `pure-media` bucket

Build 11 adds video upload support. Videos can't go in Postgres JSONB columns
(too big) — they go in **Supabase Storage**. The app uploads the file, gets back
a URL, and stores only the URL in the `ratings.videos` / `imported_rounds.videos`
column.

You need to create the storage bucket + RLS policies manually in the Supabase
Dashboard. This takes about 5 minutes.

---

## Step 1: Create the bucket

1. Open https://supabase.com/dashboard/project/kririlpmfsgvgklhykkr
2. Left sidebar → **Storage** (database icon with a folder)
3. Click **Create bucket** (top right)
4. Fill in:
   - **Name:** `pure-media`
   - **Public bucket:** ✅ ON (videos are visible to anyone with the URL — RLS on the parent rating row controls who can fetch the URL)
   - **File size limit:** `25 MB` (per file)
   - **Allowed MIME types:** `image/jpeg, image/png, image/heic, image/webp, video/mp4, video/quicktime, video/x-m4v`
5. Click **Create**

---

## Step 2: Add RLS policies

Once the bucket exists, click into it → **Policies** tab (top right).

You need 3 policies for the `objects` table on this bucket:

### Policy 1 — Authenticated users can upload to their own folder

- Click **New policy** → **For full customization** (skip the templates)
- **Policy name:** `Authenticated users can upload to own folder`
- **Allowed operation:** `INSERT`
- **Target roles:** `authenticated`
- **WITH CHECK expression:**
  ```sql
  bucket_id = 'pure-media' AND (storage.foldername(name))[1] = auth.uid()::text
  ```
- Click **Review** → **Save policy**

### Policy 2 — Authenticated users can delete their own files

- **New policy** → **For full customization**
- **Policy name:** `Authenticated users can delete own files`
- **Allowed operation:** `DELETE`
- **Target roles:** `authenticated`
- **USING expression:**
  ```sql
  bucket_id = 'pure-media' AND (storage.foldername(name))[1] = auth.uid()::text
  ```
- **Save policy**

### Policy 3 — Public read

- **New policy** → **For full customization**
- **Policy name:** `Public read pure-media`
- **Allowed operation:** `SELECT`
- **Target roles:** `anon, authenticated`
- **USING expression:**
  ```sql
  bucket_id = 'pure-media'
  ```
- **Save policy**

---

## Step 3: Verify

In the SQL Editor, run this to confirm the bucket + policies exist:

```sql
select id, name, public, file_size_limit, allowed_mime_types
from storage.buckets
where id = 'pure-media';

select policyname, cmd
from pg_policies
where tablename = 'objects' and qual like '%pure-media%';
```

Should show 1 bucket row + 3 policy rows (INSERT, DELETE, SELECT).

---

## How the app uses it

File paths follow this structure:
```
${user_id}/${timestamp}-${random}.mp4
```

Example: `a1b2c3d4-.../1730412345678-x7k9.mp4`

The `(storage.foldername(name))[1] = auth.uid()::text` policy means a user can
only upload/delete files in their own folder. Public read means anyone with
the URL can fetch it (which is fine — the URL is only ever shared via a rating
or round that has its own RLS).

---

## When you might want to revisit

- **Storage costs:** Supabase free tier includes 1GB. At average 5MB per video, that's ~200 videos total across all users. Monitor in Dashboard → Storage → Usage.
- **CDN caching:** Pure videos go through Supabase's built-in CDN. No extra setup.
- **Cleanup:** The app handles orphaned video deletion when a rating is removed (see `dbDeleteVideo` in index.html). If you ever do mass deletes via SQL, also clean up the storage files manually.

---

## Troubleshooting

**Upload fails with 403:** Policy 1 (INSERT) probably isn't right. Re-check the WITH CHECK expression matches above exactly.

**Upload fails with 413 (Payload Too Large):** File exceeded 25MB cap. App should warn before reaching this, but double-check the bucket's file size limit setting.

**Video doesn't play after upload:** Check the URL works directly in a browser. If not, check Policy 3 (SELECT) is in place — without it, even the uploader can't see their own video.

**HEIC photos won't upload:** Add `image/heic` to the bucket's allowed MIME types if you didn't include it in step 1.
