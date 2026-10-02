// gateways hand out model ids that exist in no catalog
// the vendor token and the version number are the only signal available

const _vendorVision = {'claude', 'gemini', 'grok'};

final _visionRe = RegExp(
  r'\b(gpt-4o|gpt-4\.1|gpt-4-turbo|gpt-5|o1|o3|o4|llama-3\.[89]|llama-4|llava|qwen-vl|qwen2\.5-vl|qwen3-vl|step-1v|kimi-vl|glm-4v|mistral-small|nova-(lite|pro|premier)|command-r|phi-[34](\.5)?|phi-4|aya|gemma-3|internlm|ernie-4\.5|hunyuan-vision|minicpm-v|internvl|pixtral)',
);

final _reasoningRe = RegExp(
  r'\b(thinking|reasoner|reasoning|r1|r2|qwq|deepseek-r|o1|o3|o4|gpt-5|gpt-oss|kimi-k2|kimi-k3|max-thinking|seed-thinking|hunyuan-a13b)',
);

final _t2iRe = RegExp(r'\b(t2i|image-gen|text-to-image|dall-e|imagen|flux|sdxl|stable-diffusion|kolors|qwen-image|seedream|wanx|hidream|ernie-image)');

// extended thinking is the default from these versions onward
const _thinkingFloor = {'claude': 3.7, 'gemini': 2.5};

String normalizeModelId(String id) => id.trim().toLowerCase().replaceAll(RegExp(r'[-_.]+'), '-');

// the id is lowercased and separators become dashes so 3.5 arrives as two tokens
// merge a run of numbers back into one version and ignore trailing date stamps
double _generationOf(List<String> tokens) {
  final parts = <Object>[];
  for (final token in tokens) {
    if (RegExp(r'^\d{8,}$').hasMatch(token)) continue;
    if (RegExp(r'^\d+$').hasMatch(token)) {
      final n = num.parse(token);
      if (parts.isNotEmpty && parts.last is num) {
        parts[parts.length - 1] = double.parse('${parts.last}.$n');
      } else {
        parts.add(n);
      }
      continue;
    }
    parts.add(token);
  }
  var best = 0.0;
  for (final part in parts) {
    if (part is num && part > best) best = part.toDouble();
  }
  return best;
}

class IdGuess {
  const IdGuess({this.vision, this.reasoning, this.textToImage});
  final bool? vision;
  final bool? reasoning;
  final bool? textToImage;

  IdGuess merge(IdGuess other) => IdGuess(
        vision: vision == true || other.vision == true,
        reasoning: reasoning == true || other.reasoning == true,
        textToImage: textToImage == true || other.textToImage == true,
      );
}

IdGuess guessFromModelId(String id) {
  final n = normalizeModelId(id);
  final tokens = n.split('-');
  final family = tokens.isEmpty ? '' : tokens.first;
  var vision = false;
  var reasoning = false;
  var t2i = false;
  if (_visionRe.hasMatch(n) || _vendorVision.contains(family)) vision = true;
  final floor = _thinkingFloor[family];
  if (_reasoningRe.hasMatch(n) || (floor != null && _generationOf(tokens) >= floor)) reasoning = true;
  if (_t2iRe.hasMatch(n)) t2i = true;
  return IdGuess(vision: vision, reasoning: reasoning, textToImage: t2i);
}