import 'package:flutter/material.dart';

class CaptureGuideOverlay extends StatelessWidget {
  final bool faceDetected;
  final int captureStep;
  final String guideText; // kept for API compat, no longer rendered here

  const CaptureGuideOverlay({
    super.key,
    required this.faceDetected,
    required this.captureStep,
    required this.guideText,
  });

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final ovalW = size.width * 0.65;
    final ovalH = ovalW * 1.3;

    return Stack(
      children: [
        // Dark overlay with oval cutout
        CustomPaint(
          size: size,
          painter: _OvalCutoutPainter(ovalW: ovalW, ovalH: ovalH),
        ),
        // Oval border — green when face is in position
        Center(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: ovalW,
            height: ovalH,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(ovalW / 2),
              border: Border.all(
                color: faceDetected ? const Color(0xFF00E676) : Colors.white.withValues(alpha: 0.5),
                width: faceDetected ? 3 : 2,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _OvalCutoutPainter extends CustomPainter {
  final double ovalW;
  final double ovalH;
  const _OvalCutoutPainter({required this.ovalW, required this.ovalH});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.black.withValues(alpha: 0.55);
    final full = Path()..addRect(Rect.fromLTWH(0, 0, size.width, size.height));
    final oval = Path()..addRRect(RRect.fromRectXY(
      Rect.fromCenter(
        center: Offset(size.width / 2, size.height / 2),
        width: ovalW, height: ovalH,
      ),
      ovalW / 2, ovalW / 2,
    ));
    canvas.drawPath(Path.combine(PathOperation.difference, full, oval), paint);
  }

  @override
  bool shouldRepaint(_OvalCutoutPainter old) => old.ovalW != ovalW || old.ovalH != ovalH;
}
