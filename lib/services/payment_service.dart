import 'package:flutter/foundation.dart';

import '../models/pricing.dart';
import '../models/transaction.dart';
import 'supabase_service.dart';

class PaymentFailure implements Exception {
  const PaymentFailure(this.message);

  final String message;

  @override
  String toString() => message;
}

class PaymentService {
  final _client = SupabaseService.client;

  /// Get current wallet balance for user
  Future<double> getWalletBalance(String userId) async {
    try {
      final response = await _client
          .from('users')
          .select('wallet_balance')
          .eq('id', userId)
          .single();

      return (response['wallet_balance'] as num?)?.toDouble() ?? 0.0;
    } catch (e, st) {
      debugPrint('PaymentService.getWalletBalance error: $e\n$st');
      throw PaymentFailure('Failed to fetch wallet balance');
    }
  }

  /// Get current swap pricing from admin
  Future<Pricing> getPricing() async {
    try {
      final response = await _client
          .from('pricing')
          .select()
          .eq('id', 1)
          .single();

      return Pricing.fromMap(response);
    } catch (e, st) {
      debugPrint('PaymentService.getPricing error: $e\n$st');
      // Return default pricing if not set
      return const Pricing(id: 1, swapPrice: 10.0);
    }
  }

  /// Add money to wallet (simulate payment gateway success)
  /// In production, this would integrate with Razorpay/Stripe
  ///
  /// IMPORTANT: This is a test/demo implementation.
  /// For production, integrate with:
  /// - Razorpay: https://razorpay.com/docs/
  /// - Stripe: https://stripe.com/docs
  /// - Google Pay / Apple Pay
  ///
  /// Steps for integration:
  /// 1. Initialize payment gateway SDK
  /// 2. Create payment order on backend
  /// 3. Launch payment UI
  /// 4. Verify payment signature
  /// 5. Only then call this method to update wallet
  Future<void> addMoneyToWallet({
    required String userId,
    required double amount,
  }) async {
    if (amount <= 0) {
      throw PaymentFailure('Amount must be greater than 0');
    }

    try {
      // IMPORTANT: Use atomic operation to prevent race conditions
      // This uses SQL to atomically add amount in one operation
      await _client.rpc(
        'add_wallet_balance',
        params: {'p_user_id': userId, 'p_amount': amount},
      );

      // Insert credit transaction
      await _client.from('transactions').insert({
        'user_id': userId,
        'amount': amount,
        'type': 'credit',
        'status': 'success',
      });
    } catch (e, st) {
      debugPrint('PaymentService.addMoneyToWallet error: $e\n$st');
      // Insert failed transaction
      try {
        await _client.from('transactions').insert({
          'user_id': userId,
          'amount': amount,
          'type': 'credit',
          'status': 'failed',
        });
      } catch (e2) {
        debugPrint('Failed to log failed transaction: $e2');
      }
      throw PaymentFailure('Failed to add money to wallet');
    }
  }

  /// Process payment for battery swap
  /// Uses atomic operation to prevent race conditions
  Future<bool> processSwapPayment({
    required String userId,
    required double swapPrice,
  }) async {
    try {
      // Get current balance
      final currentBalance = await getWalletBalance(userId);

      // Check if sufficient balance
      if (currentBalance < swapPrice) {
        return false; // Insufficient balance
      }

      // Deduct amount using atomic operation
      // This prevents race conditions with concurrent requests
      await _client.rpc(
        'deduct_wallet_balance',
        params: {'p_user_id': userId, 'p_amount': swapPrice},
      );

      // Insert debit transaction
      await _client.from('transactions').insert({
        'user_id': userId,
        'amount': swapPrice,
        'type': 'debit',
        'status': 'success',
      });

      return true; // Payment successful
    } catch (e, st) {
      debugPrint('PaymentService.processSwapPayment error: $e\n$st');
      // Try to log failed transaction
      try {
        await _client.from('transactions').insert({
          'user_id': userId,
          'amount': swapPrice,
          'type': 'debit',
          'status': 'failed',
        });
      } catch (e2) {
        debugPrint('Failed to log failed transaction: $e2');
      }
      throw PaymentFailure('Failed to process swap payment');
    }
  }

  /// Get transaction history for user
  Future<List<Transaction>> getTransactionHistory(String userId) async {
    try {
      final response = await _client
          .from('transactions')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false)
          .limit(50);

      return (response as List<dynamic>)
          .map((item) => Transaction.fromMap(item as Map<String, dynamic>))
          .toList();
    } catch (e, st) {
      debugPrint('PaymentService.getTransactionHistory error: $e\n$st');
      return [];
    }
  }

  /// Update swap price (Admin only)
  Future<void> updateSwapPrice(double newPrice) async {
    if (newPrice <= 0) {
      throw PaymentFailure('Price must be greater than 0');
    }

    try {
      await _client
          .from('pricing')
          .update({'swap_price': newPrice})
          .eq('id', 1);
    } catch (e, st) {
      debugPrint('PaymentService.updateSwapPrice error: $e\n$st');
      throw PaymentFailure('Failed to update swap price');
    }
  }
}
