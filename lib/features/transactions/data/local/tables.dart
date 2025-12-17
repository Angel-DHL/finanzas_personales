import 'package:drift/drift.dart';


class Categories extends Table {
IntColumn get id => integer().autoIncrement()();
TextColumn get name => text()();
TextColumn get type => text()(); // income | expense
IntColumn get sortOrder => integer().withDefault(const Constant(0))();
}


class Accounts extends Table {
IntColumn get id => integer().autoIncrement()();
TextColumn get name => text()();
IntColumn get openingBalanceCents => integer().withDefault(const Constant(0))();
BoolColumn get archived => boolean().withDefault(const Constant(false))();
// MXN fijo (si un día quieres multi-moneda, aquí lo abres)
TextColumn get currency => text().withDefault(const Constant('MXN'))();
}

class Transactions extends Table {
IntColumn get id => integer().autoIncrement()();


/// income | expense | transfer
TextColumn get type => text()();


/// Guardamos en centavos para evitar errores de double
IntColumn get amountCents => integer()();


DateTimeColumn get date => dateTime()();
TextColumn get description => text().nullable()();


/// Para income/expense
IntColumn get accountId => integer().nullable().references(Accounts, #id)();
IntColumn get categoryId => integer().nullable().references(Categories, #id)();


/// Para transfer
IntColumn get fromAccountId => integer().nullable().references(Accounts, #id)();
IntColumn get toAccountId => integer().nullable().references(Accounts, #id)();
}