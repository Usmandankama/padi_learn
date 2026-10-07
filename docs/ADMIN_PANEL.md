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
  Known gaps, not fixed here: the app's teacher earnings screen
  (`transaction_service.dart`) sums `transactions` and will not show a
  clawback until item 5's balance replaces it. Deleting a course with paid
  students is blocked only in the app (`course_service.dart`), not by RLS, so
  a crafted call could still do it and leave refunds owed against a course
  that no longer exists.

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
- [ ] **12. Screens.** Overview, reports queue, courses, users, refunds owed,
  teacher balances and payouts, categories, audit log.
- [ ] **13. Show the back office's effects in the main app.**
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

- [ ] **14.** Pages project `padilearn-admin`, custom domain
  `admin.padilearn.com`, Cloudflare Access policy, a second job in
  `.github/workflows/deploy-web-app.yml` building with
  `-t lib/admin/main.dart`, and `https://admin.padilearn.com` in the Supabase
  redirect allowlist.

---

## Later: version 2

Blocked on decisions outside the panel.

- **Paystack reconciliation**, the ledger next to Paystack's own record.
- **Automated teacher transfers**, once the marketplace review settles on
  subaccounts, split payments or Transfers.
- **Issuing refunds from the panel** through Paystack's refund API, and
  refunds outside takedowns (revoking the enrolment), once
  `website/src/pages/terms.md` has a refund policy. Item 4 only records refunds
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
which is exactly the September gross-up. The deployed `initialize-payment`
charges the bare price, so that payment either went through Paystack's own
"customer pays the fee" setting or was initialised by code that is not
deployed (a local function run, for instance). Check the Paystack dashboard
setting before the payments deploy, or the fee could be added twice.

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
