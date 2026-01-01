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

  // -----------------------------
  // Helpers: leer ints y delta savings
  // -----------------------------
  int _readInt(dynamic v, {int fallback = 0}) {
    if (v is int) return v;
    if (v is num) return v.round();
    if (v is String) return int.tryParse(v) ?? fallback;
    return fallback;
  }

  /// Regla para AHORROS:
  /// - income  => SUMA
  /// - expense => RESTA
  /// - transfer => RESTA ✅ (como pediste)
  int _deltaForSavingsFromTxData(Map<String, dynamic> data) {
    final type = (data['type'] as String?) ?? '';
    final amount = _readInt(data['amountCents'], fallback: 0);

    if (amount == 0) return 0;

    switch (type) {
      case 'income':
        return amount;
      case 'expense':
      case 'transfer':
        return -amount;
      default:
        return 0;
    }
  }

  // -------- Accounts ----------

  /// ✅ Importante:
  /// Antes tenías: .where('archived', false).orderBy('name')
  /// Eso te exige índice compuesto.
  /// Aquí evitamos el índice: traemos todo ordenado por name y filtramos en cliente.
  Stream<List<MapEntry<String, Map<String, dynamic>>>> watchAccounts(String uid) {
    return accountsCol(uid)
        .orderBy('name')
        .snapshots()
        .map((q) => q.docs
            .map((d) => MapEntry(d.id, d.data()))
            .where((e) => (e.value['archived'] as bool?) != true)
            .toList());
  }

  Future<Map<String, dynamic>?> getAccount(String uid, String id) async {
    final snap = await accountsCol(uid).doc(id).get();
    return snap.data();
  }

  /// ✅ Crear cuenta (para tu botón "+" en AddTransaction)
  Future<String> addAccount({
    required String uid,
    required String name,
    String currency = 'MXN',
    int openingBalanceCents = 0,
    String kind = 'cash', // cash | bank | card | savings | other (opcional)
  }) async {
    final ref = accountsCol(uid).doc();
    await ref.set({
      'name': name.trim(),
      'nameLower': name.trim().toLowerCase(),
      'kind': kind,
      'currency': currency,
      'openingBalanceCents': openingBalanceCents,
      'archived': false,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    return ref.id;
  }

  Future<void> archiveAccount(String uid, String accountId, {bool archived = true}) async {
    await accountsCol(uid).doc(accountId).set({
      'archived': archived,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  // -------- Categories ----------

  /// ✅ Igual que accounts: evitamos where+orderBy para no pedir índice.
  /// Traemos todo por sortOrder y filtramos por type en cliente si se pide.
  Stream<List<MapEntry<String, Map<String, dynamic>>>> watchCategories(
    String uid, {
    String? type, // 'income' | 'expense'
  }) {
    return categoriesCol(uid)
        .orderBy('sortOrder')
        .snapshots()
        .map((q) {
          final all = q.docs.map((d) => MapEntry(d.id, d.data())).toList();
          if (type == null) return all;
          return all.where((e) => (e.value['type'] as String?) == type).toList();
        });
  }

  Future<Map<String, dynamic>?> getCategory(String uid, String id) async {
    final snap = await categoriesCol(uid).doc(id).get();
    return snap.data();
  }

  /// ✅ Crear categoría (income/expense)
  /// Nota: usamos sortOrder = timestamp para que siempre quede al final sin hacer queries extra.
  Future<String> addCategory({
    required String uid,
    required String name,
    required String type, // 'income' | 'expense'
    int? sortOrder,
  }) async {
    final ref = categoriesCol(uid).doc();
    await ref.set({
      'name': name.trim(),
      'nameLower': name.trim().toLowerCase(),
      'type': type,
      'sortOrder': sortOrder ?? DateTime.now().millisecondsSinceEpoch,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    return ref.id;
  }

  // -------- Transactions ----------

  Stream<List<MapEntry<String, Map<String, dynamic>>>> watchLatestTransactions(
    String uid, {
    int limit = 200,
  }) {
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

  /// ✅ MODIFICADO:
  /// - Guarda la transacción
  /// - Actualiza users/{uid}.savingsCents en el mismo runTransaction()
  Future<void> addTransaction(String uid, Map<String, dynamic> data) async {
    final userRef = _userDoc(uid);
    final txRef = transactionsCol(uid).doc(); // generamos id como .add()

    final delta = _deltaForSavingsFromTxData(data);

    await _fs.runTransaction((tr) async {
      final userSnap = await tr.get(userRef);

      // Guardamos el movimiento
      tr.set(txRef, {
        ...data,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Actualizamos savingsCents (si user no existe, lo creamos con merge)
      if (userSnap.exists) {
        tr.update(userRef, {
          'savingsCents': FieldValue.increment(delta),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      } else {
        tr.set(
          userRef,
          {
            'savingsCents': delta,
            'updatedAt': FieldValue.serverTimestamp(),
            'createdAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );
      }
    });
  }

  /// ✅ MODIFICADO:
  /// - Borra el movimiento
  /// - Revierte su impacto en savingsCents
  Future<void> deleteTransaction(String uid, String txId) async {
    final userRef = _userDoc(uid);
    final txRef = transactionsCol(uid).doc(txId);

    await _fs.runTransaction((tr) async {
      final txSnap = await tr.get(txRef);
      if (!txSnap.exists) return;

      final txData = txSnap.data() ?? <String, dynamic>{};
      final appliedDelta = _deltaForSavingsFromTxData(txData);

      // Revertimos: si antes sumó, ahora restamos; si antes restó, ahora sumamos.
      final revert = -appliedDelta;

      final userSnap = await tr.get(userRef);

      if (userSnap.exists) {
        tr.update(userRef, {
          'savingsCents': FieldValue.increment(revert),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      } else {
        tr.set(
          userRef,
          {
            'savingsCents': revert,
            'updatedAt': FieldValue.serverTimestamp(),
            'createdAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );
      }

      tr.delete(txRef);
    });
  }
}
