import 'dart:typed_data';

import 'package:bible_pedia_dart/bible_pedia.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

/// Bridges Flutter asset and HTTPS transports to package-level verification.
final class FlutterBiblePediaResourceByteLoader
    implements BiblePediaResourceByteLoader {
  FlutterBiblePediaResourceByteLoader(
    this.assetBundle, {
    http.Client? httpClient,
    http.Client Function()? httpClientFactory,
    int maximumRedirects = 5,
  }) : maximumRedirects = _requireNonNegativeRedirects(maximumRedirects),
       _httpClient = httpClient,
       _httpClientFactory = httpClientFactory ?? http.Client.new {
    if (httpClient != null && httpClientFactory != null) {
      throw ArgumentError(
        'httpClient and httpClientFactory cannot both be provided',
      );
    }
  }

  final AssetBundle assetBundle;
  final http.Client? _httpClient;
  final http.Client Function() _httpClientFactory;
  final int maximumRedirects;

  @override
  Future<Uint8List> loadBytes(Uri uri, {required int maximumBytes}) async {
    try {
      final ByteData data;
      switch (uri.scheme.toLowerCase()) {
        case 'asset':
          final key = uri.path.startsWith('/')
              ? uri.path.substring(1)
              : uri.path;
          data = await assetBundle.load(key);
        case 'https':
          return await _loadHttps(uri, maximumBytes: maximumBytes);
        default:
          throw BiblePediaResourceException(
            code: BiblePediaErrorCode.resourcePolicy,
            message: 'Flutter cannot load resource scheme "${uri.scheme}"',
            uri: uri,
          );
      }
      if (data.lengthInBytes > maximumBytes) {
        throw BiblePediaResourceException(
          code: BiblePediaErrorCode.resourceTooLarge,
          message:
              'resource "$uri" has ${data.lengthInBytes} bytes; maximum is '
              '$maximumBytes',
          uri: uri,
        );
      }
      return data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
    } on BiblePediaResourceException {
      rethrow;
    } catch (error) {
      throw BiblePediaResourceException(
        code: BiblePediaErrorCode.resourceIo,
        message: 'Flutter could not load resource "$uri"',
        uri: uri,
        cause: error,
        isRetryable: true,
      );
    }
  }

  Future<Uint8List> _loadHttps(
    Uri initialUri, {
    required int maximumBytes,
  }) async {
    final ownsClient = _httpClient == null;
    final client = _httpClient ?? _httpClientFactory();
    final policy = BiblePediaResourcePolicy(maximumBytes: maximumBytes);
    var uri = initialUri;
    var redirectCount = 0;
    try {
      while (true) {
        policy.validateRemoteUri(uri);
        final request = http.Request('GET', uri)..followRedirects = false;
        final response = await client.send(request);

        if (_isRedirect(response.statusCode)) {
          final location = response.headers['location'];
          await _cancelResponse(response);
          if (location == null || location.trim().isEmpty) {
            throw BiblePediaResourceException(
              code: BiblePediaErrorCode.resourcePolicy,
              message: 'HTTPS redirect did not provide a Location header',
              uri: uri,
            );
          }
          if (redirectCount >= maximumRedirects) {
            throw BiblePediaResourceException(
              code: BiblePediaErrorCode.resourcePolicy,
              message: 'HTTPS resource exceeded $maximumRedirects redirects',
              uri: uri,
            );
          }
          late final Uri redirected;
          try {
            redirected = uri.resolve(location);
          } on FormatException catch (error) {
            throw BiblePediaResourceException(
              code: BiblePediaErrorCode.resourcePolicy,
              message: 'HTTPS redirect Location is malformed',
              uri: uri,
              cause: error,
            );
          }
          policy.validateRemoteUri(redirected);
          uri = redirected;
          redirectCount++;
          continue;
        }

        if (response.statusCode < 200 || response.statusCode >= 300) {
          await _cancelResponse(response);
          final statusCode = response.statusCode;
          final isMissing = statusCode == 404 || statusCode == 410;
          throw BiblePediaResourceException(
            code: isMissing
                ? BiblePediaErrorCode.resourceNotFound
                : BiblePediaErrorCode.resourceIo,
            message: 'HTTPS resource returned status $statusCode',
            uri: uri,
            isRetryable:
                statusCode == 408 ||
                statusCode == 429 ||
                (statusCode >= 500 && statusCode < 600),
          );
        }

        final declaredLength = response.contentLength;
        if (declaredLength != null && declaredLength > maximumBytes) {
          await _cancelResponse(response);
          throw _tooLarge(uri, declaredLength, maximumBytes);
        }

        final bytes = BytesBuilder(copy: false);
        await for (final chunk in response.stream) {
          final nextLength = bytes.length + chunk.length;
          if (nextLength > maximumBytes) {
            throw _tooLarge(uri, nextLength, maximumBytes);
          }
          bytes.add(chunk);
        }
        return bytes.takeBytes();
      }
    } finally {
      if (ownsClient) client.close();
    }
  }
}

bool _isRedirect(int statusCode) => switch (statusCode) {
  301 || 302 || 303 || 307 || 308 => true,
  _ => false,
};

Future<void> _cancelResponse(http.StreamedResponse response) async {
  final subscription = response.stream.listen((_) {});
  await subscription.cancel();
}

BiblePediaResourceException _tooLarge(
  Uri uri,
  int actualBytes,
  int maximumBytes,
) => BiblePediaResourceException(
  code: BiblePediaErrorCode.resourceTooLarge,
  message:
      'resource "$uri" has at least $actualBytes bytes; maximum is '
      '$maximumBytes',
  uri: uri,
);

int _requireNonNegativeRedirects(int value) {
  if (value < 0) {
    throw ArgumentError.value(
      value,
      'maximumRedirects',
      'must not be negative',
    );
  }
  return value;
}

/// Shared cache contains only bytes that passed package integrity validation.
final biblePediaVerifiedImageCache = BiblePediaMemoryVerifiedByteCache();
