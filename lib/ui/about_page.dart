import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:url_launcher/url_launcher.dart';

import '../app_info.dart' show appVersion;
import '../core/anim.dart';
import '../core/overlays.dart';
import '../core/theme.dart';
import '../core/ui_kit.dart';
import '../data/about_deps.dart';
import '../data/contributors.dart';
import '../l10n/x.dart';
import 'tg_cells.dart';

// Settings > About, laid out like the Telegram Android AboutActivity: the app
// mark with the name under it, then the version and every address as ordinary
// rows, and the dependency tree one tap further down.
//
// It was a dialog holding four paragraphs before, and the paragraphs were blob
// strings in three languages: the licence, the repository, the two projects
// this one was modelled on, and twenty seven packages inside one three thousand
// character line. Nothing in there could be restyled, reordered or corrected
// without editing that line. Everything here is a row, and a word is a title.

// The repositories and the group invites. These are addresses, not words, so
// they stay out of the arb where a translator would be tempted to break them.
const repoUrl = 'https://github.com/Celvra/paradise';
const communityUrl = 'https://discord.gg/aQaNUHPsw';
const qqGroupUrl = 'https://qm.qq.com/q/BeQPYWuzVS';
const qqGroupNumber = '272298906';

const _kelivoUrl = 'https://github.com/Chevey339/kelivo';
const _sillyTavernUrl = 'https://github.com/SillyTavern/SillyTavern';

// Three taps on the app mark. No comment.
const _markUrl = 'https://bilibili.com/video/BV1GJ411x7h7';

void openAboutPage(BuildContext c) => Navigator.of(c).push(TgRoute(builder: (_) => const AboutPage()));

void openContributorsPage(BuildContext c) => Navigator.of(c).push(TgRoute(builder: (_) => const ContributorsPage()));

/// Hands an address to whatever the system has for it.
///
/// Every link on the about page goes through here so a device with no browser
/// gets the same bulletin instead of a row that silently does nothing.
Future<void> _openExternal(BuildContext context, String url) async {
  final uri = Uri.tryParse(url);
  if (uri == null) return;
  var ok = false;
  try {
    ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
  } catch (_) {
    ok = false;
  }
  if (!ok && context.mounted) showBulletin(context, L10n.current.aboutLinkFailed);
}

/// The build number is what a bug report needs, so the row copies it.
Future<void> _copyVersion(BuildContext context) async {
  final l = context.l;
  await Clipboard.setData(ClipboardData(text: appVersion));
  if (context.mounted) showBulletin(context, l.toastCopiedLabel(l.settingsAboutSub(appVersion)));
}

class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l = context.l;
    return TgSettingsPage(
      title: l.settingsAbout,
      builder: (_, __) => ListView(
        physics: const ClampingScrollPhysics(),
        padding: const EdgeInsets.only(bottom: 40),
        children: [
          const _Mark(),
          TgSection(
            children: [
              TgTextCell(
                icon: Ic.info,
                title: l.settingsAboutSub(appVersion),
                onTap: () => _copyVersion(context),
              ),
              TgTextCell(
                icon: Ic.fileCode,
                title: l.aboutSourceCode,
                subtitle: repoUrl,
                onTap: () => _openExternal(context, repoUrl),
              ),
              TgTextCell(
                icon: Ic.chats,
                title: l.aboutCommunity,
                subtitle: communityUrl,
                onTap: () => _openExternal(context, communityUrl),
              ),
              TgTextCell(
                icon: Ic.user,
                title: l.aboutQqGroup,
                subtitle: '$qqGroupNumber · $qqGroupUrl',
                divider: false,
                onTap: () => _openExternal(context, qqGroupUrl),
              ),
            ],
          ),
          TgSection(
            header: l.aboutAcknowledgements,
            children: [
              TgTextCell(
                title: 'Kelivo',
                subtitle: l.aboutThanksKelivo,
                subtitleColor: context.p.accent,
                onTap: () => _openExternal(context, _kelivoUrl),
              ),
              TgTextCell(
                title: 'SillyTavern',
                subtitle: l.aboutThanksSillyTavern,
                subtitleColor: context.p.accent,
                onTap: () => _openExternal(context, _sillyTavernUrl),
              ),
              TgTextCell(
                icon: Ic.user,
                title: l.aboutContributors,
                divider: false,
                trailing: TgIcon(Ic.chevron, color: context.p.hint, size: 18),
                onTap: () => openContributorsPage(context),
              ),
            ],
          ),
          TgSection(
            children: [
              TgTextCell(
                icon: Ic.file,
                title: l.aboutLicenses,
                divider: false,
                trailing: TgIcon(Ic.chevron, color: context.p.hint, size: 18),
                onTap: () => Navigator.of(context).push(TgRoute(builder: (_) => const LicensesPage())),
              ),
            ],
            footer: l.aboutLicensesSub,
          ),
        ],
      ),
    );
  }
}

