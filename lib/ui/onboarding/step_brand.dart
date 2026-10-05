import 'package:flutter/widgets.dart';

import '../../app_info.dart';
import '../../core/theme.dart';
import '../../l10n/x.dart';
import 'common.dart';

/// Step 1: the mark, the name, the tagline and where the source lives. The
/// only step without a form; it exists so the wizard opens on the product
/// rather than on a request. The StepHeader would repeat the title twice, so
/// this step blanks both fields and paints its own hero block.
OnboardingStep buildBrandStep() => OnboardingStep(
      build: (c, flow) {
        final l = c.l;
        final p = c.p;
        return ListView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 8),
          children: [
            const SizedBox(height: 8),
            Center(child: OnboardingLogo(size: 104)),
            const SizedBox(height: 20),
            Center(
              child: Text(l.onboardBrandTitle, textAlign: TextAlign.center, style: TextStyle(color: p.title, fontSize: 30, fontWeight: FontWeight.w800, decoration: TextDecoration.none, letterSpacing: .3)),
            ),
            const SizedBox(height: 8),
            Center(
              child: Text(l.onboardBrandTagline, textAlign: TextAlign.center, style: TextStyle(color: p.msg, fontSize: 15, fontWeight: FontWeight.w400, decoration: TextDecoration.none, height: 1.4)),
            ),
            const SizedBox(height: 22),
            Center(
              child: Text(l.onboardBrandBody, textAlign: TextAlign.center, style: TextStyle(color: p.msg, fontSize: 15, fontWeight: FontWeight.w400, decoration: TextDecoration.none, height: 1.45)),
            ),
            const SizedBox(height: 24),
            Center(
              child: Text('v$appVersion', style: TextStyle(color: p.subtitle, fontSize: 13, decoration: TextDecoration.none)),
            ),
            const SizedBox(height: 4),
            Center(
              child: Text(l.onboardBrandLicense, textAlign: TextAlign.center, style: TextStyle(color: p.subtitle, fontSize: 13, decoration: TextDecoration.none)),
            ),
          ],
        );
      },
    );
