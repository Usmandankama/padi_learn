# Auth email templates

The emails Supabase Auth sends, in PadiLearn's name. Supabase doesn't read
these files; they are pasted into **Authentication → Emails → Templates**.
They live here so a change is reviewed and versioned like code, and so the
dashboard can be restored if someone edits it by accident.

**If you change a template in the dashboard, change the file here too.**

| Dashboard entry | File | Subject |
|---|---|---|
| Confirm sign up | `confirm_signup.html` | Confirm your email for PadiLearn |
| Invite user | `invite.html` | You're invited to PadiLearn |
| Magic link or OTP | `magic_link.html` | Your PadiLearn login link |
| Change email address | `email_change.html` | Confirm your new PadiLearn email |
| Reset password | `recovery.html` | Reset your PadiLearn password |
| Reauthentication | `reauthentication.html` | Your PadiLearn verification code |

Sender: **PadiLearn** `<hello@padilearn.com>`, through Resend (see
`docs/DEVLOG.md`).

## Which ones the app actually uses

- **Reset password.** Always. The link goes to `padilearn://reset-callback`,
  which only opens the app on a phone that has it installed, so the email says so.
- **Confirm sign up.** Only if "Confirm email" is on under Authentication →
  Sign In / Providers → Email.
- **Change email address.** When a user changes their email on Edit Profile.
- **Invite, magic link, reauthentication.** Not used by the app today. They
  are branded anyway so nothing ever goes out in Supabase's default wording.

## Rules these follow

- **Inline styles and tables only.** Gmail and Outlook remove `<style>`
  blocks and ignore flexbox and grid. What looks old-fashioned here is what
  works in email.
- **No images.** The wordmark is text, because many mail apps block images by
  default and a missing logo looks broken. A hosted logo can come later.
- **"Expires in 1 hour"** matches Supabase's default email OTP expiry. If
  that setting changes, update the wording.
- **Keep the `{{ .ConfirmationURL }}`, `{{ .Token }}`, `{{ .Email }}` and
  `{{ .NewEmail }}` placeholders exactly as written.** Supabase fills them in
  when it sends. A typo sends a broken link.
