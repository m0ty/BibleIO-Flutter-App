# BibleIO Reader

BibleIO Reader is an offline, multilingual Flutter Bible app powered by the
[`bible_io`](https://pub.dev/packages/bible_io) package. It combines a focused
reading experience with fast passage navigation, advanced search, responsive
layouts, and locally bundled translations.

## Features

- Read 19 bundled Bible editions across 14 languages without a network connection
- Browse translations by language and retain a separate reading position for each edition
- Jump to multilingual references and passage ranges such as `John 3:16` or `Romans 8:1-4`
- Search with phrase, all-word, or any-word matching, filters, highlighting, and pagination
- Load and prepare large translations in the background with progress feedback
- Use responsive compact and wide layouts with right-to-left scripture support
- Customize text size, verse spacing, and reusable reading color presets
- Select and copy scripture text

## Supported Languages

Arabic, Chinese, English, Esperanto, Finnish, French, German, Greek, Korean,
Portuguese, Romanian, Russian, Spanish, and Vietnamese.

## Getting Started

### Prerequisites

- Flutter SDK
- Platform tooling for the targets you plan to build

### Install dependencies

```bash
flutter pub get
```

### Run the app

```bash
flutter run
```

To choose a target explicitly:

```bash
flutter run -d windows
flutter run -d chrome
```

### Verify changes

```bash
flutter analyze
flutter test
```

## Project Structure

- `lib/main.dart` - application entry point, theme, and color-preset persistence
- `lib/pages/bible_home_page.dart` - responsive reader and Bible navigation
- `lib/pages/search_page.dart` - paginated, highlighted scripture search
- `lib/pages/settings_page.dart` - translation, display, theme, and app settings
- `lib/services/bible_loader.dart` - catalog lookup and background Bible loading
- `lib/models/` - reader-specific value types
- `bible_io_json/` - bundled translation catalog and Bible content
- `test/` - loader, reader, settings, and search coverage

## Bible Data and Licensing

The application source is licensed under the GNU Affero General Public License
v3.0 or later. Bible translations are independent works and retain their own
copyright and licensing terms. See [LICENSE](LICENSE) and the metadata for each
bundled edition.

## Notes

This repository is configured as a private Flutter application and is not
intended for publication as a Dart package.
