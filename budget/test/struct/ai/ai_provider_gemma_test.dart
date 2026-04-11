import 'package:budget/struct/ai/ai_provider_gemma.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('GemmaProvider.meetsAndroidRequirements', () {
    test('returns true when sdk and memory meet minimums', () {
      final result = GemmaProvider.meetsAndroidRequirements(
        sdkInt: 24,
        totalMemoryBytes: 4 * 1024 * 1024 * 1024,
      );
      expect(result, isTrue);
    });

    test('returns false when sdk below minimum', () {
      final result = GemmaProvider.meetsAndroidRequirements(
        sdkInt: 23,
        totalMemoryBytes: 8 * 1024 * 1024 * 1024,
      );
      expect(result, isFalse);
    });

    test('returns false when memory below minimum', () {
      final result = GemmaProvider.meetsAndroidRequirements(
        sdkInt: 33,
        totalMemoryBytes: (4 * 1024 * 1024 * 1024) - 1,
      );
      expect(result, isFalse);
    });
  });
}
