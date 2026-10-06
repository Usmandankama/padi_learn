/**
 * Facts the website states about PadiLearn, in one place.
 *
 * `supportEmail` must match `kSupportEmail` in `lib/utils/app_info.dart` and
 * the contact address on the Play listing.
 */
export const site = {
  name: 'PadiLearn',
  url: 'https://padilearn.com',
  supportEmail: 'hello@padilearn.com',
  description:
    'Video courses from Nigerian teachers. Learn on your phone, at your own pace, and pick up where you left off.',
  /** Date shown on the privacy policy and terms. Change it when they change. */
  legalUpdated: '14 September 2026',

  /** The Flutter web build. Works in any browser, nothing to install. */
  appUrl: 'https://app.padilearn.com',

  /**
   * The Android build, handed out directly rather than through Google Play.
   *
   * **This file is hosted on R2, not with the site** — Cloudflare Pages caps a
   * single file at 25 MiB and the universal APK is 40.6 MiB. It lives in the
   * `padilearn-dl` bucket, served from `dl.padilearn.com`; see
   * docs/LAUNCH_WEB.md for how a new build gets there. Nothing here may be
   * deployed until the object is actually at `apkUrl`, or the download button
   * 404s on the one page that exists to make people trust the product.
   *
   * Update `apkVersion`, `apkSize` and `apkUpdated` with every new upload. The
   * numbers are shown to the user, so wrong ones are worse than none.
   */
  android: {
    apkUrl: 'https://dl.padilearn.com/padilearn-latest.apk',
    apkVersion: '1.0.0',
    apkSize: '42.6 MB',
    apkUpdated: '6 October 2026',
    /** Lowest Android this build installs on — `minSdkVersion` 24. */
    minAndroid: '7.0',
  },
} as const;

/** A mailto link with a prefilled subject. */
export function mailto(subject: string): string {
  return `mailto:${site.supportEmail}?subject=${encodeURIComponent(subject)}`;
}
