import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/utils/money_format.dart';
import '../../profile/data/profile_providers.dart';
import '../data/recurring_providers.dart';
import '../domain/recurring_payment.dart';

class RecurringScreen extends ConsumerStatefulWidget {
  const RecurringScreen({super.key});

  @override
  ConsumerState<RecurringScreen> createState() => _RecurringScreenState();
}

class _RecurringScreenState extends ConsumerState<RecurringScreen> {
  bool _promptedThisOpen = false;

  String _formatDate(DateTime d) {
    final dd = d.day.toString().padLeft(2, '0');
    final mm = d.month.toString().padLeft(2, '0');
    final yy = d.year.toString();
    return '$dd/$mm/$yy';
  }

  @override
  void initState() {
    super.initState();

    // ✅ Pregunta automáticamente al abrir esta pantalla
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      await _promptDuePaymentsIfAny();
    });
  }

  Future<void> _promptDuePaymentsIfAny() async {
    if (_promptedThisOpen) return;
    _promptedThisOpen = true;

    final uid = ref.read(uidProvider);
    if (uid == null) return;

    final svc = ref.read(recurringServiceProvider);

    // Tu servicio ya decide cuáles están vencidos y requieren confirmación
    final dueNeedingConfirm = await svc.processDuePayments(uid);

    for (final p in dueNeedingConfirm) {
      if (!mounted) return;

      final paid = await _askPaidDialog(context, p);
      if (paid == true) {
        await svc.markPaid(uid: uid, recurring: p);
      }
    }
  }

  Future<bool?> _askPaidDialog(BuildContext context, RecurringPayment p) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Pago vencido'),
          content: Text(
            '¿Ya pagaste "${p.concept}" por ${formatMXNFromCents(p.amountCents)}?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Aún no'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Sí, pagado'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final items = ref.watch(recurringListProvider);
    final isWide = MediaQuery.sizeOf(context).width >= 950;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F8FF),
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            expandedHeight: 150,
            elevation: 0,
            backgroundColor: const Color(0xFF05224A),
            title: const Text('Domiciliados / Recurrentes'),
            actions: [
              IconButton(
                tooltip: 'Confirmar vencidos',
                icon: const Icon(Icons.fact_check_rounded),
                onPressed: () async {
                  // Permite re-preguntar manualmente
                  _promptedThisOpen = false;
                  await _promptDuePaymentsIfAny();
                },
              ),
              IconButton(
                tooltip: 'Agregar recurrente',
                icon: const Icon(Icons.add),
                onPressed: () => context.push('/recurring/add'),
              ),
            ],
            flexibleSpace: const FlexibleSpaceBar(
              background: _RecurringHeader(),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            sliver: items.when(
              loading: () => const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: CircularProgressIndicator()),
                ),
              ),
              error: (e, _) => SliverToBoxAdapter(
                child: Align(
                  alignment: Alignment.topCenter,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 980),
                    child: _ErrorBox(message: e.toString()),
                  ),
                ),
              ),
              data: (list) {
                return SliverToBoxAdapter(
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: isWide ? 980 : double.infinity),
                      child: list.isEmpty
                          ? const _EmptyState()
                          : Column(
                              children: [
                                _SummaryRow(
                                  total: list.length,
                                  confirmCount: list.where((x) => x.requireConfirmation).length,
                                ),
                                const SizedBox(height: 12),
                                ListView.separated(
                                  physics: const NeverScrollableScrollPhysics(),
                                  shrinkWrap: true,
                                  itemCount: list.length,
                                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                                  itemBuilder: (_, i) {
                                    final p = list[i];

                                    DateTime? nextDue;
                                    try {
                                      nextDue = (p as dynamic).nextDueAt as DateTime?;
                                    } catch (_) {
                                      nextDue = null;
                                    }

                                    final tone = p.requireConfirmation ? const Color(0xFF0B3C91) : const Color(0xFF1D4ED8);

                                    return _RecurringCard(
                                      tone: tone,
                                      concept: p.concept,
                                      amountText: formatMXNFromCents(p.amountCents),
                                      dayOfMonth: p.dayOfMonth,
                                      requireConfirmation: p.requireConfirmation,
                                      nextDueText: nextDue == null ? null : _formatDate(nextDue),
                                      onTap: () {
                                        // futuro: editar/detalle
                                      },
                                    );
                                  },
                                ),
                              ],
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
        onPressed: () => context.push('/recurring/add'),
        icon: const Icon(Icons.add),
        label: const Text('Agregar'),
      ),
    );
  }
}

