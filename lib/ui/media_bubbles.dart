import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../core/anim.dart';
import '../core/overlays.dart';
import '../core/status.dart';
import '../core/theme.dart';
import '../core/ui_kit.dart';
import '../data/models.dart';
import '../data/store.dart';
import '../l10n/x.dart';

// painted stand in for a map tile used by the location tab and the location bubble
class MapPainter extends CustomPainter {
  MapPainter({required this.dark, required this.accent, required this.t, required this.located});
  final bool dark;
  final Color accent;
  final double t;
  final bool located;

  @override
  void paint(Canvas canvas, Size s) {
    canvas.drawRect(Offset.zero & s, Paint()..color = dark ? const Color(0xFF1B2733) : const Color(0xFFE9ECE2));
    final water = Path()
      ..moveTo(0, s.height * .72)
      ..cubicTo(s.width * .3, s.height * .6, s.width * .5, s.height * .9, s.width, s.height * .7)
      ..lineTo(s.width, s.height)
      ..lineTo(0, s.height)
      ..close();
    canvas.drawPath(water, Paint()..color = dark ? const Color(0xFF16344A) : const Color(0xFFBBD9EC));
    canvas.drawOval(Rect.fromLTWH(s.width * .08, s.height * .1, s.width * .3, s.height * .25), Paint()..color = dark ? const Color(0xFF1F3A2F) : const Color(0xFFCFE3C2));
    final road = Paint()
      ..color = dark ? const Color(0xFF2B3A49) : const Color(0xFFFFFFFF)
      ..strokeWidth = 9
      ..strokeCap = StrokeCap.round;
    final thin = Paint()
      ..color = road.color
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(0, s.height * .35), Offset(s.width, s.height * .5), road);
    canvas.drawLine(Offset(s.width * .3, 0), Offset(s.width * .55, s.height), road);
    for (var i = 1; i < 6; i++) {
      canvas.drawLine(Offset(s.width * i / 6, 0), Offset(s.width * i / 6 + 40, s.height), thin);
      canvas.drawLine(Offset(0, s.height * i / 6), Offset(s.width, s.height * i / 6 - 20), thin);
    }
    final c = Offset(s.width / 2, s.height / 2);
    if (located) {
      canvas.drawCircle(c, 14 + 46 * t, Paint()..color = accent.withAlpha((60 * (1 - t)).round()));
      canvas.drawCircle(c, 9, Paint()..color = const Color(0xFFFFFFFF));
      canvas.drawCircle(c, 6.5, Paint()..color = accent);
    } else {
      canvas.drawCircle(c, 8, Paint()..color = accent.withAlpha(90));
    }
  }

  @override
  bool shouldRepaint(MapPainter o) => o.t != t || o.located != located || o.dark != dark;
}

// sticker message has no bubble, just the glyph and a time pill
class StickerBubble extends StatelessWidget {
  const StickerBubble({super.key, required this.msg});
  final Msg msg;

  @override
  Widget build(BuildContext context) {
    final m = msg;
    final p = context.p;
    return Stack(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(6, 2, 6, 2),
        child: _stickerFace(m),
      ),
      Positioned(
        right: 10,
        bottom: 8,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
          decoration: BoxDecoration(color: p.service, borderRadius: BorderRadius.circular(11)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Text(hm(m.time), style: const TextStyle(color: Color(0xFFFFFFFF), fontSize: 12, height: 1, decoration: TextDecoration.none, fontWeight: FontWeight.w400)),
            if (m.out) ...[const SizedBox(width: 4), MsgStatus(state: m.state, color: const Color(0xFFFFFFFF), danger: p.danger)],
          ]),
        ),
      ),
    ]);
  }
}

/// A red packet or a transfer. Both are the same shape in the real telegram,
/// only the fill and the glyph change, so they share one card and one layout
/// rather than drifting into two designs. Both own the whole bubble, the bubble
/// painter supplies the fill and the tail and this only lays ink on top, which
/// is why the red never has to imitate the bubble corner radius.
bool isWallet(Msg m) => m.kind == MsgKind.transfer;

/// True when the bubble behind this card must be repainted in the card's own
/// colour, which is every transfer and every red packet.
bool isFullBleed(Msg m) => isWallet(m);

/// The room the clock needs on the right of the foot band. The clock is
/// Positioned over the card by the bubble, so a long label has to be held
/// short of it rather than trusted not to reach.
const _clockGutter = 56.0;

