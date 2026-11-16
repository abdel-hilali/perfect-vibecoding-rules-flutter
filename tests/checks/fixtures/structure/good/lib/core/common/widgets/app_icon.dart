import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

// The widget kit may draw raw icons: every page goes through AppIcon (F10).
class AppIcon extends StatelessWidget {
  const AppIcon(this.icon, {super.key, this.size = 24});

  final IconData icon;
  final double size;

  @override
  Widget build(BuildContext context) => Icon(icon, size: size);
}

class AppSvgIcon extends StatelessWidget {
  const AppSvgIcon(this.asset, {super.key});

  final String asset;

  @override
  Widget build(BuildContext context) => SvgPicture.asset(asset, width: 24, height: 24);
}

const fallbackIcon = Icon(Icons.circle);
