import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';


import 'tables.dart';


part 'app_db.g.dart';


@DriftDatabase(tables: [Categories, Accounts, Transactions])
class AppDb extends _$AppDb {
AppDb() : super(driftDatabase(name: 'finance'));

@override
int get schemaVersion => 2;
}
