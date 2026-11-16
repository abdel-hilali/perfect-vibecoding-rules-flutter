import 'package:kit_app/core/common/widgets/app_icon.dart';
import 'package:kit_app/core/l10n/l10n.dart';
import 'package:kit_app/core/theme/app_colors.dart';
import 'package:kit_app/core/theme/app_icons.dart';
import 'package:kit_app/core/theme/app_radius.dart';
import 'package:material_ui/material_ui.dart';

/// Every remote picture of the app (F15).
///
/// It is decoded at the size it is shown: a 4000 px photo in a 64 dp thumbnail would hold about 64 MB in memory,
/// decoded at 64 dp it holds a few hundred KB. A placeholder shows while it loads, and an error state, never a
/// broken image, when it fails.
class AppImage extends StatelessWidget {
  const AppImage({
    super.key,
    required this.url,
    required this.width,
    required this.height,
    this.fit = BoxFit.cover,
    this.borderRadius = AppRadius.card,
    this.semanticLabel,
  });

  final String url;

  /// Finite sizes only: the decode size comes from them.
  final double width;
  final double height;
  final BoxFit fit;
  final BorderRadius borderRadius;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final pixels = (width * MediaQuery.devicePixelRatioOf(context)).round();
    return ClipRRect(
      borderRadius: borderRadius,
      child: Image.network(
        url,
        width: width,
        height: height,
        fit: fit,
        // Width only: the height follows the picture's own ratio, so nothing is stretched.
        cacheWidth: pixels > 0 ? pixels : null,
        semanticLabel: semanticLabel,
        frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
          return wasSynchronouslyLoaded || frame != null
              ? child
              : _ImageBox(width: width, height: height);
        },
        errorBuilder: (context, error, stackTrace) {
          return _ImageBox(width: width, height: height, broken: true);
        },
      ),
    );
  }
}

class _ImageBox extends StatelessWidget {
  const _ImageBox({
    required this.width,
    required this.height,
    this.broken = false,
  });

  final double width;
  final double height;
  final bool broken;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return SizedBox(
      width: width,
      height: height,
      child: ColoredBox(
        color: colors.primarySoft,
        child: broken
            ? Center(
                child: AppIcon(
                  AppIcons.imageBroken,
                  color: colors.onSurfaceMuted,
                  semanticLabel: context.l10n.commonImageUnavailable,
                ),
              )
            : null,
      ),
    );
  }
}
