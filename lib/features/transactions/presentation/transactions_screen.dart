import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/utils/money_format.dart';
import '../data/repositories/providers.dart';
import 'transactions_controller.dart';

enum TxTypeFilter { all, income, expense, transfer }
enum TxSort { dateDesc, dateAsc, amountDesc, amountAsc }

class TransactionsScreen extends ConsumerStatefulWidget {
  const TransactionsScreen({super.key});

  @override
  ConsumerState<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends ConsumerState<TransactionsScreen> {
  TxTypeFilter _typeFilter = TxTypeFilter.all;
  TxSort _sort = TxSort.dateDesc;
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final tx = ref.watch(latestTransactionsProvider);

    final isWide = MediaQuery.sizeOf(context).width >= 950;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F8FF),
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            expandedHeight: 140,
            elevation: 0,
            backgroundColor: const Color(0xFF0B3C91),
            title: const Text('Movimientos'),
            actions: [
              IconButton(
                tooltip: 'Agregar movimiento',
                icon: const Icon(Icons.add),
                onPressed: () => context.push('/transactions/add'),
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: _TransactionsHeader(
                onSearchChanged: (v) => setState(() => _query = v),
              ),
            ),
          ),

          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            sliver: SliverToBoxAdapter(
              child: Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: isWide ? 980 : double.infinity),
                  child: Column(
                    children: [
                      _FiltersRow(
                        typeFilter: _typeFilter,
                        sort: _sort,
                        onTypeChanged: (v) => setState(() => _typeFilter = v),
                        onSortChanged: (v) => setState(() => _sort = v),
                      ),
                      const SizedBox(height: 12),
                    ],
                  ),
                ),
              ),
            ),
          ),

          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            sliver: tx.when(
              loading: () => const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: CircularProgressIndicator()),
                ),
              ),
              error: (e, _) => SliverToBoxAdapter(
                child: _ErrorBox(message: e.toString()),
              ),
              data: (items) {
                // --- aplicar filtros/orden/búsqueda en memoria ---
                final filtered = items.where((it) {
                  final typeOk = switch (_typeFilter) {
                    TxTypeFilter.all => true,
                    TxTypeFilter.income => it.type == 'income',
                    TxTypeFilter.expense => it.type == 'expense',
                    TxTypeFilter.transfer => it.type == 'transfer',
                  };

                  if (!typeOk) return false;

                  final q = _query.trim().toLowerCase();
                  if (q.isEmpty) return true;

                  final hay = [
                    it.description ?? '',
                    it.categoryName ?? '',
                    it.accountName ?? '',
                    it.fromAccountName ?? '',
                    it.toAccountName ?? '',
                    it.type,
                  ].join(' ').toLowerCase();

                  return hay.contains(q);
                }).toList(growable: false);

                filtered.sort((a, b) {
                  switch (_sort) {
                    case TxSort.dateDesc:
                      return b.date.compareTo(a.date);
                    case TxSort.dateAsc:
                      return a.date.compareTo(b.date);
                    case TxSort.amountDesc:
                      return b.amountCents.compareTo(a.amountCents);
                    case TxSort.amountAsc:
                      return a.amountCents.compareTo(b.amountCents);
                  }
                });

                if (filtered.isEmpty) {
                  return SliverToBoxAdapter(
                    child: Align(
                      alignment: Alignment.topCenter,
                      child: ConstrainedBox(
                        constraints: BoxConstraints(maxWidth: isWide ? 980 : double.infinity),
                        child: const _EmptyState(),
                      ),
                    ),
                  );
                }

                return SliverToBoxAdapter(
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: isWide ? 980 : double.infinity),
                      child: ListView.separated(
                        physics: const NeverScrollableScrollPhysics(),
                        shrinkWrap: true,
                        itemCount: filtered.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (context, i) {
                          final it = filtered[i];

                          final isIncome = it.type == 'income';
                          final isExpense = it.type == 'expense';
                          final tone = isIncome
                              ? const Color(0xFF0EA5E9)
                              : isExpense
                                  ? const Color(0xFF1D4ED8)
                                  : const Color(0xFF071A3A);

                          final sign = isIncome ? '+' : (isExpense ? '-' : '');
                          final subtitle = it.type == 'transfer'
                              ? 'De ${it.fromAccountName ?? ""} → ${it.toAccountName ?? ""}'
                              : '${it.categoryName ?? "Sin categoría"} · ${it.accountName ?? ""}';

                          final title = (it.description?.trim().isNotEmpty ?? false)
                              ? it.description!.trim()
                              : (it.type == 'income'
                                  ? 'Ingreso'
                                  : it.type == 'expense'
                                      ? 'Egreso'
                                      : 'Transferencia');

                          return _TxCard(
                            tone: tone,
                            icon: isIncome
                                ? Icons.south_rounded
                                : isExpense
                                    ? Icons.north_rounded
                                    : Icons.swap_horiz_rounded,
                            title: title,
                            subtitle: subtitle,
                            date: it.date,
                            trailing: '$sign${formatMXNFromCents(it.amountCents)}',
                            onLongPress: () async {
                              final ok = await _confirmDeleteBottomSheet(context);
                              if (ok == true) {
                                await ref
                                    .read(transactionRepositoryProvider)
                                    .deleteTransaction(it.id);
                              }
                            },
                          );
                        },
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),

      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/transactions/add'),
        icon: const Icon(Icons.add),
        label: const Text('Agregar'),
      ),
    );
  }
}

