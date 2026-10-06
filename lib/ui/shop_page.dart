import 'package:flutter/widgets.dart';

import '../core/overlays.dart';
import '../core/ui_kit.dart';
import '../data/human/hub.dart';
import '../data/models.dart';
import '../data/store.dart';
import '../l10n/x.dart';
import 'ai_widgets.dart';
import 'dialogs_page.dart';
import 'human_pages.dart';
import 'tg_cells.dart';

// The shop: the pretend balance finally has somewhere to go. Boosts land on
// one chosen persona, the apology card is global, and the wallet records the
// spend like any other transaction.

class _Item {
  const _Item(this.id, this.price, this.icon, this.l10nTitle, this.l10nSub, {this.target = true});
  final String id;

  /// kind key the wallet tx carries
  final double price;
  final Ic icon;
  final String l10nTitle;
  final String l10nSub;

  /// false when the effect is global (the apology card) and nobody is picked
  final bool target;
}

const _items = [
  _Item('affection', 52, Ic.crown, 'shopItemAffection', 'shopItemAffectionSub'),
  _Item('energy', 30, Ic.regen, 'shopItemEnergy', 'shopItemEnergySub'),
  _Item('mood', 20, Ic.smile, 'shopItemMood', 'shopItemMoodSub'),
  _Item('apology', 66, Ic.check2, 'shopItemApology', 'shopItemApologySub', target: false),
];

String _itemText(AppLocalizations l, String key) => switch (key) {
      'shopItemAffection' => l.shopItemAffection,
      'shopItemEnergy' => l.shopItemEnergy,
      'shopItemApology' => l.shopItemApology,
      _ => l.shopItemMood,
    };

String _itemSub(AppLocalizations l, String key) => switch (key) {
      'shopItemAffectionSub' => l.shopItemAffectionSub,
      'shopItemEnergySub' => l.shopItemEnergySub,
      'shopItemApologySub' => l.shopItemApologySub,
      _ => l.shopItemMoodSub,
    };

class ShopPage extends StatelessWidget {
  const ShopPage({super.key});

  Future<void> _buy(BuildContext context, HumanHub h, _Item item) async {
    final l = context.l;
    final st = Store.read(context);
    Chat? chat;
    if (item.target) {
      if (st.chats.isEmpty) {
        showBulletin(context, l.shopNoChat);
        return;
      }
      final target = await showAiSelect<String>(
        context,
        title: l.shopChoose,
        value: st.chats.first.id,
        options: [
          for (final c in st.chats) (value: c.id, label: c.persona.name, sub: null),
        ],
      );
      if (target == null || !context.mounted) return;
      chat = st.chats.where((e) => e.id == target).firstOrNull;
      if (chat == null) return;
    }
    final ok = await showTgDialog<bool>(context,
        title: _itemText(l, item.l10nTitle),
        message: l.shopDeduct(item.price.toStringAsFixed(2)),
        actions: [
          DialogAction(l.actionCancel, false),
          DialogAction(l.actionOk, true),
        ]);
    if (ok != true || !context.mounted) return;
    if (!h.wallet.spend(item.price, title: _itemText(l, item.l10nTitle))) {
      showBulletin(context, l.shopNotEnough);
      return;
    }
    if (chat != null) {
      // the effect lands through the chat so the model actually hears about it:
      // a gift card goes out as the user's message and the reply answers it
      const effects = {
        'affection': '+10 affection',
        'energy': '+30 energy',
        'mood': '+20 mood',
        'apology': 'annoyance cooled to minimum',
      };
      st.sendGift(chat, itemId: item.id, title: _itemText(l, item.l10nTitle), effect: effects[item.id] ?? 'a gift effect');
      if (context.mounted) {
        showBulletin(context, l.shopDone);
        openChat(context, chat);
      }
      return;
    }
    // global items have no target chat: apply the effect on the spot
    h.settings.annoyScore = 1;
    h.changed();
    if (context.mounted) showBulletin(context, l.shopDone);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l;
    return HPage(
      title: l.shopTitle,
      body: (c, h, p) => [
        Padding(
          padding: const EdgeInsets.fromLTRB(21, 14, 21, 2),
          child: Row(children: [
            Text(l.shopBalance, style: hStyle(p, size: 14, color: p.subtitle)),
            const Spacer(),
            Text('¥ ${h.wallet.balance.toStringAsFixed(2)}',
                style: hStyle(p, size: 15, color: p.accent, weight: FontWeight.w600)),
          ]),
        ),
        const SizedBox(height: 8),
        TgSection(
          header: l.shopTitle,
          children: [
            for (final item in _items)
              TgTextCell(
                icon: item.icon,
                title: _itemText(l, item.l10nTitle),
                subtitle: _itemSub(l, item.l10nSub),
                value: '¥ ${item.price.toStringAsFixed(0)}',
                divider: item != _items.last,
                onTap: () => _buy(c, h, item),
              ),
          ],
        ),
      ],
    );
  }
}
