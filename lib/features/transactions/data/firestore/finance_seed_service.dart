import 'package:cloud_firestore/cloud_firestore.dart';
import 'finance_firestore_service.dart';

class FinanceSeedService {
  FinanceSeedService(this._fs, this._svc);
  final FirebaseFirestore _fs;
  final FinanceFirestoreService _svc;

  Future<void> seedIfEmpty(String uid) async {
    final accSnap = await _svc.accountsCol(uid).limit(1).get();
    final catSnap = await _svc.categoriesCol(uid).limit(1).get();

    final batch = _fs.batch();
    bool hasWrites = false;

    if (accSnap.docs.isEmpty) {
      hasWrites = true;

      final defaults = [
        {'name': 'Efectivo', 'kind': 'cash'},
        {'name': 'Banco', 'kind': 'bank'},
        {'name': 'Tarjeta', 'kind': 'card'},
        {'name': 'Ahorros', 'kind': 'savings'},
      ];

      for (final a in defaults) {
        final ref = _svc.accountsCol(uid).doc();
        final name = a['name']!;
        batch.set(ref, {
          'name': name,
          'nameLower': name.toLowerCase(),
          'kind': a['kind'],
          'openingBalanceCents': 0,
          'archived': false,
          'currency': 'MXN',
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
    }

    if (catSnap.docs.isEmpty) {
      hasWrites = true;

      final expense = [
        'Comida',
        'Transporte',
        'Renta',
        'Servicios',
        'Salud',
        'Suscripciones',
        'Compras',
        'Otros',
      ];

      for (var i = 0; i < expense.length; i++) {
        final ref = _svc.categoriesCol(uid).doc();
        final name = expense[i];
        batch.set(ref, {
          'name': name,
          'nameLower': name.toLowerCase(),
          'type': 'expense',
          'sortOrder': i, // quedan arriba
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      final income = ['Sueldo', 'Freelance', 'Ventas', 'Regalos', 'Otros'];
      for (var i = 0; i < income.length; i++) {
        final ref = _svc.categoriesCol(uid).doc();
        final name = income[i];
        batch.set(ref, {
          'name': name,
          'nameLower': name.toLowerCase(),
          'type': 'income',
          'sortOrder': i, // quedan arriba dentro de income si filtras
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
    }

    if (hasWrites) {
      await batch.commit();
    }
  }
}
