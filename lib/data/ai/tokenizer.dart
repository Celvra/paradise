import '../../l10n/x.dart';
import 'content.dart';

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

// ── what a picture costs the window ─────────────────────────────────────
// Vision models bill by pixels, not by characters: a picture is cut into
// tiles of about 512 px and every tile turns into a fixed handful of tokens.
// The transcript only ever described a photo in five words, so the app priced
// a window full of them at almost nothing and neither compaction nor
// truncation ever fired on a chat whose context was really full. The numbers
// below sit slightly high on purpose: compacting a turn before the provider
// asks is cheap, being refused mid sentence is not.

const _tileEdge = 512;
const _tokensPerTile = 85;
const _mediaBaseTokens = 85;
const _videoFrameTokens = 258;
const _videoCapSeconds = 900;

/// An unreadable size is not a free picture. Compressed bytes say nothing
/// about pixels (a twelve megapixel shot and a sticker can share a file size),
/// so an unknown resolution is billed as a mid sized one.
const _unknownEdge = 1024;

int imageTokens({int? width, int? height}) {
  final w = (width == null || width <= 0) ? _unknownEdge : width;
  final h = (height == null || height <= 0) ? _unknownEdge : height;
  final tiles = ((w + _tileEdge - 1) ~/ _tileEdge) * ((h + _tileEdge - 1) ~/ _tileEdge);
  return _mediaBaseTokens + tiles * _tokensPerTile;
}

int videoTokens({int? seconds, required int base64Chars}) {
  // the video endpoints sample about one frame a second, and a phone clip is
  // roughly a megabyte a second when nobody timed it
  final fromBytes = (base64Chars * 3 ~/ 4) ~/ (1024 * 1024);
  final s = seconds ?? fromBytes;
  final frames = s <= 0 ? 1 : (s > _videoCapSeconds ? _videoCapSeconds : s);
  return _mediaBaseTokens + frames * _videoFrameTokens;
}

/// What one content part adds to the window. A tool call and its result are
/// replayed with the next request, so they belong here too even though the
/// user never sees them.
int estimatePartTokens(ContentPart part) => switch (part) {
      TextPart(:final text) => estimateTokens(text),
      ImagePart(:final pixelWidth, :final pixelHeight) => imageTokens(width: pixelWidth, height: pixelHeight),
      VideoPart(:final seconds, :final data) => videoTokens(seconds: seconds, base64Chars: data.length),
      ToolCallPart(:final name, :final args) => 48 + estimateTokens(name) + estimateTokens(args.toString()),
      ToolResultPart(:final name, :final result) => 24 + estimateTokens(name) + estimateTokens(result),
    };

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