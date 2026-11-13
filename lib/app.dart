import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:masareef/data/database.dart';
import 'package:masareef/data/ledger_store.dart';
import 'package:masareef/data/sms_source.dart';
import 'package:masareef/logic/sync_service.dart';
import 'package:masareef/parser/pattern_set.dart';
import 'package:masareef/parser/sms_parser.dart';
import 'package:masareef/state/app_controller.dart';
import 'package:masareef/ui/app_scope.dart';
import 'package:masareef/ui/screens/home_shell.dart';
import 'package:masareef/ui/theme.dart';
import 'package:material_ui/material_ui.dart';

/// Wires the layers together. The only file that creates concrete classes.
Future<AppController> createController() async {
  final patterns = PatternSet.fromJson(
    jsonDecode(await rootBundle.loadString('assets/parser/patterns.json'))
        as Map<String, Object?>,
  );
  final store = LedgerStore(await openAppDatabase());
  final controller = AppController(
    store: store,
    syncService: SyncService(
      store: store,
      source: const PlatformSmsSource(),
      parser: SmsParser(patterns),
    ),
  );
  await controller.start();
  return controller;
}

class MasareefApp extends StatelessWidget {
  const MasareefApp({required this.controller, super.key});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    return AppScope(
      controller: controller,
      child: MaterialApp(
        title: 'Masareef',
        debugShowCheckedModeBanner: false,
        theme: buildTheme(),
        home: const _AutoSync(child: HomeShell()),
      ),
    );
  }
}

/// Syncs once when the app opens, so the numbers are fresh without a tap.
class _AutoSync extends StatefulWidget {
  const _AutoSync({required this.child});

  final Widget child;

  @override
  State<_AutoSync> createState() => _AutoSyncState();
}

class _AutoSyncState extends State<_AutoSync> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        unawaited(AppScope.read(context).sync());
      }
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