/// The fill handed to the bubble painter. A settled card goes grey, a pending
/// one takes the outgoing bubble's own gradient once a wallpaper colour is set,
/// since every glyph on the card is white. With no wallpaper colour it stays
/// telegram blue, or telegram red, the red being the point of a red packet.
List<Color> walletFill(Pal p, {required bool red, required bool done}) {
  if (done) return const [Color(0xFFA5A8AC), Color(0xFF9A9DA1), Color(0xFF8F9296), Color(0xFF84878B)];
  if (p.seed != null) return p.outGrad;
  return red
      ? const [Color(0xFFEE5F53), Color(0xFFDF4639), Color(0xFFD1382C), Color(0xFFC13025)]
      : const [Color(0xFF3AA3E0), Color(0xFF2494D8), Color(0xFF1B86CB), Color(0xFF1479BE)];
}

/// The ink on a wallet card, as body, faded and clock. White on the telegram
/// fills, and the bubble's own ink once the card takes the wallpaper colour,
/// since that fill is light in day and a day card would drown in white.
typedef WalletInk = ({Color ink, Color soft, Color clock});

WalletInk walletInk(Pal p) => p.seed == null
    ? (ink: const Color(0xFFFFFFFF), soft: const Color(0xB3FFFFFF), clock: const Color(0xCCFFFFFF))
    : (ink: p.textOut, soft: p.textOut.withAlpha(0xB3), clock: p.textOut.withAlpha(0xCC));

/// pending, accepted or declined, with the wording each side should see and the
/// glyph that goes with it.
(String, Ic) _footState(Msg m) {
  final l = L10n.current;
  final status = '${m.data['status'] ?? 'pending'}';
  if (status == 'accepted') return (l.walletReceived, Ic.check);
  if (status == 'declined') return (l.walletReturned, Ic.back);
  return m.out ? (l.walletWaitingOpen, Ic.up) : (l.walletTapOpen, Ic.wallet);
}

/// Red packet and transfer, one layout. The fill belongs to the bubble behind
/// it, so everything here is white ink on colour and nothing draws a box.
class WalletCard extends StatelessWidget {
  const WalletCard({super.key, required this.msg, required this.width, this.onTap});

  final Msg msg;
  final double width;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final l = L10n.current;
    final red = msg.data['kind'] == 'redpacket';
    final done = '${msg.data['status'] ?? 'pending'}' != 'pending';
    final note = '${msg.data['note'] ?? ''}'.trim();
    final (label, footIcon) = _footState(msg);
    final amount = L10n.number('#,##0.00').format(((msg.data['amount'] as num?) ?? 0).toDouble());
    final ink = walletInk(context.p);
    // a settled card is grey, so its ink has to step back with it
    final soft = done ? ink.soft : ink.ink;
    return GestureDetector(
      onTap: done || msg.out ? null : onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        // the bubble gives a wallet card 14 and 18 of padding, so this is sized
        // against what is actually left of the max width
        width: math.min(width, 236),
        padding: const EdgeInsets.fromLTRB(0, 1, 0, 0),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
            TgIcon(red ? Ic.hongbao : Ic.wallet, color: soft, size: 26, stroke: 1.7),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                Text(red ? l.walletRedPacket : l.walletTransfer, style: TextStyle(color: ink.ink, fontSize: 15, fontWeight: FontWeight.w500, height: 1.2, decoration: TextDecoration.none)),
                const SizedBox(height: 1),
                // the sender's line rides under the title, a bare packet wishes well
                Text(note.isEmpty ? (red ? l.walletBestWishes : l.walletNoNote) : note, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: soft, fontSize: 12.5, height: 1.2, decoration: TextDecoration.none)),
              ]),
            ),
            const SizedBox(width: 10),
            Text(amount, style: TextStyle(color: soft, fontSize: 15, fontWeight: FontWeight.w500, height: 1.2, decoration: TextDecoration.none, letterSpacing: .2)),
          ]),
          const SizedBox(height: 7),
          // the clock is Positioned into this band by the bubble, so the status
          // sits on the same baseline and is held clear of the clock on the right
          Padding(
            padding: const EdgeInsets.only(right: _clockGutter),
            child: SizedBox(
              height: 12,
              child: Row(children: [
                TgIcon(footIcon, color: soft, size: 12, stroke: 2),
                const SizedBox(width: 4),
                Flexible(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: soft, fontSize: 12, fontWeight: FontWeight.w400, height: 1.0, decoration: TextDecoration.none))),
              ]),
            ),
          ),
        ]),
      ),
    );
  }
}