/// The app mark over the name and the licence line, the way Telegram opens its
/// About screen. The mark is the launcher svg tinted by the theme, so there is
/// one source of truth for it instead of a second png that drifts.
class _Mark extends StatefulWidget {
  const _Mark();

  @override
  State<_Mark> createState() => _MarkState();
}

class _MarkState extends State<_Mark> {
  int _taps = 0;
  int _lastAt = 0;

  void _onTap() {
    final now = DateTime.now().millisecondsSinceEpoch;
    // slow taps do not chain: brushing the mark by accident must not arm it
    _taps = (now - _lastAt < 800) ? _taps + 1 : 1;
    _lastAt = now;
    if (_taps >= 3) {
      _taps = 0;
      _openExternal(context, _markUrl);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.p;
    return Padding(
      padding: const EdgeInsets.fromLTRB(21, 24, 21, 12),
      child: Column(children: [
        // the launcher glyph on its own, tinted by the theme. No tile: the
        // launcher background is white, which glares in night mode, and a
        // hardcoded brand gradient is a second source of truth for the mark.
        Tap(
          scale: .92,
          onTap: _onTap,
          child: SvgPicture.asset(
            'assets/icon/icon.svg',
            width: 72,
            height: 72,
            colorFilter: ColorFilter.mode(p.title, BlendMode.srcIn),
          ),
        ),
        const SizedBox(height: 12),
        Text(context.l.appTitle,
            style: TextStyle(color: p.title, fontSize: 22, height: 1.2, fontWeight: FontWeight.w500, decoration: TextDecoration.none)),
        const SizedBox(height: 2),
        // the build number is already on the version row below, so this line
        // carries the licence instead, which is what a reader came here for
        Text('AGPL-3.0',
            style: TextStyle(color: p.subtitle, fontSize: 14, height: 1.3, fontWeight: FontWeight.w400, decoration: TextDecoration.none)),
      ]),
    );
  }
}

/// Everyone who committed to the repository, read live off the GitHub api.
///
/// A row per login with the avatar and the commit count, most commits first.
/// The list is fetched when the page opens and kept for the rest of the run;
/// offline the page offers a retry instead of an empty list. Tapping a row
/// opens the profile.
class ContributorsPage extends StatefulWidget {
  const ContributorsPage({super.key});

  @override
  State<ContributorsPage> createState() => _ContributorsPageState();
}

class _ContributorsPageState extends State<ContributorsPage> {
  Future<List<Contributor>?>? _future;

  @override
  void initState() {
    super.initState();
    _future = fetchContributors();
  }

  void _retry() => setState(() {
        dropContributorsCache();
        _future = fetchContributors();
      });

  @override
  Widget build(BuildContext context) {
    final l = context.l;
    return TgSettingsPage(
      title: l.aboutContributors,
      builder: (_, __) => FutureBuilder<List<Contributor>?>(
        future: _future,
        builder: (c, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.only(top: 120),
                child: SizedBox(width: 28, height: 28, child: _Ring()),
              ),
            );
          }
          final all = snap.data;
          if (all == null) {
            return ListView(
              physics: const ClampingScrollPhysics(),
              padding: const EdgeInsets.only(bottom: 40),
              children: [
                TgSection(children: [
                  TgTextCell(
                    title: l.aboutContributorsFailed,
                    divider: false,
                    onTap: _retry,
                  ),
                ]),
              ],
            );
          }
          return ListView(
            physics: const ClampingScrollPhysics(),
            padding: const EdgeInsets.only(bottom: 40),
            children: [
              TgSection(children: [
                for (var i = 0; i < all.length; i++)
                  TgTextCell(
                    leading: _Avatar(all[i]),
                    title: all[i].login,
                    subtitle: l.aboutContributions(all[i].contributions),
                    divider: i < all.length - 1,
                    onTap: () => _openExternal(context, all[i].profileUrl),
                  ),
              ]),
            ],
          );
        },
      ),
    );
  }
}

