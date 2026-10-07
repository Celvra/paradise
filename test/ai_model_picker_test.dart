import 'package:flutter_test/flutter_test.dart';
import 'package:paradise/data/ai/provider_model.dart';
import 'package:paradise/ui/ai_model_picker.dart';

// The picker used to list every model a provider serves for every caller, so
// picking a model to chat with offered the image endpoints too. These pin the
// rule the tabs filter on, which is the capability flag and nothing else.
void main() {
  ModelMeta mk(String id, {bool t2i = false, bool vision = false}) => ModelMeta(
        id: id,
        name: id,
        contextWindow: 0,
        maxOutput: 0,
        vision: vision,
        textToImage: t2i,
        reasoning: false,
        source: ModelSource.manual,
      );

  const chat = ModelPurpose.chat;
  const image = ModelPurpose.image;

  test('the chat tab keeps chat models and drops the image ones', () {
    expect(modelFitsTab(mk('gpt-4o'), chat, 0), isTrue);
    expect(modelFitsTab(mk('gpt-image-1', t2i: true), chat, 0), isFalse);
  });

  test('the image tab keeps image models and drops the chat ones', () {
    expect(modelFitsTab(mk('gpt-image-1', t2i: true), image, 0), isTrue);
    expect(modelFitsTab(mk('gpt-4o'), image, 0), isFalse);
  });

  test('the second tab is always the other half', () {
    // a chat caller's second tab is image, an image caller's second tab is chat
    expect(modelFitsTab(mk('gpt-image-1', t2i: true), chat, 1), isTrue);
    expect(modelFitsTab(mk('gpt-4o'), chat, 1), isFalse);
    expect(modelFitsTab(mk('gpt-4o'), image, 1), isTrue);
    expect(modelFitsTab(mk('gpt-image-1', t2i: true), image, 1), isFalse);
  });

  test('the all tab keeps everything, so an unknown model is still reachable', () {
    for (final mm in [mk('a'), mk('b', t2i: true), mk('c', vision: true)]) {
      expect(modelFitsTab(mm, chat, 2), isTrue);
      expect(modelFitsTab(mm, image, 2), isTrue);
    }
  });

  test('vision alone does not make a model an image model', () {
    // a vision model reads pictures, it does not draw them
    expect(modelFitsTab(mk('gpt-4o', vision: true), chat, 0), isTrue);
    expect(modelFitsTab(mk('gpt-4o', vision: true), image, 0), isFalse);
  });
}