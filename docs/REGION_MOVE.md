# Moving the Supabase project from Mumbai to Ireland

A runbook for a one-off move, written 8 October 2026. The project's region is
fixed when it is created, so moving means a **new project in Ireland** and a
copy of everything into it. It is done on the **free plan**: Usman decided not
to pay for Supabase until PadiLearn has users, and nothing here needs a paid
plan.

Why: from Usman's laptop, Mumbai answers in about 350 ms and Ireland in about
175 ms, and every query the app makes pays that difference. It is cheapest
now, with 6 accounts and 43 files.

Ireland, not London: London was the first target, but the project first came
up in Ireland and on 9 October the two timed the same (Ireland 174 ms,
London 186 ms, best of five connects to Supabase's servers in each). Usman
chose to keep the Ireland project.

**Progress, 9 October:** steps 1 to 6 are done. The restore's counts matched
Mumbai's exactly, and all 43 files (50.2 MB) are in Ireland with matching
sizes. The dump is `~/padilearn-backups/20261009-110946`. Anything written
to Mumbai after 11:09 that day is not in Ireland.

The restore at first left Ireland **less locked down than Mumbai**: a new
project grants `anon` and `authenticated` everything on each object created
in `public`, and the dump only adds grants. 42 functions became callable
signed out and every column of `profiles` writable. Fixed the same day (82
revokes, Ireland's grants now identical to Mumbai's), `restore.sh` now
switches those defaults off first, and `counts.sql` compares grants too.
Next: step 7.

**Who does what.** Usman does anything that needs a password, a secret key or
a dashboard. Claude does the rest. The scripts read secrets from
`tool/region_move/.env`, which is git-ignored and filled in by Usman.

**Downtime.** None is needed, but anything written to the old project after
the dump (a sign-up, lesson progress) is not carried over. Pick a quiet hour.
Everyone signs in again afterwards, because the new project signs sessions
with its own keys.

---

## What moves, and how

| What | How | Who |
|---|---|---|
| Tables, functions, RLS policies, triggers in `public` and `private` | `dump.sh` + `restore.sh` (pg_dump, as `supabase db dump` runs it) | Usman runs |
| Accounts: emails, password hashes, Google/Apple identities, the admin's authenticator | Same data dump (the `auth` schema) | Usman runs |
| The sign-up trigger on `auth.users` and the 8 storage access rules | `auth_storage.sql`, applied by `restore.sh` | Usman runs |
| Realtime on `courses`, `enrollments`, `notifications` | Carried by the schema dump; checked by the counts | — |
| 17 image URLs naming the old host | `rewrite_urls.sql`, applied by `restore.sh` | Usman runs |
| Storage buckets and the 43 files | Buckets come with the data dump; files with `copy_storage.mjs` | Usman runs |
| Edge functions (5 deployed today) | Copied exactly as deployed, not from the repo (see step 6) | Claude |
| Edge function secrets | Dashboard | Usman |
| Auth settings, SMTP, email templates, MFA | Dashboard, by hand | Usman |
| The apps' Supabase URL and key | GitHub secrets, local config, redeploys, APK 1.0.2 | Usman + Claude |

Nothing else lives in the old project. Checked on 8 October: no cron jobs,
database webhooks, `pg_net`, Vault secrets or auth hooks; only Supabase's
default extensions; every account signs in by email.

---

## Steps

### 1. Create the new project (Usman)

Log in as the **company account** and create the project in its own
organisation, so the move also takes PadiLearn out of Usman's personal
account. Mumbai stays in "GroundworkTech" until step 10.

- Name `padilearn`, region **West EU (Ireland)**, `eu-west-1`. Done on
  9 October: the ref is **`bouhrbjdxxqeylrxxmdl`**.
- Generate a database password and keep it in your password manager. Don't
  paste it into chat.
- Plan: Free. The company login has its own two free projects; make sure it
  has no other active one.

Then tell Claude the new project's **ref** (the part before `.supabase.co`).
That is not a secret. Claude checks the region from the database's address
before anything is copied in.

### 2. Fill in `tool/region_move/.env` (Usman)

Copy `tool/region_move/env.example` to `tool/region_move/.env` and follow the
comments in it: both database URLs (Connect → Session pooler) and both service
keys (Project Settings → API Keys).

Two things that went wrong the first time: the **Direct connection** string
(`db.<ref>.supabase.co`) does not work from Usman's laptop, which has no
IPv6, so it must be the Session pooler one (`postgres.<ref>@aws-…pooler…`);
and the brackets in `[YOUR-PASSWORD]` go too.

### 3. Dump the old project (Usman)

In **Git Bash**, from the repo folder. `pg_dump` and `psql` 17 are installed
through MSYS2 and already on the PATH.

```bash
bash tool/region_move/dump.sh
```

It writes `schema.sql`, `data.sql` and `counts-old.txt` to
`~/padilearn-backups/<date-time>/`. That folder holds every account's email
and password hash, so keep it off the repo and off shared drives.

### 4. Restore into the new project (Usman)

```bash
bash tool/region_move/restore.sh
```

It runs everything in one transaction: if any statement fails, nothing is
written, and it can be run again after a fix. It ends by comparing row counts,
policies, functions, triggers and realtime tables between the two projects,
and says whether they match. If they don't, send Claude the output.

Errors Supabase's guide warns about, if they appear: a line
`ALTER ... OWNER TO "supabase_admin"` in `schema.sql` (comment it out), or an
`auth` or `storage` table that exists on one side only (the two projects run
different versions of Supabase's services; Claude adjusts the dump).

### 5. Copy the files (Usman)

```bash
node tool/region_move/copy_storage.mjs
```

It is safe to run again: uploads overwrite. It reports any file whose size
differs.

### 6. Edge functions (Claude)

**Done 9 October.** The plan below was to copy everything as deployed and
keep the Paystack switch for later. Paystack approved the company account
the same day, so Ireland got the **new** payment functions instead
(`initialize-payment`, `verify-payment`, and `paystack-webhook` with JWT
verification off), from the repo as of `a56e7d9`. The other three are
identical either way. Mumbai keeps the June ones until it is retired.

The original plan, for reference: each deployed function was compared with git on 8 October and matches one
commit exactly, so it is deployed from that commit
(`git show <commit>:supabase/functions/<name>/index.ts`):

| Function | Deployed | Commit |
|---|---|---|
| `initialize-payment` | v2 | `2d06c7f` |
| `verify-payment` | v5 | `52aa0fc` |
| `get-course-video` | v4 | `bd9356b` |
| `payout-account` | v2 | `bd9356b` |
| `delete-account` | v1 | `1e046bd` |

All with JWT verification on, as today. If anything is deployed to Mumbai
after 8 October, the versions above no longer match; compare again first.

- Claude deploys through the project-scoped Supabase server in `.mcp.json`,
  signed in with the company login. It sees only the new project, which is
  all this step needs.
- Then Usman copies each **secret** from the old project (Edge Functions →
  Secrets) to the new one: at least `PAYSTACK_SECRET_KEY`, and
  `PLATFORM_FEE_PERCENT` if it is set. `SUPABASE_URL` and the service key
  are provided automatically.

### 7. Dashboard settings on the new project (Usman)

Open the old project in another tab and copy across:

- **Authentication → URL Configuration.** Site URL `https://padilearn.com`,
  and the whole Redirect URLs list: at least `padilearn://reset-callback`,
  `https://padilearn.com/email-confirmed`, `https://app.padilearn.com` and
  `https://app.padilearn.com/*`.
- **Authentication → Emails → SMTP.** The Resend settings: sender
  `hello@padilearn.com`, name `PadiLearn`. The SMTP password is a Resend API
  key; make a new one in Resend if the old one isn't to hand.
- **Authentication → Emails → Templates.** Paste each file from
  `supabase/templates/`.
- **Authentication → Sign In / Providers.** Match the old project: email
  confirmation, password rules, and any providers switched on.
- **Authentication → Multi-Factor.** TOTP **on**: the admin panel cannot be
  entered without it.
- **Authentication → Rate Limits.** Match the old project.

### 8. Point the apps at Ireland (Usman + Claude)

- **GitHub** → Settings → Secrets → Actions: update `SUPABASE_URL` and
  `SUPABASE_PUBLISHABLE_KEY` (Usman).
- **Local** `lib/config/supabase_config.dart` (Claude, given the new URL and
  publishable key, which are public values).
- **Redeploy** both web apps: Actions → "Deploy web app" and "Deploy admin
  app" → Run workflow.
- **APK 1.0.2** (Claude): built with the new config, uploaded to
  `dl.padilearn.com` as in `LAUNCH_WEB.md`, and `website/src/site.ts`
  updated. **1.0.1 has Mumbai built in** and stops working when the old
  project is paused.

### 9. Check it end to end (both)

- Sign in on app.padilearn.com as a student, a teacher, and on
  admin.padilearn.com as the admin (authenticator code).
- Play a lesson (signed URL from `get-course-video`), open a course with a
  thumbnail, upload a profile photo.
- Post a comment and watch the teacher's notification bell update live.
- Request a password reset and receive the email; sign up a throwaway
  account and receive the confirmation.
- Claude re-runs the security and performance advisors on the new project.

### 10. Retire Mumbai (Usman, when step 9 passes)

Pause the old project first and keep it a week or two as a fallback. Then
delete it; a deletion cannot be undone. Pausing also frees its free-project
slot. Once it is deleted, "GroundworkTech" is empty and can be deleted too.

### 11. Afterwards (Claude)

Update the project ref in `docs/STATUS.md`, `docs/ADMIN_PANEL.md` (webhook
URL), `docs/LAUNCH_WEB.md`, `supabase/seed/demo_catalogue.sql` and memory,
and add a dev log entry.

---

## Staying on the free plan

What the free plan means for PadiLearn, and what covers each gap:

- **Uploads are capped at 50 MB per file.** Tell tutors to keep each lesson
  short and compressed (720p, exported with a web preset such as HandBrake's).
  A long lesson can be split in two. Revisit when tutors hit the limit.
- **A project with no activity for a week is paused.**
  `.github/workflows/keep-alive.yml` reads one category every three days.
  GitHub stops scheduled workflows in a repo with no commits for 60 days.
- **No automatic backups.** `bash tool/region_move/dump.sh` is also a backup
  script: run it monthly, and before any risky change, keeping the output out
  of the repo. Do not back up into GitHub Actions artifacts: the repo is
  public.
- **Leaked-password protection** is a paid feature and stays off.
- **Limits** (check the usage page monthly): 500 MB database, 1 GB storage,
  5 GB bandwidth a month. Video is what will reach the bandwidth limit first.
