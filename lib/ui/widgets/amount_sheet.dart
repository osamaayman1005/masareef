import 'package:masareef/domain/models.dart';
import 'package:masareef/domain/money.dart';
import 'package:masareef/ui/theme.dart';
import 'package:masareef/ui/widgets/receipt.dart';
import 'package:material_ui/material_ui.dart';

/// What the user typed in [editAmount].
class AmountEdit {
  const AmountEdit({
    required this.currency,
    required this.amountCents,
    required this.egpCents,
  });

  final String currency;
  final int amountCents;
  final int egpCents;
}

/// Edits a transaction's amount and currency. For another currency it also
/// asks what the bank charged in EGP, suggested from the rate the user
/// entered last time. Works offline; no rates are downloaded.
Future<AmountEdit?> editAmount(
  BuildContext context, {
  required LedgerTransaction transaction,
  required LedgerSnapshot snapshot,
}) =>
    showModalBottomSheet<AmountEdit>(
      context: context,
      isScrollControlled: true,
      builder: (_) =>
          _AmountSheet(transaction: transaction, snapshot: snapshot),
    );

const _commonCurrencies = ['EGP', 'USD', 'EUR', 'GBP', 'SAR', 'AED'];

class _AmountSheet extends StatefulWidget {
  const _AmountSheet({required this.transaction, required this.snapshot});

  final LedgerTransaction transaction;
  final LedgerSnapshot snapshot;

  @override
  State<_AmountSheet> createState() => _AmountSheetState();
}

class _AmountSheetState extends State<_AmountSheet> {
  late String _currency = widget.transaction.currency;
  late final _amount = TextEditingController(
    text: _plain(widget.transaction.amountCents),
  );
  late final _egp = TextEditingController(
    text:
        widget.transaction.isForeign ? _plain(widget.transaction.egpCents) : '',
  );

  /// Once the user types the EGP amount, suggestions stop overwriting it.
  late bool _egpTyped = widget.transaction.egpCents != null;
  String? _error;

  @override
  void initState() {
    super.initState();
    _suggest();
  }

  @override
  void dispose() {
    _amount.dispose();
    _egp.dispose();
    super.dispose();
  }

  List<String> get _currencies => {
        ..._commonCurrencies,
        widget.transaction.currency,
      }.toList();

  double? get _rate => widget.snapshot.rates[_currency];

  void _suggest() {
    final cents = parseCents(_amount.text);
    if (_egpTyped || _currency == 'EGP' || cents == null) {
      return;
    }
    final suggestion = widget.snapshot.suggestEgp(_currency, cents);
    if (suggestion != null) {
      _egp.text = _plain(suggestion);
    }
  }

  void _pickCurrency(String currency) {
    setState(() {
      _currency = currency;
      _error = null;
      if (!widget.transaction.isForeign) {
        _egpTyped = false;
        _egp.clear();
      }
      _suggest();
    });
  }

  void _save() {
    final amount = parseCents(_amount.text);
    if (amount == null || amount <= 0) {
      setState(() => _error = 'Enter an amount above 0.');
      return;
    }
    final egp = _currency == 'EGP' ? amount : parseCents(_egp.text);
    if (egp == null || egp <= 0) {
      setState(() => _error = 'Enter what your bank charged in EGP.');
      return;
    }
    Navigator.pop(
      context,
      AmountEdit(currency: _currency, amountCents: amount, egpCents: egp),
    );
  }

  @override
  Widget build(BuildContext context) {
    final rate = _rate;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        20,
        16,
        16 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('What did this cost?', style: AppText.heading),
            const SizedBox(height: 12),
            const SectionLabel('Currency'),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final currency in _currencies)
                  ChoiceChip(
                    label: Text(currency),
                    selected: currency == _currency,
                    onSelected: (_) => _pickCurrency(currency),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _amount,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              style: AppText.amount.copyWith(fontSize: 20),
              decoration: InputDecoration(labelText: 'Amount in $_currency'),
              onChanged: (_) => setState(() {
                _error = null;
                _suggest();
              }),
            ),
            if (_currency != 'EGP') ...[
              const SizedBox(height: 12),
              TextField(
                controller: _egp,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                style: AppText.amount.copyWith(fontSize: 20),
                decoration: const InputDecoration(
                  labelText: 'Charged in EGP',
                ),
                onChanged: (_) => setState(() {
                  _egpTyped = true;
                  _error = null;
                }),
              ),
              const SizedBox(height: 6),
              Text(
                rate == null
                    ? 'Check your bank statement. Nothing is looked up '
                        'online; the rate you enter is remembered.'
                    : 'Suggested from your last rate: 1 $_currency = '
                        '${rate.toStringAsFixed(2)} EGP. Change it if your '
                        'bank charged differently.',
                style: AppText.note,
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(
                _error!,
                style: AppText.strong.copyWith(color: AppColors.danger),
              ),
            ],
            const SizedBox(height: 14),
            FilledButton(onPressed: _save, child: const Text('Save')),
          ],
        ),
      ),
    );
  }

  static String _plain(int? cents) =>
      cents == null ? '' : (cents / 100).toStringAsFixed(2);
}
