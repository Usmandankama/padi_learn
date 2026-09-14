# padilearn.com

The PadiLearn website: landing page, privacy policy, terms, account-deletion page
and the Paystack payment-callback fallback. Static [Astro](https://astro.build)
site, hosted free on Cloudflare Pages.

| Path | Source | Why it exists |
|---|---|---|
| `/` | `src/pages/index.astro` | Landing page, beta sign-up |
| `/privacy` | `src/pages/privacy.md` | Play Console privacy policy URL; NDPA 2023 |
| `/terms` | `src/pages/terms.md` | Terms of service |
| `/delete-account` | `src/pages/delete-account.astro` | Play Console account-deletion URL |
| `/payment-callback` | `src/pages/payment-callback.astro` | `PaymentService.callbackUrl`; only seen if the checkout WebView doesn't intercept it |

Keep the legal pages in step with the app. What `/delete-account` and `/privacy`
say is deleted or kept must match `supabase/functions/delete-account`. The support
email is set in `src/site.ts` and must match `lib/utils/app_info.dart`.

## App screenshots

`src/assets/screens/` holds real captures from the Android app. Astro converts
them to AVIF/WebP at build time, so commit the full-size PNGs. To recapture
with the app open on an emulator or phone:

```bash
adb exec-out screencap -p > src/assets/screens/home.png
```

Emulator captures can come with a thin coloured border. Crop about 6px off
each edge before committing. The current set still shows the old seeded ratings and prices,
so recapture after the counters migration is live.

## Run locally

Needs Node 20.3 or newer.

```bash
npm install
npm run dev
```

`npm run build` writes the site to `dist/`.

## Deploy to Cloudflare Pages (one-time)

1. Push this repo to GitHub.
2. In the Cloudflare dashboard, go to **Workers & Pages → Create → Pages → Connect to Git** and pick the repo.
3. Build settings:
   - Production branch: `main`
   - Framework preset: **Astro**
   - Build command: `npm run build`
   - Build output directory: `dist`
   - **Root directory: `website`**
   - Environment variable `NODE_VERSION` = `22`
4. Deploy. The site appears at `<project>.pages.dev`.
5. **Custom domain:** add `padilearn.com` to Cloudflare as a site, then change the
   nameservers at your registrar to the two Cloudflare gives you. Then open the Pages
   project and add `padilearn.com` and `www.padilearn.com` under **Custom domains**.
6. Optional: **Email → Email Routing** forwards `hello@padilearn.com` to a personal
   inbox for free.

After that, every push to `main` redeploys, and pull requests get preview URLs. To
stop app-only commits triggering builds, set **Build watch paths** to `website/*`.

`public/_headers` sets the security headers and caching, and is applied only on
Cloudflare, not in `npm run dev`.

## Not done yet

- **Android App Links** (`/.well-known/assetlinks.json`) need the SHA-256
  fingerprint of the Play app-signing key, which doesn't exist until the first
  upload. The app doesn't need them today: password reset uses
  `padilearn://`, and the checkout WebView intercepts the callback URL itself.
- **Google Play badge.** Swap the "Join the beta" buttons for the Play link when
  the app is public.
