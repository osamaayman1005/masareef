import 'package:masareef/domain/models.dart';
import 'package:masareef/domain/money.dart';
import 'package:masareef/parser/text_tools.dart';

const _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', //
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

String formatDay(DateTime value) => '${value.day} ${_months[value.month - 1]}';

String formatDayTime(DateTime value) {
  final hour = value.hour.toString().padLeft(2, '0');
  final minute = value.minute.toString().padLeft(2, '0');
  return '${formatDay(value)} · $hour:$minute';
}

String formatRange(DayRange range) =>
    '${formatDay(range.start)} – ${formatDay(range.end)}';

String kindLabel(TxKind kind) => switch (kind) {
      TxKind.purchase => 'Payment',
      TxKind.refund => 'Refund',
      TxKind.cash => 'Cash withdrawal',
      TxKind.transferOut => 'Transfer sent',
      TxKind.transferIn => 'Money in',
    };

/// Merchant name when known, otherwise what kind of movement it was.
String transactionTitle(LedgerTransaction tx) {
  final merchant = tx.merchant;
  if (tx.kind.isAssignable || merchant == null) {
    return kindLabel(tx.kind);
  }
  return displayMerchant(merchant);
}

/// `EGP 1,250.00`, or `USD 9.99` for a charge not yet converted.
String transactionAmount(LedgerTransaction tx) =>
    tx.currency == 'EGP' || tx.egpCents != null
        ? 'EGP ${formatCents(tx.egpCents ?? tx.amountCents)}'
        : '${tx.currency} ${formatCents(tx.amountCents)}';

String plural(int count, String one, String many) =>
    '$count ${count == 1 ? one : many}';
