import 'dart:convert';

import 'package:http/http.dart' as http;

import '../app_info.dart' show defaultUserAgent;

/// One GitHub contributor, as the about page shows them.
///
/// Only the three fields the page needs. The api answers with much more, and
/// reading exactly these keeps a new field upstream adds from breaking the
/// parse.
class Contributor {
  const Contributor({required this.login, required this.avatarUrl, required this.profileUrl, required this.contributions});

  factory Contributor.fromJson(Map<String, dynamic> j) => Contributor(
        login: '${j['login'] ?? ''}',
        avatarUrl: '${j['avatarUrl'] ?? j['avatar_url'] ?? ''}',
        profileUrl: '${j['htmlUrl'] ?? j['html_url'] ?? ''}',
        contributions: (j['contributions'] as num?)?.toInt() ?? 0,
      );

  final String login;
  final String avatarUrl;
  final String profileUrl;
  final int contributions;

  bool get usable => login.isNotEmpty;
}

/// The contributors of this repository, most commits first.
///
/// Null means "could not tell": offline, rate limited, the api moved. The page
/// shows a retry then, not an empty list pretending nobody contributed.
///
/// The one good fetch is kept for the rest of the run. The unauthenticated api
/// allows sixty requests an hour per address, and reopening the page must not
/// spend one every time.
List<Contributor>? _cached;

Future<List<Contributor>?> fetchContributors({http.Client? client}) async {
  if (_cached != null) return _cached;
  final c = client ?? http.Client();
  try {
    final res = await c.get(
      Uri.parse('https://api.github.com/repos/Celvra/paradise/contributors?per_page=100'),
      headers: const {
        'Accept': 'application/vnd.github+json',
        'User-Agent': defaultUserAgent,
        'X-GitHub-Api-Version': '2022-11-28',
      },
    ).timeout(const Duration(seconds: 12));
    if (res.statusCode != 200) return null;
    final j = jsonDecode(res.body);
    if (j is! List) return null;
    final out = <Contributor>[];
    for (final e in j) {
      if (e is! Map<String, dynamic>) continue;
      final c = Contributor.fromJson(e);
      if (c.usable) out.add(c);
    }
    // an empty list is a valid answer only when the api says so with 200 and
    // a list; anything unparseable above already returned null
    _cached = out;
    return out;
  } catch (_) {
    return null;
  } finally {
    if (client == null) c.close();
  }
}

/// Forgets the cached list, so the next open fetches again. Tests use this to
/// stop one case's answer leaking into the next.
void dropContributorsCache() => _cached = null;
