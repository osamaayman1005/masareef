import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:masareef/ui/app_scope.dart';
import 'package:masareef/ui/theme.dart';
import 'package:masareef/ui/widgets/receipt.dart';
import 'package:masareef/ui/widgets/sheets.dart';

/// Rescan, copy a backup, and restore one. Lives at the bottom of Log.
class BackupSection extends StatelessWidget {
  const BackupSection({super.key});

  @override
  Widget build(BuildContext context) {
    final syncing = AppScope.of(context).syncing;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionLabel('Sync and backup'),
        const SizedBox(height: 8),
        OutlinedButton(
          onPressed: syncing ? null : () => unawaited(_rescan(context)),
          child: const Text('Rescan the last 12 months'),
        ),
        const SizedBox(height: 8),
        OutlinedButton(
          onPressed: () => unawaited(_copyBackup(context)),
          child: const Text('Copy backup'),
        ),
        const SizedBox(height: 8),
        OutlinedButton(
          onPressed: () => unawaited(_restore(context)),
          child: const Text('Restore from copied backup'),
        ),
        const SizedBox(height: 6),
        const Text(
          'A rescan never adds the same message twice. Keep a copied backup '
          'somewhere safe before uninstalling the app.',
          style: AppText.note,
        ),
      ],
    );
  }

  Future<void> _rescan(BuildContext context) async {
    final since = DateTime.now().subtract(const Duration(days: 365));
    await AppScope.read(context).sync(since: since);
  }

  Future<void> _copyBackup(BuildContext context) async {
    final backup = await AppScope.read(context).exportBackup();
    await Clipboard.setData(ClipboardData(text: backup));
    if (context.mounted) {
      showMessage(context, 'Backup copied. Paste it somewhere safe.');
    }
  }

  Future<void> _restore(BuildContext context) async {
    final controller = AppScope.read(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Replace all data?'),
        content: const Text(
          'Everything in the app is replaced by the backup on your clipboard.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Replace'),
          ),
        ],
      ),
    );
    if (confirmed != true) {
      return;
    }
    final clip = await Clipboard.getData(Clipboard.kTextPlain);
    try {
      await controller.importBackup(clip?.text ?? '');
      if (context.mounted) {
        showMessage(context, 'Backup restored.');
      }
    } on FormatException catch (error) {
      if (context.mounted) {
        showMessage(context, error.message);
      }
    } on Exception {
      if (context.mounted) {
        showMessage(context, 'Could not restore this backup. Nothing changed.');
      }
    }
  }
}
