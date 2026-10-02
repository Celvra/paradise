import 'package:flutter/widgets.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// The brands the app can show, covering the providers it ships with plus the
/// ones a custom endpoint is most likely to be pointed at.
///
/// Every logo is a monochrome svg tinted to the tile colour, so the tile
/// supplies the ink and the glyph goes with it.
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

/// The provider logo on a flat tile. Falls back to the first character of the
/// name when no logo matches.
///
/// The fill comes in as a plain colour rather than being derived here: the AI
/// pages want the header disc, the row tiles and these on one colour, and a
/// brand gradient apiece is what stopped them reading as one screen.
class ProviderAvatar extends StatelessWidget {
  const ProviderAvatar({super.key, required this.name, required this.color, this.baseUrl = '', this.size = 34, this.radius = 10});

  final String name;
  final String baseUrl;
  final double size;
  final double radius;

  final Color color;

  @override
  Widget build(BuildContext context) {
    final prov = provFor(name, baseUrl);
    final initial = name.trim().isEmpty ? '?' : name.trim().characters.first.toUpperCase();
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(radius), color: color),
      child: prov == null
          ? Text(
              initial,
              style: TextStyle(color: const Color(0xFFFFFFFF), fontSize: size * .44, fontWeight: FontWeight.w600, decoration: TextDecoration.none),
            )
          // every bundled logo is monochrome, the tile colour carries it
          : SvgPicture.asset(
              provAsset(prov),
              width: size * .62,
              height: size * .62,
              colorFilter: const ColorFilter.mode(Color(0xFFFFFFFF), BlendMode.srcIn),
            ),
    );
  }
}