/// -------------------------------
/// Header
/// -------------------------------
class _TransactionsHeader extends StatelessWidget {
  const _TransactionsHeader({required this.onSearchChanged});
  final ValueChanged<String> onSearchChanged;

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
                colors: [
                  Color(0xFF06224A),
                  Color(0xFF0B3C91),
                  Color(0xFF2563EB),
                ],
              ),
            ),
          ),
        ),
        Positioned(
          top: -40,
          right: -30,
          child: _Blob(color: Colors.white.withOpacity(0.12), size: 180),
        ),
        Positioned(
          bottom: -55,
          left: -35,
          child: _Blob(color: Colors.white.withOpacity(0.10), size: 210),
        ),
        Align(
          alignment: Alignment.bottomCenter,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
            child: _SearchBox(onChanged: onSearchChanged),
          ),
        ),
      ],
    );
  }
}

class _SearchBox extends StatelessWidget {
  const _SearchBox({required this.onChanged});
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withOpacity(0.14),
      borderRadius: BorderRadius.circular(16),
      child: TextField(
        onChanged: onChanged,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          prefixIcon: const Icon(Icons.search, color: Colors.white),
          hintText: 'Buscar por concepto, cuenta, categoría…',
          hintStyle: TextStyle(color: Colors.white.withOpacity(0.75)),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        ),
      ),
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

/// -------------------------------
/// Filters Row
/// -------------------------------
class _FiltersRow extends StatelessWidget {
  const _FiltersRow({
    required this.typeFilter,
    required this.sort,
    required this.onTypeChanged,
    required this.onSortChanged,
  });

  final TxTypeFilter typeFilter;
  final TxSort sort;
  final ValueChanged<TxTypeFilter> onTypeChanged;
  final ValueChanged<TxSort> onSortChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _TypeChip(
                  label: 'Todos',
                  selected: typeFilter == TxTypeFilter.all,
                  onTap: () => onTypeChanged(TxTypeFilter.all),
                ),
                _TypeChip(
                  label: 'Ingresos',
                  selected: typeFilter == TxTypeFilter.income,
                  onTap: () => onTypeChanged(TxTypeFilter.income),
                ),
                _TypeChip(
                  label: 'Egresos',
                  selected: typeFilter == TxTypeFilter.expense,
                  onTap: () => onTypeChanged(TxTypeFilter.expense),
                ),
                _TypeChip(
                  label: 'Transfer',
                  selected: typeFilter == TxTypeFilter.transfer,
                  onTap: () => onTypeChanged(TxTypeFilter.transfer),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 10),
        _SortMenu(
          value: sort,
          onChanged: onSortChanged,
        ),
      ],
    );
  }
}

class _TypeChip extends StatelessWidget {
  const _TypeChip({required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bg = selected ? const Color(0xFF0B3C91) : Colors.white;
    final fg = selected ? Colors.white : const Color(0xFF071A3A);

    return Padding(
      padding: const EdgeInsets.only(right: 10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: const Color(0xFF0B3C91).withOpacity(0.12)),
            boxShadow: selected
                ? [BoxShadow(color: const Color(0xFF0B3C91).withOpacity(0.25), blurRadius: 14, offset: const Offset(0, 8))]
                : null,
          ),
          child: Text(
            label,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: fg,
                  fontWeight: FontWeight.w800,
                ),
          ),
        ),
      ),
    );
  }
}

