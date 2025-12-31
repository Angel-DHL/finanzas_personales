import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../profile/data/profile_providers.dart';
import '../../profile/data/profile_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'recurring_service.dart';
import '../domain/recurring_payment.dart';

final recurringServiceProvider = Provider<RecurringService>((ref) {
  final fs = ref.read(firestoreProvider);
  final profile = ref.read(profileServiceProvider);
  return RecurringService(fs, profile);
});

final recurringListProvider = StreamProvider<List<RecurringPayment>>((ref) {
  final uid = ref.watch(uidProvider);
  if (uid == null) return const Stream.empty();
  return ref.read(recurringServiceProvider).watchRecurrings(uid);
});
