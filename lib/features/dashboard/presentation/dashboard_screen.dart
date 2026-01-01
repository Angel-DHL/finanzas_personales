import 'dart:math';
import 'dart:ui';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:finanzas_personales/core/firebase/firebase_providers.dart';
import 'package:finanzas_personales/features/transactions/data/firestore/firestore_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/utils/money_format.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../profile/data/profile_providers.dart';
import '../../profile/data/profile_service.dart';
import '../../recurring/data/recurring_providers.dart';
import '../../recurring/domain/recurring_payment.dart';

/// -------------------------------
/// Providers de Dashboard (Firestore)
/// -------------------------------
class MonthTotals {
  MonthTotals({required this.incomeCents, required this.expenseCents});
  final int incomeCents;
  final int expenseCents;
}

class TxLite {
  TxLite({
    required this.id,
    required this.type,
    required this.amountCents,
    required this.date,
    this.description,
  });

  final String id;
  final String type;
  final int amountCents;
  final DateTime date;
  final String? description;

  static TxLite fromDoc(QueryDocumentSnapshot<Map<String, dynamic>> d) {
    final data = d.data();
    return TxLite(
      id: d.id,
      type: (data['type'] as String?) ?? 'expense',
      amountCents: (data['amountCents'] as int?) ?? 0,
      date: (data['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
      description: data['description'] as String?,
    );
  }
}

DateTime _startOfMonth(DateTime d) => DateTime(d.year, d.month, 1);
DateTime _startOfNextMonth(DateTime d) => DateTime(d.year, d.month + 1, 1);

final dashboardMonthTotalsProvider = StreamProvider<MonthTotals>((ref) {
  final uid = ref.watch(uidProvider);
  if (uid == null) return const Stream.empty();

  final fs = ref.watch(firestoreProvider);
  final now = DateTime.now();
  final start = _startOfMonth(now);
  final end = _startOfNextMonth(now);

  final q = fs
      .collection('users')
      .doc(uid)
      .collection('transactions')
      .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
      .where('date', isLessThan: Timestamp.fromDate(end))
      .orderBy('date', descending: true);

  return q.snapshots().map((snap) {
    var income = 0;
    var expense = 0;
    for (final d in snap.docs) {
      final data = d.data();
      final type = (data['type'] as String?) ?? '';
      final amt = (data['amountCents'] as int?) ?? 0;
      if (type == 'income') income += amt;
      if (type == 'expense') expense += amt;
    }
    return MonthTotals(incomeCents: income, expenseCents: expense);
  });
});

final dashboardRecentTxProvider = StreamProvider<List<TxLite>>((ref) {
  final uid = ref.watch(uidProvider);
  if (uid == null) return const Stream.empty();

  final fs = ref.watch(firestoreProvider);

  final q = fs
      .collection('users')
      .doc(uid)
      .collection('transactions')
      .orderBy('date', descending: true)
      .limit(8);

  return q.snapshots().map((snap) => snap.docs.map(TxLite.fromDoc).toList());
});

class DailyPoint {
  DailyPoint({
    required this.day,
    required this.incomeCents,
    required this.expenseCents,
  });
  final DateTime day;
  final int incomeCents;
  final int expenseCents;
}

final dashboardLast14DaysProvider = StreamProvider<List<DailyPoint>>((ref) {
  final uid = ref.watch(uidProvider);
  if (uid == null) return const Stream.empty();

  final fs = ref.watch(firestoreProvider);
  final now = DateTime.now();
  final start = DateTime(now.year, now.month, now.day).subtract(const Duration(days: 13));

  final q = fs
      .collection('users')
      .doc(uid)
      .collection('transactions')
      .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
      .orderBy('date', descending: false);

  return q.snapshots().map((snap) {
    // 14 buckets
    final buckets = <DateTime, DailyPoint>{};
    for (int i = 0; i < 14; i++) {
      final day = DateTime(start.year, start.month, start.day).add(Duration(days: i));
      buckets[day] = DailyPoint(day: day, incomeCents: 0, expenseCents: 0);
    }

    for (final d in snap.docs) {
      final data = d.data();
      final dt = (data['date'] as Timestamp?)?.toDate();
      if (dt == null) continue;

      final dayKey = DateTime(dt.year, dt.month, dt.day);
      final existing = buckets[dayKey];
      if (existing == null) continue;

      final type = (data['type'] as String?) ?? '';
      final amt = (data['amountCents'] as int?) ?? 0;

      if (type == 'income') {
        buckets[dayKey] = DailyPoint(
          day: existing.day,
          incomeCents: existing.incomeCents + amt,
          expenseCents: existing.expenseCents,
        );
      } else if (type == 'expense') {
        buckets[dayKey] = DailyPoint(
          day: existing.day,
          incomeCents: existing.incomeCents,
          expenseCents: existing.expenseCents + amt,
        );
      }
    }

    final sorted = buckets.values.toList()..sort((a, b) => a.day.compareTo(b.day));
    return sorted;
  });
});

/// ---------------------------------------------------------------------------
/// ✅ NUEVO: Balance "Disponible" calculado con TODOS los movimientos + recurrentes
/// ---------------------------------------------------------------------------

/// Como pediste: TODO se refleja en "Disponible" (ingreso suma; egreso resta; transferencia también resta).
const bool kTransferCountsAgainstAvailable = true;

/// Recurrentes próximos se descuentan como "reservado". Ajusta si quieres.
const int kUpcomingRecurringWindowDays = 30;

/// Trae muchos movimientos (para calcular disponible). Ajusta límite si lo necesitas.
const int kAllTxLimit = 5000;

final dashboardAllTxProvider = StreamProvider<List<TxLite>>((ref) {
  final uid = ref.watch(uidProvider);
  if (uid == null) return const Stream.empty();

  final fs = ref.watch(firestoreProvider);

  final q = fs
      .collection('users')
      .doc(uid)
      .collection('transactions')
      .orderBy('date', descending: true)
      .limit(kAllTxLimit);

  return q.snapshots().map((snap) => snap.docs.map(TxLite.fromDoc).toList());
});

/// Provider que calcula el "Disponible" final:
/// base(savingsCents) + ingresos - egresos - transferencias - recurrentes próximos
final dashboardAvailableCentsProvider = Provider<AsyncValue<int>>((ref) {
  final profileAsync = ref.watch(profileStreamProvider);
  final txAsync = ref.watch(dashboardAllTxProvider);
  final recurringsAsync = ref.watch(recurringListProvider);

  if (profileAsync.hasError) {
    return AsyncValue.error(profileAsync.error!, profileAsync.stackTrace ?? StackTrace.current);
  }
  if (txAsync.hasError) {
    return AsyncValue.error(txAsync.error!, txAsync.stackTrace ?? StackTrace.current);
  }

  final profile = profileAsync.valueOrNull;
  final txs = txAsync.valueOrNull;

  if (profile == null || txs == null) {
    return const AsyncValue.loading();
  }

  final baseSavings = (profile['savingsCents'] as int?) ?? 0;

  // Si en algún momento guardas un timestamp al editar ahorros (savingsUpdatedAt),
  // puedes filtrar movimientos anteriores a ese momento. Si no existe, se usa todo.
  final baselineAt = (profile['savingsUpdatedAt'] as Timestamp?)?.toDate();

  int delta = 0;

  for (final t in txs) {
    if (baselineAt != null && t.date.isBefore(baselineAt)) continue;

    if (t.type == 'income') {
      delta += t.amountCents;
    } else if (t.type == 'expense') {
      delta -= t.amountCents;
    } else if (t.type == 'transfer') {
      if (kTransferCountsAgainstAvailable) {
        delta -= t.amountCents; // ✅ pedido: también descuenta
      }
    } else {
      // tipo desconocido -> no hace nada
    }
  }

  // Recurrentes próximos: restar como "reservado"
  int reservedUpcoming = 0;
  final recItems = recurringsAsync.valueOrNull ?? const <RecurringPayment>[];

  if (kUpcomingRecurringWindowDays > 0 && recItems.isNotEmpty) {
    final now = DateTime.now();
    final end = now.add(Duration(days: kUpcomingRecurringWindowDays));

    for (final r in recItems) {
      final due = r.nextDueAt;
      if (due.isBefore(end) || due.isAtSameMomentAs(end)) {
        reservedUpcoming += r.amountCents;
      }
    }
  }

  final available = baseSavings + delta - reservedUpcoming;
  return AsyncValue.data(available);
});

/// -------------------------------
/// UI
/// -------------------------------
class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  bool _didRunOnboarding = false;
  bool _didCheckDueThisSession = false;
  bool _promptedDueThisOpen = false;

  ProviderSubscription<AsyncValue<Map<String, dynamic>?>>? _profileSub;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
    if (!mounted) return;
    await _promptDuePaymentsIfAnyOnDashboard();
  });

    _profileSub = ref.listenManual<AsyncValue<Map<String, dynamic>?>>(
      profileStreamProvider,
      (prev, next) async {
        final uid = ref.read(uidProvider);
        if (uid == null) return;

        final svc = ref.read(profileServiceProvider);
        await svc.ensureProfileExists(uid);

        final uidNow = ref.read(uidProvider);
        if (uidNow == null || uidNow != uid) return;

        final data = next.valueOrNull;
        if (data == null) return;

        final onboarded = (data['onboarded'] as bool?) ?? false;
        final savingsCents = data['savingsCents'] as int?;

        if (!onboarded && !_didRunOnboarding && mounted) {
          _didRunOnboarding = true;
          await _runOnboarding(uid, svc, currentSavings: savingsCents);
        }

        if (!_didCheckDueThisSession && mounted) {
          _didCheckDueThisSession = true;
          await _checkDuePayments(uid);
        }
      },
    );
  }

  @override
  void dispose() {
    _profileSub?.close();
    super.dispose();
  }

  Future<void> _runOnboarding(
    String uid,
    ProfileService profile, {
    required int? currentSavings,
  }) async {
    final savings = await _sheetAskSavings(context, initialCents: currentSavings);
    await profile.setSavings(uid, savings ?? 0);

    final addRec = await _sheetAskAddRecurrings(context);
    if (addRec == true && mounted) {
      context.push('/recurring/add');
    }

    await profile.setOnboarded(uid, true);
  }

  Future<void> _promptDuePaymentsIfAnyOnDashboard() async {
  if (_promptedDueThisOpen) return;
  _promptedDueThisOpen = true;

  final uid = ref.read(uidProvider);
  if (uid == null) return;

  final svc = ref.read(recurringServiceProvider);
  final dueNeedingConfirm = await svc.processDuePayments(uid);

  for (final p in dueNeedingConfirm) {
    if (!mounted) return;
    final paid = await _sheetAskPaid(context, p); // tu bottom sheet del dashboard
    if (paid == true) {
      await svc.markPaid(uid: uid, recurring: p);
    }
  }
}

  Future<void> _checkDuePayments(String uid) async {
    final svc = ref.read(recurringServiceProvider);
    final dueNeedingConfirm = await svc.processDuePayments(uid);

    for (final p in dueNeedingConfirm) {
      if (!mounted) return;
      final paid = await _sheetAskPaid(context, p);
      if (paid == true) {
        await svc.markPaid(uid: uid, recurring: p);
      }
    }
  }

  Future<void> _logout() async {
    try {
      _profileSub?.close();
      _profileSub = null;
      _didRunOnboarding = false;
      _didCheckDueThisSession = false;

      await ref.read(authControllerProvider).signOut();
      if (!mounted) return;
      context.go('/login');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = ref.watch(uidProvider);
    final profile = ref.watch(profileStreamProvider);

    final availableAsync = ref.watch(dashboardAvailableCentsProvider); // ✅ NUEVO

    final monthTotals = ref.watch(dashboardMonthTotalsProvider);
    final last14 = ref.watch(dashboardLast14DaysProvider);
    final recentTx = ref.watch(dashboardRecentTxProvider);
    final recurrings = ref.watch(recurringListProvider);

    final mq = MediaQuery.of(context);
    final size = mq.size;
    final isWide = size.width >= 950;

    // ✅ FIX: variables que faltaban (evita "Undefined name bottomSafe/navBarHeightGuess")
    final bottomSafe = mq.viewPadding.bottom;
    final navBarHeightGuess = Theme.of(context).useMaterial3 ? 80.0 : kBottomNavigationBarHeight;
    final bottomPad = 24.0 + bottomSafe + navBarHeightGuess;

    if (uid == null) {
      return const Scaffold(body: Center(child: Text('No autenticado')));
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF4F8FF),
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            expandedHeight: 160,
            backgroundColor: const Color(0xFF0B3C91),
            elevation: 0,
            title: const Text('Dashboard'),
            actions: [
              IconButton(
                tooltip: 'Cerrar sesión',
                icon: const Icon(Icons.logout),
                onPressed: _logout,
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: _DashboardHeader(),
            ),
          ),
          SliverPadding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, bottomPad),
            sliver: SliverToBoxAdapter(
              child: profile.when(
                loading: () => const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: CircularProgressIndicator(),
                  ),
                ),
                error: (e, _) => Text(e.toString()),
                data: (data) {
                  final savingsCents = (data?['savingsCents'] as int?) ?? 0;

                  // ✅ Disponible calculado: savings + movimientos - recurrentes próximos
                  final computedAvailable = availableAsync.valueOrNull;
                  final balance = computedAvailable ?? savingsCents;

                  return LayoutBuilder(
                    builder: (context, constraints) {
                      if (isWide) {
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                children: [
                                  _BalanceHeroCard(
                                    balanceCents: balance,
                                    onEditSavings: () async {
                                      final newSavings = await _sheetAskSavings(
                                        context,
                                        initialCents: savingsCents,
                                      );
                                      if (newSavings != null) {
                                        await ref.read(profileServiceProvider).setSavings(uid, newSavings);
                                      }
                                    },
                                    onAddMovement: () => context.push('/transactions/add'),
                                  ),
                                  const SizedBox(height: 14),
                                  _SectionCard(
                                    title: 'Este mes',
                                    subtitle: 'Ingresos vs egresos',
                                    child: Column(
                                      children: [
                                        monthTotals.when(
                                          loading: () => const _InlineLoading(),
                                          error: (e, _) => Text(e.toString()),
                                          data: (m) => _MonthTotalsRow(m: m),
                                        ),
                                        const SizedBox(height: 14),
                                        last14.when(
                                          loading: () => const _InlineLoading(),
                                          error: (e, _) => Text(e.toString()),
                                          data: (points) => _MiniIncomeExpenseChart(points: points),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                children: [
                                  _SectionCard(
                                    title: 'Movimientos recientes',
                                    subtitle: 'Últimos 8 registros',
                                    trailing: TextButton(
                                      onPressed: () => context.go('/transactions'),
                                      child: const Text('Ver todo'),
                                    ),
                                    child: recentTx.when(
                                      loading: () => const _InlineLoading(),
                                      error: (e, _) => Text(e.toString()),
                                      data: (items) => _RecentTxList(items: items),
                                    ),
                                  ),
                                  const SizedBox(height: 14),
                                  _SectionCard(
                                    title: 'Recurrentes próximos',
                                    subtitle: 'Pagos domiciliados',
                                    trailing: TextButton(
                                      onPressed: () => context.push('/recurring'),
                                      child: const Text('Ver'),
                                    ),
                                    child: recurrings.when(
                                      loading: () => const _InlineLoading(),
                                      error: (e, _) => Text(e.toString()),
                                      data: (items) => _UpcomingRecurrings(items: items),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        );
                      }

                      // Mobile / compacto
                      return Column(
                        children: [
                          _BalanceHeroCard(
                            balanceCents: balance,
                            onEditSavings: () async {
                              final newSavings = await _sheetAskSavings(context, initialCents: savingsCents);
                              if (newSavings != null) {
                                await ref.read(profileServiceProvider).setSavings(uid, newSavings);
                              }
                            },
                            onAddMovement: () => context.push('/transactions/add'),
                          ),
                          const SizedBox(height: 14),
                          _SectionCard(
                            title: 'Este mes',
                            subtitle: 'Ingresos vs egresos',
                            child: Column(
                              children: [
                                monthTotals.when(
                                  loading: () => const _InlineLoading(),
                                  error: (e, _) => Text(e.toString()),
                                  data: (m) => _MonthTotalsRow(m: m),
                                ),
                                const SizedBox(height: 14),
                                last14.when(
                                  loading: () => const _InlineLoading(),
                                  error: (e, _) => Text(e.toString()),
                                  data: (points) => _MiniIncomeExpenseChart(points: points),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 14),
                          _SectionCard(
                            title: 'Movimientos recientes',
                            subtitle: 'Últimos 8 registros',
                            trailing: TextButton(
                              onPressed: () => context.go('/transactions'),
                              child: const Text('Ver todo'),
                            ),
                            child: recentTx.when(
                              loading: () => const _InlineLoading(),
                              error: (e, _) => Text(e.toString()),
                              data: (items) => _RecentTxList(items: items),
                            ),
                          ),
                          const SizedBox(height: 14),
                          _SectionCard(
                            title: 'Recurrentes próximos',
                            subtitle: 'Pagos domiciliados',
                            trailing: TextButton(
                              onPressed: () => context.push('/recurring'),
                              child: const Text('Ver'),
                            ),
                            child: recurrings.when(
                              loading: () => const _InlineLoading(),
                              error: (e, _) => Text(e.toString()),
                              data: (items) => _UpcomingRecurrings(items: items),
                            ),
                          ),
                        ],
                      );
                    },
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// -------------------------------
/// Header / Cards / Widgets
/// -------------------------------
class _DashboardHeader extends StatelessWidget {
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
                  Color(0xFF071A3A),
                  Color(0xFF0B3C91),
                  Color(0xFF0EA5E9),
                ],
              ),
            ),
          ),
        ),
        Positioned(
          top: -40,
          left: -30,
          child: _Blob(color: const Color(0xFF60A5FA).withOpacity(0.28), size: 180),
        ),
        Positioned(
          bottom: -60,
          right: -40,
          child: _Blob(color: const Color(0xFF38BDF8).withOpacity(0.22), size: 240),
        ),
        Align(
          alignment: Alignment.bottomLeft,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Text(
              'Resumen financiero',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
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
        boxShadow: [BoxShadow(color: color, blurRadius: 60, spreadRadius: 12)],
      ),
    );
  }
}

class _BalanceHeroCard extends StatelessWidget {
  const _BalanceHeroCard({
    required this.balanceCents,
    required this.onEditSavings,
    required this.onAddMovement,
  });

  final int balanceCents;
  final VoidCallback onEditSavings;
  final VoidCallback onAddMovement;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: Stack(
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF0B3C91), Color(0xFF0EA5E9)],
                ),
              ),
            ),
          ),
          Positioned(
            top: -60,
            right: -40,
            child: _Blob(color: Colors.white.withOpacity(0.18), size: 180),
          ),
          Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Disponible',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Colors.white.withOpacity(0.88),
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  formatMXNFromCents(balanceCents),
                  style: Theme.of(context).textTheme.displaySmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        height: 1.05,
                      ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: onEditSavings,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: BorderSide(color: Colors.white.withOpacity(0.35)),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        icon: const Icon(Icons.savings_outlined, size: 18),
                        label: const Text('Editar ahorros'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: onAddMovement,
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF071A3A).withOpacity(0.25),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          elevation: 0,
                        ),
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text('Agregar'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.subtitle,
    this.trailing,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Widget? trailing;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(0, 12),
          ),
        ],
        border: Border.all(color: const Color(0xFF0B3C91).withOpacity(0.08)),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF071A3A),
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: const Color(0xFF071A3A).withOpacity(0.65),
                          ),
                    ),
                  ],
                ),
              ),
              if (trailing != null) trailing!,
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _MonthTotalsRow extends StatelessWidget {
  const _MonthTotalsRow({required this.m});
  final MonthTotals m;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _MiniMetric(
            label: 'Ingresos',
            value: formatMXNFromCents(m.incomeCents),
            icon: Icons.arrow_downward_rounded,
            tone: const Color(0xFF0EA5E9),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _MiniMetric(
            label: 'Egresos',
            value: formatMXNFromCents(m.expenseCents),
            icon: Icons.arrow_upward_rounded,
            tone: const Color(0xFF1D4ED8),
          ),
        ),
      ],
    );
  }
}

