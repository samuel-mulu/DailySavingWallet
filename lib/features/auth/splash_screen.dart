import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/routing/routes.dart';
import '../../core/ui/app_brand.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _logoScaleAnimation;
  late Animation<double> _titleFadeAnimation;
  late Animation<double> _subtitleFadeAnimation;
  late Animation<double> _orbFloatAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1900),
    );

    _logoScaleAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutBack));

    _titleFadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.28, 0.9, curve: Curves.easeOut),
      ),
    );

    _subtitleFadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.55, 1.0, curve: Curves.easeOut),
      ),
    );

    _orbFloatAnimation = Tween<double>(begin: -14, end: 14).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOutSine),
    );

    _controller.forward();

    Timer(const Duration(milliseconds: 2300), () {
      if (mounted) {
        AppRoutes.goToAuthGate(context);
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const primaryPurple = Color(0xFF8B5CF6);
    const deepPurple = Color(0xFF5B21B6);
    const mintGreen = Color(0xFF10B981);
    const skyBlue = Color(0xFF0EA5E9);

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [deepPurple, primaryPurple],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Stack(
          children: [
            AnimatedBuilder(
              animation: _orbFloatAnimation,
              builder: (context, _) => Positioned(
                top: 100 + _orbFloatAnimation.value,
                left: 40,
                child: Container(
                  width: 74,
                  height: 74,
                  decoration: BoxDecoration(
                    color: skyBlue.withValues(alpha: 0.22),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),
            AnimatedBuilder(
              animation: _orbFloatAnimation,
              builder: (context, _) => Positioned(
                right: 48,
                bottom: 180 - _orbFloatAnimation.value,
                child: Container(
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(
                    color: mintGreen.withValues(alpha: 0.22),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ScaleTransition(
                    scale: _logoScaleAnimation,
                    child: Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.16),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.34),
                        ),
                      ),
                      child: const AppLogo(
                        size: 88,
                        borderRadius: 24,
                        padding: 10,
                        showShadow: false,
                        backgroundColor: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  FadeTransition(
                    opacity: _titleFadeAnimation,
                    child: const Text(
                      AppBrand.name,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 27,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  FadeTransition(
                    opacity: _subtitleFadeAnimation,
                    child: const Text(
                      'Secure daily savings',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
