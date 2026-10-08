# PadiLearn admin panel

The plan for a back office: what it covers, where it lives, how it is secured,
and the order it is being built in. Scoped 6 October 2026. Pair it with
`PRODUCT_OVERVIEW.md` (what PadiLearn is) and `DEVLOG.md` (why things are the
way they are).

**This is a working document.** The build order below is a checklist; tick an
item when it is applied to the live project, and add the decision that
unblocked it.

---

## Why now

Until this, PadiLearn had no notion of an admin. No role, no table, no claim,
no RPC. Supabase Studio *was* the admin panel: the `content_reports` migration
says reports are "worked from the dashboard". That works for one operator with
six accounts, and stops working on the day a second person needs access,
because Studio access is the whole database.

What the live project held when this was written:

| | |
|---|---|
| Accounts | 6 (3 teachers, 3 students) |
| Courses | 13, none archived |
| Enrolments | 2 |
| Transactions | 1 (Paystack test mode) |
| Payout accounts | 0 |
| Content reports | 0 |
| Category suggestions awaiting approval | 1 |

Web checkout is live (`kPaidCheckoutEnabled` is on for web), and
`LAUNCH_WEB.md` says teacher payouts "must work before the first real sale".
Nothing records a payout today.

### Three holes found while scoping

These exist whether or not a panel is ever built.

1. **A takedown can be undone by the teacher.** The only way to hide a course
   is `archived_at`, and teachers hold `UPDATE (archived_at)` on their own
   courses. Archive one from Studio for a policy breach and its owner can
   un-archive it from the app.
2. **A role can never be corrected.** `claim_role()` only works while
   `role is null`, so a teacher who tapped "Student" by mistake is stuck
   without raw SQL.
3. **Category suggestions have no approval path.** Teachers can suggest one
   (`is_active = false`), and one is waiting. Approving it needs Studio.

Also noticed: `initialize-payment` reads the course with the service role and
never checks `archived_at`, so an archived course can still be bought by anyone
who has its id. The app cannot reach that path (RLS hides the course), but a
crafted call can. Item 2 below fixes it alongside takedowns.

---

## Where it lives

A **second Flutter web entrypoint**, `lib/admin/main.dart`, built separately
and deployed to **admin.padilearn.com** as its own Cloudflare Pages project,
with **Cloudflare Access** in front.

- It reuses the Supabase client, models and the CI workflow that already
  builds app.padilearn.com. No second stack to keep alive.
- A separate entrypoint means tree-shaking keeps every admin screen out of the
  public app's bundle.
- Cloudflare Access (free tier) puts an email-verified gate in front of the
  page before it loads. Nobody else reaches the login form.

Rejected:

- **Admin screens inside app.padilearn.com.** Ships admin UI to every user and
  mixes two audiences in one router.
- **A separate React or Astro app.** A second framework for one maintainer.
- **Studio forever.** Fine for one person, but no audit trail, and the only way
  to delegate it is to hand over the database.

---

## Security model

Four rules. Every admin feature must follow all of them.

1. **Admins are rows in `public.admins`.** Clients have no grants on it and no
   policy exposes it. Not a value in `profiles.role` (profiles are readable by
   every signed-in user, and the app's role branching would misroute an
   unknown value). Not a JWT claim (revoking it would wait for the token to
   expire; deleting a row takes effect immediately).
2. **`public.is_admin()` is the only check, and it requires a second
   factor.** It is true only when the caller is in `admins` *and* the session
   is `aal2` (TOTP verified). A leaked password alone gets nothing.
3. **Admin writes go through security-definer RPCs.** Each one starts with
   `perform public.assert_admin();` and records itself with
   `public.log_admin_action(...)` in the same transaction, so the audit log can
   neither miss a committed action nor record one that rolled back.
4. **The service-role key never reaches a browser.** Anything that ever needs
   Supabase's auth admin API lives in an edge function that checks
   `is_admin()` with the *caller's* JWT before using the service role.
   (Suspension, which was going to be the first, ended up in SQL instead:
   item 10.)

Supabase's security advisor flags every admin RPC as "Signed-in users can
execute SECURITY DEFINER function". That is intended: `assert_admin()` inside
is the gate, and execute is revoked from `anon`. Do not "fix" it by revoking
from `authenticated`, or the admin app cannot call anything.

