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

## Creating a Release

Pushing a semantic version tag in the form `Release-x.x.x` starts the GitHub
Actions release workflow. For example:

```bash
git tag Release-1.2.3
git push origin Release-1.2.3
```

After analysis and tests pass, GitHub builds and publishes versioned artifacts
for Windows x64, Linux x64, macOS Intel, macOS Apple Silicon, Android, and web.
The release also includes a `SHA256SUMS.txt` file. Windows and Linux releases
contain their complete runtime bundles; their executable files cannot be
distributed by themselves.

The macOS artifacts are not Developer ID signed or notarized. Android currently
uses the debug signing key configured for the release build. Configure platform
signing before distributing either build through an app store. iOS is not built
because an installable iOS release requires Apple signing credentials and a
provisioning profile.

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
