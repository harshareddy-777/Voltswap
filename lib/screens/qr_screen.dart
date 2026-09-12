import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../services/auth_service.dart';
import '../services/payment_service.dart';
import '../services/station_service.dart';
import '../services/swap_service.dart';

class QrScreen extends StatefulWidget {
  const QrScreen({super.key, required this.result});

  final SwapResult result;

  @override
  State<QrScreen> createState() => _QrScreenState();
}

class _QrScreenState extends State<QrScreen> {
  late final SwapService _swapService;
  late final PaymentService _paymentService;
  bool _isUpdating = false;
  bool _swapCompleted = false;
  bool _swapFailureHandled = false;

  @override
  void initState() {
    super.initState();
    _swapService = SwapService(
      authService: AuthService(),
      stationService: StationService(),
    );
    _paymentService = PaymentService();
  }

  @override
  void dispose() {
    if (!_swapCompleted && !_swapFailureHandled) {
      unawaited(_swapService.markSwapFailed(widget.result.requestId));
    }
    super.dispose();
  }

  Future<void> _markSwapSuccessful() async {
    if (_isUpdating) return;

    // First, show payment confirmation dialog
    final userId = AuthService().currentAuthUser?.id;
    if (userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('User not authenticated'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      // Get pricing and wallet balance
      final pricing = await _paymentService.getPricing();
      final walletBalance = await _paymentService.getWalletBalance(userId);

      if (!mounted) return;

      // Show payment confirmation dialog
      final confirmed = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: const Text('Confirm Payment'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Battery Swap Cost:',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 4),
              Text(
                '₹${pricing.swapPrice.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.green,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Available Balance: ₹${walletBalance.toStringAsFixed(2)}',
                style: TextStyle(
                  fontSize: 14,
                  color: walletBalance >= pricing.swapPrice
                      ? Colors.green
                      : Colors.red,
                ),
              ),
              const SizedBox(height: 16),
              if (walletBalance < pricing.swapPrice)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: Text(
                    'Insufficient balance. Please add money to your wallet.',
                    style: TextStyle(color: Colors.red.shade700, fontSize: 12),
                  ),
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            if (walletBalance >= pricing.swapPrice)
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                child: const Text('Pay & Confirm'),
              ),
            if (walletBalance < pricing.swapPrice)
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context, false);
                  _showAddMoneyDialog();
                },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                child: const Text('Add Money'),
              ),
          ],
        ),
      );

      if (confirmed != true) {
        _swapFailureHandled = true;
        await _swapService.markSwapFailed(widget.result.requestId);
        return;
      }

      // Process payment
      setState(() => _isUpdating = true);

      final paymentSuccessful = await _paymentService.processSwapPayment(
        userId: userId,
        swapPrice: pricing.swapPrice,
      );

      if (!paymentSuccessful) {
        if (!mounted) return;
        _swapFailureHandled = true;
        await _swapService.markSwapFailed(widget.result.requestId);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Insufficient balance. Please add money first.'),
            backgroundColor: Colors.red,
          ),
        );
        setState(() => _isUpdating = false);
        return;
      }

      // Payment successful, mark swap as successful
      await _swapService.markSwapSuccessful(
        requestId: widget.result.requestId,
        stationId: widget.result.stationId,
        slotId: widget.result.slotId,
      );
      _swapCompleted = true;

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Battery swap completed successfully!'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to complete swap: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isUpdating = false);
      }
    }
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
                        final userId = AuthService().currentAuthUser?.id;

                        if (userId == null) {
                          throw Exception('User not authenticated');
                        }

                        await _paymentService.addMoneyToWallet(
                          userId: userId,
                          amount: amount,
                        );

                        if (!mounted) return;
                        Navigator.pop(context);

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

  Future<bool> _handleExit() async {
    if (_isUpdating || _swapCompleted || _swapFailureHandled) {
      return !_isUpdating;
    }

    _swapFailureHandled = true;
    await _swapService.markSwapFailed(widget.result.requestId);
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final payload = jsonEncode({
      'request_id': widget.result.requestId,
      'station_id': widget.result.stationId,
      'slot_id': widget.result.slotId,
      'charge_percentage': widget.result.chargePercentage,
    });

    return WillPopScope(
      onWillPop: _handleExit,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Battery Swap QR'),
          leading: IconButton(
            onPressed: _isUpdating
                ? null
                : () async {
                    final shouldPop = await _handleExit();
                    if (!mounted || !shouldPop) return;
                    Navigator.pop(context, false);
                  },
            icon: const Icon(Icons.arrow_back),
          ),
        ),
        body: Center(
          child: Card(
            elevation: 8,
            margin: const EdgeInsets.all(20),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Scan this at station',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1565C0),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: const Color(0xFFE3F2FD),
                        width: 2,
                      ),
                    ),
                    child: QrImageView(
                      data: payload,
                      size: 200,
                      backgroundColor: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE3F2FD),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.ev_station,
                              color: Color(0xFF1565C0),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Station: ${widget.result.stationId}',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF1565C0),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.battery_full,
                              color: Color(0xFF1565C0),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Battery ID: ${widget.result.slotId}',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF1565C0),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Leaving this screen without confirming will mark the swap as failed.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isUpdating ? null : _markSwapSuccessful,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: Colors.green,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _isUpdating
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.white,
                                ),
                              ),
                            )
                          : const Text(
                              'Pay Now',
                              style: TextStyle(
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
      ),
    );
  }
}
