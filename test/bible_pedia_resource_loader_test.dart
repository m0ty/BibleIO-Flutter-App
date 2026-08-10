import 'dart:collection';

import 'package:bible_pedia_dart/bible_pedia.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bible/services/bible_pedia_resource_loader.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

void main() {
  test('follows secure redirects and leaves an injected client open', () async {
    final client = _QueueClient([
      (_) => _response(302, headers: {'location': '/images/final.png'}),
      (_) => _response(
        200,
        chunks: const [
          [1, 2, 3],
        ],
      ),
    ]);
    final loader = FlutterBiblePediaResourceByteLoader(
      _EmptyAssetBundle(),
      httpClient: client,
    );

    final bytes = await loader.loadBytes(
      Uri.parse('https://cdn.example.test/start.png'),
      maximumBytes: 8,
    );

    expect(bytes, [1, 2, 3]);
    expect(client.requestedUris.map((uri) => uri.toString()), [
      'https://cdn.example.test/start.png',
      'https://cdn.example.test/images/final.png',
    ]);
    expect(client.closeCount, 0);
  });

  for (final redirect in [
    'http://cdn.example.test/insecure.png',
    'https://user:secret@cdn.example.test/credentialed.png',
  ]) {
    test('rejects unsafe redirect $redirect', () async {
      final client = _QueueClient([
        (_) => _response(302, headers: {'location': redirect}),
      ]);
      final loader = FlutterBiblePediaResourceByteLoader(
        _EmptyAssetBundle(),
        httpClient: client,
      );

      await expectLater(
        loader.loadBytes(
          Uri.parse('https://cdn.example.test/start.png'),
          maximumBytes: 8,
        ),
        throwsA(
          isA<BiblePediaResourceException>().having(
            (error) => error.code,
            'code',
            BiblePediaErrorCode.resourcePolicy,
          ),
        ),
      );
      expect(client.requestedUris, hasLength(1));
    });
  }

  test('stops a streamed response at the maximum byte count', () async {
    late _QueueClient client;
    final loader = FlutterBiblePediaResourceByteLoader(
      _EmptyAssetBundle(),
      httpClientFactory: () => client = _QueueClient([
        (_) => _response(
          200,
          chunks: const [
            [1, 2, 3],
            [4, 5, 6],
          ],
        ),
      ]),
    );

    await expectLater(
      loader.loadBytes(
        Uri.parse('https://cdn.example.test/large.png'),
        maximumBytes: 4,
      ),
      throwsA(
        isA<BiblePediaResourceException>().having(
          (error) => error.code,
          'code',
          BiblePediaErrorCode.resourceTooLarge,
        ),
      ),
    );
    expect(client.closeCount, 1, reason: 'owned clients must always close');
  });

  test('rejects an oversized Content-Length before reading its body', () async {
    var listened = false;
    final controller = Stream<List<int>>.multi((sink) {
      listened = true;
      sink.add([1]);
      sink.close();
    });
    final client = _QueueClient([
      (_) => http.StreamedResponse(controller, 200, contentLength: 99),
    ]);
    final loader = FlutterBiblePediaResourceByteLoader(
      _EmptyAssetBundle(),
      httpClient: client,
    );

    await expectLater(
      loader.loadBytes(
        Uri.parse('https://cdn.example.test/declared-large.png'),
        maximumBytes: 8,
      ),
      throwsA(
        isA<BiblePediaResourceException>().having(
          (error) => error.code,
          'code',
          BiblePediaErrorCode.resourceTooLarge,
        ),
      ),
    );
    expect(listened, isTrue, reason: 'the response stream is cancelled');
  });

  for (final scenario in const [
    (
      statusCode: 404,
      code: BiblePediaErrorCode.resourceNotFound,
      retryable: false,
    ),
    (
      statusCode: 410,
      code: BiblePediaErrorCode.resourceNotFound,
      retryable: false,
    ),
    (statusCode: 400, code: BiblePediaErrorCode.resourceIo, retryable: false),
    (statusCode: 408, code: BiblePediaErrorCode.resourceIo, retryable: true),
    (statusCode: 429, code: BiblePediaErrorCode.resourceIo, retryable: true),
    (statusCode: 503, code: BiblePediaErrorCode.resourceIo, retryable: true),
  ]) {
    test('maps HTTP ${scenario.statusCode} to ${scenario.code.name} '
        '(retryable: ${scenario.retryable})', () async {
      final client = _QueueClient([(_) => _response(scenario.statusCode)]);
      final loader = FlutterBiblePediaResourceByteLoader(
        _EmptyAssetBundle(),
        httpClient: client,
      );

      await expectLater(
        loader.loadBytes(
          Uri.parse('https://cdn.example.test/status.png'),
          maximumBytes: 8,
        ),
        throwsA(
          isA<BiblePediaResourceException>()
              .having((error) => error.code, 'code', scenario.code)
              .having(
                (error) => error.isRetryable,
                'isRetryable',
                scenario.retryable,
              ),
        ),
      );
    });
  }

  test('classifies unknown transport failures as retryable I/O', () async {
    final client = _QueueClient([(_) => throw StateError('connection reset')]);
    final loader = FlutterBiblePediaResourceByteLoader(
      _EmptyAssetBundle(),
      httpClient: client,
    );

    await expectLater(
      loader.loadBytes(
        Uri.parse('https://cdn.example.test/image.png'),
        maximumBytes: 8,
      ),
      throwsA(
        isA<BiblePediaResourceException>()
            .having(
              (error) => error.code,
              'code',
              BiblePediaErrorCode.resourceIo,
            )
            .having((error) => error.isRetryable, 'retryable', isTrue),
      ),
    );
  });
}

http.StreamedResponse _response(
  int statusCode, {
  Map<String, String> headers = const {},
  List<List<int>> chunks = const [],
}) => http.StreamedResponse(
  Stream<List<int>>.fromIterable(chunks),
  statusCode,
  headers: headers,
);

final class _QueueClient extends http.BaseClient {
  _QueueClient(Iterable<http.StreamedResponse Function(http.BaseRequest)> send)
    : _send = Queue.of(send);

  final Queue<http.StreamedResponse Function(http.BaseRequest)> _send;
  final List<Uri> requestedUris = [];
  int closeCount = 0;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    requestedUris.add(request.url);
    if (_send.isEmpty) throw StateError('Unexpected request ${request.url}');
    return _send.removeFirst()(request);
  }

  @override
  void close() {
    closeCount++;
  }
}

final class _EmptyAssetBundle extends AssetBundle {
  @override
  Future<ByteData> load(String key) =>
      Future.error(StateError('Unexpected asset load: $key'));
}
