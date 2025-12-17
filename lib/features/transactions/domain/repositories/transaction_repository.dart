import '../models/transaction_item.dart';


abstract class TransactionRepository {
Stream<List<TransactionItem>> watchLatest({int limit = 200});
Stream<List<AccountBalance>> watchAccountBalances();
Stream<MonthSummary> watchMonthSummary(DateTime month);


Future<void> addIncomeExpense({
required String type, // income|expense
required int amountCents,
required DateTime date,
required int accountId,
required int categoryId,
String? description,
});

Future<void> addTransfer({
required int amountCents,
required DateTime date,
required int fromAccountId,
required int toAccountId,
String? description,
});


Future<void> deleteTransaction(int id);
}