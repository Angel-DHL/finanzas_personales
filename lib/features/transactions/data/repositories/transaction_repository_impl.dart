import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../profile/data/profile_providers.dart';
import '../firestore/finance_firestore_service.dart';
import '../../domain/models/transaction_item.dart';
import '../../domain/repositories/transaction_repository.dart';

class TransactionRepositoryImpl implements TransactionRepository {
  TransactionRepositoryImpl({
    required this.uid,
    required this.svc,
  });

  final String uid;
  final FinanceFirestoreService svc;

  @override
  Stream<List<TransactionItem>> watchLatest({int limit = 200}) {
    return svc.watchLatestTransactions(uid, limit: limit).map((rows) {
      return rows.map((e) {
        final id = e.key;
        final d = e.value;

        final date = (d['date'] as Timestamp).toDate();

        return TransactionItem(
          id: id,
          type: (d['type'] as String?) ?? 'expense',
          amountCents: (d['amountCents'] as int?) ?? 0,
          date: date,
          description: d['description'] as String?,
          accountName: d['accountName'] as String?,
          categoryName: d['categoryName'] as String?,
          fromAccountName: d['fromAccountName'] as String?,
          toAccountName: d['toAccountName'] as String?,
        );
      }).toList(growable: false);
    });
  }

  @override
  Stream<List<AccountBalance>> watchAccountBalances() {
    // Combina streams sin paquetes extra
    final controller = StreamController<List<AccountBalance>>.broadcast();

    List<MapEntry<String, Map<String, dynamic>>>? accounts;
    List<MapEntry<String, Map<String, dynamic>>>? txs;

    late final StreamSubscription subAcc;
    late final StreamSubscription subTx;

    void emitIfReady() {
      if (accounts == null || txs == null) return;

      final mapBalance = <String, int>{};

      // init con openingBalance
      for (final a in accounts!) {
        final opening = (a.value['openingBalanceCents'] as int?) ?? 0;
        mapBalance[a.key] = opening;
      }

      for (final t in txs!) {
        final d = t.value;
        final type = d['type'] as String?;
        final amount = (d['amountCents'] as int?) ?? 0;

        if (type == 'income') {
          final accId = d['accountId'] as String?;
          if (accId != null) mapBalance[accId] = (mapBalance[accId] ?? 0) + amount;
        } else if (type == 'expense') {
          final accId = d['accountId'] as String?;
          if (accId != null) mapBalance[accId] = (mapBalance[accId] ?? 0) - amount;
        } else if (type == 'transfer') {
          final fromId = d['fromAccountId'] as String?;
          final toId = d['toAccountId'] as String?;
          if (fromId != null) mapBalance[fromId] = (mapBalance[fromId] ?? 0) - amount;
          if (toId != null) mapBalance[toId] = (mapBalance[toId] ?? 0) + amount;
        }
      }

      final out = accounts!.map((a) {
        final name = (a.value['name'] as String?) ?? 'Cuenta';
        final bal = mapBalance[a.key] ?? 0;
        return AccountBalance(id: a.key, name: name, balanceCents: bal);
      }).toList(growable: false);

      controller.add(out);
    }

    subAcc = svc.watchAccounts(uid).listen((a) {
      accounts = a;
      emitIfReady();
    });

    // Para balances necesitamos todos los movimientos (si son pocos, perfecto).
    subTx = svc.transactionsCol(uid).snapshots().map((q) {
      return q.docs.map((d) => MapEntry(d.id, d.data())).toList();
    }).listen((t) {
      txs = t;
      emitIfReady();
    });

    controller.onCancel = () async {
      await subAcc.cancel();
      await subTx.cancel();
      await controller.close();
    };

    return controller.stream;
  }

  @override
  Stream<MonthSummary> watchMonthSummary(DateTime month) {
    final start = DateTime(month.year, month.month, 1);
    final end = DateTime(month.year, month.month + 1, 1);

    return svc.watchTransactionsInRange(uid, start: start, end: end).map((rows) {
      var income = 0;
      var expense = 0;

      for (final e in rows) {
        final d = e.value;
        final type = d['type'] as String?;
        final amount = (d['amountCents'] as int?) ?? 0;

        if (type == 'income') income += amount;
        if (type == 'expense') expense += amount;
      }

      return MonthSummary(incomeCents: income, expenseCents: expense);
    });
  }

  @override
  Future<void> addIncomeExpense({
    required String type,
    required int amountCents,
    required DateTime date,
    required String accountId,
    required String categoryId,
    String? description,
  }) async {
    final acc = await svc.getAccount(uid, accountId);
    final cat = await svc.getCategory(uid, categoryId);

    await svc.addTransaction(uid, {
      'type': type,
      'amountCents': amountCents,
      'date': Timestamp.fromDate(date),
      'description': description,
      'accountId': accountId,
      'accountName': acc?['name'],
      'categoryId': categoryId,
      'categoryName': cat?['name'],
    });
  }

  @override
  Future<void> addTransfer({
    required int amountCents,
    required DateTime date,
    required String fromAccountId,
    required String toAccountId,
    String? description,
  }) async {
    if (fromAccountId == toAccountId) {
      throw Exception('La cuenta origen y destino no pueden ser la misma');
    }

    final fromAcc = await svc.getAccount(uid, fromAccountId);
    final toAcc = await svc.getAccount(uid, toAccountId);

    await svc.addTransaction(uid, {
      'type': 'transfer',
      'amountCents': amountCents,
      'date': Timestamp.fromDate(date),
      'description': description,
      'fromAccountId': fromAccountId,
      'fromAccountName': fromAcc?['name'],
      'toAccountId': toAccountId,
      'toAccountName': toAcc?['name'],
    });
  }

  @override
  Future<void> deleteTransaction(String id) async {
    await svc.deleteTransaction(uid, id);
  }
}
