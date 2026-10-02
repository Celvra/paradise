import '../../l10n/x.dart';

// rough token estimate for mixed cjk and latin
// cjk glyphs are close to one token each, latin runs about four chars per token
final _cjk = RegExp(r'[\u3000-\u303f\u3400-\u4dbf\u4e00-\u9fff\uf900-\ufaff\uff00-\uffef]');

int estimateTokens(String text) {
  if (text.isEmpty) return 0;
  var cjk = 0;
  var other = 0;
  for (final rune in text.runes) {
    if (_cjk.hasMatch(String.fromCharCode(rune))) {
      cjk++;
    } else {
      other++;
    }
  }
  return (cjk + other / 3.6).ceil();
}

int estimateMessages(List<({String role, String content})> messages, {int overheadPerMessage = 4}) {
  var total = 0;
  for (final m in messages) {
    total += overheadPerMessage + estimateTokens(m.content);
  }
  return total;
}

// the K and M suffixes read the same in every language we ship, only the
// grouping of the digits moves
String formatTokens(num value) {
  if (value <= 0) return L10n.current.aiTokensUnknown;
  if (value >= 1000000) return '${_trim(value / 1000000)}M';
  if (value >= 1000) return '${(value / 1000).round()}K';
  return value.toStringAsFixed(0);
}

String _trim(double v) => v >= 10 ? v.toStringAsFixed(0) : v.toStringAsFixed(1);

String formatDuration(int ms) => ms < 1000 ? '${ms.round()}ms' : '${(ms / 1000).toStringAsFixed(1)}s';