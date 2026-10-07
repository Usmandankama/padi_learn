# PadiLearn dev log

Running record of changes that are worth understanding *later* — the ones where
the reasoning matters more than the diff. Newest first.

Not a changelog: routine fixes and UI tweaks stay in git history. An entry
earns its place here when it changes a contract (database shape, auth flow,
money), when it needs manual setup outside the repo, or when the next person to
touch that area would otherwise repeat a decision we already made.

Each entry: what changed, why, what it touches, and anything still outstanding.

---

## 2026-10-07 — Closing the loose ends: course deletes, RLS speed, a new APK

**A teacher can no longer delete a course that has students**
(`20261007000002`). It was blocked only in the app, and `enrollments`
cascades, so a hand-made API call could still erase every student's access.
A trigger now refuses the delete with "Archive it instead". It applies only
when the request's role is `authenticated`, so account deletion is not
blocked: that goes through Supabase Auth's own connection, and a teacher with
only free students must still be able to delete their account, which Play
requires.

The dry run caught a bug in the first version. On a connection that once
carried a request, `request.jwt.claims` reads back `''` rather than null, and
`''::jsonb` throws, so every delete on such a connection would have failed.
`nullif(…, '')`, as `auth.jwt()` itself does, fixed it.

**RLS evaluates `auth.uid()` once per statement** (`20261007000003`). All 27
flagged policies now wrap it as `(select auth.uid())`. The `ALTER POLICY`
statements were generated from the live `pg_policies` text rather than
retyped. The check was behavioural: the number of rows each of the 7 accounts
can see in 12 tables was identical before the change, after the dry run, and
after the real apply. The 15 unindexed foreign keys are indexed too
(`…003` and `…004`).

**Android 1.0.1.** A new APK carries item 13 (real earnings, takedown
notices, the suspension banner) to sideloaded phones. The steps are those in
`LAUNCH_WEB.md`.

**Payments deploy: blocked, now with a cause.** The one live sale was charged
₦5,177.67 through the June `initialize-payment`, which asks Paystack for
exactly ₦5,000. So Paystack's own "customer pays the fee" setting is on, and
deploying the repo's version, which adds the fee itself, would charge it
twice. The steps are in `ADMIN_PANEL.md`, "Live payment functions": switch
the setting, add the webhook URL, then deploy the three functions together.

---

## 2026-10-07 — The main app learns about the back office, and the panel gets a deploy

**Admin panel item 13.** Until now, every decision the back office made was
invisible to the person it affected:

- **Earnings ignored refunds and payouts.** The earnings card summed the
  ledger, which knows nothing about either. It now reads
  `my_teacher_balance()` (migration `20261007000001`, dry-run and then
  verified live). That is the same balance definition the admin panel pays
  from, and the card says what was paid out, what is ready, and what is still
  clearing the 7-day hold. One trap in writing it: `teacher_balance_rows(null)`
  returns *every* teacher, so the function refuses a call with no signed-in
  user rather than pass null through. The dry run checked exactly that.
- **A taken-down course looked live to its teacher.** It now has a "Taken
  down" chip, which wins over "archived", and a notice on the course page with
  the reason and hello@padilearn.com. Students already got a clear message
  from `get-course-video` when they pressed play.
- **A suspended user met bare RLS errors.** `SuspensionFrame` wraps the home
  shell's tabs and shows the reason and the appeal address. It reads the
  user's own `suspensions` row and shows nothing when there is none, or when
  offline: a banner that might be wrong is worse than none.
- **A suspended teacher's delete reported success.** RLS filters a refused
  delete rather than raising, so `CourseService.delete` now asks for the
  deleted row back and fails clearly when it gets none. It also leaves the
  media alone in that case.

**Admin panel item 14, prepared.** The admin app builds in release mode,
which is a different compiler from the debug server it had been tested on. No
file outside `lib/admin` imports it, so the public bundle cannot contain it.
`deploy-admin-app.yml` deploys it to its own Pages project and is separate
from the main app's workflow, so neither can block the other. It runs the
tests before building, because nothing in CI can sign in as an admin.

The remaining steps need the Cloudflare account and are listed in
`ADMIN_PANEL.md`: the Pages project, the custom domain, and an Access policy.
The policy must cover `padilearn-admin.pages.dev` as well as
`admin.padilearn.com`, or the pages.dev address walks around it.

The suite stands at 97 tests.

---

## 2026-10-07 — The rest of the admin panel: courses, refunds, payouts, categories, audit log

**Admin panel items 12d–12h, which completes item 12.** Each screen has its
own commit and widget tests. The suite stands at 92 tests.

- **Courses.** Every course, filtered as live, archived or taken down. The
  screen keeps the teacher's "archived" apart from PadiLearn's "taken down",
  because only the second is an admin's to undo.
- **Refunds.** Who is owed, with the buyer's email and the Paystack payment
  reference to find them by, and the split the database computes. Recording
  needs Paystack's refund reference and a reason.
- **Payouts.** Each teacher's balance and full account number. "Record
  payout" appears only when the database would accept the payout. Otherwise
  the card names the rule in the way: suspended, inside the 7-day hold,
  nothing payable, or no verified account.
- **Categories.** Suggestions and switched-off categories apart from the live
  list. Approve and switch off are one click each, edit sends only what
  changed, and delete requires a destination while any course uses the
  category.
- **Audit log.** Every admin action in words, filterable by area, with
  details on expand.

**Two reads go straight to tables instead of through admin functions:**
courses and the audit log. The database already had admin-only read policies
for both, so no migration was needed. `courses.user_id` points at
`auth.users` rather than `profiles`, so PostgREST cannot embed names, and a
second `profiles` query attaches them. Both reads were checked on the live
project under an admin session: all 13 courses, a resolvable owner, and an
empty audit log.

**Shared pieces kept the screens consistent.** The takedown question and its
result sentence moved into `widgets/course_actions.dart`, so Reports and
Courses say the same thing. Kobo amounts typed by an admin go through
`parseNairaToKobo`, which refuses anything it cannot read exactly, such as a
third decimal, rather than rounding it into a different payout. Its first
version used the inline `(?i)` flag, which Dart's `RegExp` rejects, and the
payouts tests caught it throwing on every input. The shell's section switch
is now exhaustive, so a new section without a screen fails to compile.

### Still outstanding

- Item 13, the main app: show takedowns and suspensions, and switch teacher
  earnings to a balance that counts refunds and payouts.
- Item 14, hosting the panel at admin.padilearn.com behind Cloudflare Access.

---

## 2026-10-07 — Users: find someone, see everything, change what they can do

**Admin panel item 12c.** `UsersScreen` puts search on the left, debounced at
350 ms; an empty search lists the newest accounts. The chosen account is on
the right, or opens as its own page when the window is narrower than 900 px.
The detail page shows everything `admin_user_detail()` returns:

- **Account:** sign-ins, how they sign in, and authenticator state for an
  admin.
- **Teaching:** courses with their state, the balance in kobo, and the bank
  account by its last four digits.
- **Learning:** enrolments with progress, and purchases with refund state.
- **Conduct:** reports filed and against them, and admin actions on the
  account.

**The screen refuses to offer what the database would refuse.** An admin has
no Suspend button, only "Admins cannot be suspended". A suspended account
shows its reason and offers Lift instead. The role dialog disables the role
the account already has. One refusal the screen does not predict is a teacher
with courses being made a student: it shows the database's message instead
("owns 2 course(s)…"), so the rule lives in one place.

The role picker is a segmented button rather than radio buttons, because
Flutter 3.38 deprecates `RadioListTile.groupValue` and the analyzer would
start flagging it.

**Tests** (`test/admin_users_test.dart`) use fixtures in the exact shape the
live `admin_user_detail()` returned; the shape was checked against the
database, keys and types only. They pin:

- what each action sends, including a null role for "let them choose";
- that the list's badges reload after an action;
- the narrow-window page;
- that a database refusal is shown, not swallowed.

The full suite passes (70 tests).

---

## 2026-10-07 — The reports queue, where every button says what it will do

**Admin panel item 12b.** `ReportsScreen` lists reports by status (open,
dealt with, dismissed); open ones come oldest first. Each card shows the text
as it was reported and, if it has changed since, as it reads now. It also
names the reporter and the author, says how many open reports share the
target, and, once resolved, records who resolved it and why.

**The destructive actions explain themselves before they run.**

- **Delete comment** says the text survives in the report and the audit log.
- **Take course down** says students who paid lose playback and are owed
  refunds. Its confirmation then reports how many paid sales it just made
  refundable, and for how much.
- **Mark dealt with**, **dismiss** and **reopen** each ask for a reason too.
  The confirm button stays disabled until one is typed, because the database
  would refuse the call without it.

After any action the list is reloaded from the database rather than patched
locally, because acting on content can close other reports as well.

**`AdminApi` became an instance**, passed to every screen, so a test can pass
`FakeAdminApi`, which answers from memory and records each call.
`test/admin_reports_test.dart` pins what each button sends (function, id and
the reason typed), and that backing out of the dialog sends nothing. Report
reasons reuse the app's own `ReportReason` labels, so the admin and the
reporter see the same words. The full suite passes (62 tests).

There are no reports on the live project yet, so the fixtures follow the
exact columns `admin_list_reports` returns.

---

## 2026-10-07 — The admin overview, and the test that has to stand in for signing in

**Admin panel item 12a.** The overview screen shows, from one
`admin_overview()` call:

- what is waiting: reports, category suggestions, refunds owed, teachers to
  pay;
- how the money stands, to the kobo;
- accounts, catalogue and learning.

Each waiting item and the headline figures link to the screen that deals with
them. With it came the pieces every later screen reuses:

- `AdminApi`, the one place calls are made, which turns the database's error
  codes into words;
- `formatKobo`;
- `AdminCard`, `StatRow`, and `AdminLoader`, which handles loading, error and
  retry;
- the `AdminSection` enum, so screens link by name, not by rail index.

**Why a widget test rather than a look.** Seeing the screen with real data
needs the admin password and an authenticator, so neither the preview pane
nor CI can sign in. `test/admin_overview_test.dart` renders the screen at
laptop size from the exact document the live project returned today. It
checks the kobo figures (5,177.67 gross, 750.00 commission, 4,250.00 owed),
that a waiting item opens its screen, and that a refused call says why and
retries.

**It found two bugs before anyone saw them, both in `AdminLoader.reload()`.**

- `setState(() => _future = load())` returns the Future from the closure,
  which Flutter asserts against, so Refresh and Try again would have thrown.
- A load that fails fast completes before the rebuild subscribes, so the
  error was reported as uncaught even though the screen showed it.
  `..ignore()` marks it handled, and the FutureBuilder still receives it.

The whole suite passes (56 tests).

---

## 2026-10-07 — The admin app: a second entry point that stops at the code prompt

**Admin panel item 11, verified end to end.** hello@padilearn.com signed in,
enrolled an authenticator and passed the code. The database confirms one
verified TOTP factor, no leftover unverified one, and a session carrying a
`totp` authentication method. `lib/admin/main.dart` is a second entry point
into the same codebase:

```bash
flutter run -d chrome -t lib/admin/main.dart
```

It shares the Supabase client, palette and models, and nothing outside
`lib/admin` imports it, so the student app's bundle never contains an admin
screen.

**The gate is the security model, drawn.** `admin_gate.dart` decides each
screen from the session alone:

- **No session:** sign in.
- **Password only, no authenticator:** set one up.
- **Password only, with an authenticator:** enter its code.
- **Code passed:** ask `is_admin()`, then show the panel or "not an admin".

