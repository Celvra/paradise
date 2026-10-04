import 'package:flutter_test/flutter_test.dart';
import 'package:paradise/data/ai/provider_model.dart';
import 'package:paradise/data/human/human_models.dart';

// old settings blobs on disk must keep loading, the new knobs fall back to
// their defaults instead of crashing the settings screen
void main() {
  test('ai settings round trip keeps the pacing knobs', () {
    final s = AiSettings(
      providers: const [],
      chain: const [],
      replyMode: ReplyMode.character,
      temperature: 1,
      maxOutput: 0,
      firstBubbleDelayMs: 2500,
      bubbleGapScale: 2.5,
      pacingJitter: 0.6,
      stripMarkdownInCharacterMode: true,
      compaction: const CompactionSettings(),
    );
    final back = AiSettings.fromJson(s.toJson());
    expect(back.firstBubbleDelayMs, 2500);
    expect(back.bubbleGapScale, 2.5);
    expect(back.pacingJitter, 0.6);
    expect(back.replyMode, ReplyMode.character);
  });

  test('ai settings without pacing keys load with defaults', () {
    final back = AiSettings.fromJson({'replyMode': 'character'});
    expect(back.firstBubbleDelayMs, 1000);
    expect(back.bubbleGapScale, 1);
    expect(back.pacingJitter, 0.35);
    // the retired typewriter knob is simply ignored
    expect(back.toJson().containsKey('typewriterMs'), isFalse);
  });

  test('human settings round trip keeps the pacing knobs', () {
    final s = HumanSettings()
      ..replyDelayMs = 3200
      ..paceScale = 1.6;
    final back = HumanSettings.fromJson(s.toJson());
    expect(back.replyDelayMs, 3200);
    expect(back.paceScale, 1.6);
  });

  test('human settings without pacing keys load with defaults', () {
    final back = HumanSettings.fromJson({});
    expect(back.replyDelayMs, 1500);
    expect(back.paceScale, 1.0);
  });
}
