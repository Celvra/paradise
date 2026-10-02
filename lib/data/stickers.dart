// built in sticker packs each sticker is one big glyph with search keywords.
// there is no emoji pack here on purpose: emoji live in the emoji tab and the
// placeholder packs only crowded out what the user collected themselves.
class Sticker {
  const Sticker(this.emoji, this.keys);
  final String emoji;
  final String keys;
}

class StickerPack {
  const StickerPack(this.title, this.icon, this.items);
  final String title;
  final String icon;
  final List<Sticker> items;
}

const stickerPacks = <StickerPack>[
  StickerPack('Animals', '🐱', [
    Sticker('🐱', 'cat kitten meow'),
    Sticker('🐶', 'dog puppy woof'),
    Sticker('🦊', 'fox clever'),
    Sticker('🐼', 'panda bear'),
    Sticker('🐨', 'koala'),
    Sticker('🐯', 'tiger'),
    Sticker('🦁', 'lion king'),
    Sticker('🐸', 'frog'),
    Sticker('🐵', 'monkey'),
    Sticker('🐧', 'penguin'),
    Sticker('🦄', 'unicorn magic'),
    Sticker('🐙', 'octopus'),
    Sticker('🦋', 'butterfly'),
    Sticker('🐢', 'turtle slow'),
    Sticker('🐳', 'whale ocean'),
    Sticker('🦉', 'owl wise night'),
    Sticker('🐝', 'bee busy'),
    Sticker('🦖', 'dino trex'),
  ]),
  StickerPack('Food', '🍕', [
    Sticker('🍕', 'pizza'),
    Sticker('🍔', 'burger'),
    Sticker('🍟', 'fries'),
    Sticker('🌮', 'taco'),
    Sticker('🍣', 'sushi'),
    Sticker('🍜', 'noodles ramen'),
    Sticker('🍩', 'donut sweet'),
    Sticker('🍦', 'ice cream'),
    Sticker('🍰', 'cake birthday'),
    Sticker('☕', 'coffee tea'),
    Sticker('🍺', 'beer cheers'),
    Sticker('🍎', 'apple'),
    Sticker('🍉', 'watermelon summer'),
    Sticker('🥑', 'avocado'),
    Sticker('🍿', 'popcorn movie'),
    Sticker('🍫', 'chocolate'),
  ]),
  StickerPack('Vibes', '🔥', [
    Sticker('🔥', 'fire hot lit'),
    Sticker('💯', 'hundred perfect'),
    Sticker('✨', 'sparkle magic'),
    Sticker('💖', 'heart love'),
    Sticker('👍', 'thumbs up ok yes'),
    Sticker('👎', 'thumbs down no'),
    Sticker('👏', 'clap bravo'),
    Sticker('🙏', 'please thanks pray'),
    Sticker('💪', 'strong muscle'),
    Sticker('🎉', 'party tada celebrate'),
    Sticker('🚀', 'rocket launch fast'),
    Sticker('💡', 'idea bulb'),
    Sticker('⚡', 'lightning fast energy'),
    Sticker('🌈', 'rainbow'),
    Sticker('👀', 'eyes look'),
    Sticker('💀', 'skull dead lol'),
    Sticker('🫶', 'heart hands love'),
    Sticker('🤖', 'robot ai bot'),
  ]),
];

// panel order after the recent tab
List<Sticker> searchStickers(String q) {
  final s = q.trim().toLowerCase();
  if (s.isEmpty) return const [];
  final out = <Sticker>[];
  for (final p in stickerPacks) {
    for (final st in p.items) {
      if (st.keys.contains(s) || p.title.toLowerCase().contains(s)) out.add(st);
    }
  }
  return out;
}
