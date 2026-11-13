import 'dart:async';

import 'package:flutter/material.dart';
import 'package:masareef/domain/models.dart';
import 'package:masareef/domain/money.dart';
import 'package:masareef/ui/app_scope.dart';
import 'package:masareef/ui/theme.dart';
import 'package:masareef/ui/widgets/receipt.dart';

/// Splits a cash withdrawal or sent transfer into categories: all of it in
/// one tap, or part of it at a time.
class SplitEditor extends StatefulWidget {
  const SplitEditor({required this.transaction, super.key});

  final LedgerTransaction transaction;

  @override
  State<SplitEditor> createState() => _SplitEditorState();
}

class _SplitEditorState extends State<SplitEditor> {
  final _amount = TextEditingController();
  int? _categoryId;
  String? _error;

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  Future<void> _assign(int cents) async {
    final categoryId = _categoryId;
    if (categoryId == null) {
      setState(() => _error = 'Pick where it went first.');
      return;
    }
    final error = await AppScope.read(context)
        .assign(widget.transaction, categoryId, cents);
    if (!mounted) {
      return;
    }
    setState(() => _error = error);
    if (error == null) {
      _amount.clear();
    }
  }

  void _assignPart() {
    final cents = parseCents(_amount.text);
    if (cents == null) {
      setState(() => _error = 'Enter an amount above 0.');
      return;
    }
    unawaited(_assign(cents));
  }

  @override
  Widget build(BuildContext context) {
    final snapshot = AppScope.of(context).snapshot;
    final tx = widget.transaction;
    final total = tx.egpCents ?? 0;
    final splits = snapshot.splitsOf(tx.id);
    final assigned = snapshot.assignedCents(tx.id);
    final left = total - assigned;
    final leftLabel =
        tx.kind == TxKind.cash ? 'Still cash' : 'Still a transfer';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ReceiptPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(child: _Figure(label: 'Assigned', cents: assigned)),
                  Expanded(child: _Figure(label: leftLabel, cents: left)),
                ],
              ),
              const SizedBox(height: 10),
              LinearProgressIndicator(
                value: total == 0 ? 0 : assigned / total,
                minHeight: 10,
                color: AppColors.ink,
                backgroundColor: AppColors.track,
              ),
              const SizedBox(height: 6),
              if (splits.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: 6),
                  child: Text('Nothing assigned yet.', style: AppText.note),
                ),
              for (final split in splits)
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        snapshot.categoryName(split.categoryId),
                        style: AppText.strong,
                      ),
                    ),
                    Text(formatCents(split.amountCents), style: AppText.amount),
                    TextButton(
                      onPressed: () => unawaited(
                        AppScope.read(context).removeSplit(split.id),
                      ),
                      style: TextButton.styleFrom(
                          foregroundColor: AppColors.danger),
                      child: const Text('Undo'),
                    ),
                  ],
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (left <= 0)
          const Callout(
              text: 'All of it is assigned. Undo a line to change it.')
        else ...[
          const Text('Where did it go?', style: AppText.strong),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final category in snapshot.categories)
                ChoiceChip(
                  label: Text(category.name),
                  selected: _categoryId == category.id,
                  onSelected: (_) => setState(() {
                    _categoryId = category.id;
                    _error = null;
                  }),
                ),
            ],
          ),
          const SizedBox(height: 14),
          FilledButton(
            onPressed: () => unawaited(_assign(left)),
            child: Text('All of it · EGP ${formatCents(left)}'),
          ),
          const SizedBox(height: 14),
          const SectionLabel('Or only part of it'),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _amount,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  style: AppText.amount.copyWith(fontSize: 18),
                  decoration: const InputDecoration(labelText: 'Amount in EGP'),
                  onSubmitted: (_) => _assignPart(),
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton(
                onPressed: _assignPart,
                child: const Text('Assign part'),
              ),
            ],
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(
              _error!,
              style: AppText.strong.copyWith(color: AppColors.danger),
            ),
          ],
        ],
      ],
    );
  }
}

class _Figure extends StatelessWidget {
  const _Figure({required this.label, required this.cents});

  final String label;
  final int cents;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionLabel(label),
        const SizedBox(height: 2),
        Text(formatCents(cents), style: AppText.amount.copyWith(fontSize: 20)),
      ],
    );
  }
}
