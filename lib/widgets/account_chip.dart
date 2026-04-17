import 'package:flutter/material.dart';

import '../models/account_model.dart';

/// Small pill showing "{bank} · {name}" in the category-chip visual style.
/// Rendered next to transaction tiles once accounts exist.
class AccountChip extends StatelessWidget {
  final Account account;
  final VoidCallback? onTap;
  const AccountChip({super.key, required this.account, this.onTap});

  Color _bankColor(BankType bank, ColorScheme cs) {
    switch (bank) {
      case BankType.bml:
        return const Color(0xFFFF4D2D);
      case BankType.islamicBank:
        return const Color(0xFF2E7D32);
      case BankType.other:
        return cs.secondary;
    }
  }

  String _bankLabel(BankType bank) {
    switch (bank) {
      case BankType.bml:
        return 'BML';
      case BankType.islamicBank:
        return 'IB';
      case BankType.other:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final color = _bankColor(account.bank, cs);
    final bank = _bankLabel(account.bank);
    final label = bank.isEmpty ? account.name : '$bank · ${account.name}';

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: color.withValues(alpha: 0.35)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              account.isSavings
                  ? Icons.savings_rounded
                  : Icons.account_balance_rounded,
              size: 13,
              color: color,
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
