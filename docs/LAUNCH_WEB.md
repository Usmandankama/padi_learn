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

Pages is not told how to build Flutter — it receives a finished bundle.
Connecting *this Pages project* to Git would mean fetching the Flutter SDK
inside every Cloudflare build, which is slow and brittle, so that is still not
done.

**Since 2026-10-06 the bundle is built by GitHub Actions instead of by hand**
(`.github/workflows/deploy-web-app.yml`): a push to `main` touching `lib/`,
`web/`, `assets/` or `pubspec.*` builds with Flutter 3.38.3 and uploads through
the same `wrangler pages deploy`. That keeps Cloudflare out of the build while
still giving push-to-deploy, and the SDK is cached between runs rather than
re-downloaded. The command below remains the fallback, and is what
`workflow_dispatch` runs if you trigger it manually.

Two things the workflow needs that a local build does not:

- **Repository secrets.** `CLOUDFLARE_API_TOKEN` (scoped to Pages : Edit),
  `SUPABASE_URL` and `SUPABASE_PUBLISHABLE_KEY`, plus `GOOGLE_WEB_CLIENT_ID`
  and `GOOGLE_IOS_CLIENT_ID` once those exist. The account id is in the
  workflow in clear, because it is not a secret.
- **`supabase_config.dart` regenerated at build time.** It is git-ignored, so a
  fresh clone cannot compile; the workflow writes it from those secrets. If a
  field is added to that class, the workflow's heredoc has to learn about it or
  CI breaks while local builds keep working — the one failure mode this setup
  introduces.

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

`email-confirmed.astro` now offers `app.padilearn.com` alongside "go back to
the app on your phone". It used to say only the latter, written when the only
app was on Android, which was wrong for anyone who signed up on a laptop.

---

## The Android download: dl.padilearn.com

The APK is handed out directly from the landing page, because the Play Store
route is blocked on a D-U-N-S number and there is no reason to make people wait
for it.

It cannot live with the site: Cloudflare Pages caps a single file at 25 MiB and
the universal APK is 40.6 MiB. So it sits in an **R2 bucket**, `padilearn-dl`,
with `dl.padilearn.com` attached as a custom domain. Minimum TLS is 1.2, which
is safe because this APK's floor is Android 7.0, and TLS 1.2 has been on by
default since Android 5.0.

Two objects per release:

| Key | `Cache-Control` | Why |
| --- | --- | --- |
| `padilearn-<version>.apk` | `max-age=31536000, immutable` | an archive that never changes, so an old link keeps working |
| `padilearn-latest.apk` | `max-age=300` | what `site.android.apkUrl` points at; five minutes so a new build propagates fast |

### Publishing a new build

The bucket and the custom domain already exist; this is the per-release part.

```bash
flutter build apk --release --target-platform android-arm,android-arm64 --dart-define=PAID_CHECKOUT=true
APK=build/app/outputs/flutter-apk/app-release.apk
CT=application/vnd.android.package-archive

cat $APK | npx wrangler@3 r2 object put padilearn-dl/padilearn-<version>.apk   --pipe --content-type $CT --cache-control "public, max-age=31536000, immutable"

cat $APK | npx wrangler@3 r2 object put padilearn-dl/padilearn-latest.apk   --pipe --content-type $CT --cache-control "public, max-age=300"
```

**`--dart-define=PAID_CHECKOUT=true` is not optional either.** Without it the
APK says "Paid courses can't be bought in the app yet" (see
`lib/config/features.dart`). 1.0.1 and 1.0.2 went out that way; 1.0.3 is the
first with checkout on. It must never be passed to a build for Google Play.
Check before uploading: the message must be absent from the build,
`unzip -p $APK lib/arm64-v8a/libapp.so | grep -a -c "be bought in the app yet"`
prints 0.

