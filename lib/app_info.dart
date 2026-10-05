/// The app version from pubspec.yaml, kept in step by hand — the same trade
/// the About row in the settings already makes, and there is no runtime way
/// to read pubspec without pulling in a plugin for one string.
const appVersion = '1.0.1';

/// Sent as User-Agent on every ai request unless the user configured one.
const defaultUserAgent = 'Paradise-Client/$appVersion';