// body of every non text message kind
Widget mediaBody(BuildContext context, {required Msg m, required Pal p, required double width, required bool out, Widget? timePill, VoidCallback? onPhoto, void Function(int)? onVote, VoidCallback? onAction}) {
  final title = TextStyle(color: out ? p.textOut : p.textIn, fontSize: 16, fontWeight: FontWeight.w500, height: 1.2, decoration: TextDecoration.none);
  final sub = TextStyle(color: out ? p.timeOut : p.timeIn, fontSize: 13, height: 1.2, decoration: TextDecoration.none, fontWeight: FontWeight.w400);
  final accent = out ? p.lineOut : p.lineIn;
  switch (m.kind) {
    case MsgKind.voice:
      final secs = (m.data['dur'] as num?)?.toInt() ?? 3;
      final bars = List<double>.generate(22, (i) => 5 + ((i * 7 + secs * 3) % 11) * 1.6);
      return GestureDetector(
        onTap: onAction,
        behavior: HitTestBehavior.opaque,
        child: SizedBox(
          width: math.min(width, 230),
          child: Row(children: [
            Container(width: 40, height: 40, decoration: BoxDecoration(color: out ? p.lineOut : p.accent, shape: BoxShape.circle), child: const Center(child: Text('▶', style: TextStyle(color: Color(0xFFFFFFFF), fontSize: 16, decoration: TextDecoration.none)))),
            const SizedBox(width: 8),
            Expanded(child: Row(crossAxisAlignment: CrossAxisAlignment.center, mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [for (final h in bars) Container(width: 2.2, height: h, decoration: BoxDecoration(color: accent.withAlpha(190), borderRadius: BorderRadius.circular(1.5)))])),
            const SizedBox(width: 8),
            Text('0:${secs.toString().padLeft(2, '0')}', style: sub),
          ]),
        ),
      );
    case MsgKind.transfer:
      return WalletCard(msg: m, width: width, onTap: onAction);
    case MsgKind.photo:
      final path = m.data['path'] as String?;
      final radius = math.max(4.0, context.store.bubbleRadius - 3);
      return GestureDetector(
        onTap: onPhoto,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(radius),
          child: Stack(children: [
            ConstrainedBox(
              constraints: BoxConstraints(maxWidth: width, maxHeight: 360, minHeight: 120),
              child: path != null && File(path).existsSync()
                  ? Image.file(
                      File(path),
                      width: width,
                      fit: BoxFit.cover,
                      cacheWidth: 900,
                      frameBuilder: (_, child, frame, sync) => sync ? child : AnimatedOpacity(opacity: frame == null ? 0 : 1, duration: const Duration(milliseconds: 260), child: child),
                      errorBuilder: (_, __, ___) => SizedBox(width: width, height: 160, child: ColoredBox(color: p.gray)),
                    )
                  : SizedBox(width: width, height: 160, child: ColoredBox(color: p.gray, child: Center(child: TgIcon(Ic.image, color: p.hint, size: 40)))),
            ),
            if (timePill != null) Positioned(right: 6, bottom: 6, child: timePill),
          ]),
        ),
      );
    case MsgKind.file:
    case MsgKind.music:
      final music = m.kind == MsgKind.music;
      var name = '${m.data['name'] ?? (music ? context.l.attachAudioFallback : context.l.attachFileFallback)}';
      final dot = name.lastIndexOf('.');
      final ext = dot > 0 ? name.substring(dot + 1).toUpperCase() : '';
      if (music && dot > 0) name = name.substring(0, dot);
      return SizedBox(
        width: width,
        child: Row(children: [
          Container(width: 48, height: 48, decoration: BoxDecoration(color: music ? const Color(0xFFF45255) : accent, shape: BoxShape.circle), child: Center(child: TgIcon(music ? Ic.music : Ic.file, color: const Color(0xFFFFFFFF), size: 26, stroke: 1.8))),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: title),
              const SizedBox(height: 2),
              Text(ext.isEmpty ? fileSize((m.data['size'] as num?) ?? 0) : '${fileSize((m.data['size'] as num?) ?? 0)} · $ext', style: sub),
            ]),
          ),
        ]),
      );
    case MsgKind.location:
      final lat = (m.data['lat'] as num?) ?? 0;
      final lng = (m.data['lng'] as num?) ?? 0;
      return GestureDetector(
        onTap: () {
          Clipboard.setData(ClipboardData(text: '$lat, $lng'));
          showBulletin(context, context.l.attachLocationCopied);
        },
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          ClipRRect(borderRadius: BorderRadius.circular(10), child: SizedBox(width: width, height: 150, child: CustomPaint(painter: MapPainter(dark: p.dark, accent: p.accent, t: .35, located: true)))),
          const SizedBox(height: 6),
          Text(context.l.attachLocationTitle, style: title),
          Text('${lat.toStringAsFixed(5)}, ${lng.toStringAsFixed(5)}', style: sub),
        ]),
      );
    case MsgKind.contact:
      return SizedBox(
        width: width,
        child: Row(children: [
          Avatar(name: '${m.data['name']}', color: '${m.data['name']}'.hashCode.abs(), size: 46),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              Text('${m.data['name']}', maxLines: 1, overflow: TextOverflow.ellipsis, style: title),
              const SizedBox(height: 2),
              Text(('${m.data['phone']}').isEmpty ? context.l.attachNoPhone : '${m.data['phone']}', style: sub),
            ]),
          ),
        ]),
      );
    case MsgKind.poll:
      return _PollView(m: m, p: p, out: out, width: width, onVote: onVote);
    case MsgKind.text:
    case MsgKind.sticker:
    // a trace row is drawn by TraceView, it never reaches a bubble
    case MsgKind.trace:
      return const SizedBox.shrink();
  }
}

