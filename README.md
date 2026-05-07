# BibleIO Flutter App

A Flutter Bible reader app that loads multiple Bible translations from local JSON assets and provides search, navigation, and settings support.

## Features

- Browse supported Bible translations by language
- View books, chapters, and verses
- Search text across loaded translations
- Persist user settings with `shared_preferences`
- Local JSON asset support for offline usage

## Supported Languages

The app includes Bible data for these languages:

- Arabic
- Chinese
- English
- Esperanto
- Finnish
- French
- German
- Greek
- Korean
- Portuguese
- Romanian
- Russian
- Spanish
- Vietnamese

## Getting Started

### Prerequisites

- Flutter SDK installed
- A compatible editor such as Visual Studio Code or Android Studio
- Target platform setup for Android, iOS, Windows, Linux, or macOS

### Install dependencies

```bash
flutter pub get
```

### Run the app

```bash
flutter run
```

To target a specific platform, use a device ID or Flutter desktop configuration:

```bash
flutter run -d windows
flutter run -d chrome
```

## Project Structure

- `lib/main.dart` – app entry point
- `lib/pages/` – UI pages for home, chapters, search, verses, and settings
- `lib/services/bible_loader.dart` – Bible asset loading service
- `bible_io_json/` – local Bible translation JSON assets

## Dependencies

- `flutter`
- `cupertino_icons`
- `bible_io`
- `shared_preferences`

## Asset Configuration

Bible JSON assets are declared in `pubspec.yaml` under `flutter.assets` and loaded locally by the app.

## Notes

This repository is configured as a private Flutter app and is not intended for publishing to `pub.dev`.
