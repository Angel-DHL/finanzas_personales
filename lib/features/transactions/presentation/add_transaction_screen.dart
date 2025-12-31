import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/money_format.dart';
import '../../profile/data/profile_providers.dart';
import '../data/firestore/firestore_providers.dart';
import '../data/repositories/providers.dart';

class AddTransactionScreen extends ConsumerStatefulWidget {
  const AddTransactionScreen({super.key});

  @override
  ConsumerState<AddTransactionScreen> createState() => _AddTransactionScreenState();
}

class _AddTransactionScreenState extends ConsumerState<AddTransactionScreen> {
  final _formKey = GlobalKey<FormState>();

  String type = 'expense'; // income | expense | transfer
  String amount = '';
  String description = '';
  DateTime date = DateTime.now();

  String? accountId;
  String? categoryId;
  String? fromAccountId;
  String? toAccountId;

  bool saving = false;

  @override
  Widget build(BuildContext context) {
    final uid = ref.watch(uidProvider);
    final accountsAsync = ref.watch(accountsStreamProvider);
    final categoriesAsync = ref.watch(categoriesStreamProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Agregar movimiento')),
      body: uid == null
          ? const Center(child: Text('No autenticado'))
          : SafeArea(
              child: accountsAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text(e.toString())),
                data: (accounts) {
                  return categoriesAsync.when(
                    loading: () => const Center(child: CircularProgressIndicator()),
                    error: (e, _) => Center(child: Text(e.toString())),
                    data: (categories) {
                      final filteredCategories = categories.where((c) => c.value['type'] == type).toList();

                      accountId ??= accounts.isNotEmpty ? accounts.first.key : null;
                      fromAccountId ??= accounts.isNotEmpty ? accounts.first.key : null;
                      toAccountId ??= accounts.length > 1 ? accounts[1].key : fromAccountId;
                      categoryId ??= filteredCategories.isNotEmpty ? filteredCategories.first.key : null;

                      return Form(
                        key: _formKey,
                        child: ListView(
                          padding: const EdgeInsets.all(16),
                          children: [
                            SegmentedButton<String>(
                              segments: const [
                                ButtonSegment(value: 'expense', label: Text('Egreso'), icon: Icon(Icons.arrow_upward)),
                                ButtonSegment(value: 'income', label: Text('Ingreso'), icon: Icon(Icons.arrow_downward)),
                                ButtonSegment(value: 'transfer', label: Text('Transfer'), icon: Icon(Icons.compare_arrows)),
                              ],
                              selected: {type},
                              onSelectionChanged: (s) {
                                setState(() {
                                  type = s.first;
                                  categoryId = null;
                                });
                              },
                            ),
                            const SizedBox(height: 16),

                            TextFormField(
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              decoration: const InputDecoration(
                                labelText: 'Monto (MXN)',
                                prefixText: r'$ ',
                                border: OutlineInputBorder(),
                              ),
                              onChanged: (v) => amount = v,
                              validator: (v) {
                                final cents = parseCents(v ?? '');
                                if (cents <= 0) return 'Ingresa un monto válido';
                                return null;
                              },
                            ),
                            const SizedBox(height: 12),

                            TextFormField(
                              decoration: const InputDecoration(
                                labelText: 'Descripción (opcional)',
                                border: OutlineInputBorder(),
                              ),
                              onChanged: (v) => description = v,
                            ),
                            const SizedBox(height: 12),

                            if (type != 'transfer') ...[
                              DropdownButtonFormField<String>(
                                value: accountId,
                                decoration: const InputDecoration(
                                  labelText: 'Cuenta',
                                  border: OutlineInputBorder(),
                                ),
                                items: accounts
                                    .map((a) => DropdownMenuItem<String>(
                                          value: a.key,
                                          child: Text((a.value['name'] as String?) ?? 'Cuenta'),
                                        ))
                                    .toList(),
                                onChanged: (v) => setState(() => accountId = v),
                              ),
                              const SizedBox(height: 12),
                              DropdownButtonFormField<String>(
                                value: categoryId,
                                decoration: const InputDecoration(
                                  labelText: 'Categoría',
                                  border: OutlineInputBorder(),
                                ),
                                items: filteredCategories
                                    .map((c) => DropdownMenuItem<String>(
                                          value: c.key,
                                          child: Text((c.value['name'] as String?) ?? 'Categoría'),
                                        ))
                                    .toList(),
                                onChanged: (v) => setState(() => categoryId = v),
                              ),
                            ] else ...[
                              DropdownButtonFormField<String>(
                                value: fromAccountId,
                                decoration: const InputDecoration(
                                  labelText: 'De (Cuenta origen)',
                                  border: OutlineInputBorder(),
                                ),
                                items: accounts
                                    .map((a) => DropdownMenuItem<String>(
                                          value: a.key,
                                          child: Text((a.value['name'] as String?) ?? 'Cuenta'),
                                        ))
                                    .toList(),
                                onChanged: (v) => setState(() => fromAccountId = v),
                              ),
                              const SizedBox(height: 12),
                              DropdownButtonFormField<String>(
                                value: toAccountId,
                                decoration: const InputDecoration(
                                  labelText: 'A (Cuenta destino)',
                                  border: OutlineInputBorder(),
                                ),
                                items: accounts
                                    .map((a) => DropdownMenuItem<String>(
                                          value: a.key,
                                          child: Text((a.value['name'] as String?) ?? 'Cuenta'),
                                        ))
                                    .toList(),
                                onChanged: (v) => setState(() => toAccountId = v),
                              ),
                            ],

                            const SizedBox(height: 16),
                            FilledButton.icon(
                              onPressed: saving
                                  ? null
                                  : () async {
                                      if (!_formKey.currentState!.validate()) return;

                                      setState(() => saving = true);
                                      try {
                                        final repo = ref.read(transactionRepositoryProvider);
                                        final cents = parseCents(amount);

                                        if (type == 'transfer') {
                                          await repo.addTransfer(
                                            amountCents: cents,
                                            date: date,
                                            fromAccountId: fromAccountId!,
                                            toAccountId: toAccountId!,
                                            description: description.isEmpty ? null : description,
                                          );
                                        } else {
                                          await repo.addIncomeExpense(
                                            type: type,
                                            amountCents: cents,
                                            date: date,
                                            accountId: accountId!,
                                            categoryId: categoryId!,
                                            description: description.isEmpty ? null : description,
                                          );
                                        }

                                        if (mounted) Navigator.of(context).pop();
                                      } catch (e) {
                                        if (!mounted) return;
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(SnackBar(content: Text(e.toString())));
                                      } finally {
                                        if (mounted) setState(() => saving = false);
                                      }
                                    },
                              icon: const Icon(Icons.save),
                              label: Text(saving ? 'Guardando…' : 'Guardar'),
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ),
    );
  }
}