// PollView port options animate their result bars when a vote lands
class _PollView extends StatelessWidget {
  const _PollView({required this.m, required this.p, required this.out, required this.width, required this.onVote});
  final Msg m;
  final Pal p;
  final bool out;
  final double width;
  final void Function(int)? onVote;

  @override
  Widget build(BuildContext context) {
    final d = m.data;
    final opts = List<String>.from((d['opts'] as List?) ?? const []);
    final votes = List<int>.from((d['votes'] as List?) ?? const []);
    final mine = List<int>.from((d['mine'] as List?) ?? const []);
    final quiz = d['quiz'] == true;
    final multi = d['multi'] == true;
    final correct = d['correct'] as int?;
    final voted = mine.isNotEmpty;
    final total = votes.fold<int>(0, (a, b) => a + b);
    final text = out ? p.textOut : p.textIn;
    final sub = TextStyle(color: out ? p.timeOut : p.timeIn, fontSize: 13, height: 1.2, decoration: TextDecoration.none, fontWeight: FontWeight.w400);
    final line = out ? p.lineOut : p.lineIn;
    const green = Color(0xFF46AA36);
    final l = context.l;
    final base = quiz
        ? l.pollKindQuiz
        : (d['anon'] == false ? l.pollKindPublic : l.pollKindAnonymous);
    final kind = multi ? l.pollKindMultiple(base) : base;
    return SizedBox(
      width: width,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        Text('${d['q']}', style: TextStyle(color: text, fontSize: 16, fontWeight: FontWeight.w500, height: 1.25, decoration: TextDecoration.none)),
        const SizedBox(height: 2),
        Text(kind, style: sub),
        const SizedBox(height: 8),
        for (var i = 0; i < opts.length; i++)
          Tap(
            scale: .99,
            onTap: onVote == null ? null : () => onVote!(i),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                _mark(i, mine.contains(i), voted, quiz, correct, line, green),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Expanded(child: Text(opts[i], style: TextStyle(color: text, fontSize: 15, height: 1.2, decoration: TextDecoration.none, fontWeight: FontWeight.w400))),
                      if (voted) Text(L10n.number('0%').format(total == 0 ? 0 : (votes[i] * 100 / total).round()), style: TextStyle(color: text, fontSize: 14, fontWeight: FontWeight.w600, decoration: TextDecoration.none)),
                    ]),
                    const SizedBox(height: 4),
                    TweenAnimationBuilder<double>(
                      tween: Tween(end: voted && total > 0 ? votes[i] / total : 0.0),
                      duration: const Duration(milliseconds: 420),
                      curve: TgCurves.easeOutQuint,
                      builder: (_, v, __) => Stack(children: [
                        Container(height: 4, decoration: BoxDecoration(color: line.withAlpha(40), borderRadius: BorderRadius.circular(2))),
                        FractionallySizedBox(widthFactor: v.clamp(0.0, 1.0), child: Container(height: 4, decoration: BoxDecoration(color: quiz && voted ? (i == correct ? green : (mine.contains(i) ? p.danger : line)) : line, borderRadius: BorderRadius.circular(2)))),
                      ]),
                    ),
                  ]),
                ),
              ]),
            ),
          ),
        const SizedBox(height: 4),
        Text(l.pluralVotes(total), style: sub),
        const SizedBox(height: 16),
      ]),
    );
  }

  Widget _mark(int i, bool on, bool voted, bool quiz, int? correct, Color line, Color green) {
    final showCorrect = quiz && voted && i == correct;
    final showWrong = quiz && voted && on && i != correct;
    final fill = showCorrect ? green : (showWrong ? p.danger : (on ? line : const Color(0x00000000)));
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: 22,
      height: 22,
      margin: const EdgeInsets.only(top: 1),
      decoration: BoxDecoration(shape: BoxShape.circle, color: fill, border: Border.all(color: fill.a == 0 ? line.withAlpha(150) : fill, width: 1.6)),
      child: on || showCorrect ? Center(child: TgIcon(showWrong ? Ic.close : Ic.check, color: const Color(0xFFFFFFFF), size: 13, stroke: 2.4)) : null,
    );
  }
}

