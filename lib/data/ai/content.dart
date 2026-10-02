// a turn carries text plus optionally a base64 image, so every adapter can pick
// its own envelope instead of guessing from a magic string

sealed class ContentPart {
  const ContentPart();
}

class TextPart extends ContentPart {
  const TextPart(this.text);
  final String text;
}

// base64 image with its mime, loaded on demand and never written to storage
class ImagePart extends ContentPart {
  const ImagePart(this.data, this.mime);
  final String data;
  final String mime;
}

/// A tool invocation the model asked for. Kept in the turn history so the next
/// request can replay it next to its result.
class ToolCallPart extends ContentPart {
  const ToolCallPart({required this.id, required this.name, required this.args, this.signature});
  final String id;
  final String name;
  final Map<String, dynamic> args;

  /// Gemini thought signature, echoed back untouched on the follow up request
  final String? signature;
}

class ToolResultPart extends ContentPart {
  const ToolResultPart({required this.callId, required this.name, required this.result, this.isError = false});
  final String callId;
  final String name;
  final String result;
  final bool isError;
}

ContentPart textPart(String text) => TextPart(text);

String partsToText(List<ContentPart> parts) => parts.whereType<TextPart>().map((p) => p.text).join('\n\n');

int countImages(List<ContentPart> parts) => parts.whereType<ImagePart>().length;

// keeps a small text block so an image only message is still meaningful
List<ContentPart> partsFromAttachment({required String caption, required String? loadedBase64, required String mime, String name = '', String? text}) {
  final parts = <ContentPart>[];
  final lead = [
    if (caption.trim().isNotEmpty) caption.trim(),
    if (name.isNotEmpty) text != null && text.trim().isNotEmpty ? '[$name]\n${text.trim()}' : '[$name]',
  ].join('\n\n');
  if (lead.isNotEmpty) parts.add(TextPart(lead));
  if (loadedBase64 != null && loadedBase64.isNotEmpty) parts.add(ImagePart(loadedBase64, mime));
  return parts;
}