import 'package:drift/drift.dart';


import "package:finanzas_personales/features/transactions/data/local/app_db.dart";
import "package:finanzas_personales/features/transactions/domain/models/transaction_item.dart";
import "package:finanzas_personales/features/transactions/domain/repositories/transaction_repository.dart";


class TransactionRepositoryImpl implements TransactionRepository {
TransactionRepositoryImpl(this.db);
final AppDb db;


@override
Stream<List<TransactionItem>> watchLatest({int limit = 200}) {
final t = db.transactions;
final c = db.categories;
final a = db.accounts;


final fromA = db.accounts.createAlias('from_a');
final toA   = db.accounts.createAlias('to_a');

final q = db.select(t).join([
leftOuterJoin(c, c.id.equalsExp(t.categoryId)),
leftOuterJoin(a, a.id.equalsExp(t.accountId)),
leftOuterJoin(fromA, fromA.id.equalsExp(t.fromAccountId)),
leftOuterJoin(toA, toA.id.equalsExp(t.toAccountId)),
])
..orderBy([OrderingTerm.desc(t.date), OrderingTerm.desc(t.id)])
..limit(limit);


return q.watch().map((rows) {
return rows.map((row) {
final tx = row.readTable(t);
final cat = row.readTableOrNull(c);
final acc = row.readTableOrNull(a);
final fromAcc = row.readTableOrNull(fromA);
final toAcc = row.readTableOrNull(toA);

return TransactionItem(
id: tx.id,
type: tx.type,
amountCents: tx.amountCents,
date: tx.date,
description: tx.description,
accountName: acc?.name,
categoryName: cat?.name,
fromAccountName: fromAcc?.name,
toAccountName: toAcc?.name,
);
}).toList(growable: false);
});
}

@override
Stream<List<AccountBalance>> watchAccountBalances() {
// SQL agregado para calcular balance por cuenta en tiempo real
final sql = '''
SELECT
a.id as id,
a.name as name,
a.opening_balance_cents
+ COALESCE(SUM(
CASE
WHEN t.type = 'income' AND t.account_id = a.id THEN t.amount_cents
WHEN t.type = 'expense' AND t.account_id = a.id THEN -t.amount_cents
WHEN t.type = 'transfer' AND t.to_account_id = a.id THEN t.amount_cents
WHEN t.type = 'transfer' AND t.from_account_id = a.id THEN -t.amount_cents
ELSE 0
END
), 0) AS balance_cents
FROM accounts a
LEFT JOIN transactions t
ON t.account_id = a.id
OR t.from_account_id = a.id
OR t.to_account_id = a.id
WHERE a.archived = 0
GROUP BY a.id, a.name, a.opening_balance_cents
ORDER BY a.id;
''';


final query = db.customSelect(
sql,
readsFrom: {db.accounts, db.transactions},
);

return query.watch().map((rows) {
return rows.map((r) {
return AccountBalance(
id: r.read<int>('id'),
name: r.read<String>('name'),
balanceCents: r.read<int>('balance_cents'),
);
}).toList(growable: false);
});
}

@override
Stream<MonthSummary> watchMonthSummary(DateTime month) {
final start = DateTime(month.year, month.month, 1);
final end = DateTime(month.year, month.month + 1, 1);


final t = db.transactions;
final q = (db.select(t)
..where((x) => x.date.isBetweenValues(start, end))
..addColumns([t.type, t.amountCents]))
.watch();


return q.map((rows) {
var income = 0;
var expense = 0;
for (final r in rows) {
if (r.type == 'income') income += r.amountCents;
if (r.type == 'expense') expense += r.amountCents;
}
return MonthSummary(incomeCents: income, expenseCents: expense);
});
}

@override
Future<void> addIncomeExpense({
required String type,
required int amountCents,
required DateTime date,
required int accountId,
required int categoryId,
String? description,
}) async {
await db.into(db.transactions).insert(TransactionsCompanion.insert(
type: type,
amountCents: amountCents,
date: date,
accountId: Value(accountId),
categoryId: Value(categoryId),
description: Value(description),
));
}

@override
Future<void> addTransfer({
required int amountCents,
required DateTime date,
required int fromAccountId,
required int toAccountId,
String? description,
}) async {
if (fromAccountId == toAccountId) {
throw Exception('La cuenta origen y destino no pueden ser la misma');
}
await db.into(db.transactions).insert(TransactionsCompanion.insert(
type: 'transfer',
amountCents: amountCents,
date: date,
fromAccountId: Value(fromAccountId),
toAccountId: Value(toAccountId),
description: Value(description),
));
}

@override
Future<void> deleteTransaction(int id) async {
await (db.delete(db.transactions)..where((t) => t.id.equals(id))).go();
}
}