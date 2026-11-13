import 'package:masareef/logic/spending.dart';
import 'package:masareef/ui/app_scope.dart';
import 'package:masareef/ui/format.dart';
import 'package:masareef/ui/theme.dart';
import 'package:masareef/ui/widgets/receipt.dart';
import 'package:masareef/ui/widgets/transaction_tile.dart';
import 'package:material_ui/material_ui.dart';

/// Every transaction behind one line on the Spending screen.
class LineScreen extends StatelessWidget {
  const LineScreen({required this.line, super.key});

  final SpendingLine line;

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    final transactions =
        transactionsFor(controller.snapshot, controller.range, line);
    return Scaffold(
      appBar: AppBar(title: Text(line.label)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        children: [
          SectionLabel(formatRange(controller.range)),
          const SizedBox(height: 8),
          if (transactions.isEmpty)
            const Text('Nothing left here.', style: AppText.note)
          else
            ReceiptPanel(
              child: Column(
                children: [
                  for (final (index, tx) in transactions.indexed) ...[
                    if (index > 0) const Divider(height: 1),
                    TransactionTile(transaction: tx),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }
}
