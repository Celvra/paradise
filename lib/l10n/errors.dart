import '../data/ai/errors.dart';
import 'x.dart';

/// The user facing half of [describeError]. The english version in data/ai
/// stays as the diagnostic string and is what the service message quotes, this
/// one is what the localized label shows.
///
/// An unclassified error keeps the provider's own message: it is not ours to
/// translate, and an empty one falls back to the generic line.
String describeErrorL10n(AiError error) => switch (error.kind) {
      AiErrorKind.auth => L10n.current.errorAuth,
      AiErrorKind.quota => L10n.current.errorQuota,
      AiErrorKind.rate => L10n.current.errorRate,
      AiErrorKind.contextOverflow => L10n.current.errorContextOverflow,
      AiErrorKind.server => L10n.current.errorServer,
      AiErrorKind.network => L10n.current.errorNetwork,
      AiErrorKind.aborted => L10n.current.errorAborted,
      AiErrorKind.empty => L10n.current.errorEmpty,
      _ => error.message.isEmpty ? L10n.current.errorUnknown : error.message,
    };