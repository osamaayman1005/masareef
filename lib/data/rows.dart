/// Converts between SQLite rows and domain types.
library;

import 'package:masareef/domain/models.dart';

ExpenseCategory categoryFromRow(Map<String, Object?> row) => ExpenseCategory(
      id: row['id']! as int,
      name: row['name']! as String,
      sortOrder: row['sort_order']! as int,
    );

LedgerTransaction transactionFromRow(Map<String, Object?> row) {
  final currency = row['currency']! as String;
  final amount = row['amount_cents']! as int;
  return LedgerTransaction(
    id: row['id']! as int,
    messageKey: row['message_key'] as String?,
    timestamp: _time(row['timestamp']),
    kind: TxKind.fromDbName(row['kind']! as String),
    amountCents: amount,
    currency: currency,
    egpCents: currency == 'EGP' ? amount : row['egp_cents'] as int?,
    merchant: row['merchant'] as String?,
    merchantKey: row['merchant_key']! as String,
    categoryId: row['category_id'] as int?,
    source: row['source']! as String,
    card: row['card'] as String?,
    excluded: row['excluded'] == 1,
    kindSetByUser: row['kind_set_by_user'] == 1,
    amountSetByUser: row['amount_set_by_user'] == 1,
  );
}

Split splitFromRow(Map<String, Object?> row) => Split(
      id: row['id']! as int,
      transactionId: row['transaction_id']! as int,
      categoryId: row['category_id']! as int,
      amountCents: row['amount_cents']! as int,
    );

StoredMessage messageFromRow(Map<String, Object?> row) => StoredMessage(
      key: row['key']! as String,
      sender: row['sender']! as String,
      body: row['body']! as String,
      timestamp: _time(row['timestamp']),
      status: MessageStatus.fromDbName(row['status']! as String),
      rule: row['rule'] as String?,
    );

IgnoreRule ignoreRuleFromRow(Map<String, Object?> row) => IgnoreRule(
      id: row['id']! as int,
      sender: row['sender']! as String,
      signature: row['signature']! as String,
      sample: row['sample']! as String,
      createdAt: _time(row['created_at']),
    );

Map<String, Object?> messageToRow(StoredMessage message) => {
      'key': message.key,
      'sender': message.sender,
      'body': message.body,
      'timestamp': message.timestamp.millisecondsSinceEpoch,
      'status': message.status.dbName,
      'rule': message.rule,
    };

Map<String, Object?> draftToRow(TransactionDraft draft) => {
      'message_key': draft.messageKey,
      'timestamp': draft.timestamp.millisecondsSinceEpoch,
      'kind': draft.kind.dbName,
      'amount_cents': draft.amountCents,
      'currency': draft.currency,
      'egp_cents': draft.currency == 'EGP' ? draft.amountCents : null,
      'merchant': draft.merchant,
      'merchant_key': draft.merchantKey,
      'category_id': draft.categoryId,
      'source': draft.source,
      'card': draft.card,
    };

DateTime _time(Object? millis) =>
    DateTime.fromMillisecondsSinceEpoch(millis! as int);
