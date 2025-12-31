import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/theme/app_theme.dart';
import 'features/auth/presentation/login_screen.dart';
import 'features/dashboard/presentation/dashboard_screen.dart';
import 'features/transactions/presentation/transactions_screen.dart';
import 'features/transactions/presentation/add_transaction_screen.dart';

import 'features/transactions/data/local/db_provider.dart';
import 'features/transactions/data/local/db_seed.dart';
import 'features/recurring/presentation/recurring_screen.dart';
import 'features/recurring/presentation/add_recurring_screen.dart';

final bootstrapProvider = FutureProvider<void>((ref) async {
  final db = ref.read(dbProvider);
  await seedIfEmpty(db);
});

/// Notifica a GoRouter cuando cambia el stream (auth changes)
class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(Stream<dynamic> stream) {
    _sub = stream.asBroadcastStream().listen((_) => notifyListeners());
  }

  late final StreamSubscription<dynamic> _sub;

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }
}

final _routerProvider = Provider<GoRouter>((ref) {
  final auth = FirebaseAuth.instance;
  final refresh = GoRouterRefreshStream(auth.authStateChanges());

  final router = GoRouter(
    initialLocation: '/login',
    refreshListenable: refresh,
    redirect: (context, state) {
      final loggedIn = auth.currentUser != null;

      final goingToLogin = state.uri.path == '/login';

      // Si NO está logueado y quiere ir a cualquier pantalla protegida
      if (!loggedIn && !goingToLogin) {
        return '/login';
      }

      // Si YA está logueado y quiere ir a login
      if (loggedIn && goingToLogin) {
        return '/dashboard';
      }

      return null;
    },
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
          GoRoute(
  path: '/recurring',
  builder: (_, __) => const RecurringScreen(),
  routes: [
    GoRoute(
      path: 'add',
      builder: (_, __) => const AddRecurringScreen(),
    ),
  ],
),
        ],
      ),
    ],
  );

  // Limpieza cuando el provider se destruya
  ref.onDispose(() {
    refresh.dispose();
    router.dispose();
  });

  return router;
});

class App extends ConsumerWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final boot = ref.watch(bootstrapProvider);

    return boot.when(
      loading: () => const MaterialApp(
        home: Scaffold(body: Center(child: CircularProgressIndicator())),
      ),
      error: (e, _) => MaterialApp(
        home: Scaffold(body: Center(child: Text(e.toString()))),
      ),
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
      case 2:
  context.go('/recurring');
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
  NavigationDestination(icon: Icon(Icons.repeat), label: 'Recurrentes'),
],
      ),
    );
  }
}