Admin reads may use plain `SELECT` policies of the form
`using ((select public.is_admin()))`, added as *separate* policies so the
consumer policies stay untouched.

### Managing admins

There is deliberately no RPC for this. From the SQL editor:

```sql
-- Grant
insert into public.admins (user_id, note)
select id, 'founder' from auth.users where email = 'someone@example.com';

-- Revoke (effective on the next request)
delete from public.admins where user_id = '<uuid>';
```

The account then needs a TOTP factor enrolled before `is_admin()` will answer
true. The admin app enrols one on first sign-in.

---

## Build order

### Phase A: database

Ordered by risk, not by convenience. Each item is one migration in
`supabase/migrations/`, applied to the live project under the same name, with
a `DEVLOG.md` entry.

- [x] **1. Admin foundation.** `admins`, `is_admin()`, `assert_admin()`,
  `admin_actions` (append-only audit log), `log_admin_action()`. Everything
  else depends on it.
  *Applied 2026-10-06 (`20261006000001_admin_foundation.sql`). 15 role-
  simulated checks passed in a rolled-back transaction.* First admin,
  **hello@padilearn.com**, granted 2026-10-06. It has no TOTP factor yet, so
  `is_admin()` stays false for it until the admin app (item 11) enrols one.

- [x] **2. Takedowns a teacher cannot undo.** `courses.removed_at`,
  `removed_reason`, written only by `admin_remove_course()` /
  `admin_restore_course()`, both requiring a reason. Removed courses vanish
  from discovery but still resolve for their owner and enrolled students, so
  nobody's library breaks; `get-course-video` refuses to play them (previews
  included) for anyone but the owner, with a message pointing paying students
  to hello@padilearn.com. `admin_remove_course()` returns how many paid sales
  are owed refunds. Also narrows `courses` INSERT to the columns the app sends,
  which closes a teacher creating a course with invented `enrollments` or
  ratings.
  *Applied 2026-10-06 (`20261006000002_course_takedowns.sql`) and
  `get-course-video` deployed as version 3. 20 role-simulated checks passed on
  the live schema in a rolled-back transaction; the function was smoke-tested
  and boots.*
  The `initialize-payment` refusal of removed/archived courses is written but
  **held**: see "Live payment functions" below.

- [x] **3. Reports queue.** `admin_list_reports(status)`: one row per report
  with the snapshot *and* the content as it is now, the people involved, and
  how many open reports share its target. `admin_delete_comment()` and
  `admin_remove_course()` close every open report on what they act on (ten
  reports on one comment are one decision); `admin_set_report_status()`
  dismisses, marks actioned or reopens, always with a reason. Reports gain
  `resolved_by` and `resolution_note`. Also closes the same insert-grant gap
  `courses` had: `content_reports` still held table-wide INSERT, so the
  migration's five-column grant had never narrowed anything. Comes straight
  after takedowns because Play's user-generated content policy expects reports
  to be acted on, and the two are the same workflow.
  *Applied 2026-10-06 (`20261006000003_reports_queue.sql`). 22 role-simulated
  checks passed on the live schema in a rolled-back transaction, including
  the real admin account being refused without its second factor.*

