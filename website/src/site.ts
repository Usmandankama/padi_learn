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
  /** Date shown on the legal and policy pages. Change it when any of them change. */
  legalUpdated: '9 October 2026',

  /**
   * The business behind PadiLearn, as the legal pages and footer name it.
   * Paystack's reviewers and Nigerian consumer and data protection rules
   * expect it. Add the RC number and a registered address here once they are
   * to be published, and show them on /support.
   */
  company: {
    name: 'Groundwork Tech Ltd',
    country: 'Nigeria',
  },

  /**
   * What /support and /refunds promise, read from here. `terms.md` and the
   * FAQ in index.astro repeat the same numbers in prose: change them too, and
   * bump `legalUpdated`.
   */
  support: {
    responseTime: 'within 2 working days',
    hours: 'Monday to Friday, except Nigerian public holidays',
  },
  refunds: {
    /** How long after buying a "not as described" refund can be asked for. */
    windowDays: 7,
    /** How soon an approved refund is sent through Paystack. */
    issuedWithin: 'within 5 working days of approving it',
  },

  /** The Flutter web build. Works in any browser, nothing to install. */
  appUrl: 'https://app.padilearn.com',

  /**
   * The Android build, handed out directly rather than through Google Play.
   *
   * **This file is hosted on R2, not with the site** — Cloudflare Pages caps a
   * single file at 25 MiB and the APK is about 41 MiB. It lives in the
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
    apkVersion: '1.0.8',
    apkSize: '45.0 MB',
    apkUpdated: '10 October 2026',
    /** Lowest Android this build installs on — `minSdkVersion` 24. */
    minAndroid: '7.0',
  },
} as const;

/** A mailto link with a prefilled subject. */
export function mailto(subject: string): string {
  return `mailto:${site.supportEmail}?subject=${encodeURIComponent(subject)}`;
}
