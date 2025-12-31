import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/utils/money_format.dart';
import '../data/repositories/providers.dart';
import 'transactions_controller.dart';

class TransactionsScreen extends ConsumerWidget {
  const TransactionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tx = ref.watch(latestTransactionsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Movimientos')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/transactions/add'),
        child: const Icon(Icons.add),
      ),
      body: tx.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(e.toString())),
        data: (items) {
          if (items.isEmpty) {
            return const Center(child: Text('Aún no tienes movimientos.'));
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, i) {
              final it = items[i];
              final sign = it.type == 'expense' || it.type == 'transfer' ? '-' : '+';
              final subtitle = it.type == 'transfer'
                  ? 'De ${it.fromAccountName ?? ""} → ${it.toAccountName ?? ""}'
                  : '${it.categoryName ?? "Sin categoría"} · ${it.accountName ?? ""}';

              return Card(
                child: ListTile(
                  leading: Icon(
                    it.type == 'income'
                        ? Icons.arrow_downward
                        : it.type == 'expense'
                            ? Icons.arrow_upward
                            : Icons.compare_arrows,
                  ),
                  title: Text(it.description?.isNotEmpty == true ? it.description! : 'Movimiento'),
                  subtitle: Text(subtitle),
                  trailing: Text('$sign ${formatMXNFromCents(it.amountCents)}'),
                  onLongPress: () async {
                    final ok = await showDialog<bool>(
                      context: context,
                      builder: (_) => AlertDialog(
                        title: const Text('Eliminar'),
                        content: const Text('¿Eliminar este movimiento?'),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
                          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Eliminar')),
                        ],
                      ),
                    );

                    if (ok == true) {
                      await ref.read(transactionRepositoryProvider).deleteTransaction(it.id);
                    }
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}