/// The loading ring, drawn by hand instead of borrowing the Material one: the
/// default spinner is fixed blue and reads as a foreign object on a themed
/// page. Track in the theme's selector color, arc in the accent, same 900ms
/// turn as the video overlay spinner.
class _Ring extends StatefulWidget {
  const _Ring();

  @override
  State<_Ring> createState() => _RingState();
}

class _RingState extends State<_Ring> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.p;
    return AnimatedBuilder(
      animation: _c,
      builder: (_, __) => CustomPaint(
        painter: _RingPainter(t: _c.value, track: p.selector, arc: p.accent),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({required this.t, required this.track, required this.arc});
  final double t;
  final Color track;
  final Color arc;

  @override
  void paint(Canvas canvas, Size s) {
    final center = Offset(s.width / 2, s.height / 2);
    final r = math.min(s.width, s.height) / 2 - 2;
    final bg = Paint()
      ..color = track
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    final fg = Paint()
      ..color = arc
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 3;
    canvas.drawCircle(center, r, bg);
    canvas.drawArc(Rect.fromCircle(center: center, radius: r), -math.pi / 2 + t * 2 * math.pi, math.pi * 1.2, false, fg);
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.t != t || old.track != track || old.arc != arc;
}

/// A contributor's GitHub avatar, falling back to the initial on a tile when
/// offline or when the image fails, so a missing picture is a letter rather
/// than a hole.
class _Avatar extends StatelessWidget {
  const _Avatar(this.c);
  final Contributor c;

  @override
  Widget build(BuildContext context) {
    const size = 40.0;
    final initial = c.login.isEmpty ? '?' : c.login.characters.first.toUpperCase();
    return SizedBox(
      width: size,
      height: size,
      child: ClipOval(
        child: Container(
          color: context.p.selector,
          alignment: Alignment.center,
          child: Stack(children: [
            Center(
              child: Text(initial,
                  style: TextStyle(color: context.p.subtitle, fontSize: 17, fontWeight: FontWeight.w600, decoration: TextDecoration.none)),
            ),
            if (c.avatarUrl.isNotEmpty)
              Positioned.fill(
                child: Image.network(
                  c.avatarUrl,
                  width: size,
                  height: size,
                  fit: BoxFit.cover,
                  gaplessPlayback: true,
                  cacheWidth: 96,
                  errorBuilder: (_, __, ___) => const SizedBox(width: size, height: size),
                ),
              ),
          ]),
        ),
      ),
    );
  }
}

/// Open source licences, the page the old dialog could not be: one row per
/// package with the name, the version this build locked, the licence and, under
/// the name, what this app uses it for in the reader's own language.
class LicensesPage extends StatelessWidget {
  const LicensesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l = context.l;
    return TgSettingsPage(
      title: l.aboutLicenses,
      builder: (_, __) => ListView(
        physics: const ClampingScrollPhysics(),
        padding: const EdgeInsets.only(bottom: 40),
        children: [
          TgSection(
            children: [
              for (var i = 0; i < aboutDeps.length; i++)
                TgTextCell(
                  title: '${aboutDeps[i].name} ${aboutDeps[i].version}',
                  subtitle: aboutDeps[i].purpose(l),
                  trailing: TgChip(aboutDeps[i].licence),
                  divider: i < aboutDeps.length - 1,
                  onTap: () => _openExternal(context, aboutDeps[i].url),
                ),
            ],
            footer: l.aboutLicensesSub,
          ),
        ],
      ),
    );
  }
}