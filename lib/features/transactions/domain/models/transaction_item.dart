class TransactionItem {
  TransactionItem({
    required this.id,
    required this.type,
    required this.amountCents,
    required this.date,
    this.description,
    this.accountName,
    this.categoryName,
    this.fromAccountName,
    this.toAccountName,
  });

  final String id;
  final String type; // income | expense | transfer
  final int amountCents;
  final DateTime date;
  final String? description;

  final String? accountName;
  final String? categoryName;

  final String? fromAccountName;
  final String? toAccountName;
}

class AccountBalance {
  AccountBalance({required this.id, required this.name, required this.balanceCents});
  final String id;
  final String name;
  final int balanceCents;
}

class MonthSummary {
  MonthSummary({required this.incomeCents, required this.expenseCents});
  final int incomeCents;
  final int expenseCents;
  int get netCents => incomeCents - expenseCents;
}
