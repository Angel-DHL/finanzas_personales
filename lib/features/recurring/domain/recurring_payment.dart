import 'package:cloud_firestore/cloud_firestore.dart';

class RecurringPayment {
  RecurringPayment({
    required this.id,
    required this.concept,
    required this.amountCents,
    required this.dayOfMonth,
    required this.requireConfirmation,
    required this.active,
    required this.nextDueAt,
  });

  final String id;
  final String concept;
  final int amountCents;
  final int dayOfMonth; // 1-31
  final bool requireConfirmation; // si true, pregunta "pagado?"
  final bool active;
  final DateTime nextDueAt;

  static RecurringPayment fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data()!;
    return RecurringPayment(
      id: doc.id,
      concept: (d['concept'] as String?) ?? '',
      amountCents: (d['amountCents'] as int?) ?? 0,
      dayOfMonth: (d['dayOfMonth'] as int?) ?? 1,
      requireConfirmation: (d['requireConfirmation'] as bool?) ?? true,
      active: (d['active'] as bool?) ?? true,
      nextDueAt: (d['nextDueAt'] as Timestamp).toDate(),
    );
  }
}
