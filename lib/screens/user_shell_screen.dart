import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'auth_gate_screen.dart';
import 'map_home_screen.dart';
import 'profile_screen.dart';

class UserShellScreen extends StatefulWidget {
  const UserShellScreen({super.key});
  static const routeName = '/user-shell';

  @override
  State<UserShellScreen> createState() => _UserShellScreenState();
}

class _UserShellScreenState extends State<UserShellScreen> {
  int _index = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final currentUser = Supabase.instance.client.auth.currentUser;
      if (!mounted || currentUser != null) return;
      Navigator.pushNamedAndRemoveUntil(
        context,
        AuthGateScreen.routeName,
        (_) => false,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    const pages = [MapHomeScreen(), ProfileScreen()];
    return Scaffold(
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 250),
        child: pages[_index],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (value) => setState(() => _index = value),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), label: 'Home'),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}
