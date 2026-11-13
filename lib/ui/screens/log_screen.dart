import 'dart:async';

import 'package:flutter/services.dart';
import 'package:masareef/domain/models.dart';
import 'package:masareef/parser/text_tools.dart';
import 'package:masareef/ui/app_scope.dart';
import 'package:masareef/ui/format.dart';
import 'package:masareef/ui/theme.dart';
import 'package:masareef/ui/widgets/backup_section.dart';
import 'package:masareef/ui/widgets/receipt.dart';
import 'package:masareef/ui/widgets/sheets.dart';
import 'package:material_ui/material_ui.dart';

/// What the app could not read, what it skips, and what it learned.
class LogScreen extends StatelessWidget {
  const LogScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    final snapshot = controller.snapshot;
    final failed = snapshot.messages
        .where((message) => message.status == MessageStatus.failed)
        .toList();
    final merchants = snapshot.merchantRules.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        const Text('Log', style: AppText.title),
        const SizedBox(height: 4),
        const Text(
          'What the app could not read, what it skips, and what it learned.',
          style: AppText.note,
        ),
        const SizedBox(height: 20),
        const SectionLabel('Messages it could not read'),
        const SizedBox(height: 8),
        ReceiptPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                failed.isEmpty
                    ? 'None right now.'
                    : '${plural(failed.length, 'message', 'messages')} '
                        'waiting in the Inbox.',
                style: AppText.strong,
              ),
              const SizedBox(height: 4),
              const Text(
                'Copy them and send them to the developer so the next version '
                'reads them. After an update, old failures are read again.',
                style: AppText.note,
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: failed.isEmpty
                    ? null
                    : () => unawaited(_copyFailures(context)),
                child: const Text('Copy unread messages'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        const SectionLabel('Ignored formats'),
        const SizedBox(height: 8),
        if (snapshot.ignoreRules.isEmpty)
          const Text(
            'None yet. Ignore a message from the Inbox to add one.',
            style: AppText.note,
          ),
        for (final rule in snapshot.ignoreRules)
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(rule.sender, style: AppText.strong),
            subtitle: Text(
              rule.sample,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppText.note,
            ),
            trailing: TextButton(
              onPressed: () => unawaited(controller.stopIgnoring(rule.id)),
              child: const Text('Stop ignoring'),
            ),
          ),
        const SizedBox(height: 20),
        const SectionLabel('Remembered merchants'),
        const SizedBox(height: 8),
        if (merchants.isEmpty) const Text('None yet.', style: AppText.note),
        for (final entry in merchants)
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(displayMerchant(entry.key), style: AppText.strong),
            trailing:
                Text(snapshot.categoryName(entry.value), style: AppText.body),
            onTap: () => unawaited(_changeMerchant(context, entry.key)),
          ),
        const SizedBox(height: 20),
        const SectionLabel('Categories'),
        const SizedBox(height: 8),
        for (final category in snapshot.categories)
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(category.name, style: AppText.body),
            trailing: const Icon(Icons.edit_outlined, size: 18),
            onTap: () => unawaited(_rename(context, category)),
          ),
        OutlinedButton(
          onPressed: () => unawaited(_addCategory(context)),
          child: const Text('Add category'),
        ),
        const SizedBox(height: 20),
        const BackupSection(),
        const SizedBox(height: 20),
        const DashedLine(),
        const SizedBox(height: 12),
        const Text(
          'Everything is stored on this phone only. App updates keep your data.',
          style: AppText.note,
        ),
      ],
    );
  }

  Future<void> _copyFailures(BuildContext context) async {
    final report = AppScope.read(context).failuresReport();
    await Clipboard.setData(ClipboardData(text: report));
    if (context.mounted) {
      showMessage(context, 'Copied. Paste it in a chat with the developer.');
    }
  }

  Future<void> _changeMerchant(BuildContext context, String merchantKey) async {
    final controller = AppScope.read(context);
    final picked = await pickCategory(
      context,
      title: 'What is ${displayMerchant(merchantKey)}?',
      categories: controller.snapshot.categories,
    );
    if (picked != null) {
      await controller.categorizeMerchant(merchantKey, picked);
    }
  }

  Future<void> _rename(BuildContext context, ExpenseCategory category) async {
    final controller = AppScope.read(context);
    final name = await askText(
      context,
      title: 'Rename category',
      confirmLabel: 'Rename',
      initial: category.name,
    );
    if (name != null && name != category.name) {
      await controller.renameCategory(category.id, name);
    }
  }

  Future<void> _addCategory(BuildContext context) async {
    final controller = AppScope.read(context);
    final name =
        await askText(context, title: 'New category', confirmLabel: 'Add');
    if (name != null) {
      await controller.addCategory(name);
    }
  }
}
