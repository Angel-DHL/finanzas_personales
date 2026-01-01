import 'package:flutter_riverpod/flutter_riverpod.dart';

class MonthPoint {
  MonthPoint(this.label, this.incomeCents, this.expenseCents);
  final String label;
  final int incomeCents;
  final int expenseCents;
}

/// Demo temporal (reemplazable por Firestore luego)
final monthChartDemoProvider = Provider<List<MonthPoint>>((ref) {
  return [
    MonthPoint('Ene', 120000, 80000),
    MonthPoint('Feb', 110000, 70000),
    MonthPoint('Mar', 160000, 120000),
    MonthPoint('Abr', 140000, 90000),
    MonthPoint('May', 180000, 130000),
    MonthPoint('Jun', 170000, 100000),
  ];
});
