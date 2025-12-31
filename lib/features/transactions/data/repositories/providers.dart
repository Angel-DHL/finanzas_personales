import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../profile/data/profile_providers.dart';
import '../firestore/finance_firestore_service.dart';
import '../firestore/firestore_providers.dart';
import '../../domain/repositories/transaction_repository.dart';
import 'transaction_repository_impl.dart';

final transactionRepositoryProvider = Provider<TransactionRepository>((ref) {
  final uid = ref.watch(uidProvider);
  if (uid == null) {
    throw Exception('No hay usuario autenticado');
  }

  final svc = ref.read(financeFirestoreServiceProvider);
  return TransactionRepositoryImpl(uid: uid, svc: svc);
});
