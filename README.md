# BibleIO Reader

BibleIO Reader is an offline, multilingual Flutter Bible app powered by the
[`bible_io`](https://pub.dev/packages/bible_io) package. It combines a focused
reading experience with fast passage navigation, advanced search, responsive
layouts, and locally bundled translations.

## Try It Online

**[Open BibleIO Reader](https://m0ty.github.io/BibleIO-Flutter-App/)** in your
browser—no installation required.

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

### Run the web app locally

First, confirm that Flutter can see a supported browser:

```bash
flutter devices
```

Then start the development version in Chrome or Edge:

```bash
flutter run -d chrome
# Windows alternative:
flutter run -d edge
```

Flutter opens the app in the selected browser and enables hot reload while the
command is running. If you do not want Flutter to launch a browser, use its web
server device and open the URL printed in the terminal:

```bash
flutter run -d web-server --web-port 8080
```

To test the same optimized output included in a GitHub release, build and serve
it through a local HTTP server:

```bash
flutter build web --release

# Windows (Python launcher)
py -m http.server 8080 --directory build\web

# macOS or Linux
python3 -m http.server 8080 --directory build/web
```

Open <http://localhost:8080> after starting the server. Do not double-click
`build/web/index.html`; Flutter web builds need to be served over HTTP and may
show a blank page when opened directly with a `file://` URL.

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
