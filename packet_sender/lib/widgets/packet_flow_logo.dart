import 'package:flutter/material.dart';

class PacketFlowLogo extends StatelessWidget {
  final double size;
  final bool showGlow;
  final double borderRadius;

  const PacketFlowLogo({
    super.key,
    this.size = 48.0,
    this.showGlow = true,
    this.borderRadius = 12.0,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: showGlow
            ? [
                BoxShadow(
                  color: Colors.cyanAccent.withOpacity(0.35),
                  blurRadius: 10,
                  spreadRadius: 1,
                  offset: const Offset(0, 2),
                ),
                BoxShadow(
                  color: Colors.indigo.withOpacity(0.3),
                  blurRadius: 12,
                  spreadRadius: 2,
                ),
              ]
            : null,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: Image.asset(
          'assets/images/logo.png',
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            // Fallback decorative tech icon if asset loading fails
            return Container(
              color: const Color(0xFF0F172A),
              child: Center(
                child: Icon(
                  Icons.stream,
                  color: Colors.cyanAccent,
                  size: size * 0.6,
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
