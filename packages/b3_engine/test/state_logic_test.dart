import 'package:test/test.dart';
import 'package:b3_engine/b3_engine.dart';

void main() {
  final engine = B3Engine();

  group('Rule.ALL (AND) Logic', () {
    test('FAILED wins over all', () {
      expect(
          engine.evaluateAll(
              [B3State.maintained, B3State.failed, B3State.unknown]),
          B3State.failed);
    });
    test('UNKNOWN wins over DEGRADED and MAINTAINED', () {
      expect(
          engine.evaluateAll(
              [B3State.maintained, B3State.unknown, B3State.degraded]),
          B3State.unknown);
    });
    test('DEGRADED wins over MAINTAINED', () {
      expect(engine.evaluateAll([B3State.maintained, B3State.degraded]),
          B3State.degraded);
    });
    test('MAINTAINED only if all MAINTAINED', () {
      expect(engine.evaluateAll([B3State.maintained, B3State.maintained]),
          B3State.maintained);
    });
  });

  group('Rule.ANY (OR) Logic', () {
    test('MAINTAINED wins over all', () {
      expect(
          engine.evaluateAny(
              [B3State.failed, B3State.unknown, B3State.maintained]),
          B3State.maintained);
    });
    test('DEGRADED wins over UNKNOWN and FAILED', () {
      expect(
          engine
              .evaluateAny([B3State.failed, B3State.unknown, B3State.degraded]),
          B3State.degraded);
    });
    test('UNKNOWN wins over FAILED', () {
      expect(engine.evaluateAny([B3State.failed, B3State.unknown]),
          B3State.unknown);
    });
    test('FAILED only if all FAILED', () {
      expect(
          engine.evaluateAny([B3State.failed, B3State.failed]), B3State.failed);
    });
  });
}
