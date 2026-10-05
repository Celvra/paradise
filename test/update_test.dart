import 'package:flutter_test/flutter_test.dart';
import 'package:paradise/data/app_update.dart';

void main() {
  test('a newer tag counts as an update', () {
    expect(isNewerVersion('1.0.2', 'v1.0.3'), isTrue);
    expect(isNewerVersion('1.0.2', '1.1.0'), isTrue);
    expect(isNewerVersion('1.0.2', '2.0.0'), isTrue);
  });

  test('same or older tags are not updates', () {
    expect(isNewerVersion('1.0.2', 'v1.0.2'), isFalse);
    expect(isNewerVersion('1.0.3', 'v1.0.2'), isFalse);
    expect(isNewerVersion('2.0.0', '1.9.9'), isFalse);
  });

  test('leading v and build metadata are ignored', () {
    expect(isNewerVersion('1.0.2+3', 'v1.0.2'), isFalse);
    expect(isNewerVersion('1.0.2', '1.0.10'), isTrue);
    expect(isNewerVersion('1.0.2', 'v1.0.2-beta.1'), isFalse);
  });
}
