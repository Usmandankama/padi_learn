# PadiLearn on the web

The web build exists so the product can be sold while the Play Store route is
blocked on a D-U-N-S number. It is not a stopgap: selling at padilearn.com
involves no store billing, no 15–30% cut and no review, so the teacher's 85%
is untouched and `kPaidCheckoutEnabled` is **on for web** while staying off on
Android and iOS.

Build:

```bash
flutter build web --release
```

Output is `build/web/`. Deploy the contents of that folder.

---

## Where it goes: app.padilearn.com

The app is a **separate Cloudflare Pages project** from the marketing site.

`padilearn.com` stays exactly as it is — the Astro site in `website/`, which
owns the landing page, `/privacy`, `/terms` and `/delete-account`. Play Console
requires those URLs to keep working, and the landing page is what the LinkedIn
and TikTok posts point at. A marketing site and an app also want opposite
things from a web server, which is the other reason to keep them apart.

### Deploying

The Pages project is **`padilearn-app`** (Direct Upload, separate from the
Git-connected `padi-learn` project that builds the marketing site).

```bash
flutter build web --release
npx wrangler@3 pages deploy build/web --project-name padilearn-app --branch main
```

`wrangler@3` is pinned deliberately: wrangler 4 requires Node >= 22 and this
machine runs Node 20. If Node is upgraded later, plain `npx wrangler` works.

Pages is not told how to build Flutter — the bundle is built locally and
uploaded. Connecting this project to Git instead would mean fetching the
Flutter SDK inside every Cloudflare build, which is slow and brittle for no
gain while releases are occasional.

`web/_redirects` is uploaded with the bundle and supplies the SPA fallback.

A freshly created project can answer 522 for a minute or so while it
propagates; the assets return 200 before the HTML routes do. Re-check before
assuming a bad deploy.

### Custom domain (one-time, dashboard)

Wrangler cannot attach a Pages custom domain, so this part is manual:

**Workers & Pages → padilearn-app → Custom domains → Set up a custom domain →
`app.padilearn.com`.**

`padilearn.com` is already a Cloudflare zone, so the CNAME and certificate are
created automatically. Nothing changes for `padilearn.com` itself.

### Two things that must be true

**1. SPA fallback.** Paystack redirects a paying student to
`https://app.padilearn.com/payment-callback?reference=…`. No such file exists,
so the host must serve `index.html` for any path that is not a real file, or
every successful payment lands on a 404 and the student is never enrolled even
though the money left their account.

`web/_redirects` handles this (`/* /index.html 200`). The `200` matters: a
redirect would drop the `?reference=` the callback screen reads.

**2. Paystack callback whitelist.** `https://app.padilearn.com/payment-callback`
must be registered in the Paystack dashboard, and `PaymentService.callbackUrl`
must match it exactly.

Verify after deploying by opening
`https://app.padilearn.com/payment-callback?reference=not-a-real-reference`.
The correct result is the "Not confirmed" screen — not a 404, and never a
success.

### Supabase redirect URLs

Add `https://app.padilearn.com` (and `https://app.padilearn.com/*`) under
**Authentication → URL Configuration → Redirect URLs**, or password-reset and
email-confirmation links will be ignored and fall back to the Site URL.

Note that `WebLinks.emailConfirmed` still points at
`padilearn.com/email-confirmed`, which tells people to go back to *the app* —
written when the only app was on Android. For a web signup that sentence is now
slightly wrong; the page should also offer a link to `app.padilearn.com`. It is
a one-line edit in `website/src/pages/email-confirmed.astro`, not a blocker.

---

## How paying differs from mobile

Mobile puts Paystack in a WebView this app owns, so the purchase starts and
finishes inside a single `await`. The web cannot do that: `webview_flutter`
has no web implementation, and navigating to Paystack destroys the running
app along with every variable in it.

So web does a round trip:

1. `PaymentService.initialize()` returns an authorization URL and a reference.
2. `PendingPurchase.save()` writes the reference and course to local storage —
   the only thing that survives the page unload.
3. The tab navigates to Paystack (`_self`, so the back button still works and
   no popup blocker is involved).
4. Paystack redirects to `/payment-callback`. The app cold-starts, and
   `main.dart` routes to `PaymentCallbackScreen` on the strength of the URL
   before anything else builds.
5. That screen calls `PaymentService.verify()` — the same server-side
   `verify-payment` function mobile uses. **Paystack returning is not proof of
   payment; the server's answer is.** A forged `?reference=` fails.

The split lives in `lib/services/checkout/`, chosen by conditional import, so
`webview_flutter` is never referenced in a web build.

---

## The passkeys shim in `web/index.html`

`web/index.html` declares a `window.PasskeyAuthenticator` stub. **Do not
remove it** — without it the app is a blank white page with no visible cause.

`passkeys_web` arrives transitively (`supabase_flutter` → `passkeys` →
`passkeys_web`). Its `registerWith()` calls `PasskeyAuthenticator.init()`
unconditionally, behind a guard that cannot fire:

```dart
try { final _ = window['PasskeyAuthenticator']; }
catch (_) { debugPrint('...include bundle.js...'); window.close(); }
init();
```

Reading a missing key returns `undefined` rather than throwing, so the `catch`
never runs, the warning never prints, and `init()` lands on `undefined` during
plugin registration — before the first frame.

PadiLearn offers no passkeys, so the shim declares the global instead of
shipping a third-party SDK for an unused feature. `init()` is a no-op and
every other method rejects with a clear message. To actually support passkeys
on web, replace the shim with Corbado's bundle:
<https://github.com/corbado/flutter-passkeys/releases>.

---

## Known gaps

- **Teacher payouts.** `payout_accounts` is empty. Money can be taken on web
  today and there is no configured path to pay a teacher. This must work
  before the first real sale, not after.
- **Google sign-in is unavailable on web.** `SupabaseConfig.googleWebClientId`
  is empty, so the button is hidden by `isGoogleSignInConfigured` — on web
  this is graceful, not a crash. Email and password work. Enabling it needs a
  **Web application** OAuth client plus a matching entry in Supabase →
  Authentication → Providers → Google → Authorized Client IDs.
- **First load is heavy.** About 3 MB over Brotli (`main.dart.js` plus one
  CanvasKit variant), then cached. Confirm the host sends Brotli or gzip. The
  `canvaskit/*.symbols` files are debug artifacts and are never fetched by a
  browser.
- **Supabase is in `ap-south-1` (Mumbai)**, a long way from Lagos. Moving
  region means migrating the project, so it is far cheaper to decide before
  there are real users than after.
- **Leaked-password protection is disabled** in Supabase Auth. One toggle,
  worth doing before public sign-ups.
