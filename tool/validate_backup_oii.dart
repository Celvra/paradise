/// Checks a real backup archive against the real oii engine.
///
/// The app writes backups with a pure dart codec so that neither writing nor
/// reading depends on a native library being present. That is the right call
/// for a timer driven auto backup, but it leaves a question this tool answers:
/// is the archive on disk actually oii, or only something our own decoder
/// happens to accept? Every `.oii` entry goes through the vendored oii parser,
/// and the manifest's asset sizes and hashes are recomputed, so a truncated or
/// tampered archive is caught before it is ever offered for import.
///
/// Needs the bridge built for the host, because the test runner will not
/// dlopen the bundled asset on its own:
///
///     LD_LIBRARY_PATH=$PWD/build/native_assets/linux dart run tool/validate_backup_oii.dart <archive.zip>
///
/// Exits 0 when every entry checked out, 1 otherwise, so it can gate a script.
library;

import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:oii_bridge/oii_bridge.dart';

/// [exitCode] rather than a return value: this dart sdk does not turn main's
/// return value into a process exit status, so a script gating on this tool
/// would see success on a broken archive.
void main(List<String> args) {
  exitCode = _run(args);
}

int _run(List<String> args) {
  if (args.length != 1) {
    stderr.writeln('usage: dart run tool/validate_backup_oii.dart <archive.zip>');
    return 2;
  }
  final file = File(args.single);
  if (!file.existsSync()) {
    stderr.writeln('no such file: ${file.path}');
    return 2;
  }

  final Archive archive;
  try {
    archive = ZipDecoder().decodeBytes(file.readAsBytesSync());
  } catch (e) {
    stderr.writeln('not a readable zip: $e');
    return 1;
  }

  final texts = <String, String>{};
  final assets = <String, List<int>>{};
  for (final f in archive.files) {
    if (!f.isFile) continue;
    if (f.name.endsWith('.oii')) {
      texts[f.name] = utf8.decode(f.content as List<int>);
    } else {
      assets[f.name] = f.content as List<int>;
    }
  }
  if (texts.isEmpty) {
    stderr.writeln('no .oii entries: this does not look like a paradise backup');
    return 1;
  }

  var bad = 0;
  for (final entry in texts.keys.toList()..sort()) {
    final r = oiiValidateBackupDoc(texts[entry]!);
    if (r.ok) {
      stdout.writeln('ok    $entry  (${entry.split('/').first}, '
          '${r.data.length} fields)');
    } else {
      bad++;
      // the diagnostic is a stderr line: it is the reason the tool failed, and
      // it is multi line oii output with the offending source quoted
      stderr.writeln('BAD   $entry\n${_indent(r.error)}');
    }
  }

  // the manifest lists every asset with a hash and a size, so a truncated zip
  // or a swapped image shows up even though no .oii file mentions it
  final manifestEntry = texts['manifest.oii'];
  if (manifestEntry == null) {
    bad++;
    stderr.writeln('BAD   manifest.oii is missing');
  } else {
    final m = oiiValidateBackupDoc(manifestEntry);
    if (!m.ok) {
      bad++;
      stderr.writeln('BAD   manifest.oii\n${_indent(m.error)}');
    } else {
      final files = m.data['files'];
      if (files is! List) {
        bad++;
        stderr.writeln('BAD   manifest.oii has no files list');
      } else {
        for (final spec in files) {
          if (spec is! Map) continue;
          final path = '${spec['path']}';
          final wantSize = spec['size'];
          final wantSha = '${spec['sha']}';
          final bytes = assets[path];
          if (bytes == null) {
            bad++;
            stderr.writeln('BAD   $path is listed in the manifest but not in the zip');
            continue;
          }
          if (wantSize is num && bytes.length != wantSize.toInt()) {
            bad++;
            stderr.writeln('BAD   $path is ${bytes.length} bytes, manifest says $wantSize');
            continue;
          }
          if (wantSha.isNotEmpty && shaHex(bytes) != wantSha) {
            bad++;
            stderr.writeln('BAD   $path does not match its manifest hash');
          }
        }
        stdout.writeln('ok    assets (${files.length} listed, '
            '${assets.length} present)');
      }
    }
  }

  if (bad == 0) {
    stdout.writeln('\n$file: ${texts.length} documents and ${assets.length} '
        'assets are valid oii');
    return 0;
  }
  stderr.writeln('\n$file: $bad problem(s) found');
  return 1;
}

String shaHex(List<int> bytes) => sha256.convert(bytes).toString();

String _indent(String s) =>
    s.split('\n').map((l) => '        $l').join('\n');