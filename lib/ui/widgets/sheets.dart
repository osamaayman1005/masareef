import 'package:masareef/domain/models.dart';
import 'package:masareef/domain/money.dart';
import 'package:masareef/ui/format.dart';
import 'package:masareef/ui/theme.dart';
import 'package:material_ui/material_ui.dart';

/// Bottom sheet listing all categories. Returns the picked id.
Future<int?> pickCategory(
  BuildContext context, {
  required String title,
  required List<ExpenseCategory> categories,
  String? subtitle,
}) =>
    showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(title, style: AppText.heading),
              if (subtitle != null) ...[
                const SizedBox(height: 4),
                Text(subtitle, style: AppText.note),
              ],
              const SizedBox(height: 14),
              Flexible(
                child: SingleChildScrollView(
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final category in categories)
                        OutlinedButton(
                          onPressed: () => Navigator.pop(context, category.id),
                          child: Text(category.name),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Not now'),
              ),
            ],
          ),
        ),
      ),
    );

/// Bottom sheet listing every transaction type with a short explanation.
/// [current] is marked. Returns the picked type.
Future<TxKind?> pickKind(
  BuildContext context, {
  required String title,
  TxKind? current,
  String? warning,
}) =>
    showModalBottomSheet<TxKind>(
      context: context,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(title, style: AppText.heading),
              if (warning != null) ...[
                const SizedBox(height: 4),
                Text(warning, style: AppText.note),
              ],
              const SizedBox(height: 12),
              for (final kind in TxKind.values)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(kindLabel(kind), style: AppText.strong),
                  subtitle: Text(kindHint(kind), style: AppText.note),
                  trailing: kind == current
                      ? const Icon(Icons.check, color: AppColors.action)
                      : null,
                  onTap: () => Navigator.pop(context, kind),
                ),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
            ],
          ),
        ),
      ),
    );

/// Asks for an amount in EGP. Returns cents, or null when cancelled.
Future<int?> askAmount(
  BuildContext context, {
  required String title,
  required String confirmLabel,
  String? hint,
}) =>
    showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      builder: (context) => _AmountSheet(
        title: title,
        confirmLabel: confirmLabel,
        hint: hint,
      ),
    );

class _AmountSheet extends StatefulWidget {
  const _AmountSheet(
      {required this.title, required this.confirmLabel, this.hint});

  final String title;
  final String confirmLabel;
  final String? hint;

  @override
  State<_AmountSheet> createState() => _AmountSheetState();
}

class _AmountSheetState extends State<_AmountSheet> {
  final _controller = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final cents = parseCents(_controller.text);
    if (cents == null || cents <= 0) {
      setState(() => _error = 'Enter an amount above 0.');
      return;
    }
    Navigator.pop(context, cents);
  }

  @override
  Widget build(BuildContext context) {
    final hint = widget.hint;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        20,
        16,
        16 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(widget.title, style: AppText.heading),
          if (hint != null) ...[
            const SizedBox(height: 4),
            Text(hint, style: AppText.note),
          ],
          const SizedBox(height: 14),
          TextField(
            controller: _controller,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: AppText.amount.copyWith(fontSize: 20),
            decoration: InputDecoration(
              labelText: 'Amount in EGP',
              errorText: _error,
            ),
            onChanged: (_) => setState(() => _error = null),
            onSubmitted: (_) => _submit(),
          ),
          const SizedBox(height: 14),
          FilledButton(onPressed: _submit, child: Text(widget.confirmLabel)),
        ],
      ),
    );
  }
}

/// Asks for one line of text, e.g. a category name.
Future<String?> askText(
  BuildContext context, {
  required String title,
  required String confirmLabel,
  String initial = '',
}) =>
    showDialog<String>(
      context: context,
      builder: (context) => _TextDialog(
        title: title,
        confirmLabel: confirmLabel,
        initial: initial,
      ),
    );

class _TextDialog extends StatefulWidget {
  const _TextDialog({
    required this.title,
    required this.confirmLabel,
    required this.initial,
  });

  final String title;
  final String confirmLabel;
  final String initial;

  @override
  State<_TextDialog> createState() => _TextDialogState();
}

class _TextDialogState extends State<_TextDialog> {
  late final _controller = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final text = _controller.text.trim();
    if (text.isNotEmpty) {
      Navigator.pop(context, text);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _controller,
        autofocus: true,
        textCapitalization: TextCapitalization.sentences,
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _submit, child: Text(widget.confirmLabel)),
      ],
    );
  }
}

void showMessage(BuildContext context, String text) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(text)));
}
