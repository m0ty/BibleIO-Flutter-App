import 'package:bible_pedia_dart/bible_pedia.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bible/services/bible_pedia_resource_loader.dart';

/// Renders an encyclopedia image only after package-level policy/integrity
/// validation has completed.
class BiblePediaImageFigure extends StatefulWidget {
  const BiblePediaImageFigure({
    super.key,
    required this.image,
    required this.artifact,
    this.maxInlineImageBytes = defaultMaxInlineImageBytes,
    this.resourceLoader,
    this.verifiedByteCache,
  }) : assert(maxInlineImageBytes > 0);

  static const int defaultMaxInlineImageBytes = 5 * 1024 * 1024;

  final EncyclopediaImage image;
  final BiblePediaArtifact artifact;
  final int maxInlineImageBytes;

  /// Optional transport adapter, primarily for downloaded stores and tests.
  final BiblePediaResourceByteLoader? resourceLoader;

  /// Optional verified cache. The app-wide cache is used when omitted.
  final BiblePediaVerifiedByteCache? verifiedByteCache;

  @override
  State<BiblePediaImageFigure> createState() => _BiblePediaImageFigureState();
}

class _BiblePediaImageFigureState extends State<BiblePediaImageFigure> {
  AssetBundle? _inheritedAssetBundle;
  Future<Uint8List>? _bytes;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final inherited = DefaultAssetBundle.of(context);
    if (_bytes == null ||
        (widget.resourceLoader == null &&
            !identical(_inheritedAssetBundle, inherited))) {
      _inheritedAssetBundle = inherited;
      _beginLoad();
    }
  }

  @override
  void didUpdateWidget(covariant BiblePediaImageFigure oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.image != widget.image ||
        !identical(oldWidget.artifact, widget.artifact) ||
        oldWidget.maxInlineImageBytes != widget.maxInlineImageBytes ||
        !identical(oldWidget.resourceLoader, widget.resourceLoader) ||
        !identical(oldWidget.verifiedByteCache, widget.verifiedByteCache)) {
      _beginLoad();
    }
  }

  void _beginLoad() {
    final loader =
        widget.resourceLoader ??
        FlutterBiblePediaResourceByteLoader(_inheritedAssetBundle!);
    _bytes = widget.artifact.loadVerifiedImageBytes(
      widget.image,
      loader: loader,
      cache: widget.verifiedByteCache ?? biblePediaVerifiedImageCache,
      policy: BiblePediaResourcePolicy(
        maximumBytes: widget.maxInlineImageBytes,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final attribution = <String>[
      if (widget.image.credit case final credit?) 'Credit: $credit',
      if (widget.image.license case final license?) 'License: $license',
    ].join(' \u2022 ');

    Widget media = ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: ColoredBox(
        color: colors.surfaceContainerHighest,
        child: FutureBuilder<Uint8List>(
          future: _bytes,
          builder: (context, snapshot) {
            if (snapshot.hasData) {
              return Image.memory(
                snapshot.requireData,
                key: const Key('bible_pedia_image_media'),
                width: double.infinity,
                fit: BoxFit.contain,
                semanticLabel: _semanticLabel,
                excludeFromSemantics: widget.image.altText.isEmpty,
                errorBuilder: _buildLoadError,
              );
            }
            if (snapshot.hasError) {
              return _buildUnavailable(_messageFor(snapshot.error!));
            }
            return const SizedBox(
              key: Key('bible_pedia_image_loading'),
              height: 152,
              child: Center(child: CircularProgressIndicator()),
            );
          },
        ),
      ),
    );
    final declaredRatio = widget.image.aspectRatio;
    if (declaredRatio != null) {
      media = AspectRatio(
        aspectRatio: declaredRatio.clamp(0.2, 5.0).toDouble(),
        child: media,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        media,
        if (widget.image.caption case final caption?) ...[
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

  String _messageFor(Object error) {
    final source = widget.image.imageSource;
    if (error is BiblePediaResourceException) {
      if (error.code == BiblePediaErrorCode.resourceTooLarge &&
          source is DataImageSource) {
        return 'This inline image is too large to display.';
      }
      if (error.code == BiblePediaErrorCode.resourcePolicy &&
          source is RemoteImageSource) {
        return 'Only secure remote images can be displayed.';
      }
      if (error.code == BiblePediaErrorCode.resourceNotFound &&
          source is LocalImageSource &&
          error.uri == null) {
        return 'This image is not declared by the loaded Bible Pedia artifact.';
      }
    }
    return 'Image unavailable.';
  }

  Widget _buildLoadError(
    BuildContext context,
    Object error,
    StackTrace? stackTrace,
  ) => _buildUnavailable('Image unavailable.');

  Widget _buildUnavailable(String message) => Semantics(
    label: widget.image.altText.isEmpty
        ? message
        : '${widget.image.altText}. $message',
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

  String? get _semanticLabel =>
      widget.image.altText.isEmpty ? null : widget.image.altText;
}
