import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';


import 'core/theme/app_theme.dart';
import 'features/auth/presentation/login_screen.dart';
import 'features/dashboard/presentation/dashboard_screen.dart';
import 'features/transactions/presentation/transactions_screen.dart';

import 'features/transactions/data/local/db_provider.dart';
import 'features/transactions/data/local/db_seed.dart';
import 'features/transactions/presentation/add_transaction_screen.dart';


final bootstrapProvider = FutureProvider<void>((ref) async {
final db = ref.read(dbProvider);
await seedIfEmpty(db);
});

final _routerProvider = Provider<GoRouter>((ref) {
return GoRouter(
initialLocation: '/login',
routes: [
GoRoute(
path: '/login',
builder: (_, __) => const LoginScreen(),
),
ShellRoute(
builder: (context, state, child) => MainScaffold(child: child),
routes: [
GoRoute(
path: '/dashboard',
builder: (_, __) => const DashboardScreen(),
),
GoRoute(
path: '/transactions',
builder: (_, __) => const TransactionsScreen(),
routes: [
GoRoute(
path: 'add',
builder: (_, __) => const AddTransactionScreen(),
),
],
),
],
),
],
);
}
);

class App extends ConsumerWidget {
const App({super.key});


@override
Widget build(BuildContext context, WidgetRef ref) {
final boot = ref.watch(bootstrapProvider);
return boot.when(
loading: () => const MaterialApp(home: Scaffold(body: Center(child: CircularProgressIndicator()))),
error: (e, _) => MaterialApp(home: Scaffold(body: Center(child: Text(e.toString())))),
data: (_) {
final router = ref.watch(_routerProvider);
return MaterialApp.router(
debugShowCheckedModeBanner: false,
theme: AppTheme.light(),
darkTheme: AppTheme.dark(),
routerConfig: router,
);
},
);
}
}

class MainScaffold extends StatefulWidget {
const MainScaffold({super.key, required this.child});
final Widget child;


@override
State<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends State<MainScaffold> {
int index = 0;


void _onTap(int i) {
setState(() => index = i);
switch (i) {
case 0:
context.go('/dashboard');
break;
case 1:
context.go('/transactions');
break;
}
}

@override
Widget build(BuildContext context) {
return Scaffold(
body: widget.child,
bottomNavigationBar: NavigationBar(
selectedIndex: index,
onDestinationSelected: _onTap,
destinations: const [
NavigationDestination(icon: Icon(Icons.dashboard_outlined), label: 'Dashboard'),
NavigationDestination(icon: Icon(Icons.swap_horiz), label: 'Movimientos'),
],
),
);
}
}