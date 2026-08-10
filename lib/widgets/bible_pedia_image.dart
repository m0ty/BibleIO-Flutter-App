import 'package:bible_pedia_dart/bible_pedia.dart';
import 'package:flutter/material.dart';

/// Root of the verified Bible Pedia runtime artifact in Flutter's asset bundle.
const biblePediaRuntimeAssetRoot = 'assets/bible_pedia';

/// Renders one structured encyclopedia image using its validated source type.
///
/// Local sources are confined to [biblePediaRuntimeAssetRoot], remote sources
/// must use HTTPS without embedded credentials, and inline data is capped to
/// avoid decoding unexpectedly large payloads in memory.
class BiblePediaImageFigure extends StatelessWidget {
  const BiblePediaImageFigure({
    super.key,
    required this.image,
    this.maxInlineImageBytes = defaultMaxInlineImageBytes,
  }) : assert(maxInlineImageBytes > 0);

  static const int defaultMaxInlineImageBytes = 5 * 1024 * 1024;

  final EncyclopediaImage image;
  final int maxInlineImageBytes;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final attribution = <String>[
      if (image.credit case final credit?) 'Credit: $credit',
      if (image.license case final license?) 'License: $license',
    ].join(' \u2022 ');

    Widget media = ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: ColoredBox(
        color: colors.surfaceContainerHighest,
        child: _buildMedia(),
      ),
    );
    final declaredRatio = image.aspectRatio;
    if (declaredRatio != null) {
      media = AspectRatio(
        // Keep valid but extreme authored metadata from collapsing the UI.
        aspectRatio: declaredRatio.clamp(0.2, 5.0).toDouble(),
        child: media,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        media,
        if (image.caption case final caption?) ...[
          const SizedBox(height: 8),
          Text(
            caption,
            key: const Key('bible_pedia_image_caption'),
            style: theme.textTheme.bodyMedium,
          ),
        ],
        if (attribution.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            attribution,
            key: const Key('bible_pedia_image_attribution'),
            style: theme.textTheme.bodySmall?.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildMedia() {
    final source = image.imageSource;
    return switch (source) {
      LocalImageSource() => Image.asset(
        '$biblePediaRuntimeAssetRoot/${source.portablePath}',
        key: const Key('bible_pedia_image_media'),
        width: double.infinity,
        fit: BoxFit.contain,
        semanticLabel: _semanticLabel,
        excludeFromSemantics: image.altText.isEmpty,
        errorBuilder: _buildLoadError,
      ),
      RemoteImageSource() => _buildRemoteImage(source),
      DataImageSource() => _buildDataImage(source),
    };
  }

  Widget _buildRemoteImage(RemoteImageSource source) {
    if (source.uri.scheme.toLowerCase() != 'https' ||
        source.uri.userInfo.isNotEmpty) {
      return _buildUnavailable('Only secure remote images can be displayed.');
    }
    return Image.network(
      source.uri.toString(),
      key: const Key('bible_pedia_image_media'),
      width: double.infinity,
      fit: BoxFit.contain,
      semanticLabel: _semanticLabel,
      excludeFromSemantics: image.altText.isEmpty,
      errorBuilder: _buildLoadError,
    );
  }

  Widget _buildDataImage(DataImageSource source) {
    final bytes = source.data.contentAsBytes();
    if (bytes.length > maxInlineImageBytes) {
      return _buildUnavailable('This inline image is too large to display.');
    }
    return Image.memory(
      bytes,
      key: const Key('bible_pedia_image_media'),
      width: double.infinity,
      fit: BoxFit.contain,
      semanticLabel: _semanticLabel,
      excludeFromSemantics: image.altText.isEmpty,
      errorBuilder: _buildLoadError,
    );
  }

  Widget _buildLoadError(
    BuildContext context,
    Object error,
    StackTrace? stackTrace,
  ) => _buildUnavailable('Image unavailable.');

  Widget _buildUnavailable(String message) => Semantics(
    label: image.altText.isEmpty ? message : '${image.altText}. $message',
    child: SizedBox(
      key: const Key('bible_pedia_image_unavailable'),
      height: 152,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.broken_image_outlined, size: 34),
              const SizedBox(height: 8),
              Text(message, textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    ),
  );

  String? get _semanticLabel => image.altText.isEmpty ? null : image.altText;
}
