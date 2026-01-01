import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'auth_controller.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  bool loading = false;

  Future<void> _signIn() async {
    setState(() => loading = true);
    try {
      await ref.read(authControllerProvider).signInWithGoogle();
      if (!mounted) return;
      context.go('/dashboard');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final size = MediaQuery.sizeOf(context);
    final isWide = size.width >= 900;
    final contentMaxWidth = isWide ? 520.0 : double.infinity;

    return Scaffold(
      body: Stack(
        children: [
          // Fondo con degradado en azules
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    const Color(0xFF071A3A), // azul noche
                    const Color(0xFF0B3C91), // azul fuerte
                    const Color(0xFF0EA5E9), // azul cielo
                  ],
                ),
              ),
            ),
          ),

          // “Manchas” suaves para dar profundidad
          Positioned(
            top: -60,
            left: -40,
            child: _GlowBlob(
              color: const Color(0xFF60A5FA).withOpacity(0.35),
              size: 240,
            ),
          ),
          Positioned(
            bottom: -80,
            right: -60,
            child: _GlowBlob(
              color: const Color(0xFF38BDF8).withOpacity(0.30),
              size: 300,
            ),
          ),
          Positioned(
            top: size.height * 0.25,
            right: -30,
            child: _GlowBlob(
              color: const Color(0xFF1D4ED8).withOpacity(0.22),
              size: 180,
            ),
          ),

          SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: contentMaxWidth),
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: isWide ? 0 : 20,
                    vertical: 24,
                  ),
                  child: _GlassCard(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final compact = constraints.maxWidth < 420;

                          return Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Header
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  _AppMark(size: compact ? 44 : 52),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      'Finanzas Personales',
                                      style: theme.textTheme.titleLarge?.copyWith(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 18),

                              Text(
                                'Tus finanzas, en un solo lugar',
                                style: theme.textTheme.headlineSmall?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                  height: 1.15,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                'Inicia sesión para respaldar y sincronizar tus datos (opcional).',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: Colors.white.withOpacity(0.85),
                                  height: 1.35,
                                ),
                              ),

                              const SizedBox(height: 18),

                              // Bullets de valor (pro)
                              _FeatureRow(
                                icon: Icons.cloud_done_outlined,
                                text: 'Tus datos se sincronizan con tu cuenta.',
                              ),
                              const SizedBox(height: 10),
                              _FeatureRow(
                                icon: Icons.lock_outline,
                                text: 'Acceso seguro con Google.',
                              ),
                              const SizedBox(height: 10),
                              _FeatureRow(
                                icon: Icons.show_chart_outlined,
                                text: 'Dashboard con ahorros, movimientos y recurrentes.',
                              ),

                              const SizedBox(height: 22),

                              // Botón principal
                              SizedBox(
                                width: double.infinity,
                                child: FilledButton(
                                  onPressed: loading ? null : _signIn,
                                  style: FilledButton.styleFrom(
                                    padding: EdgeInsets.symmetric(
                                      vertical: compact ? 14 : 16,
                                      horizontal: 16,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    backgroundColor: const Color(0xFF1D4ED8),
                                    foregroundColor: Colors.white,
                                    elevation: 0,
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      if (loading)
                                        const SizedBox(
                                          height: 18,
                                          width: 18,
                                          child: CircularProgressIndicator(strokeWidth: 2),
                                        )
                                      else
                                        const Icon(Icons.login, size: 20),
                                      const SizedBox(width: 10),
                                      Text(
                                        loading ? 'Entrando…' : 'Continuar con Google',
                                        style: theme.textTheme.titleMedium?.copyWith(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),

                              const SizedBox(height: 12),

                              // Nota opcional
                              Text(
                                'Puedes usar la app sin iniciar sesión, pero sin respaldo en la nube.',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: Colors.white.withOpacity(0.70),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
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

class _FeatureRow extends StatelessWidget {
  const _FeatureRow({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: Colors.white.withOpacity(0.9), size: 18),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.white.withOpacity(0.85),
                  height: 1.25,
                ),
          ),
        ),
      ],
    );
  }
}

class _AppMark extends StatelessWidget {
  const _AppMark({required this.size});
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: size,
      width: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * 0.28),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF60A5FA),
            Color(0xFF1D4ED8),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.20),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: const Center(
        child: Icon(Icons.account_balance_wallet_outlined, color: Colors.white),
      ),
    );
  }
}

class _GlassCard extends StatelessWidget {
  const _GlassCard({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.10),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: Colors.white.withOpacity(0.18)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.18),
                blurRadius: 24,
                offset: const Offset(0, 18),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}

class _GlowBlob extends StatelessWidget {
  const _GlowBlob({required this.color, required this.size});
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
        boxShadow: [
          BoxShadow(
            color: color,
            blurRadius: 60,
            spreadRadius: 18,
          ),
        ],
      ),
    );
  }
}
