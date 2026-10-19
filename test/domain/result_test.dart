import 'package:flutter_test/flutter_test.dart';
import 'package:koda/core/error/failure.dart';
import 'package:koda/core/error/result.dart';

void main() {
  const failure = DatabaseFailure('boom');

  group('Result', () {
    test('Ok exposes its value and no failure', () {
      const Result<int> result = Ok(42);

      expect(result.isOk, isTrue);
      expect(result.isErr, isFalse);
      expect(result.valueOrNull, 42);
      expect(result.failureOrNull, isNull);
    });

    test('Err exposes its failure and no value', () {
      const Result<int> result = Err(failure);

      expect(result.isOk, isFalse);
      expect(result.isErr, isTrue);
      expect(result.valueOrNull, isNull);
      expect(result.failureOrNull, same(failure));
    });

    test('fold calls onOk for Ok and onErr for Err', () {
      String describe(Result<int> r) =>
          r.fold((f) => 'err:${f.message}', (v) => 'ok:$v');

      expect(describe(const Ok(1)), 'ok:1');
      expect(describe(const Err(failure)), 'err:boom');
    });

    test('map transforms Ok and propagates Err unchanged', () {
      const Result<int> ok = Ok(2);
      const Result<int> err = Err(failure);

      expect(ok.map((v) => v * 10), const Ok(20));
      final mappedErr = err.map((v) => v * 10);
      expect(mappedErr, isA<Err<int>>());
      expect(mappedErr.failureOrNull, same(failure));
    });

    test('has value equality', () {
      expect(const Ok(1), const Ok(1));
      expect(const Ok(1).hashCode, const Ok(1).hashCode);
      expect(const Ok(1), isNot(const Ok(2)));
      expect(const Err<int>(failure), const Err<int>(failure));
      expect(const Ok<Unit>(unit), const Ok<Unit>(unit));
    });

    test('a switch over Result is exhaustive', () {
      const Result<String> result = Ok('x');

      final text = switch (result) {
        Ok(:final value) => value,
        Err(:final failure) => failure.message,
      };

      expect(text, 'x');
    });
  });

  group('Failure', () {
    test('toString includes the type, message and cause', () {
      const plain = NotFoundFailure('playlist p1');
      final withCause = UnexpectedFailure('oops', cause: StateError('bad'));

      expect(plain.toString(), 'NotFoundFailure: playlist p1');
      expect(withCause.toString(), contains('UnexpectedFailure: oops'));
      expect(withCause.toString(), contains('bad'));
    });
  });
}
