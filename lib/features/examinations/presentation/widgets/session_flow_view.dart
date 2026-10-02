import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../app/constants/app_typography.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_error_banner.dart';
import '../../application/session_flow_controller.dart';

class SessionFlowView extends StatefulWidget {
  const SessionFlowView({
    super.key,
    required this.controller,
    required this.onFinished,
  });
  final SessionFlowController controller;
  final VoidCallback onFinished;

  @override
  State<SessionFlowView> createState() => _SessionFlowViewState();
}

class _SessionFlowViewState extends State<SessionFlowView> {
  late final TextEditingController _count = TextEditingController(
    text: widget.controller.flow!.draft,
  );
  Timer? _timer;
  Timer? _thanksTimer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && widget.controller.flow?.step == SessionStep.running) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _thanksTimer?.cancel();
    _count.dispose();
    super.dispose();
  }

  Future<void> _finishThanks() async {
    final controller = widget.controller;
    final finished = widget.onFinished;
    await controller.dismissThanks();
    if (controller.flow == null) finished();
  }

  String _elapsed(DateTime startedAt) {
    final seconds = DateTime.now().toUtc().difference(startedAt).inSeconds;
    final safe = seconds < 0 ? 0 : seconds;
    String two(int value) => value.toString().padLeft(2, '0');
    return '${two(safe ~/ 3600)}:${two(safe ~/ 60 % 60)}:${two(safe % 60)}';
  }

  @override
  Widget build(BuildContext context) => Router.maybeOf(context) == null
      ? _buildContent(context)
      : BackButtonListener(
          onBackButtonPressed: () async {
            final controller = widget.controller;
            if (controller.flow?.step != SessionStep.scripts) return false;
            await controller.returnToRunning();
            return true;
          },
          child: _buildContent(context),
        );

  Widget _buildContent(BuildContext context) {
    final controller = widget.controller;
    final flow = controller.flow!;
    if (flow.step == SessionStep.thanks && _thanksTimer == null) {
      _thanksTimer = Timer(const Duration(seconds: 4), _finishThanks);
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 440),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (flow.step == SessionStep.running) ...[
                        const Text(
                          'Exam in progress',
                          textAlign: TextAlign.center,
                          style: AppTypography.bodyStrong,
                        ),
                        const SizedBox(height: 24),
                        Semantics(
                          label: 'Elapsed exam time',
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              _elapsed(flow.startedAt),
                              style: const TextStyle(
                                fontSize: 64,
                                fontWeight: FontWeight.w600,
                                color: Colors.black,
                                fontFeatures: [FontFeature.tabularFigures()],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 32),
                        AppButton(
                          label: 'End session',
                          loading: controller.busy,
                          onPressed: controller.requestScripts,
                        ),
                      ] else if (flow.step == SessionStep.scripts) ...[
                        const Text(
                          'Scripts collected',
                          textAlign: TextAlign.center,
                          style: AppTypography.sectionHeading,
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Enter the number of scripts collected to finish this exam session.',
                          textAlign: TextAlign.center,
                          style: AppTypography.description,
                        ),
                        const SizedBox(height: 24),
                        TextField(
                          controller: _count,
                          enabled: !controller.busy,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          onChanged: (value) =>
                              unawaited(controller.saveDraft(value)),
                          decoration: const InputDecoration(
                            labelText: 'Number of scripts collected',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 24),
                        AppButton(
                          label: 'Save scripts and end session',
                          loading: controller.busy,
                          onPressed: () => controller.finish(_count.text),
                        ),
                      ] else if (flow.step == SessionStep.thanks) ...[
                        const Icon(
                          Icons.check_circle_outline,
                          size: 56,
                          color: Colors.black,
                        ),
                        const SizedBox(height: 24),
                        const Text(
                          'Thank you!',
                          textAlign: TextAlign.center,
                          style: AppTypography.sectionHeading,
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Your scripts count is saved and the exam session has ended.',
                          textAlign: TextAlign.center,
                          style: AppTypography.description,
                        ),
                        const SizedBox(height: 24),
                        AppButton(
                          label: 'Back to dashboard',
                          loading: controller.busy,
                          onPressed: _finishThanks,
                        ),
                      ] else ...[
                        Text(
                          flow.step == SessionStep.starting
                              ? 'Confirm session start'
                              : 'Finish ending session',
                          textAlign: TextAlign.center,
                          style: AppTypography.sectionHeading,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          flow.step == SessionStep.starting
                              ? 'Your session was interrupted. Retry to confirm its status and resume the timer.'
                              : 'Your scripts count is saved. Retry to confirm the exam has ended.',
                          textAlign: TextAlign.center,
                          style: AppTypography.description,
                        ),
                        const SizedBox(height: 24),
                        AppButton(
                          label: 'Retry',
                          loading: controller.busy,
                          onPressed: flow.step == SessionStep.starting
                              ? controller.retryStart
                              : controller.retryEnd,
                        ),
                      ],
                      if (controller.error != null) ...[
                        const SizedBox(height: 16),
                        AppErrorBanner(message: controller.error!),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
