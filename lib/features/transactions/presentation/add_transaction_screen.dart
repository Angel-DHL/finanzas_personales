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

  final _amountCtrl = TextEditingController();
  final _descCtrl = TextEditingController();

  String _type = 'expense'; // income | expense | transfer
  DateTime _date = DateTime.now();

  String? _accountId;
  String? _categoryId;
  String? _fromAccountId;
  String? _toAccountId;

  bool _saving = false;
  bool _didSeed = false;

  @override
  void dispose() {
    _amountCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  int _parseCentsLoose(String input) {
    final normalized = input.replaceAll(',', '').trim();
    return parseCents(normalized);
  }

  String _formatDate(DateTime d) {
    final dd = d.day.toString().padLeft(2, '0');
    final mm = d.month.toString().padLeft(2, '0');
    final yy = d.year.toString();
    return '$dd/$mm/$yy';
  }

  Future<void> _pickDate(BuildContext context) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(now.year - 5, 1, 1),
      lastDate: DateTime(now.year + 5, 12, 31),
    );
    if (picked == null) return;
    setState(() => _date = DateTime(picked.year, picked.month, picked.day, _date.hour, _date.minute));
  }

  void _maybeSeed(String uid) {
    if (_didSeed) return;
    _didSeed = true;
    Future.microtask(() async {
      try {
        await ref.read(financeSeedServiceProvider).seedIfEmpty(uid);
      } catch (_) {}
    });
  }

  void _ensureDefaults(
    List<MapEntry<String, Map<String, dynamic>>> accounts,
    List<MapEntry<String, Map<String, dynamic>>> filteredCategories,
  ) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      String? pickFirstAccount() => accounts.isNotEmpty ? accounts.first.key : null;
      bool changed = false;

      if (_type != 'transfer') {
        final firstAcc = pickFirstAccount();
        if (_accountId == null || !accounts.any((a) => a.key == _accountId)) {
          _accountId = firstAcc;
          changed = true;
        }

        if (filteredCategories.isNotEmpty) {
          if (_categoryId == null || !filteredCategories.any((c) => c.key == _categoryId)) {
            _categoryId = filteredCategories.first.key;
            changed = true;
          }
        } else {
          if (_categoryId != null) {
            _categoryId = null;
            changed = true;
          }
        }
      }

      if (_type == 'transfer') {
        final first = pickFirstAccount();
        if (_fromAccountId == null || !accounts.any((a) => a.key == _fromAccountId)) {
          _fromAccountId = first;
          changed = true;
        }

        final second = accounts.length > 1 ? accounts[1].key : first;
        if (_toAccountId == null || !accounts.any((a) => a.key == _toAccountId)) {
          _toAccountId = second;
          changed = true;
        }
      }

      if (changed) setState(() {});
    });
  }

  Future<String?> _createAccount(BuildContext context, String uid) async {
    final nameCtrl = TextEditingController();
    String kind = 'cash';

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Nueva cuenta'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(labelText: 'Nombre (ej. Efectivo, BBVA...)'),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: kind,
              items: const [
                DropdownMenuItem(value: 'cash', child: Text('Efectivo')),
                DropdownMenuItem(value: 'bank', child: Text('Banco')),
                DropdownMenuItem(value: 'card', child: Text('Tarjeta')),
                DropdownMenuItem(value: 'savings', child: Text('Ahorros')),
                DropdownMenuItem(value: 'other', child: Text('Otro')),
              ],
              onChanged: (v) => kind = v ?? 'cash',
              decoration: const InputDecoration(labelText: 'Tipo'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Crear')),
        ],
      ),
    );

    if (ok != true) return null;

    final name = nameCtrl.text.trim();
    if (name.isEmpty) return null;

    final id = await ref.read(financeFirestoreServiceProvider).addAccount(
          uid: uid,
          name: name,
          kind: kind,
        );
    return id;
  }

  Future<String?> _createCategory(BuildContext context, String uid) async {
    if (_type == 'transfer') return null;

    final nameCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Nueva categoría (${_type == "income" ? "Ingreso" : "Egreso"})'),
        content: TextField(
          controller: nameCtrl,
          decoration: const InputDecoration(labelText: 'Nombre (ej. Gasolina, Sueldo...)'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Crear')),
        ],
      ),
    );

    if (ok != true) return null;

    final name = nameCtrl.text.trim();
    if (name.isEmpty) return null;

    final id = await ref.read(financeFirestoreServiceProvider).addCategory(
          uid: uid,
          name: name,
          type: _type, // income | expense
        );
    return id;
  }

  @override
  Widget build(BuildContext context) {
    final uid = ref.watch(uidProvider);
    final accountsAsync = ref.watch(accountsStreamProvider);
    final categoriesAsync = ref.watch(categoriesStreamProvider);

    final isWide = MediaQuery.sizeOf(context).width >= 950;

    if (uid != null) {
      _maybeSeed(uid);
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF4F8FF),
      body: uid == null
          ? const Center(child: Text('No autenticado'))
          : CustomScrollView(
              slivers: [
                SliverAppBar(
                  pinned: true,
                  elevation: 0,
                  backgroundColor: const Color(0xFF0A2E6B),
                  expandedHeight: 160,
                  leading: IconButton(
                    icon: const Icon(Icons.arrow_back),
                    onPressed: () => Navigator.of(context).maybePop(),
                  ),
                  title: const Text('Agregar movimiento'),
                  flexibleSpace: const FlexibleSpaceBar(background: _AddTxHeader()),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                  sliver: SliverToBoxAdapter(
                    child: Align(
                      alignment: Alignment.topCenter,
                      child: ConstrainedBox(
                        constraints: BoxConstraints(maxWidth: isWide ? 980 : double.infinity),
                        child: accountsAsync.when(
                          loading: () => const Padding(
                            padding: EdgeInsets.all(24),
                            child: Center(child: CircularProgressIndicator()),
                          ),
                          error: (e, _) => _ErrorBox(message: e.toString()),
                          data: (accounts) {
                            return categoriesAsync.when(
                              loading: () => const Padding(
                                padding: EdgeInsets.all(24),
                                child: Center(child: CircularProgressIndicator()),
                              ),
                              error: (e, _) => _ErrorBox(message: e.toString()),
                              data: (categories) {
                                final filteredCategories = categories
                                    .where((c) => (c.value['type'] as String?) == _type)
                                    .toList(growable: false);

                                _ensureDefaults(accounts, filteredCategories);

                                final canSave = accounts.isNotEmpty &&
                                    (_type == 'transfer' || filteredCategories.isNotEmpty);

                                return Form(
                                  key: _formKey,
                                  child: Column(
                                    children: [
                                      _SectionCard(
                                        title: 'Tipo de movimiento',
                                        child: SegmentedButton<String>(
                                          segments: const [
                                            ButtonSegment(value: 'expense', label: Text('Egreso'), icon: Icon(Icons.north_rounded)),
                                            ButtonSegment(value: 'income', label: Text('Ingreso'), icon: Icon(Icons.south_rounded)),
                                            ButtonSegment(value: 'transfer', label: Text('Transfer'), icon: Icon(Icons.swap_horiz_rounded)),
                                          ],
                                          selected: {_type},
                                          onSelectionChanged: (s) {
                                            setState(() {
                                              _type = s.first;
                                              _categoryId = null;
                                            });
                                          },
                                        ),
                                      ),
                                      const SizedBox(height: 12),

                                      _SectionCard(
                                        title: 'Detalles',
                                        child: Column(
                                          children: [
                                            Row(
                                              children: [
                                                Expanded(
                                                  child: TextFormField(
                                                    controller: _amountCtrl,
                                                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                                    decoration: _inputDeco(
                                                      label: 'Monto (MXN)',
                                                      prefixText: r'$ ',
                                                      hintText: '0.00',
                                                      icon: Icons.payments_rounded,
                                                    ),
                                                    validator: (v) {
                                                      final cents = _parseCentsLoose(v ?? '');
                                                      if (cents <= 0) return 'Ingresa un monto válido';
                                                      return null;
                                                    },
                                                  ),
                                                ),
                                                const SizedBox(width: 12),
                                                _DateButton(dateText: _formatDate(_date), onTap: () => _pickDate(context)),
                                              ],
                                            ),
                                            const SizedBox(height: 12),
                                            TextFormField(
                                              controller: _descCtrl,
                                              decoration: _inputDeco(
                                                label: 'Descripción (opcional)',
                                                hintText: 'Ej. Supermercado, gasolina…',
                                                icon: Icons.notes_rounded,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),

                                      const SizedBox(height: 12),

                                      if (_type != 'transfer')
                                        _SectionCard(
                                          title: 'Cuenta y categoría',
                                          child: Column(
                                            children: [
                                              DropdownButtonFormField<String>(
                                                value: _accountId,
                                                decoration: _inputDeco(
                                                  label: 'Cuenta',
                                                  icon: Icons.account_balance_wallet_rounded,
                                                ).copyWith(
                                                  suffixIcon: IconButton(
                                                    tooltip: 'Nueva cuenta',
                                                    icon: const Icon(Icons.add_circle_outline_rounded),
                                                    onPressed: () async {
                                                      final newId = await _createAccount(context, uid);
                                                      if (newId != null && mounted) {
                                                        setState(() => _accountId = newId);
                                                      }
                                                    },
                                                  ),
                                                ),
                                                items: accounts
                                                    .map((a) => DropdownMenuItem<String>(
                                                          value: a.key,
                                                          child: Text((a.value['name'] as String?) ?? 'Cuenta'),
                                                        ))
                                                    .toList(growable: false),
                                                onChanged: (v) => setState(() => _accountId = v),
                                              ),
                                              const SizedBox(height: 12),

                                              DropdownButtonFormField<String>(
                                                value: _categoryId,
                                                decoration: _inputDeco(
                                                  label: 'Categoría',
                                                  icon: Icons.grid_view_rounded,
                                                ).copyWith(
                                                  suffixIcon: IconButton(
                                                    tooltip: 'Nueva categoría',
                                                    icon: const Icon(Icons.add_circle_outline_rounded),
                                                    onPressed: () async {
                                                      final newId = await _createCategory(context, uid);
                                                      if (newId != null && mounted) {
                                                        setState(() => _categoryId = newId);
                                                      }
                                                    },
                                                  ),
                                                ),
                                                items: filteredCategories
                                                    .map((c) => DropdownMenuItem<String>(
                                                          value: c.key,
                                                          child: Text((c.value['name'] as String?) ?? 'Categoría'),
                                                        ))
                                                    .toList(growable: false),
                                                onChanged: (v) => setState(() => _categoryId = v),
                                              ),

                                              if (filteredCategories.isEmpty) ...[
                                                const SizedBox(height: 10),
                                                Align(
                                                  alignment: Alignment.centerLeft,
                                                  child: FilledButton.tonalIcon(
                                                    onPressed: () async {
                                                      final newId = await _createCategory(context, uid);
                                                      if (newId != null && mounted) {
                                                        setState(() => _categoryId = newId);
                                                      }
                                                    },
                                                    icon: const Icon(Icons.add),
                                                    label: const Text('Crear primera categoría'),
                                                  ),
                                                ),
                                              ],
                                            ],
                                          ),
                                        )
                                      else
                                        _SectionCard(
                                          title: 'Transferencia',
                                          child: Column(
                                            children: [
                                              DropdownButtonFormField<String>(
                                                value: _fromAccountId,
                                                decoration: _inputDeco(
                                                  label: 'De (cuenta origen)',
                                                  icon: Icons.call_made_rounded,
                                                ).copyWith(
                                                  suffixIcon: IconButton(
                                                    tooltip: 'Nueva cuenta',
                                                    icon: const Icon(Icons.add_circle_outline_rounded),
                                                    onPressed: () async {
                                                      final newId = await _createAccount(context, uid);
                                                      if (newId != null && mounted) {
                                                        setState(() {
                                                          _fromAccountId ??= newId;
                                                          _toAccountId ??= newId;
                                                        });
                                                      }
                                                    },
                                                  ),
                                                ),
                                                items: accounts.map((a) => DropdownMenuItem<String>(
                                                  value: a.key,
                                                  child: Text((a.value['name'] as String?) ?? 'Cuenta'),
                                                )).toList(growable: false),
                                                onChanged: (v) => setState(() => _fromAccountId = v),
                                              ),
                                              const SizedBox(height: 12),
                                              DropdownButtonFormField<String>(
                                                value: _toAccountId,
                                                decoration: _inputDeco(
                                                  label: 'A (cuenta destino)',
                                                  icon: Icons.call_received_rounded,
                                                ),
                                                items: accounts.map((a) => DropdownMenuItem<String>(
                                                  value: a.key,
                                                  child: Text((a.value['name'] as String?) ?? 'Cuenta'),
                                                )).toList(growable: false),
                                                onChanged: (v) => setState(() => _toAccountId = v),
                                              ),
                                              const SizedBox(height: 10),
                                              if (_fromAccountId != null && _toAccountId != null && _fromAccountId == _toAccountId)
                                                Text(
                                                  'La cuenta origen y destino no pueden ser la misma.',
                                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                                        color: Colors.red,
                                                        fontWeight: FontWeight.w700,
                                                      ),
                                                ),
                                            ],
                                          ),
                                        ),

                                      const SizedBox(height: 14),

                                      _SectionCard(
                                        title: 'Guardar',
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.stretch,
                                          children: [
                                            FilledButton.icon(
                                              onPressed: (!_saving && canSave)
                                                  ? () async {
                                                      if (!_formKey.currentState!.validate()) return;

                                                      if (_type == 'transfer' &&
                                                          (_fromAccountId == null ||
                                                              _toAccountId == null ||
                                                              _fromAccountId == _toAccountId)) {
                                                        ScaffoldMessenger.of(context).showSnackBar(
                                                          const SnackBar(content: Text('Selecciona cuentas distintas para la transferencia.')),
                                                        );
                                                        return;
                                                      }

                                                      setState(() => _saving = true);
                                                      try {
                                                        final repo = ref.read(transactionRepositoryProvider);
                                                        final cents = _parseCentsLoose(_amountCtrl.text);
                                                        final desc = _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim();

                                                        if (_type == 'transfer') {
                                                          await repo.addTransfer(
                                                            amountCents: cents,
                                                            date: _date,
                                                            fromAccountId: _fromAccountId!,
                                                            toAccountId: _toAccountId!,
                                                            description: desc,
                                                          );
                                                        } else {
                                                          if (_accountId == null || _categoryId == null) {
                                                            throw Exception('Falta seleccionar cuenta o categoría');
                                                          }
                                                          await repo.addIncomeExpense(
                                                            type: _type,
                                                            amountCents: cents,
                                                            date: _date,
                                                            accountId: _accountId!,
                                                            categoryId: _categoryId!,
                                                            description: desc,
                                                          );
                                                        }

                                                        if (!mounted) return;
                                                        Navigator.of(context).pop();
                                                      } catch (e) {
                                                        if (!mounted) return;
                                                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
                                                      } finally {
                                                        if (mounted) setState(() => _saving = false);
                                                      }
                                                    }
                                                  : null,
                                              icon: const Icon(Icons.save_rounded),
                                              label: Text(_saving ? 'Guardando…' : 'Guardar movimiento'),
                                              style: FilledButton.styleFrom(
                                                padding: const EdgeInsets.symmetric(vertical: 14),
                                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                                backgroundColor: const Color(0xFF0B3C91),
                                              ),
                                            ),
                                            const SizedBox(height: 10),
                                            Text(
                                              'Tip: mantén consistencia en categorías para mejores gráficas.',
                                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                                    color: const Color(0xFF0A2E6B).withOpacity(0.65),
                                                  ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

/// ---------------- UI helpers ----------------

class _AddTxHeader extends StatelessWidget {
  const _AddTxHeader();

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: DecoratedBox(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF051A3A), Color(0xFF0A2E6B), Color(0xFF1D4ED8)],
              ),
            ),
          ),
        ),
        Positioned(top: -40, right: -20, child: _Blob(color: Colors.white12, size: 170)),
        Positioned(bottom: -50, left: -30, child: _Blob(color: Colors.white10, size: 220)),
        Align(
          alignment: Alignment.bottomLeft,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Registra tu movimiento',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: Colors.white, fontWeight: FontWeight.w900)),
                const SizedBox(height: 6),
                Text('Ingreso, egreso o transferencia (MXN).',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.white.withOpacity(0.82), fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _Blob extends StatelessWidget {
  const _Blob({required this.color, required this.size});
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: size,
      width: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
        boxShadow: [BoxShadow(color: color, blurRadius: 60, spreadRadius: 10)],
      ),
    );
  }
}

InputDecoration _inputDeco({
  required String label,
  String? hintText,
  String? prefixText,
  required IconData icon,
}) {
  return InputDecoration(
    labelText: label,
    hintText: hintText,
    prefixText: prefixText,
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: const Color(0xFF0B3C91).withOpacity(0.12)),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: Color(0xFF0B3C91), width: 1.6),
    ),
    filled: true,
    fillColor: Colors.white,
    prefixIcon: Icon(icon, color: const Color(0xFF0B3C91)),
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
  );
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.child});
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF0B3C91).withOpacity(0.10)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 20, offset: const Offset(0, 10))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900, color: const Color(0xFF071A3A))),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

class _DateButton extends StatelessWidget {
  const _DateButton({required this.dateText, required this.onTap});
  final String dateText;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          width: 140,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFF0B3C91).withOpacity(0.12)),
          ),
          child: Row(
            children: [
              const Icon(Icons.calendar_month_rounded, color: Color(0xFF0B3C91), size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  dateText,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w800, color: const Color(0xFF071A3A)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ErrorBox extends StatelessWidget {
  const _ErrorBox({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.red.withOpacity(0.20)),
      ),
      child: Text(message),
    );
  }
}
