import 'package:flutter/material.dart';

/// Responsive design breakpoints and helper utilities for ShopSilo Partner.
/// Provides smooth adaptive experiences across Mobile, Tablet, Laptop, and Web.
class Responsive {
  static const double mobileBreakpoint = 600;
  static const double tabletBreakpoint = 1024;
  static const double desktopBreakpoint = 1440;

  static bool isMobile(BuildContext context) =>
      MediaQuery.of(context).size.width < mobileBreakpoint;

  static bool isTablet(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    return width >= mobileBreakpoint && width < tabletBreakpoint;
  }

  static bool isDesktop(BuildContext context) =>
      MediaQuery.of(context).size.width >= tabletBreakpoint;

  static bool isWide(BuildContext context) =>
      MediaQuery.of(context).size.width >= 800;

  static double screenWidth(BuildContext context) =>
      MediaQuery.of(context).size.width;

  static double screenHeight(BuildContext context) =>
      MediaQuery.of(context).size.height;

  /// Returns adaptive grid count based on width
  static int gridAxisCount(BuildContext context, {int mobile = 2, int tablet = 3, int desktop = 4}) {
    final w = screenWidth(context);
    if (w >= tabletBreakpoint) return desktop;
    if (w >= mobileBreakpoint) return tablet;
    return mobile;
  }
}

/// A container that centers child and clamps width to [maxWidth],
/// preventing distorted wide screens on Web, Laptop, and large Tablets.
class ResponsiveContainer extends StatelessWidget {
  final Widget child;
  final double maxWidth;
  final EdgeInsetsGeometry? padding;

  const ResponsiveContainer({
    super.key,
    required this.child,
    this.maxWidth = 1200,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    Widget content = ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: child,
    );

    if (padding != null) {
      content = Padding(padding: padding!, child: content);
    }

    return Align(
      alignment: Alignment.topCenter,
      child: content,
    );
  }
}
