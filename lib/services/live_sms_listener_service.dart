import 'package:another_telephony/telephony.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/budget_provider.dart';
import 'sms_transaction_service.dart';

class LiveSmsListenerService {
  LiveSmsListenerService._();

  static final LiveSmsListenerService instance = LiveSmsListenerService._();

  static const _keyLastSmsCheck = 'last_sms_check_timestamp';

  final Telephony _telephony = Telephony.instance;
  bool _isListening = false;

  Future<void> start(BudgetProvider budget) async {
    if (_isListening) return;

    final granted = await _telephony.requestPhoneAndSmsPermissions;
    if (granted != true) {
      debugPrint('LiveSmsListenerService: SMS permissions not granted');
      return;
    }

    // Catch up on missed SMS since last check
    await _catchUpMissedSms(budget);

    _telephony.listenIncomingSms(
      onNewMessage: (SmsMessage message) async {
        await _handleIncomingSms(message, budget);
      },
      listenInBackground: true,
    );

    _isListening = true;
    debugPrint('LiveSmsListenerService: started');
  }

  /// Import any SMS transactions received while the app was closed.
  Future<void> _catchUpMissedSms(BudgetProvider budget) async {
    try {
      final enabled = await SmsTransactionService.getAutoListenEnabled();
      if (!enabled) return;

      final allParsed = await SmsTransactionService.fetchBankTransactions();
      final newTxns = SmsTransactionService.filterNew(allParsed, budget.transactions);

      for (final parsed in newTxns) {
        parsed.categoryId ??= SmsTransactionService.suggestCategory(
          parsed.merchant,
          budget.categories,
        );
        final tx = await SmsTransactionService.toTransaction(
          parsed,
          primaryCurrency: budget.currency,
        );
        await budget.addTransaction(tx);
      }

      if (newTxns.isNotEmpty) {
        debugPrint('LiveSmsListenerService: caught up ${newTxns.length} missed SMS transactions');
      }

      // Update last check timestamp
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_keyLastSmsCheck, DateTime.now().millisecondsSinceEpoch);
    } catch (e) {
      debugPrint('LiveSmsListenerService: catch-up error: $e');
    }
  }

  Future<void> _handleIncomingSms(SmsMessage message, BudgetProvider budget) async {
    try {
      final body = message.body ?? '';
      final address = message.address ?? '';

      if (body.trim().isEmpty) return;

      final enabled = await SmsTransactionService.getAutoListenEnabled();
      if (!enabled) return;

      final senderMatches = await SmsTransactionService.isConfiguredSender(address);
      if (!senderMatches) return;

      final parsed = await SmsTransactionService.parseBodyWithCurrentPattern(body);
      if (parsed == null) return;

      parsed.categoryId ??= SmsTransactionService.suggestCategory(
        parsed.merchant,
        budget.categories,
      );

      final tx = await SmsTransactionService.toTransaction(
        parsed,
        primaryCurrency: budget.currency,
      );

      if (budget.isDuplicateTransaction(tx)) {
        debugPrint('LiveSmsListenerService: skipped duplicate SMS transaction');
        return;
      }

      await budget.addTransaction(tx);
      debugPrint('LiveSmsListenerService: transaction auto-added from incoming SMS');
    } catch (e) {
      debugPrint('LiveSmsListenerService error: $e');
    }
  }
}