// PhotoViewer port swipe between photos pinch to zoom tap to hide the bar
void openPhotoViewer(BuildContext context, List<Msg> photos, Msg current) {
  final index = math.max(0, photos.indexOf(current));
  Navigator.of(context, rootNavigator: true).push(PageRouteBuilder<void>(
    opaque: false,
    transitionDuration: const Duration(milliseconds: 220),
    reverseTransitionDuration: const Duration(milliseconds: 180),
    pageBuilder: (_, __, ___) => _Viewer(photos: photos, index: index),
    transitionsBuilder: (_, a, __, child) => FadeTransition(opacity: a, child: child),
  ));
}

class _Viewer extends StatefulWidget {
  const _Viewer({required this.photos, required this.index});
  final List<Msg> photos;
  final int index;

  @override
  State<_Viewer> createState() => _ViewerState();
}

class _ViewerState extends State<_Viewer> {
  late final PageController _pc = PageController(initialPage: widget.index);
  late int _i = widget.index;
  bool _bar = true;

  @override
  void dispose() {
    _pc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    return ColoredBox(
      color: const Color(0xFF000000),
      child: Stack(children: [
        GestureDetector(
          onTap: () => setState(() => _bar = !_bar),
          child: PageView.builder(
            controller: _pc,
            itemCount: widget.photos.length,
            onPageChanged: (i) => setState(() => _i = i),
            itemBuilder: (_, i) {
              final path = widget.photos[i].data['path'] as String?;
              return InteractiveViewer(
                maxScale: 5,
                child: Center(child: path != null && File(path).existsSync() ? Image.file(File(path), fit: BoxFit.contain) : const SizedBox.shrink()),
              );
            },
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          top: 0,
          child: IgnorePointer(
            ignoring: !_bar,
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 180),
              opacity: _bar ? 1 : 0,
              child: Container(
                height: mq.padding.top + 56,
                padding: EdgeInsets.only(top: mq.padding.top),
                color: const Color(0x99000000),
                child: Row(children: [
                  Tap(scale: .88, onTap: () => Navigator.of(context).pop(), child: const SizedBox(width: 56, height: 56, child: Center(child: TgIcon(Ic.back, color: Color(0xFFFFFFFF), size: 24)))),
                  Text(context.l.photoCounter(_i + 1, widget.photos.length), style: const TextStyle(color: Color(0xFFFFFFFF), fontSize: 19, fontWeight: FontWeight.w500, decoration: TextDecoration.none)),
                ]),
              ),
            ),
          ),
        ),
      ]),
    );
  }
}


/// emoji stickers are text, library stickers are image files or links
Widget _stickerFace(Msg m) {
  final emoji = '${m.data['emoji'] ?? ''}';
  final path = '${m.data['path'] ?? ''}';
  if (emoji.isNotEmpty || path.isEmpty) return Text(emoji, style: const TextStyle(fontSize: 112, height: 1.15, decoration: TextDecoration.none));
  final remote = path.startsWith('http');
  if (!remote && !File(path).existsSync()) return const SizedBox(width: 150, height: 150);
  return ClipRRect(
    borderRadius: BorderRadius.circular(10),
    child: remote ? Image.network(path, width: 150, height: 150, fit: BoxFit.cover, gaplessPlayback: true, errorBuilder: (_, __, ___) => const SizedBox(width: 150, height: 150)) : Image.file(File(path), width: 150, height: 150, fit: BoxFit.cover, gaplessPlayback: true),
  );
}

final AudioPlayer _voicePlayer = AudioPlayer();
final FlutterTts _voiceTts = FlutterTts();

/// plays the synthesized file, or reads the transcript with the system voice
Future<void> playVoice(Msg m) async {
  final path = '${m.data['path'] ?? ''}';
  final speed = ((m.data['speed'] as num?) ?? 1).toDouble();
  try {
    if (path.isNotEmpty && File(path).existsSync()) {
      await _voicePlayer.stop();
      await _voicePlayer.setPlaybackRate(speed.clamp(0.5, 2.0));
      await _voicePlayer.play(DeviceFileSource(path));
    } else {
      await _voiceTts.setSpeechRate((0.5 * speed).clamp(0.1, 1.0));
      await _voiceTts.speak(m.text);
    }
  } catch (_) {}
}
