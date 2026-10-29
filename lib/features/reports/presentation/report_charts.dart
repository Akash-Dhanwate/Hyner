import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../domain/business_report.dart';

const salesChartColor = Color(0xff087e8b);
const expenseChartColor = Color(0xffe58a45);
const dueChartColor = Color(0xffd3a13f);

class ReportLegend extends StatelessWidget {
  const ReportLegend({super.key});

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 18,
    runSpacing: 8,
    children: const [
      _LegendItem(color: salesChartColor, label: 'Sales revenue'),
      _LegendItem(color: expenseChartColor, label: 'Recorded expenses'),
    ],
  );
}

class ActivityBarChart extends StatelessWidget {
  const ActivityBarChart({super.key, required this.report});
  final BusinessReport report;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final activity = _visibleActivity(report.activity);
    final width = math.max(360.0, activity.length * 90.0 + 56);
    final maxValue = activity.fold<BigInt>(BigInt.zero, (current, point) {
      final revenue = point.revenueMinor.abs();
      final expense = point.expenseMinor.abs();
      final pointMax = revenue > expense ? revenue : expense;
      return pointMax > current ? pointMax : current;
    });
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Revenue and expenses', style: theme.textTheme.titleMedium),
          const SizedBox(height: 6),
          Text(
            maxValue == BigInt.zero
                ? 'No sales or purchases in this period'
                : 'Maximum bar: ${formatBigMoney(maxValue, report.currency)}',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          const ReportLegend(),
          const SizedBox(height: 14),
          if (activity.isEmpty)
            const SizedBox(height: 100)
          else
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SizedBox(
                width: width,
                height: 208,
                child: CustomPaint(
                  painter: _ActivityChartPainter(
                    activity: activity,
                    maxValue: maxValue,
                    lineColor: theme.colorScheme.outlineVariant,
                    labelColor: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

List<ReportActivityPoint> _visibleActivity(List<ReportActivityPoint> activity) {
  if (activity.length <= 8) return activity;
  final grouped = <ReportActivityPoint>[];
  for (var start = 0; start < activity.length; start += 7) {
    final points = activity.skip(start).take(7).toList();
    grouped.add(
      ReportActivityPoint(
        periodStart: points.first.periodStart,
        label: 'Week ${grouped.length + 1}',
        revenueMinor: points.fold(
          BigInt.zero,
          (sum, point) => sum + point.revenueMinor,
        ),
        expenseMinor: points.fold(
          BigInt.zero,
          (sum, point) => sum + point.expenseMinor,
        ),
      ),
    );
  }
  return grouped;
}

class PaymentDonutChart extends StatelessWidget {
  const PaymentDonutChart({super.key, required this.report});
  final BusinessReport report;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 104,
            height: 104,
            child: CustomPaint(
              painter: _PaymentDonutPainter(
                received: report.paidRevenueMinor,
                due: report.unpaidRevenueMinor,
                track: theme.colorScheme.surfaceContainerHighest,
              ),
            ),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Payment status', style: theme.textTheme.titleMedium),
                const SizedBox(height: 10),
                _LegendItem(
                  color: salesChartColor,
                  label:
                      'Received · ${formatBigMoney(report.paidRevenueMinor, report.currency)}',
                ),
                const SizedBox(height: 8),
                _LegendItem(
                  color: dueChartColor,
                  label:
                      'Balance due · ${formatBigMoney(report.unpaidRevenueMinor, report.currency)}',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  const _LegendItem({required this.color, required this.label});
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
      const SizedBox(width: 8),
      Flexible(
        child: Text(label, style: Theme.of(context).textTheme.bodySmall),
      ),
    ],
  );
}

class _ActivityChartPainter extends CustomPainter {
  const _ActivityChartPainter({
    required this.activity,
    required this.maxValue,
    required this.lineColor,
    required this.labelColor,
  });

  final List<ReportActivityPoint> activity;
  final BigInt maxValue;
  final Color lineColor;
  final Color labelColor;

  @override
  void paint(Canvas canvas, Size size) {
    const top = 12.0;
    const bottom = 42.0;
    const left = 18.0;
    const right = 8.0;
    final plotHeight = size.height - top - bottom;
    final baseY = top + plotHeight;
    final grid = Paint()
      ..color = lineColor
      ..strokeWidth = .7;
    for (var i = 0; i <= 3; i++) {
      final y = top + plotHeight * i / 3;
      canvas.drawLine(Offset(left, y), Offset(size.width - right, y), grid);
    }
    if (activity.isEmpty || maxValue == BigInt.zero) return;
    final slotWidth = (size.width - left - right) / activity.length;
    final barWidth = math.min(33.0, slotWidth * .36);
    final maxDouble = maxValue.toDouble();
    final salesPaint = Paint()..color = salesChartColor;
    final expensePaint = Paint()..color = expenseChartColor;
    for (var i = 0; i < activity.length; i++) {
      final point = activity[i];
      final center = left + slotWidth * (i + .5);
      final salesHeight =
          (point.revenueMinor.abs().toDouble() / maxDouble * (plotHeight - 8))
              .clamp(0.0, plotHeight - 8);
      final expenseHeight =
          (point.expenseMinor.abs().toDouble() / maxDouble * (plotHeight - 8))
              .clamp(0.0, plotHeight - 8);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(
            center - barWidth - 1,
            baseY - salesHeight,
            barWidth,
            salesHeight,
          ),
          const Radius.circular(3),
        ),
        salesPaint,
      );
      final expenseTop = point.expenseMinor.isNegative
          ? baseY
          : baseY - expenseHeight;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(center + 1, expenseTop, barWidth, expenseHeight),
          const Radius.circular(3),
        ),
        expensePaint,
      );
      if (activity.length <= 8 || i % 5 == 0 || i == activity.length - 1) {
        _drawLabel(canvas, point.label, Offset(center, baseY + 10), labelColor);
      }
    }
  }

  void _drawLabel(Canvas canvas, String value, Offset center, Color color) {
    final painter = TextPainter(
      text: TextSpan(
        text: value,
        style: TextStyle(color: color, fontSize: 10),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout();
    painter.paint(canvas, Offset(center.dx - painter.width / 2, center.dy));
  }

  @override
  bool shouldRepaint(covariant _ActivityChartPainter oldDelegate) =>
      oldDelegate.activity != activity ||
      oldDelegate.maxValue != maxValue ||
      oldDelegate.lineColor != lineColor;
}

class _PaymentDonutPainter extends CustomPainter {
  const _PaymentDonutPainter({
    required this.received,
    required this.due,
    required this.track,
  });

  final BigInt received;
  final BigInt due;
  final Color track;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final rect = Rect.fromCircle(
      center: center,
      radius: size.shortestSide / 2 - 8,
    );
    const stroke = 15.0;
    final trackPaint = Paint()
      ..color = track
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke;
    canvas.drawArc(rect, 0, math.pi * 2, false, trackPaint);
    final total = received + due;
    if (total == BigInt.zero) return;
    final receivedSweep = math.pi * 2 * received.toDouble() / total.toDouble();
    final receivedPaint = Paint()
      ..color = salesChartColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    final duePaint = Paint()
      ..color = dueChartColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect, -math.pi / 2, receivedSweep, false, receivedPaint);
    canvas.drawArc(
      rect,
      -math.pi / 2 + receivedSweep,
      math.pi * 2 - receivedSweep,
      false,
      duePaint,
    );
  }

  @override
  bool shouldRepaint(covariant _PaymentDonutPainter oldDelegate) =>
      oldDelegate.received != received ||
      oldDelegate.due != due ||
      oldDelegate.track != track;
}