**`--pipe` is not optional, and it is the part worth remembering.** Passing
`--file` instead failed from this machine twice in a row, each time after about
five minutes, with a bare `fetch failed` and nothing uploaded. The connection is
not the problem — it measures around 540 kB/s — but one buffered 40 MiB PUT does
not survive it while a streamed one does. If `--pipe` ever fails too, upload
through the R2 dashboard rather than burning an hour on wrangler.

### Verify, and do not skip it

A truncated upload still answers `200`.

```bash
curl -I https://dl.padilearn.com/padilearn-latest.apk
md5sum build/app/outputs/flutter-apk/app-release.apk
```

`Content-Length` must equal the local file's byte count, and for a single-part
upload R2's `ETag` **is** the MD5 of the object, so the two must match. For
1.0.0: `42621037` bytes, `05a390cb9dbef5cc7574e6d04945d0d7`. Bump `version:`
in `pubspec.yaml` first (name and build number both), so a phone sees an
update rather than the same version again.

Then update `site.android` in `website/src/site.ts` — `apkVersion`, `apkSize`
and `apkUpdated` are shown to the user, so wrong numbers are worse than none —
and redeploy the marketing site.

### What this APK is

One APK for both ARM architectures (`arm64-v8a`, `armeabi-v7a`), so one link
installs on every phone. The per-ABI splits are roughly half the size and
would even fit under the Pages file cap, but they would make a stranger pick a
CPU architecture on the page whose whole job is to earn their trust.

**Not `x86_64`, and the `--target-platform` flag is what keeps it out.** This
section used to say the APK included `x86_64`, and the command above used to be
a bare `flutter build apk --release`. Plain, that command adds `x86_64`, which
only emulators and a few Chromebooks run, and makes the download 63.5 MB
instead of about 42 MB. Checked on 2026-10-07 by unzipping the live 1.0.0: it
holds only the two ARM sets, so it was built with the flag. Flutter stores
native libraries uncompressed (`minSdkVersion` 24 lets Android load them in
place), so every architecture costs its full size in the download, and
students pay for that data.

Signed with the release keystore (`CN=Groundwork Tech Ltd`), APK Signature
Scheme v2 and no v1 — v1 is only needed below Android 7.0, which `minSdkVersion`
24 already excludes. That is why `minAndroid: '7.0'` in `site.ts` is
load-bearing rather than decoration.

One consequence to plan for: this signature is not the one Play App Signing
would produce later, so anyone who sideloads today has to uninstall before a
Play build will install over it.

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

- **Teacher payouts: manual, but complete.** The admin panel records
  transfers against each teacher's balance (`ADMIN_PANEL.md`, item 12f), and
  since 2026-10-08 teachers ask for a payout in the app (item 15). The
  transfer itself is still sent by hand from the bank or Paystack.
  `payout_accounts` is still empty: no teacher has added a bank account.
- **Live payments wait on the company Paystack account.** The deployed
  payment functions are older than the repo. The order for switching over
  is in `STATUS.md`.
- **Google sign-in is unavailable on web.** `SupabaseConfig.googleWebClientId`
  is empty, so the button is hidden by `isGoogleSignInConfigured` — on web
  this is graceful, not a crash. Email and password work. Enabling it needs a
  **Web application** OAuth client plus a matching entry in Supabase →
  Authentication → Providers → Google → Authorized Client IDs.
- **First load is heavy.** About 3 MB over Brotli (`main.dart.js` plus one
  CanvasKit variant), then cached. Confirm the host sends Brotli or gzip. The
  `canvaskit/*.symbols` files are debug artifacts and are never fetched by a
  browser.
- **Supabase is in `ap-south-1` (Mumbai)**, a long way from Lagos (about
  350 ms against about 175 ms for Ireland, measured 2026-10-09). The move to
  Ireland is written up in `REGION_MOVE.md`.
- **Leaked-password protection is disabled** in Supabase Auth. It is a
  paid-plan feature, and Supabase stays on the free plan until there are
  users (`STATUS.md`).
