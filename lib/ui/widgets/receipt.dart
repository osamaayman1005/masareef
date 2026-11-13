import 'package:flutter/material.dart';
import 'package:masareef/domain/money.dart';
import 'package:masareef/ui/theme.dart';

/// Paper block with dashed top and bottom edges, like a printed receipt.
class ReceiptPanel extends StatelessWidget {
  const ReceiptPanel({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(color: AppColors.paper),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const DashedLine(thickness: 2),
          Padding(padding: const EdgeInsets.all(16), child: child),
          const DashedLine(thickness: 2),
        ],
      ),
    );
  }
}

class DashedLine extends StatelessWidget {
  const DashedLine({super.key, this.thickness = 1.5});

  final double thickness;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(double.infinity, thickness),
      painter: _DashPainter(thickness: thickness),
    );
  }
}

class _DashPainter extends CustomPainter {
  const _DashPainter({required this.thickness});

  final double thickness;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.ink
      ..strokeWidth = thickness;
    final y = size.height / 2;
    for (var x = 0.0; x < size.width; x += 9) {
      canvas.drawLine(Offset(x, y), Offset(x + 5, y), paint);
    }
  }

  @override
  bool shouldRepaint(_DashPainter oldDelegate) =>
      oldDelegate.thickness != thickness;
}

/// `Groceries ........ 1,250.00` with an optional bar and note below.
class LeaderRow extends StatelessWidget {
  const LeaderRow({
    required this.label,
    required this.cents,
    super.key,
    this.note,
    this.share,
    this.highlight = false,
    this.onTap,
  });

  final String label;
  final int cents;
  final String? note;

  /// 0 to 1. Draws a bar when given.
  final double? share;
  final bool highlight;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final share = this.share;
    final note = this.note;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Flexible(
                  child: Container(
                    color: highlight ? AppColors.highlight : null,
                    padding:
                        EdgeInsets.symmetric(horizontal: highlight ? 4 : 0),
                    child: Text(label, style: AppText.strong),
                  ),
                ),
                const Expanded(child: _DottedLeader()),
                Text(formatCents(cents), style: AppText.amount),
              ],
            ),
            if (share != null) ...[
              const SizedBox(height: 6),
              _ShareBar(share: share),
            ],
            if (note != null) ...[
              const SizedBox(height: 4),
              Text(note, style: AppText.note),
            ],
          ],
        ),
      ),
    );
  }
}

class _DottedLeader extends StatelessWidget {
  const _DottedLeader();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.fromLTRB(8, 0, 8, 5),
      child:
          CustomPaint(size: Size(double.infinity, 2), painter: _DotPainter()),
    );
  }
}

class _DotPainter extends CustomPainter {
  const _DotPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = AppColors.leader;
    for (var x = 0.0; x < size.width; x += 5) {
      canvas.drawCircle(Offset(x + 1, size.height / 2), 1, paint);
    }
  }

  @override
  bool shouldRepaint(_DotPainter oldDelegate) => false;
}

class _ShareBar extends StatelessWidget {
  const _ShareBar({required this.share});

  final double share;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 6,
      child: ColoredBox(
        color: AppColors.track,
        child: FractionallySizedBox(
          alignment: Alignment.centerLeft,
          widthFactor: share.clamp(0.02, 1),
          child: const ColoredBox(color: AppColors.ink),
        ),
      ),
    );
  }
}

class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) =>
      Text(text.toUpperCase(), style: AppText.label);
}

/// Yellow strip for things that need the user.
class Callout extends StatelessWidget {
  const Callout({required this.text, super.key, this.onTap});

  final String text;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.highlight,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                Expanded(child: Text(text, style: AppText.strong)),
                if (onTap != null) const Icon(Icons.arrow_forward, size: 18),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
