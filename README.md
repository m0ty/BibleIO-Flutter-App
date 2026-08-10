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
- Explore Bible Pedia by section, current chapter, and recently opened entries
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

## Bible Pedia Development

The unpublished package is pinned to a full Git commit so clean CI and release
checkouts resolve the same code:

```yaml
bible_pedia_dart:
  git:
    url: https://github.com/m0ty/bible-io-pedia-dart.git
    ref: 181e116cb43b0ad5c3c0c11239899acce955bbcd
```

The Bible Pedia screen loads a `BiblePediaArtifact`, keeping the unified dataset
together with its verified manifest and logical resource root. It uses
Unicode-ranked search, data-defined categories and relationship labels,
canonical legacy-ID redirects, typed incoming/outgoing relationships, rich
image metadata, and explicit editorial coverage. It provides three views:
browse, the currently open chapter, and recently opened entries.

The runtime data remains an app-owned asset. With the updated package checked
out at `../bible-io-pedia-dart`, export and verify it with:

```powershell
.\tool\sync_bible_pedia.ps1
```

The command validates the generated repository, exports a compact bundle, and
checks `assets/bible_pedia/runtime.manifest.json` and its SHA-256 payload hash.
Run it whenever the sibling's `data/` directory changes. To use another data
checkout, pass `-DataPath C:\path\to\data`.

Advance the Git `ref` before syncing data produced by newer package code. The
code revision and runtime data should be reviewed together. Local encyclopedia
images are copied and hash-verified as part of the runtime export. Because
Flutter asset-directory declarations are not recursive, the sync command also
regenerates the marked Bible Pedia asset list in `pubspec.yaml`; do not edit the
contents between those generated markers by hand. Entry pages resolve local
images through the artifact's resource root rather than a widget-level asset
constant. Flutter supplies only the asset/HTTPS byte transport: the package
verifies manifest hashes, HTTPS credentials policy, MIME allow-lists, and
payload limits before `Image.memory` receives any bytes. Bounded
`data:image/*` sources pass through the same verifier, and verified copies may
be reused by the app cache. Captions, credits, and licenses remain available
alongside the media.

Remote image responses are consumed as bounded streams. On IO-backed
platforms, automatic redirects are disabled and each redirect target is
revalidated as credential-free HTTPS. Browser transports cannot expose manual
redirect responses, so Flutter Web fails closed on redirected images; direct
cross-origin image URLs must also permit CORS. Declared and observed byte
counts are capped before decoding on every platform.

The app loader delegates strict manifest/bundle decoding to
`BiblePediaArtifactCodec` and uses Flutter `compute` through its async delegate,
keeping eager decode and index construction off the UI isolate.

Descriptions are parsed by the package into a platform-neutral block/inline
document tree. Flutter renders headings, emphasis, code, quotes, lists, and
typed links from the entry's cached document without maintaining a second
Markdown parser. Canonical `entry://` destinations navigate inside Bible Pedia;
credential-free HTTPS destinations open through the platform URL launcher,
while the package's shared safe-link policy refuses unsafe schemes.

To verify the checked-in artifact without regenerating it:

```powershell
dart run bible_pedia_dart verify --runtime assets/bible_pedia
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
- `lib/pages/bible_pedia_page.dart` - encyclopedia browse, chapter, and recent views
- `lib/pages/bible_pedia_entry_page.dart` - encyclopedia entry details and links
- `lib/pages/search_page.dart` - paginated, highlighted scripture search
- `lib/pages/settings_page.dart` - translation, display, theme, and app settings
- `lib/services/bible_loader.dart` - catalog lookup and background Bible loading
- `lib/services/bible_pedia_loader.dart` - lazy artifact, manifest, and resource-root loading
- `lib/services/bible_pedia_history.dart` - bounded recent-entry persistence
- `lib/models/` - reader-specific value types
- `bible_io_json/` - bundled translation catalog and Bible content
- `assets/bible_pedia/` - synced Bible Pedia runtime bundle
- `test/` - loader, reader, settings, and search coverage

## Bible Data and Licensing

The application source is licensed under the GNU Affero General Public License
v3.0 or later. Bible translations are independent works and retain their own
copyright and licensing terms. See [LICENSE](LICENSE) and the metadata for each
bundled edition.

## Notes

This repository is configured as a private Flutter application and is not
intended for publication as a Dart package.
