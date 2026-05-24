import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:kolo/ui/core/theme/kolo_theme.dart';

class KoloFloatingAssistant extends StatelessWidget {
  const KoloFloatingAssistant({super.key, this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Align(
      key: const Key('kolo_floating_assistant'),
      alignment: Alignment.bottomRight,
      child: Padding(
        padding: const EdgeInsets.only(right: 18, bottom: 108),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Container(
              constraints: const BoxConstraints(maxWidth: 178),
              margin: const EdgeInsets.only(right: 10, bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: KoloColors.surfaceDark.withValues(alpha: 0.92),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(18),
                  topRight: Radius.circular(18),
                  bottomLeft: Radius.circular(18),
                  bottomRight: Radius.circular(5),
                ),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x24000000),
                    blurRadius: 24,
                    offset: Offset(0, 8),
                  ),
                ],
              ),
              child: const Text(
                'Need a quick money check?',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            GestureDetector(
              onTap: onTap,
              child: const _LiquidAetherOrb(),
            ),
          ],
        ),
      ),
    );
  }
}

class _LiquidAetherOrb extends StatelessWidget {
  const _LiquidAetherOrb();

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('kolo_liquid_aether_orb'),
      height: 58,
      width: 58,
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
        child: CustomPaint(
          painter: _LiquidAetherPainter(),
          child: const SizedBox.expand(),
        ),
      ),
    );
  }
}

class _LiquidAetherPainter extends CustomPainter {
  const _LiquidAetherPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final center = Offset(size.width * 0.58, size.height * 0.48);
    final radius = size.shortestSide / 2;

    final base = Paint()
      ..shader = RadialGradient(
        center: const Alignment(0.28, -0.32),
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

    final liquid = Path()
      ..moveTo(0, size.height * 0.66);
    for (var x = 0.0; x <= size.width; x += 4) {
      final y =
          size.height * 0.66 +
          math.sin((x / size.width * math.pi * 2.2) + 0.6) * 5;
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
  bool shouldRepaint(covariant _LiquidAetherPainter oldDelegate) => false;
}
