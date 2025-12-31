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

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  bool _didRunOnboarding = false;
  bool _didCheckDueThisSession = false;

  // ✅ ESTE ERA EL FALLO: faltaba declarar la subscripción
  ProviderSubscription<AsyncValue<Map<String, dynamic>?>>? _profileSub;

  @override
  void initState() {
    super.initState();

    _profileSub = ref.listenManual<AsyncValue<Map<String, dynamic>?>>(
      profileStreamProvider,
      (prev, next) async {
        final uid = ref.read(uidProvider);
        if (uid == null) return;

        final svc = ref.read(profileServiceProvider);
        await svc.ensureProfileExists(uid);

        final data = next.valueOrNull;
        if (data == null) return;

        // Seed Firestore (cuentas/categorías) una sola vez si estás usando el seed
        // await ref.read(financeSeedServiceProvider).seedIfEmpty(uid);

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
    // ✅ cerrar la subscripción
    _profileSub?.close();
    super.dispose();
  }

  Future<void> _runOnboarding(
    String uid,
    ProfileService profile, {
    required int? currentSavings,
  }) async {
    // 1) Preguntar ahorros
    final savings = await _askSavings(context, initialCents: currentSavings);
    if (savings != null) {
      await profile.setSavings(uid, savings);
    } else {
      await profile.setSavings(uid, 0);
    }

    // 2) Preguntar si quiere agregar recurrentes
    final addRec = await _askAddRecurrings(context);
    if (addRec == true && mounted) {
      context.push('/recurring/add');
    }

    // 3) Marcar onboarding completo
    await profile.setOnboarded(uid, true);
  }

  Future<void> _checkDuePayments(String uid) async {
    final svc = ref.read(recurringServiceProvider);
    final dueNeedingConfirm = await svc.processDuePayments(uid);

    for (final p in dueNeedingConfirm) {
      if (!mounted) return;
      final paid = await _askPaid(context, p);
      if (paid == true) {
        await svc.markPaid(uid: uid, recurring: p);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = ref.watch(uidProvider);
    final profile = ref.watch(profileStreamProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        actions: [
          IconButton(
            tooltip: 'Cerrar sesión',
            icon: const Icon(Icons.logout),
            onPressed: () async {
              try {
                await ref.read(authControllerProvider).signOut();
                if (!mounted) return;
                context.go('/login');
              } catch (e) {
                if (!mounted) return;
                ScaffoldMessenger.of(context)
                    .showSnackBar(SnackBar(content: Text(e.toString())));
              }
            },
          ),
        ],
      ),
      body: uid == null
          ? const Center(child: Text('No autenticado'))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                profile.when(
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Text(e.toString()),
                  data: (data) {
                    final savingsCents = (data?['savingsCents'] as int?) ?? 0;
                    return Card(
                      child: ListTile(
                        title: const Text('Ahorros'),
                        subtitle: const Text('Se sincroniza con tu cuenta'),
                        trailing: Text(formatMXNFromCents(savingsCents)),
                        onTap: () async {
                          final newSavings =
                              await _askSavings(context, initialCents: savingsCents);
                          if (newSavings != null) {
                            await ref.read(profileServiceProvider).setSavings(uid, newSavings);
                          }
                        },
                      ),
                    );
                  },
                ),
                const SizedBox(height: 12),
                Card(
                  child: ListTile(
                    title: const Text('Domiciliados / Recurrentes'),
                    subtitle: const Text('Ver o agregar pagos recurrentes'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.push('/recurring'),
                  ),
                ),
              ],
            ),
    );
  }
}

Future<int?> _askSavings(BuildContext context, {required int? initialCents}) async {
  final controller = TextEditingController(
    text: initialCents == null ? '' : (initialCents / 100).toStringAsFixed(2),
  );

  return showDialog<int?>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) {
      return AlertDialog(
        title: const Text('¿Cuánto tienes en ahorros?'),
        content: TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(prefixText: r'$ ', hintText: '0.00'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(null),
            child: const Text('Omitir'),
          ),
          FilledButton(
            onPressed: () {
              final cents = parseCents(controller.text);
              Navigator.of(ctx).pop(cents);
            },
            child: const Text('Guardar'),
          ),
        ],
      );
    },
  );
}

Future<bool?> _askAddRecurrings(BuildContext context) {
  return showDialog<bool?>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => AlertDialog(
      title: const Text('Pagos domiciliados / recurrentes'),
      content: const Text('¿Quieres agregar pagos recurrentes ahora?'),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: const Text('No por ahora'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(ctx).pop(true),
          child: const Text('Sí, agregar'),
        ),
      ],
    ),
  );
}

Future<bool?> _askPaid(BuildContext context, RecurringPayment p) {
  return showDialog<bool?>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => AlertDialog(
      title: const Text('Pago vencido'),
      content: Text('¿Ya pagaste "${p.concept}" por ${formatMXNFromCents(p.amountCents)}?'),
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
    ),
  );
}
