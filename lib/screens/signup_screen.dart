import 'package:flutter/material.dart';

import '../services/admin_session_service.dart';
import '../services/auth_service.dart';
import 'auth_gate_screen.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});
  static const routeName = '/signup';

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _vehicleNumberController = TextEditingController();
  final _aadharController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _authService = AuthService();
  final _adminSessionService = AdminSessionService();
  bool _loading = false;
  String? _errorMessage;
  String? _selectedBatteryType;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _vehicleNumberController.dispose();
    _aadharController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _signup() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedBatteryType == null) {
      setState(() => _errorMessage = 'Please select a battery type');
      return;
    }
    setState(() {
      _loading = true;
      _errorMessage = null;
    });
    try {
      await _authService.signUp(
        name: _nameController.text.trim(),
        phone: _phoneController.text.trim(),
        vehicleNumber: _vehicleNumberController.text.trim(),
        aadharNumber: _aadharController.text.trim(),
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
        batteryType: _selectedBatteryType!,
      );
      await _adminSessionService.setAdminLoggedIn(false);
      if (!mounted) return;
      Navigator.pushNamedAndRemoveUntil(
        context,
        AuthGateScreen.routeName,
        (_) => false,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString();
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_errorMessage!)));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create Account'), elevation: 0),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Join Volt Swap',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1565C0),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Create your account to start swapping batteries',
                  style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
                ),
                const SizedBox(height: 32),
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Full Name',
                    prefixIcon: Icon(Icons.person_outline),
                  ),
                  validator: (value) => (value == null || value.isEmpty)
                      ? 'Full name is required'
                      : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Mobile Number',
                    prefixIcon: Icon(Icons.phone_outlined),
                  ),
                  validator: (value) => (value == null || value.length < 8)
                      ? 'Please enter a valid phone number'
                      : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _aadharController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Aadhar Number',
                    prefixIcon: Icon(Icons.badge),
                    hintText: '12-digit number',
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Aadhar number is required';
                    }
                    if (value.length != 12 ||
                        !value.contains(RegExp(r'^[0-9]{12}$'))) {
                      return 'Aadhar number must be exactly 12 digits';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _vehicleNumberController,
                  decoration: const InputDecoration(
                    labelText: 'Vehicle Number',
                    prefixIcon: Icon(Icons.directions_car_outlined),
                    hintText: 'e.g., TS09AB1234',
                  ),
                  validator: (value) => (value == null || value.isEmpty)
                      ? 'Vehicle number is required'
                      : null,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: _selectedBatteryType,
                  decoration: const InputDecoration(
                    labelText: 'Battery Type',
                    prefixIcon: Icon(Icons.battery_std_outlined),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'LFP', child: Text('LFP')),
                    DropdownMenuItem(value: 'NMC', child: Text('NMC')),
                    DropdownMenuItem(value: 'NMA', child: Text('NMA')),
                  ],
                  onChanged: (value) =>
                      setState(() => _selectedBatteryType = value),
                  validator: (value) =>
                      value == null ? 'Please select a battery type' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Email Address',
                    prefixIcon: Icon(Icons.email_outlined),
                  ),
                  validator: (value) => (value == null || !value.contains('@'))
                      ? 'Please enter a valid email address'
                      : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _passwordController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Password',
                    prefixIcon: Icon(Icons.lock_outlined),
                  ),
                  validator: (value) => (value == null || value.length < 6)
                      ? 'Password must be at least 6 characters'
                      : null,
                ),
                const SizedBox(height: 32),
                if (_errorMessage != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(
                      _errorMessage!,
                      style: const TextStyle(color: Colors.red, fontSize: 14),
                      textAlign: TextAlign.center,
                    ),
                  ),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _loading ? null : _signup,
                    child: Text(
                      _loading ? 'Creating account...' : 'Create Account',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
