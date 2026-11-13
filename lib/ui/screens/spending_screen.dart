import 'dart:async';

import 'package:masareef/domain/models.dart';
import 'package:masareef/domain/money.dart';
import 'package:masareef/logic/spending.dart';
import 'package:masareef/state/app_controller.dart';
import 'package:masareef/ui/app_scope.dart';
import 'package:masareef/ui/format.dart';
import 'package:masareef/ui/screens/line_screen.dart';
import 'package:masareef/ui/theme.dart';
import 'package:masareef/ui/widgets/receipt.dart';
import 'package:material_ui/material_ui.dart';

class SpendingScreen extends StatelessWidget {
  const SpendingScreen({required this.onOpenInbox, super.key});

  final VoidCallback onOpenInbox;

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    final summary = controller.summary;
    final inboxCount = controller.inbox.length;
    final largest = summary.lines
        .where((line) => line.kind == LineKind.category)
        .fold(0, (max, line) => line.cents > max ? line.cents : max);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        const _Header(),
        const SizedBox(height: 14),
        const _RangeBar(),
        const SizedBox(height: 14),
        ReceiptPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SectionLabel('Spent · ${formatRange(controller.range)}'),
              const SizedBox(height: 4),
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        formatCents(summary.totalCents),
                        style: AppText.total,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text('EGP', style: AppText.note),
                ],
              ),
              if (inboxCount > 0) ...[
                const SizedBox(height: 14),
                Callout(
                  text: plural(inboxCount, 'item needs you', 'items need you'),
                  onTap: onOpenInbox,
                ),
              ],
              const SizedBox(height: 14),
              const DashedLine(),
              const SizedBox(height: 6),
              if (summary.lines.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Text('Nothing spent in these dates.',
                      style: AppText.note),
                ),
              for (final line in summary.lines)
                LeaderRow(
                  label: line.label,
                  cents: line.cents,
                  highlight: line.kind != LineKind.category,
                  share: line.kind == LineKind.category && largest > 0
                      ? line.cents / largest
                      : null,
                  note: _noteFor(line),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) => LineScreen(line: line),
                    ),
                  ),
                ),
              if (summary.incomeCents > 0) ...[
                const SizedBox(height: 6),
                const DashedLine(),
                const SizedBox(height: 6),
                LeaderRow(
                  label: 'Money in',
                  cents: summary.incomeCents,
                  note: 'Transfers and deposits. Not counted as spending.',
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  static String _noteFor(SpendingLine line) => switch (line.kind) {
        LineKind.category => plural(line.count, 'entry', 'entries'),
        LineKind.uncategorized =>
          '${plural(line.count, 'payment', 'payments')} waiting in the Inbox',
        LineKind.unassignedCash ||
        LineKind.unassignedTransfer =>
          'Not split yet. Tap to say where it went.',
      };
}

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('MASAREEF', style: AppText.brand),
              const SizedBox(height: 2),
              Text(controller.status, style: AppText.label),
            ],
          ),
        ),
        OutlinedButton.icon(
          onPressed: controller.syncing
              ? null
              : () => unawaited(AppScope.read(context).sync()),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.action,
            side: const BorderSide(color: AppColors.action, width: 1.5),
          ),
          icon: controller.syncing
              ? const SizedBox.square(
                  dimension: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.sync, size: 18),
          label: const Text('Sync SMS'),
        ),
      ],
    );
  }
}

class _RangeBar extends StatelessWidget {
  const _RangeBar();

  static const _labels = {
    RangePreset.thisMonth: 'This month',
    RangePreset.last7Days: '7 days',
    RangePreset.all: 'All',
    RangePreset.custom: 'Custom',
  };

  Future<void> _pickCustom(BuildContext context) async {
    final controller = AppScope.read(context);
    final current = controller.range;
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2015),
      lastDate: DateTime.now(),
      initialDateRange: DateTimeRange(start: current.start, end: current.end),
    );
    if (picked != null) {
      controller.setCustomRange(DayRange(picked.start, picked.end));
    }
  }

  @override
  Widget build(BuildContext context) {
    final selected = AppScope.of(context).preset;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.paper,
        border: Border.all(color: AppColors.ink, width: 1.5),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        children: [
          for (final entry in _labels.entries)
            Expanded(
              child: Material(
                color:
                    entry.key == selected ? AppColors.ink : Colors.transparent,
                child: InkWell(
                  onTap: () => entry.key == RangePreset.custom
                      ? unawaited(_pickCustom(context))
                      : AppScope.read(context).setPreset(entry.key),
                  child: SizedBox(
                    height: 44,
                    child: Center(
                      child: Text(
                        entry.value,
                        style: AppText.strong.copyWith(
                          fontSize: 13,
                          color: entry.key == selected
                              ? AppColors.paper
                              : AppColors.ink,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
