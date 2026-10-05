import '../models.dart';
import 'adapter.dart';
import 'content.dart';
import 'provider_model.dart';

// locked so the assistant always knows the transport and the language
final _baseInstruction = [
  'You are chatting with someone through an instant messaging app.',
  'Reply in the language the user writes in.',
  'Stay in character and never break out of it to explain that you are a model.',
  'Keep replies short, like a real person typing in a chat. No headings, no bullet lists.',
].join('\n');

final _characterRules = [
  'When you share code, put it in its own ``` fenced block with the language label. A fenced block arrives as one message, so never split one across bubbles.',
  r'When a formula helps, write it in LaTeX: $..$ inline or $$..$$ on its own line, and it renders as real math.',
  'To draw a picture, use the send_cetz tool (CeTZ). Never write TikZ: \\begin{tikzpicture}, \\draw and \\node are not supported and nothing will appear.',
  'Send several short messages like a real person would. How many and how long varies turn by turn: sometimes one line, sometimes a burst of small ones. Never the same count with the same size twice.',
].join('\n');

const _notesHeader = 'Author notes (for your understanding only, never mention them in conversation):';

/// The persona card body, worded so the model reads it as a fact sheet about
/// the person on the other side rather than as one more instruction block.
const _userHeader = 'About the person you are talking to:';

class PromptInput {
  const PromptInput({
    required this.personaName,
    required this.personaPrompt,
    required this.personaBio,
    required this.userName,
    required this.userBio,
    required this.userDescription,
    required this.userPosition,
    required this.replyMode,
    this.personaExamples = '',
  });

  final String personaName;
  final String personaPrompt;
  final String personaBio;
  final String userName;
  final String userBio;

  /// The persona card body, macros already expanded by the caller
  final String userDescription;
  final PersonaPosition userPosition;
  final ReplyMode replyMode;

  /// `{{user}}:` / `{{char}}:` transcript lines, the SillyTavern example
  /// messages slot. They lock in the voice, they are never quoted back.
  final String personaExamples;
}

// the user name and bio go in so the character knows who it is talking to
String buildSystemPrompt(PromptInput input) {
  final userName = input.userName.trim().isEmpty ? 'the user' : input.userName.trim();
  final blocks = <String>[_baseInstruction];

  blocks.add('Your name is "${input.personaName}".');
  blocks.add('They are called "$userName".');

  if (input.userBio.trim().isNotEmpty) blocks.add('About them:\n${input.userBio.trim()}');
  if (input.personaPrompt.trim().isNotEmpty) blocks.add('Your persona:\n${input.personaPrompt.trim()}');
  if (input.personaExamples.trim().isNotEmpty) {
    blocks.add('Example dialogue (for rhythm and voice only, never to be quoted back):\n${formatExamples(input.personaExamples)}');
  }
  if (input.personaBio.trim().isNotEmpty) blocks.add('${_notesHeader}\n${input.personaBio.trim()}');
  if (input.replyMode == ReplyMode.character) blocks.add(_characterRules);

  // atDepth goes in as a real turn in the history instead, see the store
  if (input.userPosition != PersonaPosition.none && input.userPosition != PersonaPosition.atDepth) {
    final card = input.userDescription.trim();
    if (card.isNotEmpty) {
      switch (input.userPosition) {
        // ahead of everything else, so it survives a chat whose tail was cut
        case PersonaPosition.topNote:
          blocks.insert(0, '$_userHeader\n$card');
        // the classic slot, folded into the short blurb it extends
        case PersonaPosition.inPrompt:
          final at = blocks.indexWhere((b) => b.startsWith('About them:'));
          if (at < 0) {
            blocks.add('$_userHeader\n$card');
          } else {
            blocks[at] = 'About them:\n${input.userBio.trim()}\n\n$card';
          }
        // the last thing read before the conversation itself starts
        case PersonaPosition.bottomNote:
          blocks.add('$_userHeader\n$card');
        case PersonaPosition.atDepth:
        case PersonaPosition.none:
          break;
      }
    }
  }

  return blocks.join('\n\n');
}

// silentywaiver style macro expansion
String expandMacros(String text, String charName, String userName) => text
    .replaceAll(RegExp(r'\{\{char\}\}|\{\{persona\}\}|\{\{ai\}\}', caseSensitive: false), charName)
    .replaceAll(RegExp(r'\{\{user\}\}|\{\{me\}\}', caseSensitive: false), userName);

/// SillyTavern's in-chat depth injection. The persona block lands `depth`
/// messages back from the newest one and carries no sourceId, so whatever
/// rebuilds attachments downstream passes it through untouched.
///
/// The slot is then nudged forward off a user turn. Landing straight after a
/// reply makes the card read as part of the assistant's own last message,
/// while landing before a question reads as context the model is about to
/// answer. Returns the same list, edited in place.
List<ChatTurn> injectPersonaDepth(List<ChatTurn> turns, String text, {required int depth, required PersonaRole role}) {
  final body = text.trim();
  if (body.isEmpty || turns.isEmpty) return turns;
  final back = depth < 1 ? 1 : depth;
  var at = turns.length - back;
  if (at < 0) at = 0;
  // step over any user turn so the card never trails an answer it is not part of
  while (at < turns.length && turns[at].role == 'user') {
    at++;
  }
  final name = switch (role) {
    PersonaRole.user => 'user',
    PersonaRole.assistant => 'assistant',
    PersonaRole.system => 'system',
  };
  turns.insert(at.clamp(0, turns.length), ChatTurn(name, [TextPart(body)]));
  return turns;
}

// the example block reads as a transcript so the model can imitate the rhythm
String formatExamples(String raw) => raw
    .split(RegExp(r'\r?\n'))
    .map((line) => line.trim())
    .where((line) => line.isNotEmpty)
    .map((line) {
      final m = RegExp(r'^(.+?)\s*[:：]\s*(.*)$').firstMatch(line);
      if (m == null) return line;
      final who = m.group(1)!.trim();
      final body = m.group(2)!;
      if (RegExp(r'^(me|user|用户)$', caseSensitive: false).hasMatch(who)) return '{{user}}: $body';
      if (RegExp(r'^(you|assistant|ai|char|助手)$', caseSensitive: false).hasMatch(who)) return '{{char}}: $body';
      return line;
    })
    .join('\n');