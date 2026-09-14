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
} as const;

/** A mailto link with a prefilled subject. */
export function mailto(subject: string): string {
  return `mailto:${site.supportEmail}?subject=${encodeURIComponent(subject)}`;
}
