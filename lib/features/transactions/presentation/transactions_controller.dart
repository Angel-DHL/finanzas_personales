import 'package:flutter_riverpod/flutter_riverpod.dart';


import '../data/repositories/provider.dart';
import '../domain/models/transaction_item.dart';


final latestTransactionsProvider = StreamProvider<List<TransactionItem>>((ref) {
return ref.read(transactionRepositoryProvider).watchLatest();
});


final accountBalancesProvider = StreamProvider<List<AccountBalance>>((ref) {
return ref.read(transactionRepositoryProvider).watchAccountBalances();
});


final monthSummaryProvider = StreamProvider<MonthSummary>((ref) {
final now = DateTime.now();
return ref.read(transactionRepositoryProvider).watchMonthSummary(DateTime(now.year, now.month, 1));
});