It re-decides on sign-in, sign-out and verification. A generation counter
means a slow `is_admin()` cannot land after a sign-out and put the panel back
on screen. None of this is the protection, which is in the database. The
gate only keeps the app from drawing what the database would refuse.

**Setting up the authenticator.** The enrol screen first removes any
unverified factor left by an abandoned setup, so a reload always gets a fresh
code. Supabase sends the QR code as SVG, which Flutter cannot draw without a
package. `qr_flutter` (pure Dart, small) draws it from the `otpauth://` link
instead, and the key is shown as text for typing in. It is the only new
dependency, and only `lib/admin` imports it.

**No self-service reset for a lost authenticator.** A bypass on the code
screen would turn the second factor into decoration. The factor is removed in
the Supabase dashboard instead, and the screen says so.

**Verified in the browser pane:** the `admin` launch configuration runs
`flutter run -d web-server` on port 5180. The sign-in screen renders in both
themes and at phone width, and it refuses empty fields locally. Signing in,
enrolling, the challenge, "not an admin" and the shell were not exercised:
that needs the real admin password and an authenticator app.
`flutter analyze lib/admin` is clean.

### Still outstanding

- Nothing for the shell. The screens behind it are item 12.

---

## 2026-10-06 — Suspended means signed in but unable to act

**Admin panel item 10, live.** The plan was a
Supabase auth ban via an `admin-users` edge function. Decision 6 ruled that
out: a suspended user keeps signing in. They can still watch what they own,
save progress, read notifications, delete their own comments and ratings, and
delete their account. Everything else stops: creating or editing courses and
lessons, uploading, commenting, rating, reporting, suggesting categories,
editing their profile, enrolling or buying, and changing bank details. A
suspended teacher's courses leave the catalogue, but enrolled students keep
them, so a suspension owes no refunds; if the content is the problem, that is
a takedown. Their payouts are held.

**A table, a private check, and restrictive policies.**

- `suspensions` holds one row per suspended user.
- `private.is_suspended()` is security definer, so policies can see every
  row. It lives in a `private` schema, which PostgREST does not expose, so it
  is not an RPC anyone could use to ask about another user.
- Each blocked write gets a *restrictive* policy, ANDed onto the existing
  permissive ones, so not one existing policy changed.
- Triggers and admin functions run as the table owner, which bypasses RLS. A
  suspended student deleting their rating therefore still lets the rating
  trigger recount the course; the dry run checked exactly that.

**Update rules use WITH CHECK only, deliberately.** A restrictive `USING` on
UPDATE would quietly match no rows, and the app would report success. WITH
CHECK fails loudly. DELETE has no WITH CHECK, so a suspended teacher's delete
silently does nothing, and the app should stop offering it (item 13).

**No token lag.** An auth ban only bites when the access token expires, up to
an hour later. These rules are evaluated on every request, so a suspension
applies on the next one.

**The service role sees past all of it,** so three functions check too:

- `get-course-video` refuses previews of a suspended teacher's courses. It
  fails closed if it cannot check.
- `payout-account` refuses to save bank details for a suspended user.
- `initialize-payment` refuses a suspended buyer or seller. This one waits for
  the payments deploy, with the rest of that function.

**Dry run against the live schema**, 34 checks, rolled back. The controls ran
first: an upload and a course edit by the teacher both succeeded before the
suspension, so the refusals afterwards are the suspension and nothing else.
One test was wrong on the first run, not the migration: users have no UPDATE
grant on `enrollments` at all, and progress is saved through
`lesson_progress`, which is what the passing run used.

**Applied, then deployed, in that order.** Both functions query
`suspensions`, so the table had to exist first. After applying, 18 more checks
passed against the full admin-screen functions:

- Suspending moved a teacher from "payable" to "payouts held", and a real
  payout attempt was refused.
- Lifting the suspension let the same payout through.

Both functions answered a smoke test from their own code. PostgREST refuses
`private` outright (`PGRST106`), so `is_suspended` is unreachable from the
API.

### Still outstanding

- The app does not yet tell a suspended user why their actions fail (item 13).
- `initialize-payment`'s suspension check waits for the payments deploy.

---

## 2026-10-06 — One screen for what is waiting and how the money stands

**Admin panel item 9, live, which completes Phase A.** It is the last
database item. `admin_overview()` is the admin app's first screen as one JSON
document. It answers what needs doing (open reports, category suggestions,
refunds owed, teachers who could be paid) and how things stand (accounts,
catalogue, enrolments, money).

**The overview borrows its sums rather than redoing them.** Teacher figures
come from `teacher_balance_rows()`, and refunds owed use the same rule as
`admin_refunds_owed()`. A summary that computed them separately could drift
from the screens it summarises.

**PadiLearn's net is shown, not just its commission.** The net is commission
minus what refunds cost the platform, because a takedown refund gives back
the commission and swallows Paystack's fee. The dry run showed it: on the one
real sale, after a takedown and refund the net went from ₦750 to −₦177.67.

**What it says today:**

- 7 accounts, 13 live courses (all by one teacher, one of them paid), 123
  lessons, 2 enrolments.
- One sale of ₦5,177.67: ₦750 to PadiLearn, ₦4,250 to the teacher, still
  pending under the 7-day hold.
- One category suggestion waiting.

### Still outstanding

- The performance advisor's findings are listed under item 9 in
  `ADMIN_PANEL.md`. Mostly pre-existing, and immaterial at this size.

---

## 2026-10-06 — Who is this person, and what have they got

**Admin panel item 8, live.** Support starts
with that question, and the answer is spread across `auth.users`,
`profiles`, and every table that hangs off a user. Clients can read none of
it for anyone but themselves, by design. `admin_search_users()` finds an
account by part of an email or name, or by exact id. `admin_user_detail()`
returns everything about one account as a single JSON document, so the
detail page costs one round trip.

**Two details worth keeping.** Search escapes LIKE wildcards, so typing `%`
finds a literal percent sign rather than every account. The detail shows
only the last four digits of a payout account; the full number appears in
one place only, `admin_teacher_balances()`, where it is needed to send money.

**Read-only, so not logged.** Only actions that change something write to
`admin_actions`. If access to personal data ever needs its own audit trail,
for a regulator or because there are more admins, this is where it would go.

**Verified before and after applying**, 15 and 12 checks, rolled back. They
print only counts and yes/no answers, so no personal data reached the logs.

---

## 2026-10-06 — Category suggestions can be approved, renamed or merged

**Admin panel item 7, live.** Teachers have
been able to suggest categories since August. A suggestion saves as inactive
and stays out of the browse filters, and approving one was left to "SQL or
the dashboard". There are now four admin functions: list (pending first),
approve or switch off, rename or reorder, and delete. Delete can merge into
another category.

**Names are compared case-insensitively.** The table's unique constraint is
case-sensitive, so a teacher can suggest "design" while "Design" exists.
Approving it would put two near-identical filters side by side, so approval
refuses a clash and points to merging instead.

**Nothing is left without a category by accident.** `courses.category`
references the category by name with `ON DELETE SET NULL`, so deleting a
category in use would silently clear it on those courses. Deleting therefore
requires a category to move them to whenever any course uses it, and that
target must be active. Renames cascade to courses through the existing
`ON UPDATE CASCADE`.

**Reasons are optional here.** Unlike takedowns and money, nothing in this
item affects a user's access or a balance. Every action is still logged.

**Dry run against the live schema**, 17 checks, rolled back. Among them, a
synthetic "design" duplicate used by one course was refused for approval,
refused for deletion without a target, and then merged into "Design", which
carried its course across. The checks passed again after applying.

### Still outstanding

- "Philosophy" is still waiting. It can be approved from the admin app, or
  now with `admin_set_category_active` from a second-factor session.

---

## 2026-10-06 — A wrong role at signup can be undone

**Admin panel item 6, live.** `claim_role()`
lets a user pick a role once, and `role` has been out of reach of client
writes since August, so nobody can promote themselves. The side effect was
that a user who tapped the wrong role at signup was stuck without SQL.
`admin_set_role()` sets Student or Teacher, or clears the role. Clearing is
the gentler fix, because the app reads a null role as "onboarding
unfinished": on the next launch it shows the picker, and the user chooses
through `claim_role()` themselves.

**A teacher who owns courses cannot be demoted or cleared.** The student
shell has nowhere to manage courses, so their courses, sales and students
would be stranded. The dry run hit exactly this: the dev teacher owns all 13
courses and was refused.

**Verified before and after applying**, 14 checks each time, rolled back. They
covered self-promotion still being blocked, the refusals, a student promoted
and then cleared, and that user re-claiming their own role exactly once.

---

## 2026-10-06 — What each teacher is owed, and what they have been paid

**Admin panel item 5, live.** Web checkout
takes real money, and until now nothing recorded what PadiLearn then owes
each teacher or what it has sent them. Transfers are still made by hand;
`payouts` records them, and a balance says what can be sent.

**One definition of the balance.** `teacher_balance_rows()` is internal and
shared by the admin list and by the payout check, so the number an admin sees
is the number a payout is checked against:

- balance: the teacher's share of every sale, minus refund clawbacks, minus
  payouts;
- pending: unrefunded sales younger than `payout_hold()`;
- available: balance minus pending.

A refunded sale counts once in earnings and once, negatively, in clawbacks,
so it nets to zero and is kept out of pending.

**The rules were decided today** (`ADMIN_PANEL.md`, decision 5):

- **7-day hold.** The interval lives in one function, `payout_hold()`, so
  changing it is a one-line migration.
- **Negative balances carry forward.** A refund after a payout is recovered
  from later sales, never chased.
- **Verified accounts only.** Payouts go only to a Paystack-verified account,
  and each payout keeps a copy of the account it went to, because the teacher
  can change theirs later.
- **No overpaying.** A payout cannot exceed what is available.

Recording a payout locks the teacher's bank-account row, which serialises
payouts per teacher, so two admins cannot both pay out the same balance. The
transfer reference is unique, so the same transfer cannot be recorded twice.

**Dry run against the live schema**, 18 checks, rolled back:

- Today's real sale (₦4,250 to the teacher, paid three hours earlier) showed
  as pending, with nothing payable.
- A synthetic sale backdated 10 days made ₦2,000 payable. Paying ₦1,500
  left ₦500.
- Refunding that sale afterwards took the payable balance to −₦1,500, which
  then blocked any further payout.

The same checks passed again after applying.

### Still outstanding

- No teacher has a payout account yet (`payout_accounts` is empty), so
  nothing can actually be paid out until one adds and verifies their bank
  details in the app.
- Teachers cannot see their balance or payouts in the app. The earnings
  screen still sums raw sales (`ADMIN_PANEL.md`, item 13).

---

## 2026-10-06 — A refund is its own row, and the teacher's share goes with it

**Admin panel item 4, live.** A takedown
stops playback for students who paid, so they are owed their money back.
Refunds are issued by hand in the Paystack dashboard; `refunds` records them,
one row per refunded sale, so teacher balances (item 5) can leave them out.

**Who pays was decided today** (`ADMIN_PANEL.md`, decision 4). The student
gets everything back. The teacher loses their whole share, because the breach
was theirs. PadiLearn gives up its commission and absorbs Paystack's fee,
which Paystack keeps on a refund. The function computes the split from the
ledger, so no admin can type a different one: `amount_kobo` and
`teacher_clawback_kobo` are copied from the sale, and `platform_cost_kobo` is
generated as the difference. On the one real (test-mode) sale it came out at
₦5,177.67 back, ₦4,250 off the teacher, ₦927.67 to PadiLearn.

