import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/money_format.dart';
import '../../profile/data/profile_providers.dart';
import '../data/recurring_providers.dart';

class AddRecurringScreen extends ConsumerStatefulWidget {
  const AddRecurringScreen({super.key});

  @override
  ConsumerState<AddRecurringScreen> createState() => _AddRecurringScreenState();
}

class _AddRecurringScreenState extends ConsumerState<AddRecurringScreen> {
  final _formKey = GlobalKey<FormState>();
  bool saving = false;

  String concept = '';
  String amount = '';
  int dayOfMonth = 15;
  bool requireConfirmation = true; // si false = auto descuento

  @override
  Widget build(BuildContext context) {
    final uid = ref.watch(uidProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Agregar recurrente')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              TextFormField(
                decoration: const InputDecoration(
                  labelText: 'Concepto',
                  border: OutlineInputBorder(),
                ),
                onChanged: (v) => concept = v,
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Escribe un concepto' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Monto (MXN)',
                  prefixText: r'$ ',
                  border: OutlineInputBorder(),
                ),
                onChanged: (v) => amount = v,
                validator: (v) => parseCents(v ?? '') <= 0 ? 'Ingresa un monto válido' : null,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<int>(
                value: dayOfMonth,
                decoration: const InputDecoration(
                  labelText: 'Día del mes en que se cobra',
                  border: OutlineInputBorder(),
                ),
                items: List.generate(31, (i) => i + 1)
                    .map((d) => DropdownMenuItem(value: d, child: Text('Día $d')))
                    .toList(),
                onChanged: (v) => setState(() => dayOfMonth = v ?? 15),
              ),
              const SizedBox(height: 12),
              SwitchListTile(
                value: requireConfirmation,
                onChanged: (v) => setState(() => requireConfirmation = v),
                title: const Text('Pedir confirmación al vencer'),
                subtitle: Text(requireConfirmation
                    ? 'Te preguntará si ya se pagó; si dices que sí, descuenta ahorros.'
                    : 'Al vencer, descuenta automáticamente de ahorros.'),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: saving
                    ? null
                    : () async {
                        if (uid == null) return;
                        if (!_formKey.currentState!.validate()) return;

                        setState(() => saving = true);
                        try {
                          await ref.read(recurringServiceProvider).addRecurring(
                                uid: uid,
                                concept: concept.trim(),
                                amountCents: parseCents(amount),
                                dayOfMonth: dayOfMonth,
                                requireConfirmation: requireConfirmation,
                              );
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
        ),
      ),
    );
  }
}
