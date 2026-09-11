/// How the app names and dates itself to users.
///
/// One copy, because the version string had already been written out by hand
/// in two places and adding a third is how they start disagreeing.
///
/// These are still constants, so they have to be kept in step with `version:`
/// in `pubspec.yaml` by hand. The real fix is `package_info_plus`, which reads
/// the number the build was actually stamped with — worth adding the first time
/// a shipped build claims the wrong version.
library;

const String kAppName = 'PadiLearn';

/// Mirrors `version:` in pubspec.yaml (the part before the `+`).
const String kAppVersion = '1.0.0';

const String kAppLegalese = '© 2026 PadiLearn';
