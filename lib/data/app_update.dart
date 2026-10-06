import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../app_info.dart' show defaultUserAgent;

/// GitHub releases live here. The badge in README points at the same repo.
const updateRepo = 'Celvra/paradise';

/// The one release the update sheet shows.
class AppRelease {
  const AppRelease({
    required this.tag,
    required this.name,
    required this.body,
    required this.htmlUrl,
    required this.publishedAt,
  });

  final String tag;
  final String name;
  final String body;
  final String htmlUrl;
  final String publishedAt;

  factory AppRelease.fromJson(Map<String, dynamic> j) => AppRelease(
        tag: '${j['tag_name'] ?? ''}'.trim(),
        name: '${j['name'] ?? j['tag_name'] ?? ''}'.trim(),
        body: '${j['body'] ?? ''}',
        htmlUrl: '${j['html_url'] ?? 'https://github.com/$updateRepo/releases/latest'}'.trim(),
        publishedAt: '${j['published_at'] ?? ''}'.trim(),
      );
}

/// Grabs /releases/latest, which already skips drafts and prereleases.
/// Null means "could not tell": offline, rate limited, no releases yet.
Future<AppRelease?> fetchLatestRelease({http.Client? client}) async {
  final c = client ?? http.Client();
  try {
    final res = await c.get(
      Uri.parse('https://api.github.com/repos/$updateRepo/releases/latest'),
      headers: const {
        'Accept': 'application/vnd.github+json',
        'User-Agent': defaultUserAgent,
        'X-GitHub-Api-Version': '2022-11-28',
      },
    ).timeout(const Duration(seconds: 12));
    if (res.statusCode != 200) return null;
    final j = jsonDecode(res.body);
    if (j is! Map<String, dynamic>) return null;
    final rel = AppRelease.fromJson(j);
    if (rel.tag.isEmpty) return null;
    return rel;
  } catch (_) {
    return null;
  } finally {
    if (client == null) c.close();
  }
}

/// True when [tag] is strictly newer than [current].
///
/// A leading `v` and trailing build metadata (`+3`) or pre-release suffix
/// (`-beta.1`) are ignored: tags say `v1.0.4`, the app says `1.0.3`.
bool isNewerVersion(String current, String tag) => _compare(_parts(tag), _parts(current)) > 0;

List<int> _parts(String v) {
  var s = v.trim();
  if (s.startsWith('v') || s.startsWith('V')) s = s.substring(1);
  final plus = s.indexOf('+');
  if (plus >= 0) s = s.substring(0, plus);
  final dash = s.indexOf('-');
  if (dash >= 0) s = s.substring(0, dash);
  return [
    for (final seg in s.split('.'))
      int.tryParse(RegExp(r'^\d+').firstMatch(seg.trim())?.group(0) ?? '') ?? 0,
  ];
}

int _compare(List<int> a, List<int> b) {
  final n = a.length > b.length ? a.length : b.length;
  for (var i = 0; i < n; i++) {
    final x = i < a.length ? a[i] : 0;
    final y = i < b.length ? b[i] : 0;
    if (x != y) return x.compareTo(y);
  }
  return 0;
}
