import 'package:cloud_firestore/cloud_firestore.dart';

class FinanceFirestoreService {
  FinanceFirestoreService(this._fs);
  final FirebaseFirestore _fs;

  DocumentReference<Map<String, dynamic>> _userDoc(String uid) =>
      _fs.collection('users').doc(uid);

  CollectionReference<Map<String, dynamic>> accountsCol(String uid) =>
      _userDoc(uid).collection('accounts');

  CollectionReference<Map<String, dynamic>> categoriesCol(String uid) =>
      _userDoc(uid).collection('categories');

  CollectionReference<Map<String, dynamic>> transactionsCol(String uid) =>
      _userDoc(uid).collection('transactions');

  // -------- Accounts ----------
  Stream<List<MapEntry<String, Map<String, dynamic>>>> watchAccounts(String uid) {
    return accountsCol(uid)
        .where('archived', isEqualTo: false)
        .orderBy('name')
        .snapshots()
        .map((q) => q.docs.map((d) => MapEntry(d.id, d.data())).toList());
  }

  Future<Map<String, dynamic>?> getAccount(String uid, String id) async {
    final snap = await accountsCol(uid).doc(id).get();
    return snap.data();
  }

  // -------- Categories ----------
  Stream<List<MapEntry<String, Map<String, dynamic>>>> watchCategories(String uid, {String? type}) {
    Query<Map<String, dynamic>> q = categoriesCol(uid).orderBy('sortOrder');
    if (type != null) q = q.where('type', isEqualTo: type);
    return q.snapshots().map((q) => q.docs.map((d) => MapEntry(d.id, d.data())).toList());
  }

  Future<Map<String, dynamic>?> getCategory(String uid, String id) async {
    final snap = await categoriesCol(uid).doc(id).get();
    return snap.data();
  }

  // -------- Transactions ----------
  Stream<List<MapEntry<String, Map<String, dynamic>>>> watchLatestTransactions(String uid, {int limit = 200}) {
    return transactionsCol(uid)
        .orderBy('date', descending: true)
        .limit(limit)
        .snapshots()
        .map((q) => q.docs.map((d) => MapEntry(d.id, d.data())).toList());
  }

  Stream<List<MapEntry<String, Map<String, dynamic>>>> watchTransactionsInRange(
    String uid, {
    required DateTime start,
    required DateTime end,
  }) {
    final startTs = Timestamp.fromDate(start);
    final endTs = Timestamp.fromDate(end);

    return transactionsCol(uid)
        .where('date', isGreaterThanOrEqualTo: startTs)
        .where('date', isLessThan: endTs)
        .orderBy('date', descending: true)
        .snapshots()
        .map((q) => q.docs.map((d) => MapEntry(d.id, d.data())).toList());
  }

  Future<void> addTransaction(String uid, Map<String, dynamic> data) async {
    await transactionsCol(uid).add({
      ...data,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteTransaction(String uid, String txId) async {
    await transactionsCol(uid).doc(txId).delete();
  }
}
