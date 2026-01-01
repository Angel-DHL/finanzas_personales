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

  final _conceptCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();

  bool _saving = false;

  int _dayOfMonth = 15;
  bool _requireConfirmation = true; // true: pregunta / false: auto

  @override
  void dispose() {
    _conceptCtrl.dispose();
    _amountCtrl.dispose();
    super.dispose();
  }

  int _parseCentsLoose(String input) {
    final normalized = input.replaceAll(',', '').trim();
    return parseCents(normalized);
  }

  @override
  Widget build(BuildContext context) {
    final uid = ref.watch(uidProvider);
    final isWide = MediaQuery.sizeOf(context).width >= 950;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F8FF),
      body: uid == null
          ? const Center(child: Text('No autenticado'))
          : CustomScrollView(
              slivers: [
                SliverAppBar(
                  pinned: true,
                  elevation: 0,
                  backgroundColor: const Color(0xFF061A3A),
                  expandedHeight: 160,
                  leading: IconButton(
                    icon: const Icon(Icons.arrow_back),
                    onPressed: () => Navigator.of(context).maybePop(),
                  ),
                  title: const Text('Agregar recurrente'),
                  flexibleSpace: const FlexibleSpaceBar(
                    background: _AddRecurringHeader(),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                  sliver: SliverToBoxAdapter(
                    child: Align(
                      alignment: Alignment.topCenter,
                      child: ConstrainedBox(
                        constraints: BoxConstraints(maxWidth: isWide ? 980 : double.infinity),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            children: [
                              _SectionCard(
                                title: 'Información del pago',
                                child: Column(
                                  children: [
                                    TextFormField(
                                      controller: _conceptCtrl,
                                      textInputAction: TextInputAction.next,
                                      decoration: _inputDeco(
                                        label: 'Concepto',
                                        hintText: 'Ej. Netflix, Internet, Renta…',
                                        icon: Icons.text_snippet_rounded,
                                      ),
                                      validator: (v) {
                                        if (v == null || v.trim().isEmpty) return 'Escribe un concepto';
                                        if (v.trim().length < 3) return 'Escribe un concepto más descriptivo';
                                        return null;
                                      },
                                    ),
                                    const SizedBox(height: 12),
                                    TextFormField(
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
                                  ],
                                ),
                              ),
                              const SizedBox(height: 12),

                              _SectionCard(
                                title: 'Cuándo se cobra',
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Selecciona el día del mes:',
                                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                            color: const Color(0xFF061A3A).withOpacity(0.75),
                                            fontWeight: FontWeight.w700,
                                          ),
                                    ),
                                    const SizedBox(height: 10),

                                    // ✅ NUEVO: selector tipo “calendario” con 31 días visibles
                                    _DayOfMonthPicker(
                                      value: _dayOfMonth,
                                      onChanged: (d) => setState(() => _dayOfMonth = d),
                                    ),

                                    const SizedBox(height: 10),
                                    Text(
                                      'Seleccionado: Día $_dayOfMonth',
                                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                            color: const Color(0xFF061A3A).withOpacity(0.75),
                                            fontWeight: FontWeight.w800,
                                          ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Tip: Si tu cobro cae en 29/30/31, el sistema lo ajusta al último día del mes cuando aplica.',
                                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                            color: const Color(0xFF061A3A).withOpacity(0.65),
                                          ),
                                    ),
                                  ],
                                ),
                              ),

                              const SizedBox(height: 12),

                              _SectionCard(
                                title: 'Modo de cobro',
                                child: Column(
                                  children: [
                                    _ModeTile(
                                      value: _requireConfirmation,
                                      onChanged: (v) => setState(() => _requireConfirmation = v),
                                    ),
                                    const SizedBox(height: 8),
                                    _ModeHint(requireConfirmation: _requireConfirmation),
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
                                      onPressed: _saving
                                          ? null
                                          : () async {
                                              if (uid == null) return;
                                              if (!_formKey.currentState!.validate()) return;

                                              setState(() => _saving = true);
                                              try {
                                                final concept = _conceptCtrl.text.trim();
                                                final amountCents = _parseCentsLoose(_amountCtrl.text);

                                                await ref.read(recurringServiceProvider).addRecurring(
                                                      uid: uid,
                                                      concept: concept,
                                                      amountCents: amountCents,
                                                      dayOfMonth: _dayOfMonth,
                                                      requireConfirmation: _requireConfirmation,
                                                    );

                                                if (!mounted) return;
                                                Navigator.of(context).pop();
                                              } catch (e) {
                                                if (!mounted) return;
                                                ScaffoldMessenger.of(context).showSnackBar(
                                                  SnackBar(content: Text(e.toString())),
                                                );
                                              } finally {
                                                if (mounted) setState(() => _saving = false);
                                              }
                                            },
                                      icon: const Icon(Icons.save_rounded),
                                      label: Text(_saving ? 'Guardando…' : 'Guardar recurrente'),
                                      style: FilledButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(vertical: 14),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                        backgroundColor: const Color(0xFF0B3C91),
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    Text(
                                      'Podrás ver estos cobros en “Recurrentes” y afectarán tus ahorros según el modo.',
                                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                            color: const Color(0xFF061A3A).withOpacity(0.65),
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
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

/// Selector tipo “calendario” (grid 7 columnas) con 31 días visibles
class _DayOfMonthPicker extends StatelessWidget {
  const _DayOfMonthPicker({
    required this.value,
    required this.onChanged,
  });

  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    const cols = 7;
    const totalDays = 31;

    // 31 días -> 5 filas (aprox). Alto fijo para que no rompa layout.
    return SizedBox(
      height: 6 * 44, // un poco holgado
      child: GridView.builder(
        physics: const NeverScrollableScrollPhysics(),
        itemCount: totalDays,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: cols,
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          childAspectRatio: 1.15,
        ),
        itemBuilder: (ctx, i) {
          final day = i + 1;
          final selected = day == value;

          final bg = selected ? const Color(0xFF0B3C91) : Colors.white;
          final fg = selected ? Colors.white : const Color(0xFF071A3A);
          final border = selected ? const Color(0xFF0B3C91) : const Color(0xFF0B3C91).withOpacity(0.18);

          return Material(
            color: bg,
            borderRadius: BorderRadius.circular(14),
            child: InkWell(
              onTap: () => onChanged(day),
              borderRadius: BorderRadius.circular(14),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: border, width: 1.2),
                  boxShadow: selected
                      ? [
                          BoxShadow(
                            color: const Color(0xFF0B3C91).withOpacity(0.20),
                            blurRadius: 14,
                            offset: const Offset(0, 8),
                          )
                        ]
                      : null,
                ),
                alignment: Alignment.center,
                child: Text(
                  '$day',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: fg,
                        fontWeight: FontWeight.w900,
                      ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// ---------------- Header ----------------
class _AddRecurringHeader extends StatelessWidget {
  const _AddRecurringHeader();

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
                  Color(0xFF061A3A),
                  Color(0xFF0B3C91),
                ],
              ),
            ),
          ),
        ),
        Positioned(
          top: -45,
          right: -25,
          child: _Blob(color: Colors.white.withOpacity(0.12), size: 175),
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
                  'Agrega un pago recurrente',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                      ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Para que la app te ayude a planear y descontar a tiempo.',
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

/// ---------------- UI helpers ----------------
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
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                  color: const Color(0xFF071A3A),
                ),
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

class _ModeTile extends StatelessWidget {
  const _ModeTile({required this.value, required this.onChanged});
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0B3C91).withOpacity(0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF0B3C91).withOpacity(0.10)),
      ),
      child: SwitchListTile(
        value: value,
        onChanged: onChanged,
        title: Text(
          value ? 'Pedir confirmación' : 'Descontar automáticamente',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w900,
                color: const Color(0xFF071A3A),
              ),
        ),
        subtitle: Text(
          value ? 'Te preguntará si ya se pagó.' : 'Se descontará al vencer.',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: const Color(0xFF071A3A).withOpacity(0.70),
                fontWeight: FontWeight.w600,
              ),
        ),
        activeColor: const Color(0xFF0B3C91),
      ),
    );
  }
}

class _ModeHint extends StatelessWidget {
  const _ModeHint({required this.requireConfirmation});
  final bool requireConfirmation;

  @override
  Widget build(BuildContext context) {
    final text = requireConfirmation
        ? 'Cuando llegue la fecha, la app te preguntará si el pago ya se realizó. Si dices “sí”, descontará de ahorros.'
        : 'Cuando llegue la fecha, la app descontará automáticamente el monto de tus ahorros y avanzará al siguiente mes.';
    return Text(
      text,
      style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: const Color(0xFF061A3A).withOpacity(0.65),
          ),
    );
  }
}
