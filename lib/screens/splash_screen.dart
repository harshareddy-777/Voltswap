import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'login_screen.dart';
import 'user_shell_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  static const routeName = '/';

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    Future<void>.delayed(const Duration(milliseconds: 700), _route);
  }

  void _route() {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (!mounted) return;
      Navigator.pushReplacementNamed(
        context,
        user == null ? LoginScreen.routeName : UserShellScreen.routeName,
      );
    } catch (_) {
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, LoginScreen.routeName);
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Text(
          'Volt Swap',
          style: TextStyle(
            color: Color(0xFF1565C0),
            fontWeight: FontWeight.w700,
            fontSize: 32,
          ),
        ),
      ),
    );
  }
}
