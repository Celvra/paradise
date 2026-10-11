import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:paradise/data/ai_config.dart';
import 'package:paradise/data/store.dart';
import 'package:paradise/main.dart';
import 'package:paradise/ui/human_data_pages.dart';

Future<void> settle(WidgetTester t, [int ms = 600]) async {
  for (var i = 0; i < ms ~/ 50; i++) {
    await t.pump(const Duration(milliseconds: 50));
  }
}

void main() {
  testWidgets('the tools row counts the built in tools, not only the MCP ones', (t) async {
    SharedPreferences.setMockInitialValues({});
    t.view.physicalSize = const Size(1080, 2200);
    t.view.devicePixelRatio = 2.75;
    final store = await Store.load();
    final ai = await AiConfig.load();
    store.attachAi(ai);
    store.onboarded = true;
    await t.pumpWidget(TgApp(store: store, ai: ai));
    await settle(t);

    await t.tap(find.text('Settings').last);
    await settle(t, 700);
    await t.tap(find.text('Humanize'));
    await settle(t, 700);

    // the row used to count h.mcp.tools alone, which is zero until a server
    // answers and stayed zero for everyone who never added one
    expect(find.text('0 MCP'), findsNothing);
    final builtin = kBuiltinTools.where((e) => store.workspace.toolsEnabled || !kWorkspaceTools.contains(e)).length;
    expect(find.text('$builtin'), findsWidgets);
    expect(find.text('Tools, MCP servers and permissions'), findsOneWidget);
  });
}