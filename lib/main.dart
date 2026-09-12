import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'screens/admin_dashboard_screen.dart';
import 'screens/admin_login_screen.dart';
import 'screens/advanced_options_screen.dart';
import 'screens/auth_gate_screen.dart';
import 'screens/login_screen.dart';
import 'screens/signup_screen.dart';
import 'screens/user_shell_screen.dart';
import 'utils/app_config.dart';
import 'utils/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: AppConfig.supabaseUrl,
    anonKey: AppConfig.supabaseAnonKey,
  );
  runApp(const VoltSwapApp());
}

class VoltSwapApp extends StatelessWidget {
  const VoltSwapApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Volt Swap',
      theme: AppTheme.themeData,
      initialRoute: AuthGateScreen.routeName,
      routes: {
        AuthGateScreen.routeName: (_) => const AuthGateScreen(),
        LoginScreen.routeName: (_) => const LoginScreen(),
        SignupScreen.routeName: (_) => const SignupScreen(),
        AdminLoginScreen.routeName: (_) => const AdminLoginScreen(),
        UserShellScreen.routeName: (_) => const UserShellScreen(),
        AdminDashboardScreen.routeName: (_) => const AdminDashboardScreen(),
        AdvancedOptionsScreen.routeName: (_) => const AdvancedOptionsScreen(),
      },
    );
  }
}
