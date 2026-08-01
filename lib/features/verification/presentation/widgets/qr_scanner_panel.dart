import 'package:flutter/material.dart';
import 'package:invigilator_app/app/constants/app_colors.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

/// Camera preview for scanning examination-pass QR codes.
class QrScannerPanel extends StatelessWidget {
  const QrScannerPanel({
    super.key,
    required this.controller,
    required this.onDetect,
    required this.isPaused,
  });

  final MobileScannerController controller;
  final void Function(BarcodeCapture capture) onDetect;
  final bool isPaused;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: AspectRatio(
            aspectRatio: 4 / 3,
            child: Stack(
              fit: StackFit.expand,
              children: [
                MobileScanner(
                  controller: controller,
                  onDetect: onDetect,
                ),
                IgnorePointer(
                  child: CustomPaint(
                    painter: _ScanFramePainter(),
                  ),
                ),
                if (isPaused)
                  ColoredBox(
                    color: AppColors.ink.withValues(alpha: 0.55),
                    child: const Center(
                      child: Text(
                        'QR captured',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        const Text(
          'Align the examination pass QR within the frame. Scanning pauses after a successful read.',
          style: TextStyle(fontSize: 13, color: AppColors.muted),
        ),
      ],
    );
  }
}

class _ScanFramePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final frameSize = Size(size.width * 0.62, size.height * 0.62);
    final left = (size.width - frameSize.width) / 2;
    final top = (size.height - frameSize.height) / 2;
    final rect = Rect.fromLTWH(left, top, frameSize.width, frameSize.height);

    final overlayPaint = Paint()..color = Colors.black.withValues(alpha: 0.28);
    final path = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
      ..addRRect(RRect.fromRectAndRadius(rect, const Radius.circular(12)))
      ..fillType = PathFillType.evenOdd;
    canvas.drawPath(path, overlayPaint);

    final borderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(12)),
      borderPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
