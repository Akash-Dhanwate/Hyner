import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/hyner_mark.dart';
import '../../../core/widgets/page_content.dart';
import '../../auth/presentation/session_controller.dart';

class WelcomeScreen extends ConsumerWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final failure = ref.watch(sessionProvider.select((state) => state.failure));
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            padding: const EdgeInsets.all(28),
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: 480,
                  minHeight: (constraints.maxHeight - 56).clamp(
                    0,
                    double.infinity,
                  ),
                ),
                // Minimum height plus spaceBetween anchors the footer without
                // an IntrinsicHeight pre-layout pass or flex in a scroll view.
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const HynerMark(size: 36),
                            const SizedBox(width: 12),
                            Flexible(
                              child: Text(
                                'Hyner',
                                style: theme.textTheme.titleLarge,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 52),
                        AspectRatio(
                          aspectRatio: 1.25,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: scheme.primaryContainer.withValues(
                                alpha: .45,
                              ),
                              borderRadius: BorderRadius.circular(36),
                            ),
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                Positioned.fill(
                                  child: CustomPaint(
                                    painter: _WelcomePattern(
                                      scheme.primary.withValues(alpha: .12),
                                    ),
                                  ),
                                ),
                                const HynerMark(size: 128),
                                Positioned(
                                  bottom: 26,
                                  child: Text(
                                    'BUSINESS, IN ORDER.',
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      letterSpacing: 2.4,
                                      color: scheme.primary,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 36),
                        Text(
                          'Your business.\nA little clearer.',
                          style: theme.textTheme.displaySmall,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'A considered space for the business you’re building.',
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 36),
                        if (failure != null) ...[
                          InlineNotice(failure.displayMessage, isError: true),
                          const SizedBox(height: 20),
                        ],
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        FilledButton(
                          onPressed: () => context.push<void>('/sign-in'),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Flexible(
                                child: Text(
                                  'Get started',
                                  textAlign: TextAlign.center,
                                ),
                              ),
                              SizedBox(width: 12),
                              Icon(Icons.arrow_forward_rounded, size: 20),
                            ],
                          ),
                        ),
                        const SizedBox(height: 18),
                        Text(
                          'One Google account. Your own workspace.',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _WelcomePattern extends CustomPainter {
  _WelcomePattern(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.clipRRect(
      RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(36)),
    );
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    for (final scale in [.62, .86, 1.1]) {
      final rect = Rect.fromCenter(
        center: Offset(size.width / 2, size.height * .46),
        width: size.width * scale,
        height: size.width * scale,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(48)),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _WelcomePattern oldDelegate) =>
      oldDelegate.color != color;
}
