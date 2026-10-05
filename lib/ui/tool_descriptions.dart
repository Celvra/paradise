// What each tool on the tools page does, in the user's terms rather than the
// model's.
//
// The list in human_data_pages.dart is the source of truth for which tools
// exist and in what order they are shown; this is the source of truth for what
// they are for. A tool with no entry here would render as a row with an empty
// line under the name, which looks like a bug rather than a missing string.
//
// Kept beside the list rather than inside it because the strings belong to the
// arb files and the list is a hand written array of names. The test at the
// bottom is what stops the two from drifting.

import 'package:paradise/l10n/x.dart';

/// `null` for a tool this build does not have a description for. The tools page
/// renders that as the raw name rather than as a blank line, so a missing entry
/// is visible instead of silent.
String? toolDescription(AppLocalizations l, String tool) => switch (tool) {
      'get_time' => l.toolDescGetTime,
      'schedule_message' => l.toolDescSchedule,
      'cancel_scheduled' => l.toolDescCancelScheduled,
      'modify_scheduled' => l.toolDescModifyScheduled,
      'list_scheduled' => l.toolDescListScheduled,
      'set_status' => l.toolDescSetStatus,
      'adjust_feeling' => l.toolDescAdjustFeeling,
      'write_memory' => l.toolDescWriteMemory,
      'read_memory' => l.toolDescReadMemory,
      'complete_todo' => l.toolDescCompleteTodo,
      'set_life_schedule' => l.toolDescLifeSchedule,
      'pin_message' => l.toolDescPinMessage,
      'edit_message' => l.toolDescEditMessage,
      'quote_message' => l.toolDescQuoteMessage,
      'update_character_card' => l.toolDescCharacterCard,
      'adjust_rating' => l.toolDescRating,
      'send_sticker' => l.toolDescSendSticker,
      'save_sticker' => l.toolDescSaveSticker,
      'recall_message' => l.toolDescRecall,
      'send_typo' => l.toolDescTypo,
      'send_image' => l.toolDescSendImage,
      'send_file' => l.toolDescSendFile,
      'send_svg' => l.toolDescSendSvg,
      'send_html' => l.toolDescSendHtml,
      'send_latex' => l.toolDescSendLatex,
      'send_cetz' => l.toolDescSendCetz,
      'send_transfer' => l.toolDescSendTransfer,
      'read_file' => l.wsToolDescRead,
      'write_file' => l.wsToolDescWrite,
      'edit_file' => l.wsToolDescEdit,
      'list_dir' => l.wsToolDescList,
      'glob' => l.wsToolDescGlob,
      'grep' => l.wsToolDescGrep,
      'shell' => l.wsToolDescShell,
      'view_image' => l.wsToolDescViewImage,
      _ => null,
    };

/// One line for an MCP tool, which has no string of our own and only the
/// server's description. A server that sends an empty one gets the name back,
/// so the row is never a bare label over nothing.
String mcpToolDescription(String name, String description) {
  final d = description.trim().replaceAll('\n', ' ');
  return d.isEmpty ? name : d;
}

/// The same for an MCP server row, which shows where it points and how many
/// tools it answered with.
String mcpServerDescription(String url, int toolCount, AppLocalizations l) =>
    '${url.isEmpty ? l.toolNoUrl : url}\n${l.toolCountSuffix(toolCount)}';
