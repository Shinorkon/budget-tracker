import 'package:another_telephony/telephony.dart';
import 'package:flutter/foundation.dart';

import '../models/budget_provider.dart';
import 'sms_transaction_service.dart';

class LiveSmsListenerService {
  LiveSmsListenerService._();

  static final LiveSmsListenerService instance = LiveSmsListenerService._();

  final Telephony _telephony = Telephony.instance;
  bool _isListening = false;

  Future<void> start(BudgetProvider budget) async {
    if (_isListening) return;

    final granted = await _telephony.requestPhoneAndSmsPermissions;
    if (granted != true) {
      debugPrint('LiveSmsListenerService: SMS permissions not granted');
      return;
    }

    _telephony.listenIncomingSms(
      onNewMessage: (SmsMessage message) async {
        try {
          final body = message.body ?? '';
          final address = message.address ?? '';

          if (body.trim().isEmpty) return;

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
      },
      listenInBackground: false,
    );

    _isListening = true;
    debugPrint('LiveSmsListenerService: started');
  }
}
