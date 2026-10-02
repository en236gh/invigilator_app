import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../application/offline_controller.dart';

/// Keeps dismissal local to the dashboard and to one download attempt.
class DashboardDownloadOverlay extends ConsumerStatefulWidget {
  const DashboardDownloadOverlay({super.key});

  @override
  ConsumerState<DashboardDownloadOverlay> createState() =>
      _DashboardDownloadOverlayState();
}

class _DashboardDownloadOverlayState
    extends ConsumerState<DashboardDownloadOverlay> {
  int? _dismissedAttempt;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(offlineProvider);
    final failed = !state.downloading && state.downloadError != null;
    if (state.downloadServerUnreachable ||
        _dismissedAttempt == state.downloadAttemptId ||
        (!failed && (!state.downloading || state.downloadProgress <= 0))) {
      return const SizedBox.shrink();
    }
    return OfflineDownloadPopup(
      progress: state.downloadProgress,
      failed: failed,
      onRetry: state.download,
      onClose: () =>
          setState(() => _dismissedAttempt = state.downloadAttemptId),
    );
  }
}

/// Compact dashboard overlay; progress comes from download and local storage.
class OfflineDownloadPopup extends StatefulWidget {
  const OfflineDownloadPopup({
    super.key,
    required this.progress,
    this.failed = false,
    this.title = 'Downloading offline data',
    this.showPercentage = false,
    this.onRetry,
    this.onClose,
  });

  final double progress;
  final bool failed;
  final String title;
  final bool showPercentage;
  final VoidCallback? onRetry;
  final VoidCallback? onClose;

  @override
  State<OfflineDownloadPopup> createState() => _OfflineDownloadPopupState();
}

class _OfflineDownloadPopupState extends State<OfflineDownloadPopup>
    with SingleTickerProviderStateMixin {
  late final AnimationController _motion = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (widget.failed || MediaQuery.disableAnimationsOf(context)) {
      _motion.stop();
    } else {
      _motion.repeat();
    }
  }

  @override
  void didUpdateWidget(covariant OfflineDownloadPopup oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.failed || MediaQuery.disableAnimationsOf(context)) {
      _motion.stop();
    } else if (!_motion.isAnimating) {
      _motion.repeat();
    }
  }

  @override
  void dispose() {
    _motion.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final progress = widget.progress.clamp(0.0, 1.0);
    return PopScope(
      canPop: false,
      child: Stack(
        children: [
          const Positioned.fill(
            child: ModalBarrier(dismissible: false, color: Color(0x33000000)),
          ),
          Center(
            child: Semantics(
              scopesRoute: true,
              explicitChildNodes: true,
              namesRoute: true,
              label: widget.failed ? 'Download failed' : widget.title,
              child: Container(
                width: 300,
                margin: const EdgeInsets.all(24),
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.black12),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 32,
                      offset: Offset(0, 12),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      widget.failed ? 'Download failed' : widget.title,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.black,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        decoration: TextDecoration.none,
                      ),
                    ),
                    const SizedBox(height: 20),
                    if (widget.failed)
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: widget.onClose,
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.black,
                                side: const BorderSide(color: Colors.black),
                              ),
                              child: const Text('Close'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: FilledButton(
                              onPressed: widget.onRetry,
                              style: FilledButton.styleFrom(
                                backgroundColor: Colors.black,
                                foregroundColor: Colors.white,
                              ),
                              child: const Text('Retry'),
                            ),
                          ),
                        ],
                      )
                    else
                      Semantics(
                        label: '${widget.title} progress',
                        value: '${(progress * 100).floor()}%',
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: SizedBox(
                            height: 12,
                            width: double.infinity,
                            child: ColoredBox(
                              color: const Color(0xFFECECEC),
                              child: TweenAnimationBuilder<double>(
                                tween: Tween(end: progress),
                                duration:
                                    MediaQuery.disableAnimationsOf(context)
                                    ? Duration.zero
                                    : const Duration(milliseconds: 250),
                                builder: (context, fill, _) => Align(
                                  alignment: Alignment.centerLeft,
                                  child: FractionallySizedBox(
                                    widthFactor: fill,
                                    heightFactor: 1,
                                    child: AnimatedBuilder(
                                      animation: _motion,
                                      builder: (context, _) => CustomPaint(
                                        painter: _MovingBarsPainter(
                                          _motion.value,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    if (!widget.failed && widget.showPercentage) ...[
                      const SizedBox(height: 12),
                      Text(
                        '${(progress * 100).floor()}%',
                        style: const TextStyle(
                          color: Colors.black,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          decoration: TextDecoration.none,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MovingBarsPainter extends CustomPainter {
  const _MovingBarsPainter(this.phase);
  final double phase;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.clipRect(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, Paint()..color = Colors.black);
    final stripe = Paint()
      ..color = const Color(0x55FFFFFF)
      ..strokeWidth = 4;
    for (double x = -24 + phase * 20; x < size.width + 24; x += 20) {
      canvas.drawLine(Offset(x, size.height), Offset(x + 8, 0), stripe);
    }
  }

  @override
  bool shouldRepaint(_MovingBarsPainter oldDelegate) =>
      oldDelegate.phase != phase;
}
