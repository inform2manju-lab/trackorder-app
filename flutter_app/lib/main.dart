import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'config/theme.dart';
import 'providers/auth_provider.dart';
import 'services/api_service.dart';
import 'services/location_service.dart';
import 'screens/auth/login_screen.dart';
import 'screens/dashboard/dashboard_screen.dart';
import 'screens/tracking/tracking_screen.dart';
import 'screens/tracking/attendance_screen.dart';
import 'screens/orders/orders_screen.dart';
import 'screens/tasks/tasks_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  ApiService.init();
  await LocationService.init();
  runApp(const TrackOrderApp());
}

class TrackOrderApp extends StatelessWidget {
  const TrackOrderApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()..checkAuth()),
      ],
      child: MaterialApp(
        title: 'TrackOrder',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        home: const AppRoot(),
      ),
    );
  }
}

class AppRoot extends StatelessWidget {
  const AppRoot({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (ctx, auth, _) {
        if (auth.status == AuthStatus.unknown) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        if (auth.status == AuthStatus.unauthenticated) {
          return const LoginScreen();
        }
        return const HomeShell();
      },
    );
  }
}

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    LocationService.requestPermissions().then((granted) {
      if (granted) LocationService.startTracking();
    });
  }

  @override
  void dispose() {
    LocationService.stopTracking();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final isAdmin = auth.isAdmin;
    final isSupervisor = auth.isSupervisor;

    // Build nav items based on role
    final List<({Widget screen, BottomNavigationBarItem navItem})> pages = [
      (
        screen: const DashboardScreen(),
        navItem: const BottomNavigationBarItem(icon: Icon(Icons.dashboard_outlined), activeIcon: Icon(Icons.dashboard), label: 'Dashboard'),
      ),
      if (isAdmin || isSupervisor)
        (
          screen: const TrackingScreen(),
          navItem: const BottomNavigationBarItem(icon: Icon(Icons.map_outlined), activeIcon: Icon(Icons.map), label: 'Tracking'),
        ),
      (
        screen: const AttendanceScreen(),
        navItem: const BottomNavigationBarItem(icon: Icon(Icons.how_to_reg_outlined), activeIcon: Icon(Icons.how_to_reg), label: 'Attendance'),
      ),
      (
        screen: const OrdersScreen(),
        navItem: const BottomNavigationBarItem(icon: Icon(Icons.receipt_long_outlined), activeIcon: Icon(Icons.receipt_long), label: 'Orders'),
      ),
      (
        screen: const TasksScreen(),
        navItem: const BottomNavigationBarItem(icon: Icon(Icons.task_outlined), activeIcon: Icon(Icons.task), label: 'Tasks'),
      ),
    ];

    final idx = _selectedIndex.clamp(0, pages.length - 1);

    return Scaffold(
      body: IndexedStack(
        index: idx,
        children: pages.map((p) => p.screen).toList(),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: idx,
        onTap: (i) => setState(() => _selectedIndex = i),
        items: pages.map((p) => p.navItem).toList(),
      ),
    );
  }
}
