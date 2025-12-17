import 'package:drift/drift.dart';
import 'app_db.dart';

Future<void> seedIfEmpty(AppDb db) async {
  final accountsCount = await db.select(db.accounts).get();
  if (accountsCount.isEmpty) {
    await db.into(db.accounts).insert(AccountsCompanion.insert(
      name: 'Efectivo',
      openingBalanceCents: const Value(0),
    ));
    await db.into(db.accounts).insert(AccountsCompanion.insert(
      name: 'Tarjeta',
      openingBalanceCents: const Value(0),
    ));
  }

  final categoriesCount = await db.select(db.categories).get();
  if (categoriesCount.isEmpty) {
    final expense = [
      'Comida','Transporte','Renta','Servicios','Salud','Suscripciones','Compras','Otros',
    ];

    for (var i = 0; i < expense.length; i++) {
      await db.into(db.categories).insert(CategoriesCompanion.insert(
        name: expense[i],
        type: 'expense',
        sortOrder: Value(i),
      ));
    }

    final income = ['Sueldo', 'Freelance', 'Ventas', 'Regalos', 'Otros'];
    for (var i = 0; i < income.length; i++) {
      await db.into(db.categories).insert(CategoriesCompanion.insert(
        name: income[i],
        type: 'income',
        sortOrder: Value(i),
      ));
    }
  }
}
