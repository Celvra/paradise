import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:paradise/data/contributors.dart';

// The contributors list comes off the network, so these pin the parsing and
// the failure contract: a row missing its name is skipped rather than fatal,
// and anything that is not a 200 with a list reads as "could not tell".
void main() {
  setUp(dropContributorsCache);
  tearDown(dropContributorsCache);

  MockClient ok(List<Object?> body, {int status = 200}) => MockClient(
        (_) async => http.Response(jsonEncode(body), status),
      );

  Map<String, Object?> row(String login, {int n = 1}) => {
        'login': login,
        'avatar_url': 'https://avatars.example/$login',
        'html_url': 'https://github.com/$login',
        'contributions': n,
      };

  test('a list of rows parses, most commits first from the api order', () async {
    final got = await fetchContributors(client: ok([row('a', n: 27), row('b', n: 2)]));
    expect(got, isNotNull);
    expect(got!.map((c) => c.login), ['a', 'b']);
    expect(got.first.contributions, 27);
    expect(got.first.avatarUrl, contains('avatars.example/a'));
    expect(got.first.profileUrl, 'https://github.com/a');
  });

  test('a nameless row is skipped, not fatal', () async {
    final got = await fetchContributors(client: ok([row('a'), {'login': '', 'contributions': 5}, 'junk', row('b')]));
    expect(got!.map((c) => c.login), ['a', 'b']);
  });

  test('a non-200 reads as unknown', () async {
    expect(await fetchContributors(client: ok([], status: 403)), isNull);
  });

  test('garbage reads as unknown, not an empty list', () async {
    final bad = MockClient((_) async => http.Response('not json', 200));
    expect(await fetchContributors(client: bad), isNull);
  });

  test('the second call does not hit the network again', () async {
    var hits = 0;
    final counting = MockClient((_) async {
      hits++;
      return http.Response(jsonEncode([row('a')]), 200);
    });
    await fetchContributors(client: counting);
    await fetchContributors(client: counting);
    expect(hits, 1);
  });
}