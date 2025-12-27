import 'package:dart_odbc/src/worker/client.dart';
import 'package:dart_odbc/src/worker/message.dart';
import 'package:test/test.dart';

class TestIsolateClient extends IsolateClient {
  @override
  ResponsePayload handleeMessage(RequestPayload message) {
    switch (message.command) {
      case 'ping':
        return ResponsePayload(true);

      case 'add':
        return ResponsePayload(
          (message.arguments![0] as int) + (message.arguments![1] as int),
        );

      case 'throw':
        throw StateError('boom');

      default:
        throw UnsupportedError('unknown command');
    }
  }
}

void main() {
  group('IsolateClient', () {
    late TestIsolateClient client;

    setUp(() async {
      client = TestIsolateClient();
    });

    tearDown(() async {
      await client.close();
    });

    test('handles simple request/response', () async {
      final response = await client.request(RequestPayload('ping'));

      expect(response, isA<ResponsePayload>());
      expect((response as ResponsePayload).data, equals(true));
    });

    test('handles multiple concurrent requests', () async {
      final futures = List.generate(
        10,
        (i) => client.request(RequestPayload('add', [i, i])),
      );

      final results = await Future.wait(futures);

      for (var i = 0; i < results.length; i++) {
        if (results[i] is ErrorPayload) {
          fail('Received error payload: ${results[i]}');
        }

        expect(results[i], isA<ResponsePayload>());
        expect((results[i] as ResponsePayload).data, equals(i + i));
      }
    });

    test('propagates worker exceptions', () async {
      expect(
        () => client.request(RequestPayload('throw')),
        throwsA(isA<Exception>()),
      );
    });

    test('unknown command returns error', () async {
      expect(
        () => client.request(RequestPayload('nope')),
        throwsA(isA<Exception>()),
      );
    });

    test('request ids are matched correctly', () async {
      final r1 = client.request(RequestPayload('add', [1, 2]));
      final r2 = client.request(RequestPayload('add', [10, 20]));

      final res1 = await r1;
      final res2 = await r2;

      if (res1 is ErrorPayload) {
        fail('Received error payload: $res1');
      }
      if (res2 is ErrorPayload) {
        fail('Received error payload: $res2');
      }

      // expect(res1['result'], equals(3));
      expect((res1 as ResponsePayload).data, equals(3));
      expect((res2 as ResponsePayload).data, equals(30));
    });

    test('closing client kills isolate and prevents use', () async {
      await client.close();

      expect(
        () async {
          await client.request(RequestPayload('ping'));
        },
        throwsA(anything), // StateError / SendPort error is fine
      );
    });
  });
}
