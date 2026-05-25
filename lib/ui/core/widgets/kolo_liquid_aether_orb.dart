import 'dart:math' as math;

import 'package:flutter/material.dart';

class KoloLiquidAetherOrb extends StatefulWidget {
  const KoloLiquidAetherOrb({super.key, this.size = 58});

  final double size;

  @override
  State<KoloLiquidAetherOrb> createState() => _KoloLiquidAetherOrbState();
}

class _KoloLiquidAetherOrbState extends State<KoloLiquidAetherOrb>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 3600),
  )..forward();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: widget.size,
      width: widget.size,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Color(0x557C3AED),
            blurRadius: 24,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: ClipOval(
        child: AnimatedBuilder(
          key: const Key('kolo_liquid_aether_animation'),
          animation: _controller,
          builder: (context, _) {
            return CustomPaint(
              painter: _LiquidAetherPainter(
                phase: _controller.value * math.pi * 2,
              ),
              child: const SizedBox.expand(),
            );
          },
        ),
      ),
    );
  }
}

class _LiquidAetherPainter extends CustomPainter {
  const _LiquidAetherPainter({required this.phase});

  final double phase;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final center = Offset(
      size.width * (0.58 + math.sin(phase) * 0.03),
      size.height * (0.48 + math.cos(phase) * 0.025),
    );
    final radius = size.shortestSide / 2;

    final base = Paint()
      ..shader = RadialGradient(
        center: Alignment(
          0.28 + math.sin(phase * 0.7) * 0.08,
          -0.32 + math.cos(phase * 0.7) * 0.05,
        ),
        radius: 0.92,
        colors: const [
          Color(0xFF111827),
          Color(0xFF111827),
          Color(0xFF3347FF),
          Color(0xFF7C3AED),
          Color(0xFF050816),
        ],
        stops: const [0, 0.35, 0.62, 0.78, 1],
      ).createShader(rect);
    canvas.drawCircle(Offset(size.width / 2, size.height / 2), radius, base);

    final liquid = Path()..moveTo(0, size.height * 0.66);
    for (var x = 0.0; x <= size.width; x += 4) {
      final y =
          size.height * 0.66 +
          math.sin((x / size.width * math.pi * 2.2) + phase + 0.6) * 5;
      liquid.lineTo(x, y);
    }
    liquid
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();

    canvas.drawPath(
      liquid,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF38BDF8), Color(0xFF7C3AED), Color(0xFF020617)],
        ).createShader(rect),
    );

    final glint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.42, -0.44),
        radius: 0.35,
        colors: [
          Colors.white.withValues(alpha: 0.65),
          Colors.white.withValues(alpha: 0),
        ],
      ).createShader(rect);
    canvas.drawCircle(center.translate(-18, -16), 17, glint);

    canvas.drawCircle(
      Offset(size.width / 2, size.height / 2),
      radius - 1,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = Colors.white.withValues(alpha: 0.22),
    );
  }

  @override
  bool shouldRepaint(covariant _LiquidAetherPainter oldDelegate) {
    return oldDelegate.phase != phase;
  }
}
