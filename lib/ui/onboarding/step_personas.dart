import 'package:flutter/widgets.dart';

import '../../core/anim.dart';
import '../../core/theme.dart';
import '../../core/ui_kit.dart';
import '../../data/models.dart';
import '../../data/persona_templates.dart';
import '../../data/store.dart';
import '../../l10n/x.dart';
import 'common.dart';

/// Step 8: who is waiting on the other shore. Multi select from the six
/// templates; finishing creates one chat per pick, greeting message included.
/// Picking nothing is fine too, the dialog list has its own new-chat road.
OnboardingStep buildPersonasStep() => OnboardingStep(
      title: (l) => l.onboardPersonaTitle,
      body: (l) => l.onboardPersonaBody,
      build: (c, flow) {
        return ListView(
          padding: const EdgeInsets.fromLTRB(18, 4, 18, 8),
          children: [
            for (var i = 0; i < personaTemplates.length; i++)
              Enter(
                fly: true,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _TemplateCard(
                    template: personaTemplates[i],
                    picked: flow.pickedPersonas.contains(personaTemplates[i].id),
                    onTap: () => flow.togglePersona(personaTemplates[i].id),
                  ),
                ),
              ),
          ],
        );
      },
    );

/// One template: avatar block in the persona's gradient, name, the one liner,
/// and a check that animates in when picked. The full card body lives in the
/// persona card editor, this step only needs the face and the pitch.
class _TemplateCard extends StatelessWidget {
  const _TemplateCard({required this.template, required this.picked, required this.onTap});

  final PersonaTemplate template;
  final bool picked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l = context.l;
    final p = context.p;
    return Tap(
      scale: .97,
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: TgCurves.easeOut,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: picked ? p.accent.withAlpha(22) : p.gray,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: picked ? p.accent : const Color(0x00000000), width: 1.2),
        ),
        child: Row(children: [
          Avatar(name: template.name(l), color: template.color, size: 46),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 220),
                curve: TgCurves.easeOut,
                style: TextStyle(color: picked ? p.accent : p.title, fontSize: 15.5, fontWeight: FontWeight.w600, decoration: TextDecoration.none),
                child: Text(template.name(l)),
              ),
              const SizedBox(height: 2),
              Text(template.bio(l), style: TextStyle(color: p.subtitle, fontSize: 12.5, decoration: TextDecoration.none, height: 1.3)),
            ]),
          ),
          const SizedBox(width: 8),
          // the tick grows and fades in, so a tap reads as a decision
          AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: TgCurves.easeOutBack,
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: picked ? p.accent : p.subtitle.withAlpha(120), width: 1.6),
              color: picked ? p.accent : const Color(0x00000000),
            ),
            child: AnimatedScale(
              duration: const Duration(milliseconds: 220),
              curve: TgCurves.easeOutBack,
              scale: picked ? 1 : 0,
              child: Center(child: TgIcon(Ic.check, color: p.dark ? const Color(0xFF0F1A24) : const Color(0xFFFFFFFF), size: 13, stroke: 2.6)),
            ),
          ),
        ]),
      ),
    );
  }
}

/// Creates one chat per picked template, in template order. Called from the
/// page when the wizard finishes: the step only collects the ids.
List<Chat> createPickedChats(Store st, Set<String> ids, AppLocalizations l) {
  final out = <Chat>[];
  for (final t in personaTemplates) {
    if (!ids.contains(t.id)) continue;
    out.add(st.createChat(
      t.name(l),
      t.prompt,
      bio: t.bio(l),
      greeting: t.greeting(l),
      examples: t.examples,
      color: t.color,
      thinking: t.thinking,
      agent: t.agent,
    ));
  }
  return out;
}
