import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../profile/data/profile_providers.dart'; // uidProvider
import 'finance_firestore_service.dart';
import 'finance_seed_service.dart';

final financeFirestoreServiceProvider = Provider<FinanceFirestoreService>((ref) {
  return FinanceFirestoreService(FirebaseFirestore.instance);
});

final financeSeedServiceProvider = Provider<FinanceSeedService>((ref) {
  final svc = ref.read(financeFirestoreServiceProvider);
  return FinanceSeedService(FirebaseFirestore.instance, svc);
});

final accountsStreamProvider = StreamProvider<List<MapEntry<String, Map<String, dynamic>>>>((ref) {
  final uid = ref.watch(uidProvider);
  if (uid == null) return const Stream.empty();
  return ref.read(financeFirestoreServiceProvider).watchAccounts(uid);
});

final categoriesStreamProvider = StreamProvider<List<MapEntry<String, Map<String, dynamic>>>>((ref) {
  final uid = ref.watch(uidProvider);
  if (uid == null) return const Stream.empty();
  return ref.read(financeFirestoreServiceProvider).watchCategories(uid);
});
