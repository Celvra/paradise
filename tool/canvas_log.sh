#!/usr/bin/env bash
# Canvas card logcat, filtered to the two engines that draw a chat message.
#
#   tool/canvas_log.sh            follow (ctrl-c to stop)
#   tool/canvas_log.sh -d         dump what is already buffered and exit
#   tool/canvas_log.sh > file     save instead of showing
#
# Flutter routes print/debugPrint/dart:developer through logcat's `flutter`
# tag, so the card lines are grepped out of that stream. Each line carries
# ParaCanvas (card lifecycle) or ParaStore (the failure the transcript shows
# the model). A card that renders logs one ok line; a card that does not logs
# FAILED with the engine's own message, so a missing ok line is as telling as
# a present error.
set -u
pattern='ParaCanvas|ParaStore'

if [ "${1:-}" = "-d" ]; then
  adb logcat -d -v time flutter:I '*:S' | grep -E "$pattern"
else
  adb logcat -v time flutter:I '*:S' | grep --line-buffered -E "$pattern"
fi
