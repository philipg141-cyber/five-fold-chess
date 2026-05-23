import 'package:flutter/material.dart';

/// Atmospheric chess-piece photography behind a tinted overlay. Use for
/// menu screens (home, variant picker, settings, account, lobby) so the
/// UI floats over a moody chess scene without losing legibility.
///
/// The overlay is a navy gradient — top is more transparent (so the photo
/// shows through behind the AppBar) and bottom is darker (so the ad
/// banner area stays readable). Tune [topAlpha] and [bottomAlpha] to
/// taste.
class ChessBackground extends StatelessWidget {
  final String imageAsset;
  final Widget child;

  /// 0.0 = no tint at top of screen; 1.0 = solid navy.
  final double topAlpha;

  /// 0.0 = no tint at bottom; 1.0 = solid navy. Usually higher than top
  /// so buttons and ad banners stay legible.
  final double bottomAlpha;

  const ChessBackground({
    super.key,
    required this.imageAsset,
    required this.child,
    this.topAlpha = 0.55,
    this.bottomAlpha = 0.85,
  });

  @override
  Widget build(BuildContext context) {
    const navy = Color(0xFF1F3864); // app theme seed colour
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.asset(
          imageAsset,
          fit: BoxFit.cover,
          alignment: Alignment.center,
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                navy.withOpacity(topAlpha),
                navy.withOpacity(bottomAlpha),
              ],
            ),
          ),
        ),
        child,
      ],
    );
  }
}
