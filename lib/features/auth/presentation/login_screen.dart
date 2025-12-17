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


@override
Widget build(BuildContext context) {
return Scaffold(
body: SafeArea(
child: Padding(
padding: const EdgeInsets.all(20),
child: Column(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
const SizedBox(height: 24),
Text('Tus finanzas, en un solo lugar', style: Theme.of(context).textTheme.headlineMedium),
const SizedBox(height: 8),
Text('Inicia sesión para respaldar y sincronizar tus datos (opcional).',
style: Theme.of(context).textTheme.bodyMedium),
const Spacer(),
FilledButton.icon(
onPressed: loading
? null
: () async {
setState(() => loading = true);
try {
await ref.read(authControllerProvider).signInWithGoogle();
if (mounted) context.go('/dashboard');
} catch (e) {
if (!mounted) return;
ScaffoldMessenger.of(context).showSnackBar(
SnackBar(content: Text(e.toString())),
);
} finally {
if (mounted) setState(() => loading = false);
}
},
icon: const Icon(Icons.login),
label: Text(loading ? 'Entrando…' : 'Continuar con Google'),
),
const SizedBox(height: 16),
],
),
),
),
);
}
}