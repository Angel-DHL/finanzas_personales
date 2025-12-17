import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app_db.dart';


final dbProvider = Provider<AppDb>((ref) {
final db = AppDb();
ref.onDispose(db.close);
return db;
});