/// ---------------- Header ----------------
class _RecurringHeader extends StatelessWidget {
  const _RecurringHeader();

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
                  Color(0xFF051A3A),
                  Color(0xFF05224A),
                  Color(0xFF0B3C91),
                ],
              ),
            ),
          ),
        ),
        Positioned(
          top: -45,
          right: -25,
          child: _Blob(color: Colors.white.withOpacity(0.12), size: 180),
        ),
        Positioned(
          bottom: -55,
          left: -30,
          child: _Blob(color: Colors.white.withOpacity(0.10), size: 220),
        ),
        Align(
          alignment: Alignment.bottomLeft,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Controla tus pagos',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                      ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Revisa próximos cobros y confirma los pendientes.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.white.withOpacity(0.82),
                        fontWeight: FontWeight.w600,
                      ),
                ),
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

/// ---------------- Summary ----------------
class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.total, required this.confirmCount});
  final int total;
  final int confirmCount;

  @override
  Widget build(BuildContext context) {
    final autoCount = total - confirmCount;

    return Row(
      children: [
        Expanded(
          child: _MiniStat(
            label: 'Total',
            value: total.toString(),
            icon: Icons.receipt_long_rounded,
            tone: const Color(0xFF05224A),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _MiniStat(
            label: 'Auto',
            value: autoCount.toString(),
            icon: Icons.auto_awesome_rounded,
            tone: const Color(0xFF1D4ED8),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _MiniStat(
            label: 'Confirmar',
            value: confirmCount.toString(),
            icon: Icons.verified_user_rounded,
            tone: const Color(0xFF0B3C91),
          ),
        ),
      ],
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({
    required this.label,
    required this.value,
    required this.icon,
    required this.tone,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color tone;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: tone.withOpacity(0.10)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            height: 40,
            width: 40,
            decoration: BoxDecoration(
              color: tone.withOpacity(0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: tone, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                        color: const Color(0xFF071A3A),
                      ),
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: const Color(0xFF071A3A).withOpacity(0.65),
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// ---------------- Card ----------------
class _RecurringCard extends StatelessWidget {
  const _RecurringCard({
    required this.tone,
    required this.concept,
    required this.amountText,
    required this.dayOfMonth,
    required this.requireConfirmation,
    required this.nextDueText,
    required this.onTap,
  });

  final Color tone;
  final String concept;
  final String amountText;
  final int dayOfMonth;
  final bool requireConfirmation;
  final String? nextDueText;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final chipBg = requireConfirmation ? const Color(0xFF0B3C91) : const Color(0xFF1D4ED8);
    final chipLabel = requireConfirmation ? 'Confirmar' : 'Auto';

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: tone.withOpacity(0.10)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                height: 44,
                width: 44,
                decoration: BoxDecoration(
                  color: tone.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(Icons.event_repeat_rounded, color: tone, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      concept,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w900,
                            color: const Color(0xFF071A3A),
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      nextDueText == null ? 'Se cobra el día $dayOfMonth' : 'Próximo: $nextDueText · Día $dayOfMonth',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: const Color(0xFF071A3A).withOpacity(0.65),
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    amountText,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w900,
                          color: tone,
                        ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: chipBg.withOpacity(0.10),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: chipBg.withOpacity(0.20)),
                    ),
                    child: Text(
                      chipLabel,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            fontWeight: FontWeight.w900,
                            color: chipBg,
                          ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// ---------------- Empty/Error ----------------
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
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            height: 54,
            width: 54,
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFF05224A), Color(0xFF1D4ED8)]),
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Icon(Icons.event_repeat_rounded, color: Colors.white),
          ),
          const SizedBox(height: 12),
          Text(
            'Sin pagos recurrentes',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                  color: const Color(0xFF071A3A),
                ),
          ),
          const SizedBox(height: 6),
          Text(
            'Agrega pagos domiciliados para que se reflejen en tus ahorros y te ayuden a planear.',
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