class _SortMenu extends StatelessWidget {
  const _SortMenu({required this.value, required this.onChanged});
  final TxSort value;
  final ValueChanged<TxSort> onChanged;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<TxSort>(
      onSelected: onChanged,
      itemBuilder: (ctx) => const [
        PopupMenuItem(value: TxSort.dateDesc, child: Text('Fecha: más nuevo')),
        PopupMenuItem(value: TxSort.dateAsc, child: Text('Fecha: más viejo')),
        PopupMenuItem(value: TxSort.amountDesc, child: Text('Monto: mayor')),
        PopupMenuItem(value: TxSort.amountAsc, child: Text('Monto: menor')),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFF0B3C91).withOpacity(0.12)),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 18, offset: const Offset(0, 10))],
        ),
        child: Row(
          children: [
            const Icon(Icons.sort, color: Color(0xFF0B3C91), size: 18),
            const SizedBox(width: 8),
            Text(
              'Ordenar',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF071A3A),
                  ),
            ),
            const SizedBox(width: 6),
            const Icon(Icons.expand_more, color: Color(0xFF0B3C91)),
          ],
        ),
      ),
    );
  }
}

/// -------------------------------
/// Card
/// -------------------------------
class _TxCard extends StatelessWidget {
  const _TxCard({
    required this.tone,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.date,
    required this.trailing,
    required this.onLongPress,
  });

  final Color tone;
  final IconData icon;
  final String title;
  final String subtitle;
  final DateTime date;
  final String trailing;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onLongPress: onLongPress,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: tone.withOpacity(0.10)),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 20, offset: const Offset(0, 10))],
          ),
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                height: 44,
                width: 44,
                decoration: BoxDecoration(
                  color: tone.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: tone, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w900,
                            color: const Color(0xFF071A3A),
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: const Color(0xFF071A3A).withOpacity(0.65),
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _formatShortDate(date),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: const Color(0xFF071A3A).withOpacity(0.55),
                          ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Text(
                trailing,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w900,
                      color: tone,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _formatShortDate(DateTime d) {
  final dd = d.day.toString().padLeft(2, '0');
  final mm = d.month.toString().padLeft(2, '0');
  final yy = d.year.toString();
  return '$dd/$mm/$yy';
}

/// -------------------------------
/// Empty/Error + Delete sheet
/// -------------------------------
class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF0B3C91).withOpacity(0.10)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 20, offset: const Offset(0, 10))],
      ),
      child: Column(
        children: [
          Container(
            height: 54,
            width: 54,
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFF0B3C91), Color(0xFF2563EB)]),
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Icon(Icons.receipt_long_rounded, color: Colors.white),
          ),
          const SizedBox(height: 12),
          Text(
            'Sin movimientos',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                  color: const Color(0xFF071A3A),
                ),
          ),
          const SizedBox(height: 6),
          Text(
            'Agrega tu primer ingreso o egreso para ver tu historial aquí.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: const Color(0xFF071A3A).withOpacity(0.70),
                ),
          ),
        ],
      ),
    );
  }
}

class _ErrorBox extends StatelessWidget {
  const _ErrorBox({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 18),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.red.withOpacity(0.20)),
        ),
        child: Text(message),
      ),
    );
  }
}

Future<bool?> _confirmDeleteBottomSheet(BuildContext context) {
  return showModalBottomSheet<bool?>(
    context: context,
    backgroundColor: Colors.transparent,
    useSafeArea: true,
    builder: (ctx) {
      return ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
        child: Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                height: 5,
                width: 42,
                decoration: BoxDecoration(
                  color: const Color(0xFF0B3C91).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Container(
                    height: 40,
                    width: 40,
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.10),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(Icons.delete_outline, color: Colors.red),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Eliminar movimiento',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w900,
                            color: const Color(0xFF071A3A),
                          ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                'Esto no se puede deshacer. ¿Seguro que quieres eliminarlo?',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: const Color(0xFF071A3A).withOpacity(0.70),
                    ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(ctx).pop(false),
                      child: const Text('Cancelar'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      style: FilledButton.styleFrom(backgroundColor: Colors.red),
                      onPressed: () => Navigator.of(ctx).pop(true),
                      child: const Text('Eliminar'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    },
  );
}
