import '../models/transaction_item.dart';

abstract class TransactionRepository {
  Stream<List<TransactionItem>> watchLatest({int limit = 200});
  Stream<List<AccountBalance>> watchAccountBalances();
  Stream<MonthSummary> watchMonthSummary(DateTime month);

  Future<void> addIncomeExpense({
    required String type, // income|expense
    required int amountCents,
    required DateTime date,
    required String accountId,
    required String categoryId,
    String? description,
  });

  Future<void> addTransfer({
    required int amountCents,
    required DateTime date,
    required String fromAccountId,
    required String toAccountId,
    String? description,
  });

  Future<void> deleteTransaction(String id);
}
