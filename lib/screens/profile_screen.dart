import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/app_user.dart';
import '../models/swap_request.dart';
import '../services/admin_session_service.dart';
import '../services/auth_service.dart';
import '../services/payment_service.dart';
import '../services/station_service.dart';
import '../services/supabase_service.dart';
import '../services/swap_service.dart';
import '../widgets/wallet_card.dart';
import 'auth_gate_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _authService = AuthService();
  final _adminSessionService = AdminSessionService();
  final _paymentService = PaymentService();
  final _client = SupabaseService.client;
  late final SwapService _swapService = SwapService(
    authService: _authService,
    stationService: StationService(),
  );
  late Future<AppUser?> _profileFuture;
  late Future<List<SwapRequest>> _swapFuture;
  RealtimeChannel? _userChannel;

  @override
  void initState() {
    super.initState();
    _profileFuture = Future.value(null);
    _swapFuture = Future.value(const <SwapRequest>[]);
    _loadProtectedData();
    _setupRealtimeListener();
  }

  void _setupRealtimeListener() {
    final userId = _authService.currentAuthUser?.id;
    if (userId == null) return;

    debugPrint('Setting up real-time listener for user: $userId');

    // Subscribe to user profile changes (battery assignments, wallet)
    _userChannel = _client
        .channel('profile-changes-$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'users',
          callback: (payload) {
            debugPrint('Real-time event received for users table');
            debugPrint('Old record: ${payload.oldRecord}');
            debugPrint('New record: ${payload.newRecord}');

            // Refresh if this update affects battery or wallet fields
            if (payload.newRecord['id'].toString() == userId) {
              debugPrint(
                'Update detected for current user - refreshing profile...',
              );
              if (mounted) {
                _refreshProfileData();
              }
            }
          },
        )
        .subscribe();
  }

  @override
  void dispose() {
    _userChannel?.unsubscribe();
    super.dispose();
  }

  // Refresh user profile data
  Future<void> _refreshProfileData() async {
    debugPrint('Refreshing profile data from database...');
    if (!mounted) return;
    setState(() {
      _profileFuture = _authService.getProfile();
    });
  }

  Future<void> _loadProtectedData() async {
    if (_authService.currentAuthUser == null) {
      if (!mounted) return;
      Navigator.pushNamedAndRemoveUntil(
        context,
        AuthGateScreen.routeName,
        (_) => false,
      );
      return;
    }

    setState(() {
      _profileFuture = _authService.getProfile();
      _swapFuture = _swapService.getMySwaps();
    });
  }

  Future<void> _signOut() async {
    await _adminSessionService.setAdminLoggedIn(false);
    await _authService.signOut();
    if (!mounted) return;
    Navigator.pushNamedAndRemoveUntil(
      context,
      AuthGateScreen.routeName,
      (_) => false,
    );
  }

  Future<void> _showAddMoneyDialog() async {
    final amountController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool isLoading = false;

    await showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Add Money to Wallet'),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Enter amount to add (₹):',
                    style: TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: amountController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      prefixText: '₹ ',
                      hintText: '100.00',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Amount is required';
                      }
                      final amount = double.tryParse(value);
                      if (amount == null || amount <= 0) {
                        return 'Enter a valid amount';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Note: This will trigger Razorpay/Stripe payment in production',
                    style: TextStyle(fontSize: 12, color: Colors.orange),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: isLoading ? null : () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: isLoading
                  ? null
                  : () async {
                      if (formKey.currentState?.validate() != true) return;

                      setState(() => isLoading = true);

                      try {
                        final amount = double.parse(
                          amountController.text.trim(),
                        );
                        final userId = _authService.currentAuthUser?.id;

                        if (userId == null) {
                          throw Exception('User not authenticated');
                        }

                        // Add money to wallet
                        await _paymentService.addMoneyToWallet(
                          userId: userId,
                          amount: amount,
                        );

                        if (!mounted) return;
                        Navigator.pop(context);

                        // Refresh profile
                        setState(() {
                          _profileFuture = _authService.getProfile();
                        });

                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              '₹${amount.toStringAsFixed(2)} added successfully!',
                            ),
                            backgroundColor: Colors.green,
                          ),
                        );
                      } catch (e) {
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Payment failed: $e'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      } finally {
                        if (mounted) setState(() => isLoading = false);
                      }
                    },
              child: isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Pay Now'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showEditProfileDialog(AppUser user) async {
    final nameController = TextEditingController(text: user.name);
    final phoneController = TextEditingController(text: user.phone);
    final vehicleNumberController = TextEditingController(
      text: user.vehicleNumber,
    );
    final aadharController = TextEditingController(text: user.aadharNumber);
    final formKey = GlobalKey<FormState>();

    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Profile'),
        content: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'Name'),
                  validator: (value) => (value == null || value.trim().isEmpty)
                      ? 'Name required'
                      : null,
                ),
                TextFormField(
                  controller: phoneController,
                  decoration: const InputDecoration(labelText: 'Phone'),
                  keyboardType: TextInputType.phone,
                  validator: (value) => (value == null || value.trim().isEmpty)
                      ? 'Phone required'
                      : null,
                ),
                TextFormField(
                  controller: aadharController,
                  decoration: const InputDecoration(labelText: 'Aadhar Number'),
                  keyboardType: TextInputType.number,
                  enabled: false,
                ),
                TextFormField(
                  controller: vehicleNumberController,
                  decoration: const InputDecoration(
                    labelText: 'Vehicle Number',
                  ),
                  validator: (value) => (value == null || value.trim().isEmpty)
                      ? 'Vehicle number required'
                      : null,
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (formKey.currentState?.validate() != true) return;
              try {
                await _authService.updateProfile(
                  name: nameController.text.trim(),
                  phone: phoneController.text.trim(),
                  vehicleNumber: vehicleNumberController.text.trim(),
                  aadharNumber: aadharController.text.trim(),
                );
                if (!mounted) return;
                setState(() {
                  _profileFuture = _authService.getProfile();
                });
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Profile updated successfully')),
                );
              } catch (e) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Failed to update profile: $e')),
                );
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Profile'),
        elevation: 0,
        actions: [
          IconButton(
            onPressed: _refreshProfileData,
            icon: const Icon(Icons.refresh, size: 22),
            tooltip: 'Refresh',
            iconSize: 22,
          ),
          IconButton(
            onPressed: _signOut,
            icon: const Icon(Icons.logout),
            tooltip: 'Sign Out',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await _loadProtectedData();
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Profile Section
            Row(
              children: [
                const Icon(
                  Icons.person_outline,
                  color: Color(0xFF1565C0),
                  size: 24,
                ),
                const SizedBox(width: 8),
                Text(
                  'My Account',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            FutureBuilder<AppUser?>(
              future: _profileFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Card(
                    child: Padding(
                      padding: EdgeInsets.all(32),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                  );
                }
                if (snapshot.hasError) {
                  return Card(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                          Icon(
                            Icons.error_outline,
                            color: Colors.grey.shade400,
                            size: 48,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Unable to load profile right now',
                            style: TextStyle(color: Colors.grey.shade600),
                          ),
                        ],
                      ),
                    ),
                  );
                }
                final user = snapshot.data;
                return Card(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: user == null
                        ? Column(
                            children: [
                              Icon(
                                Icons.account_circle,
                                color: Colors.grey.shade400,
                                size: 48,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'Profile not found',
                                style: TextStyle(color: Colors.grey.shade600),
                              ),
                            ],
                          )
                        : Column(
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFE3F2FD),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: const Icon(
                                      Icons.account_circle,
                                      color: Color(0xFF1565C0),
                                      size: 24,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          user.name,
                                          style: const TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.black87,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          user.email,
                                          style: TextStyle(
                                            color: Colors.grey.shade600,
                                            fontSize: 14,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  IconButton(
                                    onPressed: () =>
                                        _showEditProfileDialog(user),
                                    icon: const Icon(Icons.edit),
                                    tooltip: 'Edit Profile',
                                  ),
                                ],
                              ),
                              const SizedBox(height: 20),
                              _buildProfileItem(
                                Icons.phone_outlined,
                                'Phone',
                                user.phone,
                              ),
                              const SizedBox(height: 12),
                              _buildProfileItem(
                                Icons.badge,
                                'Aadhar',
                                user.aadharNumber,
                              ),
                              const SizedBox(height: 12),
                              _buildProfileItem(
                                Icons.directions_car_outlined,
                                'Vehicle Number',
                                user.vehicleNumber,
                              ),
                            ],
                          ),
                  ),
                );
              },
            ),

            const SizedBox(height: 24),

            // Wallet Section
            Row(
              children: [
                const Icon(
                  Icons.account_balance_wallet,
                  color: Color(0xFF1565C0),
                  size: 24,
                ),
                const SizedBox(width: 8),
                Text(
                  'My Wallet',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            FutureBuilder<AppUser?>(
              future: _profileFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Card(
                    child: Padding(
                      padding: EdgeInsets.all(32),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                  );
                }
                final user = snapshot.data;
                if (snapshot.hasError || user == null) {
                  return Card(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                          Icon(
                            Icons.error_outline,
                            color: Colors.grey.shade400,
                            size: 48,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Unable to load wallet',
                            style: TextStyle(color: Colors.grey.shade600),
                          ),
                        ],
                      ),
                    ),
                  );
                }
                return WalletCard(
                  balance: user.walletBalance,
                  onAddMoney: _showAddMoneyDialog,
                );
              },
            ),

            const SizedBox(height: 24),
            Row(
              children: [
                const Icon(
                  Icons.battery_charging_full,
                  color: Color(0xFF1565C0),
                  size: 24,
                ),
                const SizedBox(width: 8),
                Text(
                  'Current Battery',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            FutureBuilder<AppUser?>(
              future: _profileFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Card(
                    child: Padding(
                      padding: EdgeInsets.all(32),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                  );
                }
                if (snapshot.hasError || snapshot.data == null) {
                  return Card(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                          Icon(
                            Icons.battery_alert,
                            color: Colors.grey.shade400,
                            size: 48,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Unable to load current battery info',
                            style: TextStyle(color: Colors.grey.shade600),
                          ),
                        ],
                      ),
                    ),
                  );
                }
                final user = snapshot.data!;
                return Card(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child:
                        user.currentBatterySlotId == null ||
                            user.currentStationId == null
                        ? Column(
                            children: [
                              Icon(
                                Icons.battery_unknown,
                                color: Colors.grey.shade400,
                                size: 48,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'No battery assigned',
                                style: TextStyle(color: Colors.grey.shade600),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Complete a battery swap to assign one',
                                style: TextStyle(
                                  color: Colors.grey.shade500,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          )
                        : Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFE8F5E8),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(
                                  Icons.battery_full,
                                  color: Color(0xFF4CAF50),
                                  size: 24,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Station: ${user.currentStationId}',
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.black87,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Slot: ${user.currentBatterySlotId}',
                                      style: TextStyle(
                                        color: Colors.grey.shade600,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                  ),
                );
              },
            ),

            const SizedBox(height: 24),

            // Swap History Section
            Row(
              children: [
                const Icon(Icons.history, color: Color(0xFF1565C0), size: 24),
                const SizedBox(width: 8),
                Text(
                  'My Swap History',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            FutureBuilder<List<SwapRequest>>(
              future: _swapFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Card(
                    child: Padding(
                      padding: EdgeInsets.all(32),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                  );
                }
                if (snapshot.hasError) {
                  return Card(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                          Icon(
                            Icons.error_outline,
                            color: Colors.grey.shade400,
                            size: 48,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Unable to load swap history',
                            style: TextStyle(color: Colors.grey.shade600),
                          ),
                        ],
                      ),
                    ),
                  );
                }
                final swaps = snapshot.data ?? [];
                if (swaps.isEmpty) {
                  return Card(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        children: [
                          Icon(
                            Icons.battery_charging_full,
                            color: Colors.grey.shade400,
                            size: 48,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'No battery swaps yet',
                            style: TextStyle(color: Colors.grey.shade600),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Your swap history will appear here',
                            style: TextStyle(
                              color: Colors.grey.shade500,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }
                return Column(
                  children: swaps
                      .map(
                        (swap) => Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 2,
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFE8F5E8),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(
                                    Icons.swap_horiz,
                                    color: Color(0xFF4CAF50),
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Station ${swap.stationId} • Slot ${swap.slotId}',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 16,
                                          color: Colors.black87,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Swapped on ${DateFormat('dd MMM yyyy, hh:mm a').format(swap.createdAt.toLocal())}',
                                        style: TextStyle(
                                          color: Colors.grey.shade600,
                                          fontSize: 12,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: _statusColor(
                                            swap.status,
                                          ).withOpacity(0.12),
                                          borderRadius: BorderRadius.circular(
                                            999,
                                          ),
                                        ),
                                        child: Text(
                                          swap.status.toUpperCase(),
                                          style: TextStyle(
                                            color: _statusColor(swap.status),
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      )
                      .toList(),
                );
              },
            ),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileItem(IconData icon, String label, String value) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFFF5F5F5),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: Colors.grey.shade600, size: 16),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
            Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Colors.black87,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'success':
        return const Color(0xFF2E7D32);
      case 'failed':
        return const Color(0xFFC62828);
      default:
        return const Color(0xFFEF6C00);
    }
  }
}