**`transactions` is not touched.** Marking the sale "refunded" would mean
editing the ledger. A separate row keeps it append-only, and a `RESTRICT`
foreign key means a refunded sale can never be deleted out from under its
refund.

**Recording a refund removes the enrolment.** Access is already gone while the
course is down, but a course restored on appeal would otherwise give the
student both the refund and the course.

**Only takedown refunds, for now.** Refunding for any other reason needs a
refund policy (`terms.md` still has a placeholder) and its own answer to who
pays, so `admin_record_refund()` refuses sales of courses that are still live.

**Verified live.** 16 checks passed both as a dry run and after applying, in
transactions ending in an exception. The checks cover the split, the enrolment
removal surviving a restore, double refunds, the refusal for live courses,
non-admins, the real admin without a second factor, and anon.

### Still outstanding

- The app's teacher earnings (`transaction_service.dart`) sum `transactions`
  and will not show a clawback until item 5's balance replaces them.
- Deleting a course with paid students is blocked in the app, not in RLS. A
  crafted call could still do it, leaving its buyers owed refunds against a
  course that no longer exists.

---

## 2026-10-06 — Reports can be read, and acted on once per target

**Admin panel item 3, live.** Reports have
been write-only since they shipped: filed from the app, readable only in
Studio. `admin_list_reports(status)` is the queue. Each row carries the
snapshot taken at report time *and* the content as it is now, because a comment
may have been edited or deleted since, plus the reporter, the owner, and how
many open reports point at the same thing. Open reports come oldest first, so
the queue is worked in order.

**Acting on content closes its reports.** `admin_delete_comment()` and
`admin_remove_course()` (now redefined) close every open report about what
they act on, as `actioned` with the same reason, so ten people flagging one
comment is one decision. Order matters for comments: the reports are closed
*before* the delete, because `content_reports.comment_id` is
`ON DELETE SET NULL` and the match would be gone afterwards. The text survives
in the reports' snapshot and in the audit log. Taking a course down leaves
reports about *comments* on that course open: those are about someone else's
words. `admin_set_report_status()` covers the rest (dismiss, mark actioned
when the owner already fixed it, reopen a mistake), always with a reason.

**The reports insert grant never narrowed anything.** The September migration
granted INSERT on five columns but never revoked the table-wide INSERT that
Supabase gives every new table, so the column grant was a no-op. The fill
trigger overwrote most server-owned fields, which is why it never mattered, but
the new `resolved_by` and `resolution_note` columns would have been settable
by whoever filed the report. The table privilege is now revoked and the five
columns re-granted, which is the same fix `courses` got in item 2. The trigger
also clears the two new columns, so "server-owned fields are set here" stays
true if a grant is ever widened again. Reports still cannot be read by users,
and a duplicate still raises `23505`, which the app shows as "already
reported".

**Dry run first, then verified live.** In each pass, reports were filed
through the app's exact insert shape, then queued, acted on, reopened and
dismissed, inside a transaction ending in an exception: 21 checks before
applying, 22 after. The extra one confirms the real admin account,
hello@padilearn.com, is refused while it has no second factor.

### Still outstanding

- Nothing in the database. The queue gets a screen with the admin app
  (`ADMIN_PANEL.md`, items 11–12).

---

## 2026-10-06 — A takedown the teacher cannot undo

**Admin panel item 2, live.** Until now the
only way to hide a course was `archived_at`, which the teacher owns: archive
one for copyright and its owner could put it straight back. Takedowns get
their own columns, `removed_at` and `removed_reason`, that no client can
write. Only `admin_remove_course()` and `admin_restore_course()` touch them,
both require a reason, and both log to `admin_actions`.

**Students who paid lose playback** (decided today, `ADMIN_PANEL.md`
decision 2). A removed course still *resolves* for its owner and for enrolled
students, the same way an archived one does, so libraries and the player do
not break. `get-course-video` is what actually stops playback: it runs as the
service role, so RLS never applied there, and it now loads the course for
every request, previews included, and refuses a removed one to everyone but
the owner. The player shows the function's error verbatim, so the message
itself tells a paying student to email hello@padilearn.com. The removal call
returns how many paid sales it just made refundable.

**Course INSERT is now column-by-column.** It was the last table-wide grant on
`courses`, so a new `removed_at` would have been settable at creation. The
same grant had always let a teacher create a course with `enrollments` or
`rating_avg` set to anything, and the counters are only recounted when an
enrolment or rating changes, so an invented number stuck. Narrowed to the
seven columns `create_course_screen.dart` sends.

**Dry run first, then verified live.** Before applying, the migration and 18
behaviour checks ran in one transaction that ends in an exception, so nothing
persisted. Among the checks: a stranger sees the same 13 courses before and
after, which confirms the rewritten select policy hides nothing it should not.
After applying the migration and then deploying `get-course-video` (version
3, in that order because the function selects `removed_at`), the same checks
plus two more (a teacher can still edit their course; anon cannot reach the
RPCs) passed on the real schema, and the function answered a smoke test from
its own code.

### Still outstanding

