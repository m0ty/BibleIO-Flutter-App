import 'dart:convert';
import 'dart:io';

import 'package:bible_io/bible_io.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

const _bookAbbreviationAliases = {
  'jz': 'jud',
  '1rs': '1kgs',
  '2rs': '2kgs',
  '1cr': '1ch',
  '2cr': '2ch',
  'ag': 'hg',
  'ap': 're',
  'atos': 'act',
  'ct': 'so',
  'ed': 'ezr',
  'ef': 'eph',
  'fm': 'phm',
  'fp': 'ph',
  'hc': 'hk',
  'jÃ³': 'job',
  'jô': 'job',
  'j�': 'job',
  'lc': 'lk',
  'mc': 'mk',
  'mq': 'mi',
  'os': 'ho',
  'pv': 'prv',
  'sf': 'zp',
  'sl': 'ps',
  'tg': 'jm',
};

/// Loads bundled Bible JSON assets with Flutter's UTF-8 asset decoding.
Future<Bible> loadBibleAsset(String assetPath) async {
  final jsonString = await _loadUtf8String(assetPath);
  final normalizedJson = _normalizeBibleJson(jsonString);
  return Bible.fromJson(normalizedJson);
}

Future<String> _loadUtf8String(String assetPath) async {
  try {
    return await rootBundle.loadString(assetPath);
  } on FlutterError {
    if (kIsWeb) {
      rethrow;
    }
    return File(assetPath).readAsString();
  }
}

String _normalizeBibleJson(String jsonString) {
  final data = json.decode(jsonString) as Map<String, dynamic>;
  final books = data['books'] as Map<String, dynamic>?;
  if (books == null) {
    return jsonString;
  }

  var changed = false;
  final normalizedBooks = <String, dynamic>{};
  for (final entry in books.entries) {
    final normalizedKey = _bookAbbreviationAliases[entry.key] ?? entry.key;
    normalizedBooks[normalizedKey] = entry.value;
    if (normalizedKey != entry.key) {
      changed = true;
    }
  }

  if (!changed) {
    return jsonString;
  }

  data['books'] = normalizedBooks;
  return json.encode(data);
}
