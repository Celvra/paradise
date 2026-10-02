import 'package:flutter/widgets.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// The brands the app can show, covering the providers it ships with plus the
/// ones a custom endpoint is most likely to be pointed at.
///
/// Every logo is a monochrome svg with fill="currentColor", so the tile
/// supplies the brand colour and the glyph is tinted to match.
enum Prov {
  openai,
  anthropic,
  gemini,
  deepseek,
  openrouter,
  siliconflow,
  mistral,
  groq,
  ollama,
  github,
  cloudflare,
  xai,
  cohere,
  zhipu,
  qwen,
  moonshot,
  vertex,
}

/// One rule of the name table. [re] decides whether a provider matches and
/// [prov] is what it becomes. Not const, RegExp has no const constructor.
class _Rule {
  _Rule(this.re, this.prov);
  final RegExp re;
  final Prov prov;
}

// Order matters, the first hit wins, so the specific names come before the
// broad ones. An o3 model must read as OpenAI before xAI is even considered,
// and a Google endpoint on Vertex reads as Google.
final _rules = <_Rule>[
  _Rule(RegExp(r'openai|\bgpt|\bo\d|chatgpt|davinci|o1\b|o3\b|o4\b'), Prov.openai),
  _Rule(RegExp(r'anthropic|claude'), Prov.anthropic),
  _Rule(RegExp(r'gemini|\bbard\b|palm'), Prov.gemini),
  _Rule(RegExp(r'vertex'), Prov.vertex),
  _Rule(RegExp(r'google'), Prov.vertex),
  _Rule(RegExp(r'deepseek'), Prov.deepseek),
  _Rule(RegExp(r'openrouter'), Prov.openrouter),
  _Rule(RegExp(r'silicon|硅基'), Prov.siliconflow),
  _Rule(RegExp(r'mistral|\bmixtral\b|\bministral\b'), Prov.mistral),
  _Rule(RegExp(r'groq'), Prov.groq),
  _Rule(RegExp(r'ollama'), Prov.ollama),
  _Rule(RegExp(r'github'), Prov.github),
  _Rule(RegExp(r'cloudflare'), Prov.cloudflare),
  _Rule(RegExp(r'\bgrok\b'), Prov.xai),
  _Rule(RegExp(r'\bxai\b'), Prov.xai),
  _Rule(RegExp(r'cohere|command-r'), Prov.cohere),
  _Rule(RegExp(r'zhipu|智谱|\bglm\b'), Prov.zhipu),
  _Rule(RegExp(r'qwen|qwq|qvq|通义|dashscope'), Prov.qwen),
  _Rule(RegExp(r'moonshot|月之暗面|\bkimi\b'), Prov.moonshot),
];

/// Which logo a provider gets, or null when nothing matches so the caller can
/// fall back to the initial.
///
/// [name] is the provider name the user typed. [baseUrl] is searched as well
/// because a custom provider is usually named after nothing at all while its
/// endpoint still says who it is, but only its host is looked at. Nearly every
/// compatible relay serves under an `/openai/` path, so matching the whole url
/// would hand all of them the OpenAI logo.
Prov? provFor(String? name, [String? baseUrl]) {
  for (final s in [name ?? '', _hostOf(baseUrl)]) {
    final q = s.trim().toLowerCase();
    if (q.isEmpty) continue;
    for (final rule in _rules) {
      if (rule.re.hasMatch(q)) return rule.prov;
    }
  }
  return null;
}

/// The host of a base url, or the input itself when it is not a url at all.
String _hostOf(String? url) {
  final raw = (url ?? '').trim();
  if (raw.isEmpty) return '';
  final parsed = Uri.tryParse(raw);
  // a bare host like api.groq.com parses with an empty host and a path
  final host = parsed?.host ?? '';
  if (host.isNotEmpty) return host;
  return raw.split('/').first.split(':').first;
}

/// The bundled file for a brand. Declared as assets/providers/ in pubspec.
/// [Prov.name] and not the enum itself, interpolation would give Prov.openai.
String provAsset(Prov p) => 'assets/providers/${p.name}.svg';

/// The two gradient stops behind each logo, so the tile carries the brand
/// colour the monochrome glyph is drawn in.
List<Color> provTile(Prov p) => switch (p) {
      Prov.openai => const [Color(0xFF10A37F), Color(0xFF0D8A6B)],
      Prov.anthropic => const [Color(0xFFD97757), Color(0xFFC15F3C)],
      Prov.gemini => const [Color(0xFF4285F4), Color(0xFF9B72CB)],
      Prov.deepseek => const [Color(0xFF4D6BFE), Color(0xFF3B5BDB)],
      Prov.openrouter => const [Color(0xFF6467F2), Color(0xFF4F46E5)],
      Prov.siliconflow => const [Color(0xFF6C5CE7), Color(0xFF00B4D8)],
      Prov.mistral => const [Color(0xFFFAB700), Color(0xFFFF8800)],
      Prov.groq => const [Color(0xFFF55036), Color(0xFFD0342C)],
      Prov.ollama => const [Color(0xFF3A3A3A), Color(0xFF1A1A1A)],
      Prov.github => const [Color(0xFF6E5494), Color(0xFF24292E)],
      Prov.cloudflare => const [Color(0xFFF6821F), Color(0xFFFA8D3D)],
      Prov.xai => const [Color(0xFF2A2A2A), Color(0xFF000000)],
      Prov.cohere => const [Color(0xFF39594D), Color(0xFF2A4238)],
      Prov.zhipu => const [Color(0xFF3864FF), Color(0xFF2B54E8)],
      Prov.qwen => const [Color(0xFF6A4CFF), Color(0xFF8C5BFF)],
      Prov.moonshot => const [Color(0xFF2F2F2F), Color(0xFF111111)],
      Prov.vertex => const [Color(0xFF4285F4), Color(0xFF34A853)],
    };

/// Ink for the fallback tile, which stands in for every provider with no logo.
const provFallback = [Color(0xFF8B7BDB), Color(0xFF6A5ACD)];

/// The provider logo on a rounded tile, matching the gradient block the
/// provider cards and rows already use. Falls back to the first character of
/// the name when no logo matches.
class ProviderAvatar extends StatelessWidget {
  const ProviderAvatar({super.key, required this.name, this.baseUrl = '', this.size = 34, this.radius = 10});

  final String name;
  final String baseUrl;
  final double size;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final prov = provFor(name, baseUrl);
    final initial = name.trim().isEmpty ? '?' : name.trim().characters.first.toUpperCase();
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: prov == null ? provFallback : provTile(prov),
        ),
      ),
      child: prov == null
          ? Text(
              initial,
              style: TextStyle(color: const Color(0xFFFFFFFF), fontSize: size * .44, fontWeight: FontWeight.w600, decoration: TextDecoration.none),
            )
          // every bundled logo is monochrome, the tile colour carries the brand
          : SvgPicture.asset(
              provAsset(prov),
              width: size * .62,
              height: size * .62,
              colorFilter: const ColorFilter.mode(Color(0xFFFFFFFF), BlendMode.srcIn),
            ),
    );
  }
}