- [x] **4. Refund records.** Promoted from version 2 by decision 2: a
  takedown now creates refund debts. New `refunds` table, one row per refunded
  sale, with the split computed from the ledger per decision 4, never typed:
  `amount_kobo` (the whole charge, back to the student),
  `teacher_clawback_kobo` (the teacher's whole share) and a generated
  `platform_cost_kobo` (commission plus Paystack's kept fee).
  `admin_refunds_owed()` lists paid sales of taken-down courses with no refund
  yet, including the buyer's email; `admin_record_refund(transaction,
  paystack_reference, reason)` records one *after* it is issued in the
  Paystack dashboard, and removes the buyer's enrolment so a course restored
  on appeal does not hand them both; `admin_list_refunds()`. `transactions` is
  untouched, so the ledger stays append-only. Only takedown refunds for now;
  other refunds need a policy (version 2). Comes before payouts because a
  teacher's balance must not include refunded sales.
  *Applied 2026-10-06 (`20261006000004_refund_records.sql`). 16 role-simulated
  checks passed on the live schema in a rolled-back transaction; on the real
  test sale the split came out ₦5,177.67 / ₦4,250 / ₦927.67.*
  Known gaps at the time, both since closed:
  - The teacher earnings screen summed `transactions` and ignored clawbacks.
    Fixed by item 13 (`my_teacher_balance()`).
  - Deleting a course with students was blocked only in the app.
    `20261007000002` now refuses it in the database for API callers, while
    leaving account deletion's cascade alone.

- [x] **5. Payouts ledger.** New `payouts` table: teacher, amount in kobo, a
  copy of the bank account it went to, a unique transfer reference, paid_at,
  recorded_by. One shared balance definition (`teacher_balance_rows()`, internal)
  feeds both `admin_teacher_balances()` and the check in
  `admin_record_payout()`, so the number an admin sees is the number a payout
  is checked against:
  balance = teacher share of every sale − refund clawbacks − payouts;
  pending = unrefunded sales younger than `payout_hold()` (7 days);
  available = balance − pending. Rules per decision 5. `admin_list_payouts()`.
  Records manual transfers now; automated Paystack Transfers come later, once
  the marketplace compliance review decides the structure.
  *Applied 2026-10-06 (`20261006000005_payouts_ledger.sql`). 18 checks as a
  dry run and 17 after applying, all rolled back: today's real sale showed as
  pending and unpayable, a synthetic 10-day-old sale became payable, and a
  refund after a payout took the balance to −₦1,500, which blocked further
  payouts.*

- [x] **6. Role correction.** `admin_set_role(user_id, role, reason)` sets
  Student or Teacher, or clears the role so the user picks again through
  `claim_role()` on their next launch. Refuses to demote or clear a teacher
  who owns courses, which the student shell cannot manage. Ranked below the
  money because the workaround is one line of SQL.
  *Applied 2026-10-06 (`20261006000006_role_correction.sql`). 14 checks
  passed as a dry run and again after applying, rolled back each time.*

- [x] **7. Category approval.** `admin_list_categories()` (pending
  suggestions first, with how many courses use each);
  `admin_set_category_active()` approves or switches off;
  `admin_update_category()` renames (cascades to courses through the existing
  foreign key) or reorders; `admin_delete_category(id, move_to)` rejects a
  suggestion or merges a duplicate into the real category, and requires a
  target whenever courses use it. Names are compared case-insensitively, so
  "design" cannot be approved next to "Design". Reasons are optional here:
  these are low-stakes. Pending on 2026-10-06: "Philosophy", no courses.
  *Applied 2026-10-06 (`20261006000007_category_admin.sql`). 17 checks as a
  dry run and 14 after applying, rolled back each time.*

- [x] **8. User lookup.** `admin_search_users(query)` matches part of an
  email or name (case-insensitive, LIKE wildcards escaped) or an exact id;
  an empty query lists the newest accounts. `admin_user_detail(user_id)`
  returns one JSON document for the detail page. Account: email, sign-up,
  last sign-in, confirmation, ban, providers, second factors, admin.
  Teaching: courses with takedown state, balance, payout account (last four
  digits only). Learning: enrolments, purchases with refund state. Conduct:
  reports filed and against, admin actions on the user. Read-only, so not
  logged.
  *Applied 2026-10-06 (`20261006000008_user_lookup.sql`). 15 checks as a dry
  run and 12 after applying, rolled back each time.*

- [x] **9. Overview.** `admin_overview()`, one JSON document for the first
  screen. *Waiting*: open reports, category suggestions, refunds owed, teachers
  payable (and how many of those have no verified bank account). *Accounts*:
  by role, new in 7 and 30 days, suspended, admins. *Catalogue*: live,
  archived, taken down, paid, lessons. *Learning*: enrolments. *Money*: gross,
  fees, teacher earnings, refunds and what they cost PadiLearn, PadiLearn's net
  (commission less refund cost), payouts, and what teachers are owed, payable,
  pending or negative. Teacher figures come from `teacher_balance_rows()` and
  refunds owed use the same rule as `admin_refunds_owed()`, so the overview
  cannot disagree with the detail screens.
  *Applied 2026-10-06 (`20261006000009_admin_overview.sql`), verified before
  and after applying, rolled back each time. Phase A complete.*

  **Performance, before scale.** After Phase A the performance advisor
  reports, mostly from before this work:
  - 27 RLS policies that call `auth.uid()` per row instead of
    `(select auth.uid())`.
  - 14 foreign keys without an index, four of them new today:
    `admin_actions.admin_id`, `content_reports.resolved_by`,
    `payouts.recorded_by` and `refunds.recorded_by`.
  - Two permissive SELECT policies on `courses`: the consumer policy and
    "Admins can see every course".

  None of it matters at this size. Fix it in one pass before traffic does.
  *Done 2026-10-07 in `20261007000003` and `20261007000004`:*
  - **Policies.** All 27 now use `(select auth.uid())`. The statements were
    generated from the live definitions and checked: what each of the 7
    accounts can see in 12 tables was identical before and after.
  - **Indexes.** All 15 foreign keys are indexed, including
    `suspensions.suspended_by`, which arrived later.
  - **Left alone.** The multiple permissive policies, on purpose.

### Phase B: account suspension

- [x] **10. Suspension.** Redesigned by decision 6. The original plan was an
  `admin-users` function using Supabase's auth ban, but a ban blocks sign-in,
  which was not wanted. Instead:
  - **Who is suspended.** A `suspensions` row per suspended user. They can
    read their own reason, but not who suspended them.
  - **The check.** `private.is_suspended()` lives in a `private` schema that
    PostgREST does not expose, so policies can call it and the API cannot.
  - **Blocked writes.** 19 restrictive policies, one per blocked write, so no
    existing policy is touched. INSERT and UPDATE fail loudly; DELETE silently
    matches nothing.
  - **Catalogue.** The course select policy drops a suspended teacher's
    courses from discovery. Enrolled students keep them.
  - **Admin actions.** `admin_suspend_user()` refuses admins;
    `admin_lift_suspension()` needs a reason.
  - **Payouts held.** `admin_record_payout()` refuses while the teacher is
    suspended.
  - **Admin screens.** Balances, search, user detail and the overview all
    show suspension.
  - **Server functions.** `get-course-video` refuses previews of a suspended
    teacher's courses, and `payout-account` refuses saving bank details.
    Both are deployed with the migration. `initialize-payment` refuses a
    suspended buyer or seller, but waits for the payments deploy.

  The rules apply on the next request, with no token lag.
  *Applied 2026-10-06 (`20261006000010_account_suspension.sql`).
  `get-course-video` is now version 4 and `payout-account` version 2, both
  smoke-tested. 34 checks as a dry run and 18 after applying, rolled back.
  PostgREST confirmed `private` is not exposed (`PGRST106`: only `public` and
  `graphql_public`).*

### Phase C: admin app

- [x] **11. Shell.** `lib/admin/main.dart`, email sign-in, TOTP enrol and
  challenge, refuses to render anything until `is_admin()` is true.
  *Verified 2026-10-07: hello@padilearn.com signed in, enrolled an
  authenticator and passed the code. The database shows one verified TOTP
  factor, no leftover unverified one, and a session with a `totp`
  authentication method. Written 2026-10-07:*
  - **The gate.** `admin_gate.dart` decides each step from the session
    alone:
    - no session: sign in;
    - password only, no authenticator: set one up;
    - password only, an authenticator: enter its code;
    - code passed: call `is_admin()`, then show the panel or "not an admin".
    It re-decides on sign-in, sign-out and verification, and a newer decision
    beats one still in flight.
  - **Setup.** The enrol screen clears any abandoned, unverified factor
    first. It shows the QR code (via `qr_flutter`, the only new dependency)
    and the key as text.
  - **Lost authenticator.** There is deliberately no self-service reset: the
    factor is removed in the Supabase dashboard.
  - **The shell.** Navigation for every section, with the signed-in email and
    sign-out. Overview lists what is waiting, which proves the whole chain.
  - **Running it locally.** The `admin` entry in `.claude/launch.json` runs
    `flutter run -d web-server -t lib/admin/main.dart` on port 5180.

  Needs TOTP enabled under Authentication → Multi-Factor in the dashboard.
- [x] **12. Screens.** Built one at a time, in the same priority order as the
  database work. Each is checked against the live project before the next.
  - [x] **12a. Overview**, plus the shared pieces every screen uses: the RPC
    wrapper with readable errors, NGN-to-the-kobo formatting, cards, and the
    load/error/retry frame. Waiting items link to their screens.
    *Built 2026-10-07:*
    - **What is shared.** `data/admin_api.dart` holds every call and turns
      errors into words: 42501 means "sign in again".
      `widgets/format.dart` has `formatKobo` (NGN 5,177.67) and
      `formatWhen`. `widgets/panel.dart` has `AdminCard`, `StatRow` and
      `AdminLoader`. `shell/sections.dart` holds the section enum that
      screens link by.
    - **The test.** `test/admin_overview_test.dart` renders the screen at
      laptop size from the document the live project returned, checks every
      kobo figure, checks a waiting item opens its screen, and checks a
      refused call explains itself and retries. It caught two bugs in
      `AdminLoader.reload()` before anyone saw them.
  - [x] **12b. Reports queue.** Act on, dismiss or reopen a report; delete a
    comment; take a course down from its report.
    *Built 2026-10-07:*
    - **Layout.** Tabs for open, dealt with and dismissed. Each card shows
      the reported text and, if it changed since, what it says now; who
      reported it and who wrote it; how many open reports share the target;
      and, once resolved, by whom and why.
    - **Actions.** Every action asks for a reason in a dialog whose confirm
      button stays disabled until one is typed, and the list reloads from the
      database afterwards. Taking a course down says how many paid sales it
      just made refundable.
    - **What changed underneath.** `AdminApi` became an instance that every
      screen takes, so tests pass `FakeAdminApi` (`test/admin_fakes.dart`).
      Report reasons reuse the app's `ReportReason` labels.
    - **Tests.** `test/admin_reports_test.dart` pins what each button sends,
      and that backing out sends nothing.
  - [x] **12c. Users.** Search, the detail page, correct a role, suspend or
    lift a suspension.
    *Built 2026-10-07:*
    - **Layout.** Search on the left (debounced; empty lists the newest),
      the selected account on the right, or as its own page on a narrow
      window. Badges show role, admin, suspended and unconfirmed email.
    - **The detail page.** Sections for account, teaching (courses with
      their state, balance, bank account's last four digits), learning
      (enrolments, purchases with refund state) and conduct (reports filed
      and against, admin actions on the account).
    - **Actions.** An admin has no Suspend button; a suspended account shows
      its reason and offers Lift instead. Change role picks Student, Teacher,
      or "let them choose" (null).
    - **Tests.** `test/admin_users_test.dart`, with fixtures in the shape the
      live `admin_user_detail()` returned.
  - [x] **12d. Courses.** Every course including archived and taken-down
    ones; take down or restore.
    *Built 2026-10-07:*
    - **Reading.** Courses are read straight from the table through "Admins
      can see every course", with teachers' names from a second `profiles`
      lookup, because `courses.user_id` points at auth.users. No migration
      was needed.
    - **Filters.** All, live, archived (the teacher's) and taken down
      (PadiLearn's), with search across title, teacher and category.
    - **Shared wording.** The takedown question and its result sentence moved
      to `widgets/course_actions.dart`, so Reports and Courses say the same
      thing. Tests: `test/admin_courses_test.dart`.
  - [x] **12e. Refunds.** What is owed, record a refund, refunds recorded.
    *Built 2026-10-07:* the owed tab lists each paid sale of a taken-down
    course with the buyer's email, the Paystack payment reference to find it
    by, and the split the database computes. Recording asks for Paystack's
    refund reference and a reason, both required. Tests:
    `test/admin_refunds_test.dart`.
  - [x] **12f. Payouts.** Teacher balances, record a payout, payouts made.
    *Built 2026-10-07:*
    - **Balances.** Each teacher's balance with the full account number to
      copy into a transfer.
    - **The record button.** Offered only when the database would accept the
      payout. Otherwise the card says which rule is in the way: suspended,
      inside the 7-day hold, nothing payable, or no verified account.
    - **The amount.** Prefilled with everything payable. `parseNairaToKobo`
      refuses anything it cannot read exactly, including a third decimal,
      rather than rounding.
    - **Tests.** `test/admin_payouts_test.dart`. They caught Dart's
      `RegExp` rejecting the inline `(?i)` flag, which made the parser throw
      on every input.
  - [x] **12g. Categories.** Approve, rename, reorder, merge or delete.
    *Built 2026-10-07:*
    - **Layout.** Categories the app does not show (suggestions, with who
      suggested them, and anything switched off) come first, then the live
      ones in display order.
    - **Actions.** Approve and switch off are one click, each undoing the
      other. Edit sends only the fields that changed. Delete cannot be
      confirmed without a destination while any course uses the category.
    - **Tests.** `test/admin_categories_test.dart`.
  - [x] **12h. Audit log.** Every admin action, newest first.
    *Built 2026-10-07:*
    - **Reading.** Read through "Admins can read the audit log", with admin
      names from `profiles`.
    - **Display.** Actions in words ("Took a course down"), filter chips by
      area, and details on expand with kobo shown as money.
    - **Read-only by design.** The shell's section switch is now exhaustive,
      so a section without a screen fails to compile. Tests:
      `test/admin_audit_log_test.dart`.

  *Item 12 complete 2026-10-07. All eight screens are built and each is
  covered by widget tests (92 tests in the suite). The two direct-table reads
  (courses, audit log) were checked against the live project under an admin
  session.*
- [x] **13. Show the back office's effects in the main app.**
  *Done 2026-10-07:*
  - **Earnings.** The teacher's earnings card now reads
    `my_teacher_balance()` (migration `20261007000001`, applied and verified
    live). It shows earnings net of refunds, plus a line for paid out, ready
    and clearing, or "on hold" while suspended. The function refuses a call
    without a signed-in user, because `teacher_balance_rows(null)` returns
    every teacher.
  - **Takedowns.** `CourseStatusChip` gains a "Taken down" state, which wins
    over archived. The teacher's course page shows the reason and the appeal
    address, and the "Live" filter in My courses excludes taken-down courses.
    Students already get a clear message from `get-course-video` when they
    press play.
  - **Suspension.** `SuspensionFrame` wraps the home shell's tabs: invisible
    normally, a banner with the reason and appeal address when suspended.
  - **Delete.** `CourseService.delete` asks for the deleted row back and
    fails clearly when RLS matched nothing, instead of reporting success and
    leaving the course.
  - **Tests.** `test/app_admin_effects_test.dart`.

  Original plan:
  - Takedowns: the teacher's dashboard and the student's library should say
    a course was removed and why, instead of looking normal until a video
    refuses to play. Needs `removed_at` / `removed_reason` selected and a
    badge; no backend change.
  - Teacher earnings: `transaction_service.dart` sums raw sales, so it ignores
    refund clawbacks and payouts. Needs a caller-only RPC (the teacher's own
    row of `teacher_balance_rows()`, plus their payouts) and the screen
    switched to it.
  - Suspension: read the user's own `suspensions` row at start-up. If there
    is one, show the reason and "email hello@padilearn.com to appeal", and
    hide the actions that would fail. Until then a suspended user meets raw
    RLS errors, and their course deletes silently do nothing.

### Phase D: hosting

- [ ] **14. Hosting.** *Live 2026-10-07, except one lock:*
  - **Live and locked.** `admin.padilearn.com` and `www.admin.padilearn.com`
    serve the admin build and redirect to Cloudflare Access.
  - **Auto-deploy works.** Both GitHub deploys succeeded on the PR #3 merge,
    once the repository secrets existed. The web app's deploy had been
    failing on missing secrets until then.
  - **Still open.** `padilearn-admin.pages.dev`, and each deploy's preview
    address, still serve the sign-in page without Access. Fix: Pages →
    padilearn-admin → Settings → Enable access policy, then in that Access
    application add the hostname again without the `*`.

  *Prepared earlier the same day:*
  - **Release build.** `flutter build web --release -t lib/admin/main.dart
    -o <abs>/build/admin-web` builds clean. `main.dart.js` is 2.8 MB, and no
    file outside `lib/admin` imports it.
  - **CI.** `.github/workflows/deploy-admin-app.yml` runs analyze, the tests,
    the admin build and `wrangler pages deploy` on every push to `main` that
    touches the app. It is separate from `deploy-web-app.yml`, so neither
    deploy can block the other.
  - **Supabase.** Nothing to add to the redirect allowlist: the admin app
    signs in with a password and an authenticator, and sends no email links.

  One-time setup, in this order:

  1. Create the Pages project: `npx wrangler@3 pages project create
     padilearn-admin --production-branch main`, or Workers & Pages → Create →
     Pages → Direct Upload.
  2. Pages → `padilearn-admin` → Custom domains → `admin.padilearn.com`. The
     zone is already on Cloudflare, so DNS and the certificate are automatic.
  3. Zero Trust → Access → Applications → Add → Self-hosted:
     - Domains: `admin.padilearn.com` **and** `padilearn-admin.pages.dev`.
       The pages.dev address bypasses a policy that only covers the custom
       domain.
     - Policy: Allow; Include: Emails, `hello@padilearn.com`.
     - Login method: One-time PIN.
  4. First deploy: merge `feat/admin-panel` into `main`, or run the workflow
     by hand (Actions → Deploy admin app → Run workflow).
  5. Check it: a private window on admin.padilearn.com asks for Cloudflare's
     email PIN before the sign-in page appears, and padilearn-admin.pages.dev
     does the same.

  Original plan: Pages project `padilearn-admin`, custom domain
  `admin.padilearn.com`, Cloudflare Access policy, a second job in
  `.github/workflows/deploy-web-app.yml` building with
  `-t lib/admin/main.dart`, and `https://admin.padilearn.com` in the Supabase
  redirect allowlist.

### Phase E: after the panel

- [x] **15. Payout requests.** *Applied 2026-10-08 (`20261008000001`),
  dry-run first with 20 checks, all passing.* Until now a payout began only
  on the admin's side, and a teacher's only way to ask was email.
  - **Database.** `payout_requests`, no grants, read and written only
    through functions. `request_payout()` asks for everything payable. It
    refuses a suspended teacher, a missing or unverified bank account, a
    second open request (also a unique index, so two taps cannot race), and
    anything under `payout_minimum()`, which is NGN 1,000.
    `cancel_payout_request()` and `my_payouts()` serve the teacher;
    `my_payouts()` leaves out the admin's note on a payout.
  - **Admin side.** `admin_teacher_balances()` carries the open request and
    lists requesters first, oldest first. `admin_record_payout()` closes the
    open request as paid, even for a partial amount, and notifies the
    teacher. `admin_decline_payout_request()` needs a reason, which the
    teacher is shown, and is logged as `payout_request.decline`. The
    overview's "Waiting for you" counts open requests.
  - **Notifications** gained a third type, `payout`. Older app builds show
    it with the purchase icon, which is harmless.
  - **Main app.** Profile → Payouts, and "Get paid" on the earnings card,
    open `TeacherPayoutsScreen`. It shows the balance, the bank account, one
    next step (request, cancel, add an account, or why not), and the
    payouts sent.
  - **Tests.** `test/teacher_payouts_test.dart`, plus request and decline
    cases in `test/admin_payouts_test.dart`.

---

## Later: version 2

Blocked on decisions outside the panel.

- **Paystack reconciliation**, the ledger next to Paystack's own record.
- **Automated teacher transfers**, once the marketplace review settles on
  subaccounts, split payments or Transfers.
- **Issuing refunds from the panel** through Paystack's refund API, and
  refunds outside takedowns (revoking the enrolment). *More pressing since
  2026-10-08:* the draft terms promise refunds for double charges and for
  courses clearly not as described, and `admin_record_refund()` still
  refuses anything but a taken-down course. Item 4 only records refunds
  issued by hand.
- **Free grants**: give a student a course without a payment.

## Out of scope

- Logging in as another user.
- Editing teacher content, uploading video.
- Editing or deleting transactions. The ledger is append-only.
- Broadcast messages.
- Reviewing courses before publication. Moderating through reports is what
  Play's user-generated content policy asks for.

---

## Live payment functions

Found on 2026-10-06 while preparing item 2, and outside the panel's scope, but
it decides how item 2 can ship.

The deployed `initialize-payment` (version 2, June) and `verify-payment`
(version 5, early August) are **older than the repo**, and `paystack-webhook`
is **not deployed at all**. The live pair agree with each other: they charge
and check the bare list price, and Paystack's fee comes out of the teacher's
share. So web checkout works, but on the pre-29-September money model, with no
webhook to rescue a payment whose tab died, and with a fallback callback URL on
`padilearn.app`, a domain PadiLearn does not own. `DEVLOG.md` (17 September)
already lists these as not yet deployed.

One caveat, found later the same day: the only sale in the ledger (paid
2026-10-06, card, test mode) was charged ₦5,177.67 for a ₦5,000 course,
which is exactly the September gross-up. **Paystack's own "customer pays the
fee" setting is on.** The web app that day was the hand-deployed build,
calling the live `initialize-payment` (version 2, June), which asks Paystack
for exactly 500,000 kobo. Paystack added the fee itself. The repo's
`initialize-payment` also adds the fee, so deploying it with that setting on
would charge students the fee twice (about ₦5,358 for a ₦5,000 course).

*Update 2026-10-08:* a **company Paystack account** now replaces the one
that took the test sale. Its fee setting, webhook and keys start fresh, so
the steps below apply to the new account. The full order, with the
compliance checklist, is in `STATUS.md`. The fallback callback URL in the
repo's `initialize-payment` now points at `app.padilearn.com` too.

Payments deploy, in this order:

1. Paystack → Settings → Preferences → set "who pays the transaction fee"
   to the business, since the code now adds the fee itself.
2. Paystack → Settings → API Keys & Webhooks → webhook URL
   `https://wnxuxplzoddadjpwfhxe.supabase.co/functions/v1/paystack-webhook`.
3. Then deploy `initialize-payment`, `verify-payment` and `paystack-webhook`
   (`--no-verify-jwt` on the webhook) together.

Deploying the repo's `initialize-payment` alone would mix the two models
(students charged the grossed-up total, checked by the old verify). So the
item 2 change to it waits for one deliberate payments deploy:
`initialize-payment`, `verify-payment` and `paystack-webhook` together
(`--no-verify-jwt` on the webhook), plus the webhook URL in Paystack's
dashboard. Until then a removed course can still be bought by a hand-made call
that knows its id; the app cannot reach that path, because RLS hides the
course.

---

## Open decisions

1. **Who uses it: only the founder, or a moderator soon?** Only the founder
   means Studio plus items 1–2 could hold for a while. A second person is when
   the app stops being optional.
2. ~~When a course is taken down for a policy breach, do students who paid
   keep access?~~ **Decided 2026-10-06: no.** Playback stops for everyone but
   the owner, the students who paid are owed refunds (item 4), and
   `get-course-video` enforces it.
3. ~~Record payouts now, before the Paystack structure is decided?~~
   **Yes** (2026-10-06, by going ahead with item 5): even manual bank transfers
   need a record, or no teacher balance can ever be trusted.
4. ~~Who pays for a takedown refund?~~ **Decided 2026-10-06:** the student
   gets everything back; the teacher loses their whole share of that sale;
   PadiLearn gives up its commission and absorbs Paystack's fee. On a ₦5,000
   course: ₦5,178 back, ₦4,250 off the teacher, ₦928 borne by PadiLearn.
   Applies to takedown refunds only.
5. ~~How do teacher balances and payouts work?~~ **Decided 2026-10-06:**
   (1) a sale is payable 7 days after it was paid, pending until then;
   (2) a refund after a payout takes the balance negative, recovered from
   later sales, never chased; (3) payouts only to a Paystack-verified bank
   account, with a copy of it kept on the payout; (4) a payout cannot exceed
   the payable balance. The 7 days live in `payout_hold()`.
6. ~~What does suspending an account do?~~ **Decided 2026-10-06:**
   - **Duration.** Indefinite, until an admin lifts it on appeal.
   - **What still works.** The user can still sign in, watch what they own,
     save progress, read notifications, delete their own comments and
     ratings, and delete their account.
   - **What is blocked.** Creating or editing courses and lessons, uploading,
     commenting, rating, reporting, suggesting categories, editing their
     profile, enrolling or buying, and changing bank details.
   - **Their courses.** A suspended teacher's courses leave the catalogue.
     Students who enrolled keep them, so no refunds are owed.
   - **Money.** Payouts are held, and the balance is kept.
   - **Admins** cannot be suspended.
