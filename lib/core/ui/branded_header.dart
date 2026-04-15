import 'package:flutter/material.dart';

import 'app_brand.dart';

/// Clean branded header for auth and app lock screens.
class BrandedHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final double height;

  const BrandedHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.height = 200,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: <Color>[
            Colors.white,
            AppBrand.surface,
            AppBrand.primary.withValues(alpha: 0.08),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppBrand.primary.withValues(alpha: 0.12)),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: AppBrand.primary.withValues(alpha: 0.10),
            blurRadius: 28,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Stack(
        children: <Widget>[
          Positioned(
            top: -28,
            right: -24,
            child: Container(
              width: 118,
              height: 118,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppBrand.accent.withValues(alpha: 0.08),
              ),
            ),
          ),
          Positioned(
            bottom: -36,
            left: -18,
            child: Container(
              width: 128,
              height: 128,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppBrand.primary.withValues(alpha: 0.08),
              ),
            ),
          ),
          Center(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  const AppLogo(size: 82, borderRadius: 24, padding: 8),
                  const SizedBox(height: 18),
                  Text(
                    title,
                    style: const TextStyle(
                      color: AppBrand.textPrimary,
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.4,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  if (subtitle != null) ...<Widget>[
                    const SizedBox(height: 8),
                    Text(
                      subtitle!,
                      style: const TextStyle(
                        color: AppBrand.textMuted,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