- `initialize-payment` now refuses archived and removed courses, but must not
  be deployed alone. The live payment functions are the June/August versions
  and `paystack-webhook` was never deployed (see `ADMIN_PANEL.md`, "Live
  payment functions"). They go out together, in one payments deploy.
- The main app does not show that a course was taken down (admin item 13).

---

## 2026-10-06 — An admin is a row, and every admin action leaves one

**The admin panel is scoped, in `docs/ADMIN_PANEL.md`.** Until now Supabase
Studio was the back office: fine for one operator, but it keeps no record of
who did what, and the only way to delegate it is to hand over the whole
database. The doc holds the build order as a checklist; this is item 1.

**Admins are rows in `public.admins`, not a role and not a claim.** Putting
"Admin" in `profiles.role` would publish the list of admins to every signed-in
user (profiles are world-readable to the app), and the app's role branching
would drop an unknown value into the student shell. A JWT claim in
`app_metadata` would outlive its revocation until the token expired; a deleted
row is gone on the next request. Clients have no grants on the table at all.

**`is_admin()` requires a second factor.** It is true only for a listed user
whose session is `aal2`, so a leaked password reaches nothing. The admin app
will enrol and challenge a TOTP factor before calling anything.

**Every admin write logs itself in the same transaction.** Admin RPCs start
with `perform public.assert_admin();` and end with `log_admin_action(...)`,
which writes `admin_actions` with the admin taken from the session rather than
an argument. Same transaction, so the log can neither miss a committed action
nor show one that rolled back. Admins can read the log; nobody can write it
except through those functions.

Nothing existing changes: no table, policy or grant the app relies on is
touched, so the app behaves exactly as before.

### Still outstanding

- ~~Apply `20261006000001_admin_foundation.sql` to the live project.~~ Applied
  2026-10-06; 15 role-simulated checks passed in a rolled-back transaction.
- ~~Add the first admin, hello@padilearn.com.~~ Granted 2026-10-06. It has no
  TOTP factor yet, so `is_admin()` answers false for it until the admin app
  enrols one.
- `log_admin_action` reads `auth.uid()`, which is null under the service role.
  The `admin-users` edge function (item 9) must log through an RPC called with
  the admin's own JWT, or its rows will have no author.

---

## 2026-10-06 — The APK is hosted, at dl.padilearn.com

**The download the landing page promises now exists.** The release APK sits in
an R2 bucket, `padilearn-dl`, behind `dl.padilearn.com` (custom domain, minimum
TLS 1.2 — safe, because the APK's floor is Android 7.0 and TLS 1.2 has been
default since 5.0). Two objects per release: `padilearn-1.0.0.apk`, immutable
and cached for a year, and `padilearn-latest.apk` on a five-minute cache, which
is what `site.android.apkUrl` points at. Until today that URL resolved to
nothing, so the new landing page could not have shipped without a dead download
button on the one page whose job is to earn a stranger's trust.

**It cannot live with the marketing site.** Cloudflare Pages caps a single file
at 25 MiB; the universal APK is 40.6 MiB. The per-ABI splits *would* fit, and
are roughly half the size, but serving those means asking a stranger which CPU
their phone has. R2 instead, where egress is free.

**`--pipe`, not `--file`.** `wrangler r2 object put --file` failed twice, each
time after about five minutes, with a bare `fetch failed` and nothing uploaded.
Streaming the same bytes in (`cat $APK | wrangler … --pipe`) worked first try.
Worth recording because the obvious diagnosis was wrong: a bandwidth test run
*while* the upload was in flight read 13 kB/s, which was pure contention for the
uplink. Measured clean, the link does ~540 kB/s — fine for 40 MiB — and large
request bodies only collapsed when `Expect: 100-continue` was in play. One
buffered PUT does not survive this connection; a streamed one does.

**Verified, not assumed.** For a single-part upload R2's `ETag` is the MD5 of
the object, so a 42 MB download is not needed to prove the bytes are intact:
`Content-Length` matched 42,621,037 exactly and the ETag matched the local
`md5sum` (`05a390cb…`). A truncated upload would still have answered `200`.
Note that the bucket's own `object_count` and `bucket_size` read zero for
roughly an hour afterwards — those metrics lag, and are useless for verifying a
fresh upload.

**The numbers on the page were wrong.** `site.ts` claimed `41 MB`; the file is
42.6 MB as a browser will report it. Understating a download by 4% on a trust
page is a small own-goal, so `apkSize` and `apkUpdated` now match the artifact
that is actually being served.

### Still outstanding

- **Enabling R2 was a by-hand dashboard step**, as it requires accepting terms
  and a payment method. Nothing in this repo can do that, and the API answers
  `code: 10042` until it is done.
- **Uploads are still manual.** The CI workflow added yesterday builds the
  *web* app only. Building the APK in CI would mean putting the release
  keystore and its passwords into repository secrets, and `CLOUDFLARE_API_TOKEN`
  would need R2 edit on top of Pages edit. That is a real decision about where
  the signing key lives, deliberately not taken yet.
- **This signature is not Play App Signing's.** Anyone who sideloads today must
  uninstall before a future Play build will install over it. Worth saying out
  loud in the release notes when there is a Play listing.

---

## 2026-10-05 — The demo catalogue went live, and a second campaign for teachers

**The seed is applied.** `demo_catalogue.sql` ran against the `padilearn`
project: 12 seeded courses, 121 seeded lessons, one free preview each, every
filmed lesson sitting at the position printed in its own footage. The six real
courses and their 8 lessons were untouched — the uuid prefixes did their job.

The 10 courses from the previous catalogue were deleted with the teardown
scoped to just them, which cascaded away 4 demo enrolments. `welcome-to-padilearn`
survived, being in both sets.

**A bug caught on the way in.** The lesson-trimming DELETE added yesterday was
scoped to every course matching the `a0000000-…` prefix, not to the courses
the run actually writes. It would have stripped the lessons off the 10 retired
courses and left them in the marketplace with no curriculum at all — worse
than leaving them alone, and not that statement's job. It now scopes to
`_seed_courses`. Retiring an old course is the teardown's job, deliberately a
separate and manual one.

**The media is uploaded**, by hand, from the staging trees. Both buckets were
verified afterwards rather than assumed: all 12 clip keys and all 12 thumbnail
keys exist, every one byte-identical to the file in `video/out/`, and the
public thumbnail URLs return 200 with the right length and `image/jpeg`.
`course-media` still refuses anonymous reads, so playback goes through
`get-course-video` as designed. No clips from the previous catalogue remain
under `demo/`.

Nothing in this repo did the uploading. There is no Supabase CLI on this
machine, no access token, the repo rightly refuses to store a `service_role`
key, and the MCP server exposes SQL but no Storage API — so the buckets stay a
by-hand or dashboard job, and `DEMO_MEDIA.md` says so.

### The "first teachers" announcement

A second campaign in `video/`: `TeacherCall` (9:16 and 1:1, 18s, silent) and
`TeacherFlyer` (1080×1350, dark and light). Copy in `src/announcement.ts`.

It exists because the catalogue is the thing actually missing. Eleven courses
are seeded and all eleven are ours; the product does not need more learners
yet, it needs someone to teach.

**What it may and may not claim is written into the copy file, with reasons.**
The 85/15 split, the student-paid card fee, and the worked example — a course
listed at ₦5,000 pays the teacher ₦4,250 — are real and checked against
`PRODUCT_OVERVIEW.md`. Three things a recruitment ad would normally reach for
are banned: *start earning today* (nothing is open; the closed beta ships free
courses only), *get paid straight to your account* (payouts are not built —
`payout_accounts` and the ledger exist, moving money is manual and undesigned,
and the product ad's version of this line is ahead of itself), and any claim
of scale (there are two teacher accounts, both ours). The honest pitch is that
the terms are real and the doors are not open yet, which is the offer.

It deliberately looks nothing like `AppAd`: no phones, no product screens, no
scene-by-scene tour. Type on a dark ground, one statement at a time, around a
single number. Flat brand colour, hairline rules, a hanging left margin — and
none of the things that make a graphic read as generated, down to keeping
em-dashes out of the body copy.

Both videos are silent on purpose. A typographic notice carries without sound,
most of it is watched muted, and the two audio beds are still unlistened
placeholders — the wrong thing to attach to something going out in public.

### Outstanding

- `welcome-to-padilearn`'s thumbnail is 1920x1080 where the other eleven are
  1280x720, because it is a frame of the ad rather than of a lesson board. The
  card crops to fill so it looks right; it is just the odd one out in the set.
- `welcome-to-padilearn` has a second, hand-made lesson on it ("What padilearn
  is", lowercase p) that predates the seed and has a random uuid, so the seed
  neither manages nor removes it. The course shows two lessons, both previews.
  Delete it by hand if it is not wanted.
- Nobody has read the announcement copy but me. It makes claims about money to
  people who may act on them; it should get a second pair of eyes before it is
  posted.

---

## 2026-10-04 — The demo catalogue became eleven real lessons, and the ad shows them

The demo catalogue was eleven courses whose lessons all played Pixabay b-roll:
a sewing machine for the tailoring course, a spreadsheet for the Excel one.
Footage of the *subject*, with nobody teaching it. It is now eleven
purpose-built lesson videos that each teach one idea — a figure that draws
itself, the formula, and the rule it proves — rendered from a separate project,
`PadiLearn-lesson-videos`, in PadiLearn's own palette.

`supabase/seed/import_lesson_videos.py` is the boundary between the two
repos. It takes the MP4s, writes the bucket-ready trees in `video/out/`, cuts
the course thumbnails, and drops render copies into `video/public/`. Re-run it
after rebuilding a lesson over there and the catalogue, the thumbnails and the
ad all follow.

### The footage dictates the catalogue

Each video prints its own course name and lesson number into the corner of
every frame — "WAEC PHYSICS · LESSON 14". That is not decoration, it is a
constraint, because `course_description_screen.dart` numbers curriculum rows
**by their index in the list, not by `lessons.position`**. A course whose
Projectile Motion lesson is filmed as lesson 14 has to actually have fourteen
lessons or the screen contradicts the video playing on it.

So the courses were rebuilt around the footage rather than the other way
round: twelve courses and 121 lessons, each course as long as its filmed
lesson's number requires, and every course title beginning with the exact name
its video prints. Nothing in there can be reordered or trimmed without
re-cutting a video. The seed says so at the top, at length, because this is
exactly the kind of coupling that gets discovered by breaking it.

The seed now also deletes seeded lessons that are no longer in the set. Without
that, a course that was longer on a previous run keeps its surplus rows, and
the surplus pushes the filmed lesson past its own printed number.

### One real lesson per course, and it is the preview

120 distinct lesson videos is not a thing anyone is about to record, so a
course's lessons still share one clip. What changed is which one is free: the
filmed lesson is now the course's only preview. A visitor who has not enrolled
can only open previews, so the only video they can reach is the one whose
burned-in number matches the row they tapped. Enrol and open lesson 3 of WAEC
Physics and you still get the lesson 14 clip — that is the known cost, written
down rather than discovered.

The seeded student's progress moved onto that lesson too, for the same reason:
their resume point is now nine seconds into WAEC Mathematics lesson 7, the one
lesson in the course with its own video, so the dashboard's "continue" lands on
footage that matches the row it came from.

### The ad was rebuilt on the same data

`video/src/catalogue.ts` mirrors the seed the way `theme.ts` mirrors
`colors.dart`, and the ad renders from it. The marketplace mock shows the
eleven real courses with the real thumbnails, scrolling, instead of six
invented ones behind gradient placeholders.

A new scene carries the actual footage. Hook → browse → **lesson** → learn →
teach → cta, still 24 seconds. The lesson scene plays two clips large enough to
read: the physics one joined while its trajectory is still drawing, the pricing
one joined as the formula resolves and the takeaway lands, so between them you
see a lesson build an idea and then close it. Everything else in the cut is a
claim about the product; that scene is the product, which is why it is the one
the notes say cannot be dropped from a 15-second version.

### Invented traction came out of the ad

The cards used to read "1.2k students · 4.8 ★". The database stopped carrying
invented counters when the 2026-09-14 migration made them trigger-derived, so
the ad was showing numbers the app itself would not, and a public ad is a worse
place to fabricate traction than a demo database was. They now show `New` and a
zero count, which is what the seeded app actually renders. At card size the
line is a few pixels tall and unreadable either way, so the fake was buying
nothing.

Three other things in the mock had drifted from `course_card.dart` and were
corrected while the file was open: the rating pill sat top-right instead of
bottom-left, the category pill printed in ink instead of brand green, and a
paid course's price printed in ink instead of green.

### Outstanding

- **Nothing is uploaded.** `video/out/demo-clips/demo/` (9.3 MB) goes to
  `course-media` and `video/out/demo-thumbs/demo/` (364 KB) to
  `course-thumbnails`. The seed has not been run against the database either —
  it is the usual by-hand job, and running it replaces the old demo courses.
- **The old courses do not disappear on their own.** Slugs that are gone —
  `waec-english`, `flutter-for-beginners`, `phone-photography`,
  `personal-finance`, `whatsapp-marketing` and the rest — keep their rows until
  the teardown block at the bottom of the seed is run. Their media is still in
  the buckets too.
- **Still nobody teaching.** Every figure and number in the footage is
  correct and checkable, but these are diagrams, not a person. They exist so
  the catalogue is not visibly empty for the first testers. On a marketplace a
  shaky phone recording of someone who knows their subject outsells an
  animation, because the buyer is buying the teacher.
- `fetch_demo_clips.py` and `fetch_demo_thumbs.py` are retired and banner-marked
  rather than deleted — they are the provenance and licence record for footage
  that may still be sitting in a bucket.

---

## 2026-09-29 — The card fee moved from the teacher to the student

A teacher's price used to be what the student paid, so Paystack's cut came out
of the teacher's share and their earnings moved with a fee they never agreed
to. It now works the other way: **the list price is what settles**, and the fee
is grossed up on top at checkout. The platform still keeps 15%.

On a NGN 5,000 course the student pays NGN 5,178 and the teacher earns
NGN 4,250 — previously they earned about NGN 4,100, and how much depended on
which side of Paystack's flat-fee threshold the price fell.

### The threshold trap is gone

The old model had a band where raising a price *lowered* what the teacher
earned: crossing NGN 2,500 added Paystack's NGN 100 flat fee to a price the
teacher absorbed. `pricing.dart` carried an `isInFeeDeadZone` warning for it.
Teacher earnings are now a flat 85% of the list price at every price, and
`test/pricing_test.dart` asserts that earnings rise monotonically — that is the
regression guard for the whole change.

The cliff still exists, but it moved to the student's total, so the warning was
reframed rather than deleted: one naira over the threshold adds about NGN 100
to what the student pays, which is still worth telling a teacher before they
price.

### Grossing up is not "add the fee"

Paystack's fee is a percentage of the amount *charged*, so adding a fee to a
price grows the fee and lands short. `customerTotalFor` solves for the total
instead, picking between three regimes — flat fee waived, flat fee applied, fee
capped — and only accepting a regime's answer if that regime still holds at the
resulting total. Rounding up is what makes the check order matter: the ceiling
can nudge a total across NGN 2,500, silently re-introducing the flat fee and
underpaying the teacher on every sale. The first draft did exactly that, and
the test caught it.

It is duplicated deliberately in `lib/utils/pricing.dart` and
`supabase/functions/_shared/paystack.ts` — Dart cannot run in an edge function
— and the two must agree exactly, because `initialize-payment` charges the
total and `grantEntitlement` rejects anything under it. A divergence would
reject real payments. Both files say so.

### What the student sees

Browsing still shows the teacher's price. The fee appears itemised in a
confirmation sheet before Paystack opens, because Paystack renders its own
checkout in a WebView and cannot be asked to explain our fee — so without that
sheet its page would be the first place the real number appeared. Grossed-up
prices in the catalogue were considered and rejected: it turns every
deliberate NGN 5,000 into NGN 5,178 and makes the marketplace look unfinished.

### Notes

The server still computes the split from what genuinely settles rather than
from the list price, so if Paystack's real fee differs from our estimate the
split follows the money. Existing prices need no migration: the only sales on
record are four Paystack test-mode transactions from development accounts,
made while in-app checkout was still switched on. They carry the old split —
NGN 4,101 to the teacher on a NGN 5,000 course, against NGN 4,250 now — and
they keep it, because a ledger row records what was actually paid, not what
today's rules would have paid.

---

## 2026-09-17 — A payment no longer depends on the buyer's phone surviving

Until now the only thing joining a payment to an enrolment was the handset
holding the checkout screen. `verify-payment` ran when the app asked it to, so
if the app was killed, the network dropped or the battery died between Paystack
taking the money and that call being made, Paystack kept the money and the
student got nothing. Nobody would have noticed except the student.

`supabase/functions/paystack-webhook` closes that window. Paystack delivers
`charge.success` independently of the buyer's device and retries for days, so
fulfilment survives the app dying.

### Why the logic moved to `_shared`

The webhook and `verify-payment` must reach an identical outcome, and the fee
split is where that would quietly fail. Paystack deducts its fee before
settlement, so the platform's 15% is taken on what *arrives*, not on the list
price — get that wrong on a cheap course and the teacher is paid more than was
received. Two hand-maintained copies would have drifted within months, and the
symptom would be a teacher's balance that depends on whether their student's
phone stayed awake. `_shared/paystack.ts` now holds one copy; both entry points
call it.

`fetchTransaction` re-asks Paystack rather than trusting the webhook payload's
own numbers. A signed payload is authentic but not necessarily current, and the
webhook's `data` is not shaped quite like a verify response — `fees` in
particular is not always present.

### Authentication, and the deployment that breaks it

The webhook is public: Paystack has no Supabase JWT. It must be deployed with
`--no-verify-jwt`, which makes the HMAC SHA-512 signature check the *only* thing
standing between a stranger and a free course. The comparison is constant-time,
because `===` on a hex digest leaks how many bytes were right and lets a
signature be forged a byte at a time.

Deploying it *with* JWT verification does not fail loudly — it silently rejects
every delivery, which looks exactly like Paystack not sending anything.

### Retry semantics

A 500 asks Paystack to deliver again; a 200 ends it. So a database blip retries
and missing metadata or a deleted course does not, because redelivering those
would fail identically forever. That is what `retry` on the `Fulfilment` type
carries.

### Outstanding

Nothing here has been deployed, and none of it has been type-checked — this
machine has neither Deno nor the Supabase CLI. `verify-payment` changed too and
must be redeployed. The webhook URL still has to be set in Paystack's dashboard,
and the `_shared` import means both functions have to go up through the CLI
rather than the dashboard editor. Then it needs testing with a real payment,
and with the app deliberately killed straight after paying.

---

## 2026-09-16 — Google sign-in: which certificate Google actually checks

The code for Google sign-in has been finished for a while; none of it works yet,
because the setup lives outside the repo and nobody had written down what has to
match what. `docs/LAUNCH_ANDROID.md` section C now records it.

### Why the Supabase dialog is mostly decoration

The app signs in **natively** — `GoogleSignIn.authenticate()` hands an ID token
to `signInWithIdToken` (`auth_service.dart`). It never calls `signInWithOAuth`,
so the provider page's **Client Secret** and **Callback URL** are unused, and
so is "Skip nonce checks" (`google_sign_in` mints no nonce, so there is nothing
to skip). Only **Client IDs** does anything: Supabase matches the token's `aud`
claim against that list.

Which ID lands in `aud` is the part that reads backwards. On Android it is the
**Web** client ID, because Android passes it as `serverClientId` — the Android
client ID never appears in `aud` and so is never listed in Supabase, even
though Google refuses to issue a token without that client existing. On iOS
`aud` is the iOS client ID.

### The failure that only shows up in front of testers

Google ties the Android client to a **signing certificate**, and under Play App
Signing the bundle you upload is re-signed with *Google's* key before it reaches
anyone. So the fingerprint on every build made by hand is not the fingerprint on
the build testers install. Register only the debug and upload SHA-1s and
sign-in passes every check you can run yourself, then fails for all 15 closed
testers at once. The **App signing key** SHA-1 from Play Console has to go in
too.

Debug SHA-1 on the owner's laptop is
`17:B5:FB:AD:FC:1B:CC:9C:01:70:15:D4:D2:4E:7B:6E:CD:DB:77:7F`. These are public
certificate fingerprints, not secrets — the keystores and their passwords stay
out of the repo as before.

### Outstanding

No OAuth clients exist yet, and anything created earlier under
`com.dankamaInnoHu.padiLearn` died with the package rename. `googleWebClientId`
in the git-ignored `lib/config/supabase_config.dart` is still empty, which is
the one mercy here: `isGoogleSignInConfigured` hides the button rather than
shipping one that fails. The upload keystore still does not exist, so its
fingerprint cannot be registered. `assets/branding/google_logo.png` is missing,
and `ios/Runner/Info.plist` has no `CFBundleURLTypes` block for the reversed
iOS client ID.

---

## 2026-09-16 — Release signing, without the secrets

`android/app/build.gradle` had shipped the Flutter template's placeholder since
day one: release builds signed with the **debug** key, under a TODO. That build
installs and runs perfectly on a phone, which is exactly why it is dangerous —
nothing goes wrong until Play rejects the upload.

### How it works now

`signingConfigs.release` reads `android/key.properties`: store path, store
password, key alias, key password. That file is git-ignored (so are `*.jks` and
`*.keystore`), and `android/key.properties.example` records the shape without
any values.

**The fallback is deliberate, but it stops at the bundle.** When
`key.properties` is absent, `assembleRelease` still signs with the debug key, so
`flutter run --release` and `flutter build apk --release` work on a clone that
has no keystore. `bundleRelease` does not: it fails at configuration with a
message naming the file to create. An `.aab` is only ever built in order to
upload it, so a missing keystore there is a mistake rather than a convenience.

The first attempt at this was a `logger.lifecycle` warning on the fallback path.
A test build proved it worthless — `flutter build` filters Gradle's lifecycle
output, so the warning never appeared and the debug-signed bundle was produced
in silence. Verified by `keytool -printcert -jarfile`, which reported
`CN=Android Debug`. A warning nobody sees is not a safeguard; failing the one
task that matters is.

The keystore itself is not created here and its passwords are not in this repo
or known to anyone but the owner. It lives outside the repo by instruction in
`key.properties.example`, because a `.jks` sitting in the working tree is one
`git add -A` away from being public.

### Why this one is unforgiving

The upload key is the only proof that an update comes from the same author.
Lose it and the app can never be updated — not recovered, not reset, a new
listing and every install starts from zero. Leak it and someone else can sign
something Google will accept as genuinely yours. Play App Signing softens the
first risk once enrolled, but the upload key still has to survive.

### Still outstanding

- Run `keytool`, write the real `key.properties`, enrol in Play App Signing.
- Back the keystore up somewhere that is not this laptop.
- The Google OAuth Android client must be registered against the **release**
  key's SHA-1 as well as the debug key's, or social sign-in fails in exactly
  the build the testers get.

---

## 2026-09-16 — The app is com.padilearn.app

The package name moved from `com.dankamaInnoHu.padiLearn` to `com.padilearn.app`
so the app identifies itself by the product's own domain rather than a
workspace name that no student will recognise.

**This had to happen now or never.** Google Play freezes the package name at the
first upload and there is no way to change it afterwards — a different name
means a different app, a different listing and a fresh start on installs and
reviews. Nothing has been uploaded yet, so the change cost nothing today and
would have cost everything in a fortnight.

`com.padilearn.app` rather than bare `com.padilearn`: three segments keep
native plugins that assume the conventional shape happy, and leave room for a
sibling app under the same domain later.

### What it touched

- `android/app/build.gradle` — `namespace` and `applicationId`
- `android/app/src/main/AndroidManifest.xml` — the stale `package=` attribute is
  **gone**, not renamed. AGP 8.9 takes the namespace from Gradle; the manifest
  attribute has been unsupported since AGP 8, and leaving it behind would have
  meant two sources of truth disagreeing after the rename
- `MainActivity.kt` — package declaration, and the directory tree under it
  (`kotlin/com/padilearn/app/`)
- `ios/Runner.xcodeproj/project.pbxproj` — six bundle identifiers, app and
  `RunnerTests`
- `android/app/google-services.json` — **deleted.** A leftover from the removed
  Firebase; no `google-services` plugin is applied anywhere in the Gradle
  files, so nothing read it. It carried the old package name

Nothing in `lib/`, the website or Supabase referenced the package name. The
`padilearn://reset-callback` deep link is a custom URL scheme and is unaffected.

This also settles the "Noticed, not fixed" item from the 2026-08-24 entry: only
`build.gradle` remains, so there is no longer a second file declaring a rival
`applicationId`.

### Still outstanding

- The Google and Apple OAuth clients don't exist yet, which is *why* this was
  cheap — Android OAuth clients are registered against package name plus
  SHA-1. Create them against `com.padilearn.app` and the release keystore's
  fingerprint, never the old name.
- `flutter clean` before the next build; `build/` still holds artifacts under
  the old name.
- The release keystore is still unmade and release builds are still signed with
  the debug key.

---

## 2026-09-14 — Every email the app sends has somewhere to land

With padilearn.com live, the app links to the site for its legal pages, and
each auth email now sends people somewhere that works.

### Links to the site

`lib/config/web_links.dart` holds every padilearn.com URL the app uses.
`lib/utils/external_links.dart` has the two ways the app leaves itself:
`openWebPage` (the external browser; copies the link if none opens) and
`emailSupport` (mailto; copies the address if there's no mail app). Both
profile screens now show Privacy Policy and Terms of Service under **Support
& Legal**. Register and login show "By continuing, you agree to our Terms and
Privacy Policy". Login needs it too, because Google sign-in creates an account
from there.

### Where each email lands

| Email | Link goes to | Why |
|---|---|---|
| Password reset | `padilearn://reset-callback` (unchanged) | Setting a password needs the app's recovery session, so it has to open the app |
| Sign-up confirmation | `https://padilearn.com/email-confirmed` | Was the project Site URL. People open these on laptops too, and a deep link does nothing there |
| Email change | `https://padilearn.com/email-confirmed` | Same |

Supabase has already confirmed the address before it redirects, so
`/email-confirmed` only reports the result. If the URL carries
`error_code`, it shows "This link didn't work" and tells the user to use
**Resend**. It also clears the one-time code from the address bar.

### Other fixes

- **Login with an unconfirmed email** used to show Supabase's bare "Email not
  confirmed", with no way forward. It now offers **Resend**, which sends a new
  link to the same page.
- **Forgot password** printed the raw exception (`Error: AuthException(...)`),
  had no loading state so a double tap sent two emails, and its "Back to
  Login" *pushed* another login screen. It now checks the email format, shows
  a spinner, returns to the existing login screen, and uses the same wording
  whether or not the account exists, so it can't be used to test which emails
  are registered.
- **Rate limits** get plain wording (`authEmailErrorMessage`). With custom
  SMTP, Supabase allows 30 auth emails an hour by default, which a group of
  testers can hit.

### Needs doing in the Supabase dashboard

Authentication → URL Configuration:

- **Site URL:** `https://padilearn.com`
- **Redirect URLs:** `padilearn://reset-callback` and
  `https://padilearn.com/email-confirmed`

A redirect that isn't listed is silently replaced with the Site URL, so the
code alone doesn't make these work.

---

## 2026-09-14 — padilearn.com: landing page and legal pages

A static site in `website/`, for Cloudflare Pages. It has a landing page,
`/privacy`, `/terms`, `/delete-account` (the web deletion URL Play requires)
and `/payment-callback`. Not deployed yet. `website/README.md` has the steps.

**Why Cloudflare Pages:** it's free with unlimited bandwidth, and its free plan
allows commercial use. Vercel's Hobby plan doesn't, and PadiLearn sells courses.
Moving the domain's DNS there also gives free email forwarding for
`hello@padilearn.com` and makes the custom SMTP records easy to add.

**Design, second pass (same day).** The first version, with a serif display
font, gradient hero, drawn phone mockup and feature cards, read as generic.
It was replaced with a plain product-page style: system fonts, white and
light-grey sections, large centred headlines, brand green as the only accent,
and **real app screenshots**. The three screens (home, marketplace, course page)
were captured from the emulator with `adb exec-out screencap` and live in
`website/src/assets/screens/`. `astro:assets` serves them as AVIF/WebP at
about 15–60 KB each. They come from the build that was installed at the time,
so they still show the old seeded ratings, enrolment counts and prices. Recapture
them once the counters migration is live. The video player wasn't used: its
only lesson is a third-party TikTok clip.

**Why Astro 5, not the latest:** Astro 7 needs Node 22.12+, and this machine
runs Node 20.16. Astro 5 builds the same static output. Upgrade both together.
Cloudflare builds with `NODE_VERSION=22`. Tailwind was left out: five pages
don't need it, and the colours come from `lib/utils/colors.dart` as CSS
variables, including dark mode.

**The legal pages describe real behaviour, so they are a contract.** What
`/delete-account` and `/privacy` say is deleted or kept comes from
`supabase/functions/delete-account` and migration `20260914000001`. That
covers purchase records kept with the buyer removed, reports kept, and paid
teachers refused and sent to support. Change the function and the pages
together. The landing page shows no ratings or enrolment counts, for the same
reason the app stopped faking them.

**`/payment-callback` grants nothing.** Normally the checkout WebView
intercepts it before it loads. If someone does reach it in a browser, it shows
the Paystack reference and sends them back to the app, where `verify-payment`
does the real work.

**Outstanding:** deploy; add the operator's legal name to the privacy policy
once it's decided; `assetlinks.json` once the Play signing key exists; refunds
and payouts terms before paid courses launch.

---

## 2026-09-14 — Play Store blockers: deletion, reporting, honest numbers

Five items from `LAUNCH_ANDROID.md` section B, done together because the
production review would reject the app for any one of them.

### Account deletion

Play requires an in-app way to delete an account. It is a new edge function,
`delete-account`, because removing an auth user needs the service role. Both
profile screens have a "Delete account" tile that asks the user to type DELETE
first.

The function works in the order that fails safe: remove the user's storage
files first, delete the auth user second. Storage removal can be retried. The
other order could leave personal files behind for an account that no longer
exists, with nobody left to ask for them to be removed.

**Two schema problems had to be fixed first** (migration
`20260914000001_account_deletion_and_reports.sql`):

- `transactions.buyer_id` was `ON DELETE CASCADE`. Deleting an account would
  have erased the record of what it paid, and taken the matching amount out
  of the teacher's earnings. It is `SET NULL` now, like `teacher_id`. **The
  privacy policy must say payment records are kept.**
- `bump_course_enrollments` only ever added one. With deletion, enrolments
  cascade away and the count would never come down. It is replaced by a
  recount on insert and delete.

**A teacher whose courses have paying students is refused**, with a 409 asking
them to contact support. Deleting a teacher deletes their courses, so the
students would lose what they paid for, and there is no refund flow yet.
Everyone else goes straight through.

### The fake numbers are gone

Every card showed 4.5 stars from a hard-coded default, and the demo seed had
written 18,140 enrolments against 10 real rows. The migration recounts both
counters from the real rows, and the seed now inserts zeros. Cards read
`rating_avg` / `rating_count` through `courseRating()` and show **New** when
nothing is rated. The minimum-rating filter leaves unrated courses out instead
of counting them as zero stars.

`courseRating()` accepts a number or a string. A query returns numeric columns
as numbers, but the realtime stream can return them as strings, and a plain
cast would have thrown on the first live update.

### Reporting

Play's User Generated Content policy wants objectionable content reportable
from inside the app. There is now a flag in the course page's app bar, and
"Report" in the menu on other people's comments. Both open one shared sheet
(`report_sheet.dart`).

`content_reports` is write-only for clients. A trigger fills in the reporter,
the status, and a snapshot of the reported text. That way a report can't be
forged to point at someone else, and it keeps its evidence after the content
is taken down. Every foreign key is `SET NULL` for the same reason. A unique
index allows one report per person per item, and the app shows a second
report as "already reported" rather than an error.

**Nobody is told when a report arrives.** For the closed test, check
`content_reports where status = 'open'` in the dashboard every day. Add an
email alert (a database webhook) before production.

### Paid checkout is switched off

`kPaidCheckoutEnabled` in `lib/config/features.dart` is `false`. Paid courses
still appear, with their price and free preview lessons, but the button reads
"Not available yet". The note underneath deliberately doesn't say where else a
course could be bought, because Play also bans steering users to an outside
checkout. All the Paystack code is still there behind the flag.

### Support and error reporting

Help & Support opens an email to `kSupportEmail` (`hello@padilearn.com`). If
the phone has no mail app, the address is copied instead.

The domain is `padilearn.com`, bought 2026-09-14. The Paystack callback URL
pointed at `padilearn.app`, which we never owned, so it now points at `.com`
in both `payment_service.dart` and `initialize-payment`. Checkout is off, so
nothing depends on this yet. `initialize-payment` needs redeploying before
checkout is switched back on.

Sentry is set up in `main.dart` and reads its DSN from
`--dart-define=SENTRY_DSN`, so a build without one reports nothing and the key
stays out of git. It sends errors only (no tracing, no PII). Events carry the
user's id and never a name or email, which keeps the Data safety answer
simple.

### Outstanding

- Apply the migration and deploy `delete-account` to the live project.
- Create a Sentry project and pass its DSN in release builds.
- Test deletion end to end on a throwaway student and a throwaway teacher.
  Check that their storage files are gone and their transactions remain.
- Moderation alerts, as above.

---

## 2026-09-06 — Courses you already own

A student could see a course they had already bought sitting in the marketplace
with its price on it, and buy it again.

Two changes. The marketplace now hides courses the student is enrolled in — the
shelf is for things they can still buy. Everywhere a card can still show an
owned course (the dashboard's "Popular Courses", the course page) it prints
**Owned** where the price would go.

"Owned" rather than "Purchased" on purpose: free courses are enrolments too, and
telling someone they purchased something they got for nothing is a small lie a
receipt would contradict.

### Where the answer comes from

`OngoingCoursesController` already streams this student's `enrollments` for the
"Continue learning" row, so `ownedIds` is derived from the rows it has rather
than from a second query. Opening another realtime subscription on the same
table for the same user would have doubled this screen's share of the
connection budget to learn nothing new.

All three places rows land — the stream, the pull-to-refresh, the offline cache
— now go through one `_apply`, so the id set cannot drift from the list.

Two things that would have made this silently not work:

- **`RxSet` was the wrong type.** Its `value` is `@protected`, and its
  `contains()` reads the backing field directly — so calling it inside an `Obx`
  registers no dependency and the marketplace would not drop a course until
  some unrelated rebuild wandered past. It is a plain `Rx<Set<String>>`, read
  through `.value`, which is what actually subscribes.
- **Registration order.** The controller is registered per user id by the
  dashboard's widget, so whether the marketplace saw any enrolments depended on
  which tab built first. `HomeShell` now registers it alongside the student
  screens, and `forCurrentUser()` is the read-only accessor for screens that
  should not care about the tag — returning null rather than throwing, because
  teachers and signed-out users have no enrolments controller at all.

### Outstanding

Search shares the filter, so searching for a course you own finds nothing. That
is defensible for browsing and arguably wrong for search — the fix, if it
bites, is to filter the catalogue but let an explicit query through with the
card's `isOwned` badge already built for it.

---

## 2026-09-05 — Dark mode actually works, and password reset reaches the app

### Dark mode was a toggle attached to nothing

`SettingsController` switched `ThemeMode` and 36 files went on painting
`appWhite` surfaces with `richBlack` text, so turning it on produced black text
on white cards on a dark ground. The toggle worked; nothing downstream did.

The fix is a split in `colors.dart`. Constants there are now only things that
mean the same in both themes — the brand green, and foregrounds that always sit
on it (white on the green button is white either way). Anything describing a
**surface, or the ink on it**, moved to `AppPalette`, a `ThemeExtension` with
five tokens: `ground`, `surface`, `surfaceAlt`, `ink`, `inkSoft`, `hairline`.
Five, not a full system, because those are the only ones the app broke without.

`primaryColor` stays theme-independent on purpose. It is the identity, it
carries white text at the same contrast on either ground, and freezing it kept
168 usages out of this change.

`main.dart` now points every Material default that paints a surface at the
palette — scaffold, app bar, cards, dividers, dialogs, sheets, inputs,
snackbars. That matters more than it sounds: a screen that simply *doesn't* set
a colour now comes out right in both themes, so only the screens that
hard-coded one needed touching.

302 substitutions across 36 files. `appWhite` was the hard part — 71 uses split
between "white text on a green button" (must stay white) and "card background"
(must flip), which no find-and-replace can tell apart. They were classified by
walking back to the enclosing constructor, defaulting to *leaving it white*
when ambiguous: a stray white card is visible and fixable, white text turned
dark on a green button is invisible. 48 flipped, 24 stayed.

### `AppColors.palette` is a deliberate compromise

Much of this app paints from helper methods that were never handed a
`BuildContext` — `Widget _buildStats(TeacherController c)` and its like. A
context-only API would have meant changing dozens of signatures across 36 files
to fix a colour bug.

So there is a static `AppColors.palette`, bound once per frame from `MyApp`'s
builder above the Navigator. `AppColors.of(context)` still exists and is
preferred where a context is already in hand. The static holds because this app
has one `MaterialApp` and never renders two themes at once — if that changes, a
themed preview or a per-subtree `Theme`, those widgets have to move to `of`.

**The first version of this shipped broken, and it is worth understanding why.**
Reading a static creates *no dependency* on the `Theme` inherited widget. So
when the mode flipped, `MaterialApp` rebuilt and the static updated correctly,
but every screen already sitting in the Navigator never rebuilt — nothing had
told it to. Switching to light mode left a dark screen with a light strip along
the bottom, where the `Scaffold` (which *does* depend on the theme) had
repainted underneath a body that had not.

The fix is `AppColors.watch(context)`, called once at the top of every `build`
that paints from the palette — 46 of them. `Theme.of` inside it registers the
dependency, which is the part that makes the widget rebuild; refreshing the
static at the same time is what keeps the context-free helper methods correct,
since they re-run as part of that rebuild.

`test/widget_test.dart` covers it: a probe widget that watches and then paints
from the static, asserted across a mode flip. Removing the `watch` call fails
it, so it is a real guard rather than a restatement.

### Password reset dead-ended before it reached the app

`resetPasswordForEmail` was called with no `redirectTo`, there was no scheme
registered on Android, and nothing listened for the recovery session. The mail
arrived, the link opened a browser, and that was the end of it — no screen in
the app could set a password.

Now: `redirectTo: DeepLinks.passwordReset` (`padilearn://reset-callback`), an
intent-filter in `AndroidManifest.xml`, and a `passwordRecovery` listener in
`MyApp` that pushes the new `ResetPasswordScreen`. Following the link signs the
user into a short-lived recovery session, which is what lets `updateUser`
change the password without the old one — so that screen is only ever reached
from the link, never navigated to directly.

**Three places have to agree** or the redirect is silently refused and the user
lands on the project's site URL: `lib/config/deep_links.dart`, the
intent-filter, and Supabase's Redirect URLs allowlist.

### One home per account action

Logout, About and Edit Profile each existed in both Settings and the Profile
screen. They now live on Profile only, and Settings keeps just the things that
have no other home: Change Password, Notifications, Dark Mode.

The direction matters more than which copy survived. Removing duplicates in
*opposite* directions — Logout kept on Profile, Edit Profile kept in Settings —
would have taught two contradictory rules for where account actions live. So
Profile is the single home, and the Edit Profile button stays under the name
card, beside the photo and name it changes.

The commented-out GENERAL block went with it rather than being left to rot; git
has it.

Deleting it exposed a gap: About had only ever existed there and in the
*student* profile, so teachers were left without it. The section is now a shared
`ProfileSupportSection` used by both profiles rather than a block copied into
one of them — the two profile screens are maintained separately, which is
exactly how the roles diverged in the first place.

The version string went the same way. It had been written by hand in two places
and this would have made three, so `lib/utils/app_info.dart` holds the name,
version and legalese. It is still a constant that has to track `pubspec.yaml` by
hand; `package_info_plus` reads the number the build was actually stamped with,
and is worth adding the first time a shipped build claims the wrong version.

### Outstanding — needs doing in the Supabase dashboard

- Add `padilearn://reset-callback` under **Authentication → URL Configuration →
  Redirect URLs**. Until this is done the deep link does not work.
- Point **Authentication → SMTP Settings** at a real provider. The built-in
  sender is rate-limited to a handful of mails an hour and is not for
  production — a reset nobody receives is the same bug in a different place.
  Custom SMTP is available on the free plan; this does not need Pro.
- iOS will need the same scheme under `CFBundleURLTypes` whenever it ships.

---

## 2026-09-03 — System navigation insets, and four kinds of duplication

### The nav pill was underneath the device's own navigation

Flutter draws edge-to-edge by default at this target SDK, so the Scaffold's
`bottomNavigationBar` slot extends *behind* the system navigation bar. The pill
had a hard-coded `margin: bottom 30`, measured from the bottom of the screen
rather than from the bottom of the usable area — so on three-button navigation
(48dp) its lower half sat behind Back/Home/Recents, and on gesture navigation
it sat inside the handle strip, which swallows touches outright.

The gap is now measured from `MediaQuery.viewPadding.bottom`. `viewPadding`
rather than `padding` because `padding` collapses to zero when the keyboard is
up, and the pill would jump.

Same bug, same fix, in every other place something is anchored to the bottom:
the onboarding "Get Started" sheet, the marketplace filter and course-preview
sheets, the settings change-password sheet, the bank picker's last row, the
video player's comment box, and the course description's buy button. Bottom
sheets use `padding.bottom` there, not `viewPadding` — they already offset for
`viewInsets`, and double-counting would leave a gap the height of the nav bar
above the keyboard.

Two things fell out of rewriting the pill:

- The `Stack` around it was **not** left over from the deleted centre button —
  it was doing the centring. Scaffold hands that slot a *tight* full-width
  constraint, so a `Container` with its own `width` cannot size itself and
  silently becomes a full-width bar. It needs a full-width parent (`Align`) to
  be a pill inside. A test caught this; the eye would not have, quickly.
- The items are `Expanded` now. They were fixed-width children scaled with
  `.w` inside a pill whose width was *not* scaled, which overflows once the
  screen is far enough from the 393pt design width. Scale all three or none —
  this file now scales none, matching its unscaled 28pt icons.

`test/widget_test.dart` covers it at 0 / 24 / 48dp insets. It was the generated
counter smoke test before, tapping an `Icons.add` this app has never had.

### `Get.put` was quietly undoing the fenix registration

`teacher_dashboard.dart` and `my_courses.dart` both did
`Get.put(TeacherController())`. `main()` registers that controller with
`fenix: true` specifically so it survives the `Get.deleteAll()` on sign-out —
and `Get.put` replaces that registration with a non-fenix one, after which
every *other* screen's `Get.find<TeacherController>()` throws once someone
signs out. It also built a fresh controller, re-running all three fetches,
every time either tab was rebuilt. Both are `Get.find` now.

Register in `main()`, find at the point of use. Don't `Get.put` a controller
`main()` already owns.

### Tabs are an IndexedStack

`_screens[_selectedIndex]` disposed the outgoing tab's State on every switch,
which tore down and rebuilt its realtime subscriptions — the teacher's course
stream, the activity feed — and discarded scroll position and search text.
Safe to do now that the tabs share their controllers rather than each putting
their own.

### One spelling for money

`'NGN ${x.toStringAsFixed(0)}'` was written by hand in six places; the
"Free or price" rule existed a seventh time inside `PriceTag`, which took a
pre-stringified price *and* an `isFree` bool the price already implies; the
marketplace screen imported a card *component* to reach `formatPriceLabel`;
and `earnings_hint.dart` carried its own thousands-separator routine and wrote
the currency as the naira glyph while every other screen wrote `NGN`.

All of it is `lib/utils/money.dart` now, and the app says `NGN` throughout.
`NGN` over the glyph deliberately: the glyph is not guaranteed present in every
font we ship, and a tofu box where a price should be is worse than three
letters. Amounts are grouped (`NGN 25,000`), which they were not before outside
the earnings hint.

### Dead code

Removed: `avatar_stack.dart` (hard-coded `+52` and three asset faces, never
referenced), `custom_back_button.dart` and `center_nav_button.dart` (entirely
commented out), `otp_screen.dart` (a non-functional stub whose button does
nothing — nothing routes to it), and `firebase.json` (a leftover pointing at
the retired Firebase project; nothing in `pubspec.yaml` or `lib/` references
Firebase any more).

`CoursesController` lost `courses` / `fetchCourses()` and its `UserController`
handle. Nothing read that list — `MarketplaceController` owns the catalogue and
both the marketplace and the student dashboard read it from there — so it was a
full-table `select()`, every column including descriptions, fetched on every
launch and thrown away. It carries the tapped course to the description screen;
that is all it ever did.

### Still outstanding

`README.md` still describes a Firebase backend, `firebase_options.dart`, and a
FlutterFire setup that no longer exists. It needs rewriting against Supabase
before anyone new tries to follow it.

Dark mode is a toggle that does not work. `SettingsController` switches
`ThemeMode` and 36 files then paint `AppColors.appWhite` backgrounds and
`richBlack` text regardless. Either hide the toggle for v1 or do a proper
token pass — a half-dark app is worse than a light one.

---

## 2026-08-31 — Continue-learning order, course load time, thumbnails

### Latest enrolment first

`ongoing_courses_controller.dart` had **no ordering at all** — neither the
realtime stream nor the pull-to-refresh path. Rows arrived in whatever order
Postgres returned them, so the course you just bought landed wherever it
happened to fall, which is the one place a user will not look for it. Both
paths now `.order('enrolled_at', ascending: false)`. Ordering both matters: if
only the stream had it, a refresh would reshuffle the list.

### Opening a course was four round trips

`videoPlayer.dart` fetched the course, then its lessons, then this user's
progress, then their rating — sequentially, each awaiting the last, none
depending on the one before. Four serial round trips before the player even
asked for a video URL, which on a mobile connection is most of a second of
nothing.

Now one `Future.wait` over a record. Two things fell out of the rewrite:

- Each fetch is individually wrapped, so one failure no longer takes the others
  down. They previously shared a try/catch, meaning a ratings hiccup could
  leave the screen with no lessons at all.
- The course row is selected by column instead of `select()`, which had been
  pulling every field including the full description.

The fifth trip — the signed playback URL — genuinely depends on knowing which
lesson, so it stays sequential.

### Thumbnails

Eleven photographs, 1.4 MB, at `video/out/demo-thumbs/`. Plain photography with
no text baked in: the card already prints title, author and price *underneath*
the image, so type in the picture collides with it, and stock photos with words
on top are the tacky look to avoid.

Took three passes, and every rejection came from actually looking at the
results: a literal **snake** for Python, a **cartoon dog with a guitar** for the
welcome card, a flat "RISK ASSESSMENT" illustration for Excel, the blue
"SOCIAL" tech-collage for WhatsApp, and — twice — foreign banknotes for a
course priced in naira. Adding `image_type=photo` to the Pixabay search stopped
the vector art; the currency problem was solved by picking an image with no
money in frame.

Remaining imperfections are recorded in `supabase/seed/DEMO_THUMBNAILS.md`
rather than smoothed over: the finance ledger is a joke if you read it closely,
the photography card shows a film SLR rather than a phone, and the WhatsApp one
leans laptop.

---

## 2026-08-31 — Demo lesson clips

Eleven themed clips, one per seeded course, 13 MB total, sitting at
`video/out/demo-clips/` ready to drag into `course-media`. Every seeded lesson
now points at them with a truthful `duration_seconds`.

**Pixabay was the only stock library that could be scripted.** Coverr, and
Pexels without an API key, are closed; Pixabay's search pages do expose their
CDN `_medium.mp4` URLs. One catch worth recording: Pixabay serves curl fine but
returns 403 to Python's urllib no matter what User-Agent is set — they
fingerprint below the header level, so `fetch_demo_clips.py` shells out to curl.

Pixabay Content License: commercial use, no attribution. The one limit is that
you cannot redistribute their content *as the product* — fine as placeholder
lesson video, not fine if a paid course were nothing but Pixabay stock.

### Verified by looking, which audio never allowed

Extracted a frame from each clip and actually reviewed them. Three of the first
ten were wrong and got refetched: Flutter had a dated "matrix code" wall,
personal finance showed hands counting **US dollars** for a course priced in
naira, and photography was an out-of-focus coastline — a photo's subject, not
the craft. A fourth pass caught phone-photography and whatsapp-marketing
resolving to the *identical* clip, which would have played the same video in
two different courses; the fetch script grew a candidate offset.

This is the difference from the music: video can be checked before it ships.

### Decisions

- **One clip per course, shared by its lessons.** Nobody in a demo opens six
  lessons of one course, and 11 files keep this at 13 MB rather than 42 files.
- **`duration_seconds` rewritten to the real file length**, and the seeded
  resume point pulled from 4:12 back to 6s — it was beyond the end of a 14s
  clip, so the player would have tried to seek past the file.
- **Silent.** Audio stripped; the sources were ambient b-roll.
- Clips are gitignored (regenerable stock footage); the fetch script and
  `DEMO_MEDIA.md` are tracked so the set can be rebuilt or audited.

Still approximations: the photography clip shows a film camera rather than a
phone, and the finance spreadsheet is in dollars. Best available from a general
stock library — replace first if anyone will look closely.

---

## 2026-08-27 — Audio pipeline, with placeholder beds

Remotion's `<Audio>` takes a per-frame `volume` function, so fades and (later)
ducking under a voiceover are envelope edits rather than new plumbing. Both
compositions now carry a bed.

The ad's music starts at the **browse** scene rather than frame 0, so the hook
plays dry and the opening line lands in silence — that is what
`directions.hook` asks for, honoured in the build instead of left as a note for
someone else to apply.

### Sourcing was harder than expected

Free Music Archive, Pixabay and Incompetech all turned out to be dead ends for
automated download: FMA and Pixabay serve file URLs through JavaScript, and
Incompetech's old direct MP3 paths now 404. The Internet Archive was the only
source with genuinely direct, unauthenticated file URLs.

Landed on two HoliznaCC0 tracks — that artist dedicates their catalogue under
CC0 1.0, so no attribution is owed and the dedication cannot be revoked.

### Two caveats, both recorded in `public/audio/SOURCES.md`

- **The licence rests on the artist, not the Archive item it came from.** That
  item has no `licenseurl` in its metadata and is a user-assembled compilation
  containing other artists whose terms were not checked. Only HoliznaCC0-credited
  files were taken; the authoritative CC0 statement is on the artist's own FMA
  pages. Verify there before anything ships.
- **Nobody has listened to these.** They were picked from title, genre tag and
  duration. Audio is the one thing in this project that cannot be checked by
  looking at it, and music choice is almost entirely taste. Placeholders that
  prove the pipeline — swapping is a file replacement, same names, nothing else
  changes.

Still missing: voiceover, and every spot effect the direction asks for. A logo
sting in particular wants designed sound rather than a music bed; what is on it
now exists so the file is not silent.

---

## 2026-08-27 — Spores, depth, and a director's cut

### Logo

Particles and a slight 3D tilt on the mark. The motes are precomputed once from
Remotion's seeded `random`, **not** `Math.random`: frames render independently
and in parallel, so an unseeded value re-rolls every frame and the motes strobe
instead of drifting. The tilt is capped around 16 degrees — past roughly 14 the
tile's rounded corners start reading as a distorted rectangle rather than a
square turned in space.

Two wrong passes on the particles worth remembering: brand green made them
invisible (they travel over green in both variants), and clustering them at the
leaf's base read as dirt on the artwork rather than something coming off it.
They are white now, larger, spread along the leaf's whole length.

### Editing direction

`EditorsNotes` — the ad at half size with running timecode, the current scene
and its bounds, and the voiceover / sound / vibe direction beside it, plus a
scene timeline and the notes holding across the whole cut. For handing to a
sound designer, VO artist or editor.

**A separate composition, not an overlay inside the ad.** That was a choice: an
in-ad flag can be left switched on, and the notes would then ship. This way
`AppAdLandscape` has no code path that draws them at all. The reference cut
also carries a standing "REFERENCE — NOT FOR RELEASE" watermark so a stray copy
is obviously not the deliverable, with no context needed.

The direction lives in `src/theme.ts` beside the ad copy and reads the same
`SCENES` table the ad does, so retiming a scene carries its notes along instead
of silently desynchronising them.

---

## 2026-08-27 — Logo motion graphic

`video/src/components/LogoMark.tsx` — the mark animated as a plant growing,
which is the idea already sitting in the logo that nothing was using. The stem
rises out of the baseline, the bowl sweeps right to close the "P", the shoot
draws along its curve, and the leaf springs from where it meets the shoot with
a little overshoot. A pass of light crosses the tile; once settled the mark
breathes very slightly, so a held frame is never quite dead.

Two new compositions (`LogoSting`, `LogoStingSquare`, 4s each) and the ad's
closing card, which now runs the same build instead of showing a flat PNG.

### Why live SVG rather than animating the PNG

The point is animating the parts *against each other* — a raster can only scale
and fade as one lump. The leaf, its vein and the shoot are the exact path data
lifted out of `assets/branding/icon_foreground.svg`, so the organic shapes are
the real artwork. Only the "P" is reconstructed: it is two rounded rectangles
and a half-round right edge, trivial to match and far easier to reveal
piecewise than the converter's clip-path soup.

**Consequence to remember:** the mark is now drawn in two places. If the brand
mark ever changes, `LogoMark.tsx` has to follow, and it will not fail loudly if
it doesn't — it will just quietly animate the old logo.

### The mistake worth keeping

The first attempt at the tile-less variant inverted the fills, painting
everything white for the green background. The leaf disappeared: it sits *on*
the white P in the real artwork, so white-on-white is nothing at all. The
variant now keeps the true colours and only drops the tile. Noted in the props
doc so it isn't re-derived.

`speed` multiplies the build's pace — the full 110-frame growth reads well
standing alone but would eat a whole scene of the ad, so the closing card runs
it at 2x and holds the wordmark back until the mark has finished.

---

## 2026-08-27 — Demo catalogue seed

`supabase/seed/demo_catalogue.sql` — 11 courses, 42 lessons, and one student
part-way through a course. Applied to the remote project.

**Not in `supabase/migrations/`.** Migrations describe the database's shape and
every environment has to run all of them; this is sample data for showing the
app to people, and production should be able to skip it. Run by hand.

Re-runnable: every id is derived from its slug
(`'a0000000-…' || substr(md5(slug),1,12)`) rather than generated, so a second
run updates the same rows instead of duplicating them. The shared prefix is
also what makes the teardown at the bottom of the file safe — real courses get
random ids and cannot collide with it.

Two things the first run taught us, both now fixed in the file:

- `courses.enrollments` is maintained by a trigger on real signups, so the
  `on conflict do update` must NOT refresh it — doing so would discard genuine
  enrolments every time the seed was re-applied. The invented starting counts
  are set on insert only.
- The first row's `null` category needed an explicit `::text`, or the column
  type stays unknown and the FK to `categories(name)` will not resolve.

Student progress is seeded by inserting `lesson_progress` rows and letting the
recompute trigger derive the percentage, rather than writing
`enrollments.progress` directly — so what the app shows is what the app would
have calculated. JAMB Mathematics reads 33%, from 2 of 6 lessons complete.

### Outstanding, and deliberate

The seed writes thumbnail URLs and video keys for files that do not exist yet.
Nothing breaks meanwhile: `CourseThumbnail` degrades to the branded placeholder
on a 404, so it reads as deliberate rather than broken. The file header carries
the manifest of exactly which filenames to upload and to which bucket. The one
that matters most is `demo/welcome-to-padilearn/1.mp4` — put the rendered ad
there and it becomes the video that plays in the free Welcome course.

**The instructor names, enrolment counts and ratings are invented.** They exist
so the cards do not all read "0 students". Do not present them as traction, and
do not let an invented instructor name reach anywhere a reader would take it
for a real teacher.

---

## 2026-08-27 — Promo video, rendered from code

### Why

The demo needs course content, and the honest options were all bad: scraped
TikTok or YouTube clips are somebody else's copyright (and their music is
licensed for playback *on that platform*, so even the creator's permission
doesn't clear it), and stock b-roll doesn't look like a lesson. Building the ad
instead sidesteps the question entirely and produces something needed anyway —
a Play Store listing video, a pitch asset, a thing to forward on WhatsApp.

It also gives the marketplace an honest place to put it: a free "Welcome to
PadiLearn" course pinned at the top, which real platforms genuinely do.

### What

`video/` — a standalone Remotion workspace. Node, not Dart; it is not part of
the Flutter build and does not touch `pubspec.yaml`. The only thing crossing
the boundary is the MP4s, which get uploaded to `course-media` like any other
video. Both cuts render at ~3 MB, well under the free tier's 50 MB per-file cap.

Two compositions off one set of components — 1920x1080 for the in-app course
video, 1080x1920 for store and social. Sharing the components is the point:
the two cuts cannot drift apart, and the layout reads its own orientation to
decide whether the caption sits beside the phone or above it.

The app screens in it are React recreations, not screen recordings.
`CourseCard.tsx` follows the real widget's proportions and `Phone.tsx` lays its
children out at 393x852 — the app's own ScreenUtil design size — so a mock is
built from a widget's real dimensions with no arithmetic. Sharper than a
capture, re-renders at any resolution, and needs no device. The tradeoff is
that it can drift: **if a screen changes materially, the mock has to follow, or
the ad advertises something that no longer exists.**

All ad copy lives in one `script` object in `src/theme.ts`, and all timing in
one `SCENES` table in `AppAd.tsx`. Rewording the ad is editing strings and
re-rendering — no re-timing, no reflowing. That is the whole argument for doing
this in code rather than a timeline.

### Still outstanding

- **No narration.** Remotion animates but does not speak. A voiceover recorded
  in a Nigerian accent would carry more for this market than any TTS; add it
  with Remotion's `<Audio>`.
- **No captions**, and most social video is watched muted. Needed before the
  vertical cut goes anywhere public.
- **Licence.** Remotion is free for individuals and small companies but needs a
  paid company licence above a small headcount — check remotion.dev/license
  before this ships as company work.
- `demoCourses` is placeholder catalogue data, and the payout figure in the
  teacher scene is illustrative. Both want replacing with real seed data before
  the ad is shown as fact.

---

## 2026-08-24 — Social sign-in, and role as a separate step

### Why

Signup asked for name, email, password, confirmation *and* a role before the
user had seen anything of the app. Adding Google/Apple removes most of that,
but the two providers return an identity and nothing else — there is no way to
attach a role to `signInWithOAuth` or `signInWithIdToken`, because the provider
owns the token payload.

So role stopped being part of signup and became its own step. Identity first,
role second, and the second step only appears when the first could not supply
one. Email signup still collects both on the register form and never sees the
new screen.

### Database — `20260803000001_role_claiming.sql`

- `handle_new_user` no longer defaults the role to `'Student'`. That
  `coalesce` was invisible while email was the only way in; with OAuth it would
  have silently filed every teacher as a student, with no prompt and no route
  back. A profile may now exist with `role` null, which the app reads as
  "hasn't been asked yet".
- `profiles.role` gained a check constraint. The value arrives as client-set
  auth metadata, so it is user input; anything other than `Student`/`Teacher`
  used to land in the column verbatim and fall through the app's
  `role == 'Student'` test into the student shell.
- New `claim_role(p_role text)` — security definer, fills the column only
  `where role is null`. That predicate is the whole security argument: it can
  complete onboarding but cannot promote anyone. Returns the role in force, so
  a retry after a lost response is not mistaken for a failure.
- **Pre-existing hole closed while here.** The "Users can update their own
  profile" policy is `auth.uid() = id` with no `WITH CHECK`, so *any* signed-in
  user could patch their own row and become a Teacher in one client call,
  bypassing every teacher-gated policy behind it. RLS cannot say "any column
  but this one", so the grant was narrowed instead: table-level UPDATE revoked,
  then re-granted on `(name, profile_image_url)` only — the same reasoning as
  `payout_accounts`. Those two are the only columns the app writes
  (`editprofile_screen.dart`).

### App

- `auth_service.dart` — `signInWithGoogle`, `signInWithApple`, `claimRole`,
  and the `isGoogleSignInConfigured` / `isAppleSignInAvailable` gates that
  decide whether a button is worth showing.
- Native flow (`signInWithIdToken`), not `signInWithOAuth`. The browser flow
  bounces the user out to a custom tab and back through a deep link; the native
  one uses the platform account picker and needs no URL scheme registered for
  either provider.
- `RoleSelectionScreen` — two cards, no back button, no skip. The app branches
  on role everywhere, so an unanswered picker has nowhere to go but itself.
- `HomeShell` — the branch that used to treat a null role as a dead session and
  sign the user out now routes to the picker. Left alone, every social sign-in
  would have landed straight back on the login screen, forever. A missing
  profile *row* is still a dead session and still signs out.
- `SocialSignIn` — shared by login and register, renders nothing when no
  provider is configured, so an unconfigured build looks exactly like before.
- Apple only ever discloses a name on the *first* authorization, so it is
  written to the blank `profiles.name` right after sign-in. Never overwrites.

### Expected advisor warning

Supabase's security linter flags `claim_role` under
`authenticated_security_definer_function_executable` — a signed-in user can
call a SECURITY DEFINER function over `/rest/v1/rpc/`. That is the design, not
a slip: the function exists precisely so a client can write a column it has no
grant on, and the `where role is null` predicate is what makes that safe. Do
not "fix" it by revoking EXECUTE or switching to SECURITY INVOKER — either one
breaks the role picker.

Applied to the remote project on 2026-08-24; verified afterwards that the
UPDATE grant is down to `(name, profile_image_url)`, the constraint is present,
and both existing profiles kept their roles.

### Still outstanding

Everything below is console/Xcode work that cannot be done from the repo. Until
the first item is done the Google button stays hidden and nothing regresses.

1. **Google Cloud Console** — create a *Web* client and an *iOS* client, plus
   an *Android* client for each signing certificate (the debug keystore's SHA-1
   too, or debug builds fail with a null ID token). Put the web and iOS IDs in
   `lib/config/supabase_config.dart` — see `supabase_config.example.dart`.
2. **Supabase dashboard** — Authentication → Providers → Google: enable, and
   list the **web** client ID under "Authorized Client IDs". That is the
   audience the ID token is validated against. Enable Apple the same way.
3. **iOS** — add the reversed iOS client ID
   (`com.googleusercontent.apps.…`) as a URL scheme in `ios/Runner/Info.plist`,
   and add the "Sign in with Apple" capability in Xcode (there is no
   `Runner.entitlements` yet; adding one by hand means editing the pbxproj, so
   it was left for Xcode to do properly).
4. **`assets/branding/google_logo.png`** — the official mark. Google's branding
   terms do not allow redrawing it, so the button ships without one and renders
   fine when it appears.
5. **Existing rows are untouched.** Everyone who signed up before this has a
   role already, so nobody is sent to the picker retroactively.

### Noticed, not fixed

`android/app/` has *both* `build.gradle` and `build.gradle.kts`, declaring
different `applicationId`s (`com.dankamaInnoHu.padiLearn` vs
`…padi_learn`). Whichever Gradle picks decides the package name that Google's
Android OAuth client must be registered against — worth resolving before step 1.

Also: `.gitignore` ignores `/supabase` wholesale, so no migration file in
`supabase/migrations/` is under version control — the remote database is
currently the only record of the schema. The new migration follows that
existing convention rather than quietly breaking it, but a schema this app
depends on should be tracked (`git add -f`, or narrow the ignore rule).
