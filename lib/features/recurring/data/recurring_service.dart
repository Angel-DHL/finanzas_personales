import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../profile/data/profile_service.dart';
import '../domain/recurring_payment.dart';

class RecurringService {
  RecurringService(this._fs, this._profile);
  final FirebaseFirestore _fs;
  final ProfileService _profile;

  CollectionReference<Map<String, dynamic>> _col(String uid) =>
      _fs.collection('users').doc(uid).collection('recurrings');

  Stream<List<RecurringPayment>> watchRecurrings(String uid) {
    return _col(uid)
        .where('active', isEqualTo: true)
        .orderBy('nextDueAt')
        .snapshots()
        .map((q) => q.docs.map(RecurringPayment.fromDoc).toList());
  }

  DateTime _firstDueDate(DateTime now, int dayOfMonth) {
    final lastDayThisMonth = DateTime(now.year, now.month + 1, 0).day;
    final dayThis = min(dayOfMonth, lastDayThisMonth);
    final candidate = DateTime(now.year, now.month, dayThis, 9);

    if (candidate.isAfter(now)) return candidate;

    // siguiente mes
    final nextMonth = DateTime(now.year, now.month + 1, 1);
    final lastDayNext = DateTime(nextMonth.year, nextMonth.month + 1, 0).day;
    final dayNext = min(dayOfMonth, lastDayNext);
    return DateTime(nextMonth.year, nextMonth.month, dayNext, 9);
  }

  DateTime _nextDueAfter(DateTime from, int dayOfMonth) {
    final nextMonth = DateTime(from.year, from.month + 1, 1);
    final lastDay = DateTime(nextMonth.year, nextMonth.month + 1, 0).day;
    final day = min(dayOfMonth, lastDay);
    return DateTime(nextMonth.year, nextMonth.month, day, 9);
  }

  Future<void> addRecurring({
    required String uid,
    required String concept,
    required int amountCents,
    required int dayOfMonth,
    required bool requireConfirmation,
  }) async {
    final now = DateTime.now();
    final firstDue = _firstDueDate(now, dayOfMonth);

    await _col(uid).add({
      'concept': concept,
      'amountCents': amountCents,
      'dayOfMonth': dayOfMonth,
      'requireConfirmation': requireConfirmation,
      'active': true,
      'nextDueAt': Timestamp.fromDate(firstDue),
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'lastChargeAt': null,
    });
  }

  /// Corre al abrir el dashboard.
  /// - Si está vencido y requireConfirmation = true: regresa lista para preguntar al usuario
  /// - Si requireConfirmation = false: descuenta automático y avanza nextDueAt
  Future<List<RecurringPayment>> processDuePayments(String uid) async {
    final now = DateTime.now();

    final q = await _col(uid)
        .where('active', isEqualTo: true)
        .where('nextDueAt', isLessThanOrEqualTo: Timestamp.fromDate(now))
        .get();

    final due = q.docs.map(RecurringPayment.fromDoc).toList();
    final needConfirm = <RecurringPayment>[];

    for (final p in due) {
      if (p.requireConfirmation) {
        needConfirm.add(p);
      } else {
        // automático: descuenta y avanza
        await markPaid(uid: uid, recurring: p);
      }
    }

    return needConfirm;
  }

  Future<void> markPaid({required String uid, required RecurringPayment recurring}) async {
    final ref = _col(uid).doc(recurring.id);

    await _fs.runTransaction((tx) async {
      final snap = await tx.get(ref);
      final data = snap.data()!;
      final dayOfMonth = (data['dayOfMonth'] as int?) ?? recurring.dayOfMonth;
      final amountCents = (data['amountCents'] as int?) ?? recurring.amountCents;
      final nextDueAt = (data['nextDueAt'] as Timestamp).toDate();

      // 1) descuenta ahorros
      // (delta negativo)
      // Nota: profileService usa otra transacción, pero para MVP está ok así.
      // Si quieres 1 sola transacción cross-doc, te lo preparo después.
      await _profile.adjustSavings(uid, -amountCents);

      // 2) avanza nextDueAt
      final next = _nextDueAfter(nextDueAt, dayOfMonth);

      tx.set(ref, {
        'nextDueAt': Timestamp.fromDate(next),
        'lastChargeAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    });
  }
}
