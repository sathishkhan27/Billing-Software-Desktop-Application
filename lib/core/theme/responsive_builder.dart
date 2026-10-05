import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// A widget that builds different layouts based on screen width breakpoints.
///
/// Usage:
/// ```dart
/// ResponsiveBuilder(
///   mobile: (ctx) => MobileLayout(),
///   tablet: (ctx) => TabletLayout(),
///   desktop: (ctx) => DesktopLayout(),
/// )
/// ```
/// If [tablet] is omitted, [mobile] is used for tablet screens.
/// If [desktop] is omitted, [tablet] (or [mobile]) is used for desktop screens.
class ResponsiveBuilder extends StatelessWidget {
  final WidgetBuilder mobile;
  final WidgetBuilder? tablet;
  final WidgetBuilder? desktop;

  const ResponsiveBuilder({
    super.key,
    required this.mobile,
    this.tablet,
    this.desktop,
  });

  @override
  Widget build(BuildContext context) {
    if (AppTheme.isDesktop(context)) {
      return (desktop ?? tablet ?? mobile)(context);
    }
    if (AppTheme.isTablet(context)) {
      return (tablet ?? mobile)(context);
    }
    return mobile(context);
  }
}

/// A widget that lays out children in a [Wrap] on mobile and a [Row] on tablet+.
/// Useful for form fields, KPI cards, and action rows.
class ResponsiveRow extends StatelessWidget {
  final List<Widget> children;
  final double spacing;
  final double runSpacing;

  const ResponsiveRow({
    super.key,
    required this.children,
    this.spacing = 16,
    this.runSpacing = 16,
  });

  @override
  Widget build(BuildContext context) {
    if (AppTheme.isMobile(context)) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children
            .map((c) => Padding(
                  padding: EdgeInsets.only(bottom: runSpacing),
                  child: c,
                ))
            .toList(),
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children.asMap().entries.map((e) {
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(
              left: e.key > 0 ? spacing : 0,
            ),
            child: e.value,
          ),
        );
      }).toList(),
    );
  }
}

/// Returns an appropriate horizontal padding based on screen width.
/// Mobile: 12, Tablet: 20, Desktop: 24
double responsivePadding(BuildContext context) {
  if (AppTheme.isMobile(context)) return 12;
  if (AppTheme.isTablet(context)) return 20;
  return 24;
}

/// Returns an appropriate content max-width based on screen width.
double responsiveMaxWidth(BuildContext context) {
  if (AppTheme.isMobile(context)) return double.infinity;
  if (AppTheme.isTablet(context)) return 900;
  return double.infinity;
}
