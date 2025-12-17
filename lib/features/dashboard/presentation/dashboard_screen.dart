import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';


import '../../../core/utils/money_format.dart';
import '../../transactions/presentation/transactions_controller.dart';


class DashboardScreen extends ConsumerWidget {
const DashboardScreen({super.key});


@override
Widget build(BuildContext context, WidgetRef ref) {
final balances = ref.watch(accountBalancesProvider);
final month = ref.watch(monthSummaryProvider);


return Scaffold(
appBar: AppBar(title: const Text('Dashboard')),
body: ListView(
padding: const EdgeInsets.all(16),
children: [
balances.when(
loading: () => const Center(child: CircularProgressIndicator()),
error: (e, _) => Text(e.toString()),
data: (items) {
final total = items.fold<int>(0, (s, a) => s + a.balanceCents);
return Column(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
Card(
child: Padding(
padding: const EdgeInsets.all(16),
child: Column(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
Text('Saldo total', style: Theme.of(context).textTheme.labelLarge),
const SizedBox(height: 8),
Text(formatMXNFromCents(total), style: Theme.of(context).textTheme.displaySmall),
],
),
),
),
const SizedBox(height: 12),
Text('Cuentas', style: Theme.of(context).textTheme.titleMedium),
const SizedBox(height: 8),
...items.map((a) => Card(
child: ListTile(
title: Text(a.name),
trailing: Text(formatMXNFromCents(a.balanceCents)),
),
)),
],
);
},
),
const SizedBox(height: 12),
month.when(
loading: () => const SizedBox.shrink(),
error: (e, _) => Text(e.toString()),
data: (m) {
return Card(
child: Padding(
padding: const EdgeInsets.all(16),
child: Column(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
Text('Este mes', style: Theme.of(context).textTheme.titleMedium),
const SizedBox(height: 8),
Row(
children: [
Expanded(child: Text('Ingresos: ${formatMXNFromCents(m.incomeCents)}')),
Expanded(child: Text('Egresos: ${formatMXNFromCents(m.expenseCents)}')),
],
),
const SizedBox(height: 8),
Text('Neto: ${formatMXNFromCents(m.netCents)}'),
],
),
),
);
},
),
],
),
);
}
}
