import 'package:flutter_riverpod/flutter_riverpod.dart';


import '../local/db_provider.dart';
import 'transaction_repository_impl.dart';
import "package:finanzas_personales/features/transactions/domain/repositories/transaction_repository.dart";
import "package:finanzas_personales/features/transactions/domain/repositories/transaction_repository_impl.dart";

final transactionRepositoryProvider = Provider<TransactionRepository>((ref) {
final db = ref.read(dbProvider);
return TransactionRepositoryImpl(db);
});