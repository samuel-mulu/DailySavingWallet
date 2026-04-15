import 'package:flutter/material.dart';

final class AppBrand {
  AppBrand._();

  static const String name = 'MAHTOT';
  static const String shortName = 'MAHTOT';
  static const String logoAssetPath = 'lib/assets/logo/logo.jpg';
  static const String legacyLogoAssetPath = 'assets/logo/logo.png';

  static const Color primary = Color(0xFF2D6F73);
  static const Color primaryDark = Color(0xFF204F53);
  static const Color accent = Color(0xFFC79A47);
  static const Color surface = Color(0xFFF8F6F1);
  static const Color border = Color(0xFFE5DDD0);
  static const Color textPrimary = Color(0xFF1F2937);
  static const Color textMuted = Color(0xFF64748B);

  static const LinearGradient primaryGradient = LinearGradient(
    colors: <Color>[primary, primaryDark],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

class AppLogo extends StatelessWidget {
  const AppLogo({
    super.key,
    this.size = 56,
    this.borderRadius = 18,
    this.padding = 6,
    this.fit = BoxFit.cover,
    this.backgroundColor = Colors.white,
    this.showShadow = true,
  });

  final double size;
  final double borderRadius;
  final double padding;
  final BoxFit fit;
  final Color backgroundColor;
  final bool showShadow;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      padding: EdgeInsets.all(padding),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(color: AppBrand.border),
        boxShadow: showShadow
            ? <BoxShadow>[
                BoxShadow(
                  color: AppBrand.primary.withValues(alpha: 0.12),
                  blurRadius: 18,
                  offset: const Offset(0, 10),
                ),
              ]
            : const <BoxShadow>[],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius - padding / 2),
        child: Image.asset(
          AppBrand.logoAssetPath,
          fit: fit,
          filterQuality: FilterQuality.high,
          errorBuilder: (context, error, stackTrace) => Image.asset(
            AppBrand.legacyLogoAssetPath,
            fit: fit,
            filterQuality: FilterQuality.high,
            errorBuilder: (context, error, stackTrace) => DecoratedBox(
              decoration: BoxDecoration(
                color: AppBrand.surface,
                borderRadius: BorderRadius.circular(borderRadius - padding / 2),
              ),
              child: const Icon(Icons.savings_outlined, color: AppBrand.primary),
            ),
          ),
        ),
      ),
    );
  }
}
