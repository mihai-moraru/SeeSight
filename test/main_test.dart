import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fastvlm_flutter/main.dart';

void main() {
  // Note: We test the SeeSightApp widget properties without fully rendering,
  // as HomeScreen requires native camera/permissions that can't be mocked easily.

  group('SeeSightApp', () {
    test('is a ConsumerWidget', () {
      const app = SeeSightApp();
      expect(app, isA<ConsumerWidget>());
    });

    test('has const constructor', () {
      const app1 = SeeSightApp();
      const app2 = SeeSightApp();
      expect(app1, isNotNull);
      expect(app2, isNotNull);
    });

    test('can be instantiated', () {
      expect(() => const SeeSightApp(), returnsNormally);
    });
  });
}
