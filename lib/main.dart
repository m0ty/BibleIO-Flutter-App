import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';

export 'app.dart' show BibleReaderApp;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SharedPreferences? preferences;
  try {
    preferences = await SharedPreferences.getInstance();
  } on Object {
    // The app can still start with defaults if preference storage is unavailable.
  }
  runApp(BibleReaderApp(initialPreferences: preferences));
}
