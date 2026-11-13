import 'package:flutter/material.dart';
import 'package:masareef/ui/app_scope.dart';
import 'package:masareef/ui/screens/inbox_screen.dart';
import 'package:masareef/ui/screens/log_screen.dart';
import 'package:masareef/ui/screens/spending_screen.dart';
import 'package:masareef/ui/theme.dart';

/// Three tabs: Spending, Inbox and Log.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _tab = 0;

  void _open(int tab) => setState(() => _tab = tab);

  @override
  Widget build(BuildContext context) {
    final inboxCount = AppScope.of(context).inbox.length;
    final tabs = [
      'Spending',
      inboxCount > 0 ? 'Inbox · $inboxCount' : 'Inbox',
      'Log',
    ];
    return Scaffold(
      body: SafeArea(
        child: IndexedStack(
          index: _tab,
          children: [
            SpendingScreen(onOpenInbox: () => _open(1)),
            const InboxScreen(),
            const LogScreen(),
          ],
        ),
      ),
      bottomNavigationBar: ColoredBox(
        color: AppColors.ink,
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: 64,
            child: Row(
              children: [
                for (final (index, label) in tabs.indexed)
                  Expanded(
                    child: Material(
                      color: index == _tab ? AppColors.highlight : AppColors.ink,
                      child: InkWell(
                        onTap: () => _open(index),
                        child: Center(
                          child: Text(
                            label,
                            style: AppText.strong.copyWith(
                              color: index == _tab ? AppColors.ink : AppColors.paper,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
