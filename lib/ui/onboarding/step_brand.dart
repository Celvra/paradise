import 'package:flutter/widgets.dart';

import '../../app_info.dart';
import '../../core/theme.dart';
import '../../l10n/x.dart';
import 'common.dart';

/// Step 1: the app icon centred, the product name as the 26sp hero, the
/// README one-liner as the centred 15sp subtitle, version as a tiny grey
/// footer. No extra body, no copyright line.
OnboardingStep buildBrandStep() => OnboardingStep(
      build: (c, flow) {
        final l = c.l;
        final p = c.p;
        return Center(
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 8),
            children: [
              const Center(child: OnboardingLogo(size: 104)),
              const SizedBox(height: 20),
              Text(l.onboardBrandTitle,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: p.title, fontSize: 26, fontWeight: FontWeight.w700, decoration: TextDecoration.none, height: 1.2)),
              const SizedBox(height: 12),
              Text(l.onboardBrandTagline,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: p.msg, fontSize: 15, fontWeight: FontWeight.w400, decoration: TextDecoration.none, height: 1.35)),
              const SizedBox(height: 28),
              Text('v$appVersion',
                  textAlign: TextAlign.center, style: TextStyle(color: p.subtitle, fontSize: 13, decoration: TextDecoration.none)),
            ],
          ),
        );
      },
    );
