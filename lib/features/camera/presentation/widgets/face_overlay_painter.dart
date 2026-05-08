import 'package:flutter/material.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:aurafarm/core/theme/app_colors.dart';

class FaceOverlayPainter extends CustomPainter {
  final List<Face> faces;
  final Size imageSize;
  final bool isFrontCamera;
  final String? recognizedName;

  FaceOverlayPainter({
    required this.faces,
    required this.imageSize,
    required this.isFrontCamera,
    this.recognizedName,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final scaleX = size.width / imageSize.width;
    final scaleY = size.height / imageSize.height;

    for (final face in faces) {
      final rect = face.boundingBox;
      final scaled = Rect.fromLTRB(
        isFrontCamera ? size.width - rect.right * scaleX : rect.left * scaleX,
        rect.top * scaleY,
        isFrontCamera ? size.width - rect.left * scaleX : rect.right * scaleX,
        rect.bottom * scaleY,
      );

      final isRecognized = recognizedName != null;
      final color = isRecognized ? AppColors.orange : Colors.white.withValues(alpha: 0.6);

      // Corner brackets instead of full rect
      final paint = Paint()
        ..color = color
        ..strokeWidth = isRecognized ? 3 : 2
        ..style = PaintingStyle.stroke;

      final cornerLen = scaled.width * 0.2;

      // Top-left
      canvas.drawLine(scaled.topLeft, scaled.topLeft + Offset(cornerLen, 0), paint);
      canvas.drawLine(scaled.topLeft, scaled.topLeft + Offset(0, cornerLen), paint);
      // Top-right
      canvas.drawLine(scaled.topRight, scaled.topRight + Offset(-cornerLen, 0), paint);
      canvas.drawLine(scaled.topRight, scaled.topRight + Offset(0, cornerLen), paint);
      // Bottom-left
      canvas.drawLine(scaled.bottomLeft, scaled.bottomLeft + Offset(cornerLen, 0), paint);
      canvas.drawLine(scaled.bottomLeft, scaled.bottomLeft + Offset(0, -cornerLen), paint);
      // Bottom-right
      canvas.drawLine(scaled.bottomRight, scaled.bottomRight + Offset(-cornerLen, 0), paint);
      canvas.drawLine(scaled.bottomRight, scaled.bottomRight + Offset(0, -cornerLen), paint);

      // Glow effect when recognized
      if (isRecognized) {
        final glowPaint = Paint()
          ..color = AppColors.orangeGlow
          ..strokeWidth = 8
          ..style = PaintingStyle.stroke;
        canvas.drawRRect(
          RRect.fromRectAndRadius(scaled, const Radius.circular(8)),
          glowPaint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(FaceOverlayPainter old) =>
      old.faces != faces || old.recognizedName != recognizedName;
}