class _MiniMetric extends StatelessWidget {
  const _MiniMetric({
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
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: tone.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: tone.withOpacity(0.15)),
      ),
      child: Row(
        children: [
          Container(
            height: 34,
            width: 34,
            decoration: BoxDecoration(
              color: tone.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: tone, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: const Color(0xFF071A3A).withOpacity(0.75),
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                        color: const Color(0xFF071A3A),
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

class _MiniIncomeExpenseChart extends StatelessWidget {
  const _MiniIncomeExpenseChart({required this.points});
  final List<DailyPoint> points;

  @override
  Widget build(BuildContext context) {
    final maxVal = points.isEmpty
        ? 1
        : max(
            points.map((e) => e.incomeCents).fold<int>(0, max),
            points.map((e) => e.expenseCents).fold<int>(0, max),
          );

    return SizedBox(
      height: 130,
      child: CustomPaint(
        painter: _BarsPainter(points: points, maxVal: maxVal),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _BarsPainter extends CustomPainter {
  _BarsPainter({required this.points, required this.maxVal});
  final List<DailyPoint> points;
  final int maxVal;

  @override
  void paint(Canvas canvas, Size size) {
    final paintIncome = Paint()..color = const Color(0xFF0EA5E9).withOpacity(0.90);
    final paintExpense = Paint()..color = const Color(0xFF1D4ED8).withOpacity(0.85);
    final paintGrid = Paint()
      ..color = const Color(0xFF071A3A).withOpacity(0.10)
      ..strokeWidth = 1;

    // grid lines
    for (int i = 1; i <= 3; i++) {
      final y = size.height * (i / 4);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paintGrid);
    }

    if (points.isEmpty) return;

    final n = points.length;
    final gap = 6.0;
    final groupWidth = (size.width - (gap * (n - 1))) / n;
    final barWidth = (groupWidth - 6) / 2; // 2 bars (income/expense)
    final baseY = size.height;

    for (int i = 0; i < n; i++) {
      final p = points[i];
      final x0 = i * (groupWidth + gap);

      final hIncome = (p.incomeCents / maxVal) * (size.height * 0.92);
      final hExpense = (p.expenseCents / maxVal) * (size.height * 0.92);

      final rIncome = RRect.fromRectAndRadius(
        Rect.fromLTWH(x0, baseY - hIncome, barWidth, hIncome),
        const Radius.circular(6),
      );
      final rExpense = RRect.fromRectAndRadius(
        Rect.fromLTWH(x0 + barWidth + 6, baseY - hExpense, barWidth, hExpense),
        const Radius.circular(6),
      );

      canvas.drawRRect(rIncome, paintIncome);
      canvas.drawRRect(rExpense, paintExpense);
    }
  }

  @override
  bool shouldRepaint(covariant _BarsPainter oldDelegate) {
    return oldDelegate.points != points || oldDelegate.maxVal != maxVal;
  }
}

class _RecentTxList extends StatelessWidget {
  const _RecentTxList({required this.items});
  final List<TxLite> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return Text(
        'Aún no hay movimientos. Agrega tu primer ingreso o egreso.',
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: const Color(0xFF071A3A).withOpacity(0.7),
            ),
      );
    }

    return Column(
      children: items.map((t) {
        final isIncome = t.type == 'income';
        final isExpense = t.type == 'expense';
        final tone = isIncome
            ? const Color(0xFF0EA5E9)
            : isExpense
                ? const Color(0xFF1D4ED8)
                : const Color(0xFF071A3A);

        final sign = isIncome ? '+' : (isExpense ? '-' : '');

        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: tone.withOpacity(0.06),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: tone.withOpacity(0.14)),
            ),
            child: Row(
              children: [
                Container(
                  height: 38,
                  width: 38,
                  decoration: BoxDecoration(
                    color: tone.withOpacity(0.14),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    isIncome
                        ? Icons.south_rounded
                        : isExpense
                            ? Icons.north_rounded
                            : Icons.swap_horiz_rounded,
                    color: tone,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        (t.description?.trim().isNotEmpty ?? false)
                            ? t.description!.trim()
                            : _labelForType(t.type),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF071A3A),
                            ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        _formatShortDate(t.date),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: const Color(0xFF071A3A).withOpacity(0.65),
                            ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  '$sign${formatMXNFromCents(t.amountCents)}',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w900,
                        color: tone,
                      ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

String _labelForType(String t) {
  if (t == 'income') return 'Ingreso';
  if (t == 'expense') return 'Egreso';
  if (t == 'transfer') return 'Transferencia';
  return 'Movimiento';
}

class _UpcomingRecurrings extends StatelessWidget {
  const _UpcomingRecurrings({required this.items});
  final List<RecurringPayment> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return Text(
        'No tienes pagos recurrentes activos.',
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: const Color(0xFF071A3A).withOpacity(0.7),
            ),
      );
    }

    final top = items.take(3).toList();

    return Column(
      children: top.map((p) {
        final due = p.nextDueAt;
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF0EA5E9).withOpacity(0.06),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFF0EA5E9).withOpacity(0.14)),
            ),
            child: Row(
              children: [
                Container(
                  height: 38,
                  width: 38,
                  decoration: BoxDecoration(
                    color: const Color(0xFF0EA5E9).withOpacity(0.14),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.repeat_rounded, color: Color(0xFF0EA5E9), size: 20),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        p.concept,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF071A3A),
                            ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Se cobra: ${_formatShortDate(due)}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: const Color(0xFF071A3A).withOpacity(0.65),
                            ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  formatMXNFromCents(p.amountCents),
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w900,
                        color: const Color(0xFF1D4ED8),
                      ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _InlineLoading extends StatelessWidget {
  const _InlineLoading();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      height: 44,
      child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
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
/// Bottom sheets profesionales (azules)
/// -------------------------------
Future<int?> _sheetAskSavings(BuildContext context, {required int? initialCents}) async {
  final controller = TextEditingController(
    text: initialCents == null ? '' : (initialCents / 100).toStringAsFixed(2),
  );

  return showModalBottomSheet<int?>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    useSafeArea: true,
    builder: (ctx) {
      final bottom = MediaQuery.viewInsetsOf(ctx).bottom;
      return Padding(
        padding: EdgeInsets.only(bottom: bottom),
        child: _BlueSheet(
          title: 'Ahorros',
          subtitle: '¿Cuánto tienes actualmente en ahorros?',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: controller,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  prefixText: r'$ ',
                  hintText: '0.00',
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(ctx).pop(null),
                      child: const Text('Omitir'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: () {
                        final cents = parseCents(controller.text);
                        Navigator.of(ctx).pop(cents);
                      },
                      child: const Text('Guardar'),
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

Future<bool?> _sheetAskAddRecurrings(BuildContext context) {
  return showModalBottomSheet<bool?>(
    context: context,
    backgroundColor: Colors.transparent,
    useSafeArea: true,
    builder: (ctx) {
      return _BlueSheet(
        title: 'Recurrentes',
        subtitle: '¿Quieres agregar pagos domiciliados ahora?',
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('No por ahora'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                child: const Text('Sí, agregar'),
              ),
            ),
          ],
        ),
      );
    },
  );
}

Future<bool?> _sheetAskPaid(BuildContext context, RecurringPayment p) {
  return showModalBottomSheet<bool?>(
    context: context,
    backgroundColor: Colors.transparent,
    useSafeArea: true,
    builder: (ctx) {
      return _BlueSheet(
        title: 'Pago vencido',
        subtitle: '¿Ya pagaste "${p.concept}" por ${formatMXNFromCents(p.amountCents)}?',
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('Aún no'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                child: const Text('Sí, pagado'),
              ),
            ),
          ],
        ),
      );
    },
  );
}

class _BlueSheet extends StatelessWidget {
  const _BlueSheet({required this.title, required this.subtitle, required this.child});
  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.18),
                blurRadius: 24,
                offset: const Offset(0, -8),
              )
            ],
          ),
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
              const SizedBox(height: 12),
              Row(
                children: [
                  Container(
                    height: 38,
                    width: 38,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF0B3C91), Color(0xFF0EA5E9)],
                      ),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(Icons.account_balance_wallet_outlined, color: Colors.white, size: 20),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w900,
                                color: const Color(0xFF071A3A),
                              ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: const Color(0xFF071A3A).withOpacity(0.65),
                              ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              child,
            ],
          ),
        ),
      ),
    );
  }
}
