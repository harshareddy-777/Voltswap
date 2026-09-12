import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/admin_session_service.dart';
import 'admin_dashboard_screen.dart';
import 'login_screen.dart';
import 'user_shell_screen.dart';

class AuthGateScreen extends StatefulWidget {
  const AuthGateScreen({super.key});
  static const routeName = '/';

  @override
  State<AuthGateScreen> createState() => _AuthGateScreenState();
}

class _AuthGateScreenState extends State<AuthGateScreen> {
  final _adminSessionService = AdminSessionService();

  @override
  void initState() {
    super.initState();
    _validateAndRoute();
  }

  Future<void> _validateAndRoute() async {
    try {
      final isAdmin = await _adminSessionService.isAdminLoggedIn();
      if (!mounted) return;
      if (isAdmin) {
        Navigator.pushReplacementNamed(context, AdminDashboardScreen.routeName);
        return;
      }

      final session = Supabase.instance.client.auth.currentSession;
      final currentUser = Supabase.instance.client.auth.currentUser;
      if (session == null || currentUser == null) {
        if (!mounted) return;
        Navigator.pushReplacementNamed(context, LoginScreen.routeName);
        return;
      }

      if (!mounted) return;
      Navigator.pushReplacementNamed(context, UserShellScreen.routeName);
    } catch (_) {
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, LoginScreen.routeName);
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
}
