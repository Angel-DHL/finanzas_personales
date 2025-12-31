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

    if (accSnap.docs.isEmpty) {
      final a1 = _svc.accountsCol(uid).doc();
      final a2 = _svc.accountsCol(uid).doc();
      batch.set(a1, {
        'name': 'Efectivo',
        'openingBalanceCents': 0,
        'archived': false,
        'currency': 'MXN',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      batch.set(a2, {
        'name': 'Tarjeta',
        'openingBalanceCents': 0,
        'archived': false,
        'currency': 'MXN',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }

    if (catSnap.docs.isEmpty) {
      final expense = [
        'Comida','Transporte','Renta','Servicios','Salud','Suscripciones','Compras','Otros',
      ];
      for (var i = 0; i < expense.length; i++) {
        final c = _svc.categoriesCol(uid).doc();
        batch.set(c, {
          'name': expense[i],
          'type': 'expense',
          'sortOrder': i,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      final income = ['Sueldo', 'Freelance', 'Ventas', 'Regalos', 'Otros'];
      for (var i = 0; i < income.length; i++) {
        final c = _svc.categoriesCol(uid).doc();
        batch.set(c, {
          'name': income[i],
          'type': 'income',
          'sortOrder': i,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
    }

    await batch.commit();
  }
}
