import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/utils/money_format.dart';
import '../data/recurring_providers.dart';

class RecurringScreen extends ConsumerWidget {
  const RecurringScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(recurringListProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Domiciliados / Recurrentes')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/recurring/add'),
        child: const Icon(Icons.add),
      ),
      body: items.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(e.toString())),
        data: (list) {
          if (list.isEmpty) return const Center(child: Text('Aún no tienes pagos recurrentes.'));
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: list.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (_, i) {
              final p = list[i];
              return Card(
                child: ListTile(
                  title: Text(p.concept),
                  subtitle: Text('Se cobra el día ${p.dayOfMonth} · ${p.requireConfirmation ? "Confirmar" : "Auto"}'),
                  trailing: Text(formatMXNFromCents(p.amountCents)),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
