import 'package:flutter_test/flutter_test.dart';
import 'package:masareef/data/database.dart';
import 'package:masareef/data/ledger_store.dart';
import 'package:masareef/data/sms_source.dart';
import 'package:masareef/domain/models.dart';
import 'package:masareef/logic/sync_service.dart';
import 'package:masareef/parser/sms_parser.dart';
import 'package:masareef/parser/text_tools.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'support.dart';

void main() {
  sqfliteFfiInit();

  late Database db;
  late LedgerStore store;

  setUp(() async {
    db = await openAppDatabase(
      path: inMemoryDatabasePath,
      factory: databaseFactoryFfi,
    );
    store = LedgerStore(db);
  });

  tearDown(() async {
    await db.close();
  });

  final now = DateTime.now();
  final purchase = RawSms(
    sender: 'FABMISR',
    body: 'Your Card ** 7852 was debited with EGP 175 at dancing goat sm on '
        '11/11/26 12:20. Available limit is EGP 28206.',
    timestamp: now.subtract(const Duration(hours: 3)),
  );
  final notice = RawSms(
    sender: 'CIB',
    body:
        'عميل CIB العزيز، سيتم تحديث أسعار العائد اعتبارًا من 10 نوفمبر 2026. '
        'لمعرفة المزيد اضغط هنا https://cib.eg/2azq',
    timestamp: now.subtract(const Duration(hours: 2)),
  );
  final personal = RawSms(
    sender: '+201000000000',
    body: 'Are you coming tonight?',
    timestamp: now.subtract(const Duration(hours: 1)),
  );

  SyncService service(List<RawSms> inbox) => SyncService(
        store: store,
        source: FakeSmsSource(inbox),
        parser: SmsParser(loadPatterns()),
      );

  test('syncing twice never adds a payment twice', () async {
    final sync = service([purchase, notice, personal]);
    final first = await sync.sync();
    final second =
        await sync.sync(since: now.subtract(const Duration(days: 30)));

    expect(first.added, 1);
    expect(first.failed, 1);
    expect(second.added, 0);
    final snapshot = await store.load();
    expect(snapshot.transactions, hasLength(1));
    expect(snapshot.transactions.single.amountCents, 17500);
  });

  test('personal messages are not stored', () async {
    await service([personal]).sync();
    final keys = await store.messageKeysSince(DateTime(2000));
    expect(keys, isEmpty);
  });

  test('an ignored format matches the next message worded like it', () {
    final rules = [
      IgnoreRule(
        id: 1,
        sender: 'CIB',
        signature: messageSignature(notice.body),
        sample: notice.body,
        createdAt: now,
      ),
    ];
    final nextMonth = notice.body.replaceAll('10 نوفمبر', '3 ديسمبر');
    expect(matchingIgnoreRule(rules, 'CIB', nextMonth), isNotNull);
    expect(matchingIgnoreRule(rules, 'QNB EGYPT', nextMonth), isNull);
    expect(
      matchingIgnoreRule(rules, 'CIB', purchase.body),
      isNull,
      reason: 'a payment never looks like an ignored notice',
    );
  });

  test('stopping an ignore rule sends its messages back to the Inbox',
      () async {
    await service([notice]).sync();
    final failed = (await store.load()).messages.single;
    final ruleId = await store.addIgnoreRule(
      failed.sender,
      messageSignature(failed.body),
      failed.body,
    );
    await store.updateMessage(
      failed.key,
      MessageStatus.ignored,
      rule: 'ignore:$ruleId',
    );
    expect((await store.load()).messages.single.status, MessageStatus.ignored);

    await store.deleteIgnoreRule(ruleId);
    expect((await store.load()).messages.single.status, MessageStatus.failed);
  });

  test('a parser update reads old failures again', () async {
    await store.saveMessage(
      StoredMessage(
        key: 'old',
        sender: 'FABMISR',
        body: purchase.body,
        timestamp: purchase.timestamp,
        status: MessageStatus.failed,
      ),
    );
    final recovered = await service(const []).reparseIfParserChanged();
    expect(recovered, 1);
    expect((await store.load()).transactions, hasLength(1));
    expect(await service(const []).reparseIfParserChanged(), 0);
  });

  test('a backup restores exactly what was exported', () async {
    await service([purchase, notice]).sync();
    final exported = await store.exportTables();
    await store.importTables({});
    expect((await store.load()).transactions, isEmpty);
    await store.importTables(exported);
    final restored = await store.load();
    expect(restored.transactions, hasLength(1));
    expect(restored.messages, hasLength(1));
  });
}
