import 'package:flutter/material.dart';

/// Curved bottom section with purple background for tagline/branding
class CurvedBottom extends StatelessWidget {
  final String mainText;
  final String subText;
  final double height;

  const CurvedBottom({
    super.key,
    required this.mainText,
    required this.subText,
    this.height = 160,
  });

  @override
  Widget build(BuildContext context) {
    return ClipPath(
      clipper: _CurvedTopClipper(),
      child: Container(
        height: height,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF8B5CF6), Color(0xFF7C3AED)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                mainText,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                subText,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.9),
                  fontSize: 20,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.5,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CurvedTopClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    
    // Start from top-left
    path.lineTo(0, 40);
    
    // Create a smooth curve at the top
    path.quadraticBezierTo(
      size.width / 2, // control point x
      0, // control point y
      size.width, // end point x
      40, // end point y
    );
    
    // Right side
    path.lineTo(size.width, size.height);
    
    // Bottom
    path.lineTo(0, size.height);
    
    // Close path
    path.close();
    
    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}
