import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/account_model.dart';
import '../models/account_provider.dart';
import '../models/budget_provider.dart';

/// Modal sheet for moving money between the user's own accounts. Writes two
/// transactions (expense on source, income on destination) sharing a
/// transferGroupId so budget/stats math can exclude them as non-spending.
class TransferSheet extends StatefulWidget {
  const TransferSheet({super.key});

  @override
  State<TransferSheet> createState() => _TransferSheetState();
}

class _TransferSheetState extends State<TransferSheet> {
  Account? _from;
  Account? _to;
  final _amountCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  DateTime _date = DateTime.now();
  bool _saving = false;

  @override
  void dispose() {
    _amountCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accounts = context.watch<AccountProvider>().accounts;
    _from ??= accounts.isNotEmpty ? accounts.first : null;
    if (accounts.length > 1 && _to == null) {
      _to = accounts.firstWhere(
        (a) => a.id != _from?.id,
        orElse: () => accounts.last,
      );
    }

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 8,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Transfer between accounts',
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          _accountPicker(
              label: 'From', value: _from, onChanged: (a) => setState(() => _from = a)),
          const SizedBox(height: 12),
          _accountPicker(
              label: 'To', value: _to, onChanged: (a) => setState(() => _to = a)),
          const SizedBox(height: 12),
          TextField(
            controller: _amountCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Amount',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _noteCtrl,
            decoration: const InputDecoration(
              labelText: 'Note (optional)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Date'),
            trailing: Text(
                '${_date.year}-${_date.month.toString().padLeft(2, "0")}-${_date.day.toString().padLeft(2, "0")}'),
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: _date,
                firstDate: DateTime(2000),
                lastDate: DateTime.now().add(const Duration(days: 1)),
              );
              if (picked != null) setState(() => _date = picked);
            },
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: _saving ? null : _submit,
            child: _saving
                ? const SizedBox(
                    height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Transfer'),
          ),
        ],
      ),
    );
  }

  Widget _accountPicker({
    required String label,
    required Account? value,
    required ValueChanged<Account?> onChanged,
  }) {
    final accounts = context.watch<AccountProvider>().accounts;
    return DropdownButtonFormField<String>(
      initialValue: value?.id,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
      items: accounts
          .map((a) => DropdownMenuItem(
                value: a.id,
                child: Text(a.name),
              ))
          .toList(),
      onChanged: (id) {
        final picked = accounts.firstWhere(
          (a) => a.id == id,
          orElse: () => accounts.first,
        );
        onChanged(picked);
      },
    );
  }

  Future<void> _submit() async {
    final from = _from;
    final to = _to;
    if (from == null || to == null || from.id == to.id) {
      _show('Pick two different accounts');
      return;
    }
    final amount = double.tryParse(_amountCtrl.text.trim()) ?? 0;
    if (amount <= 0) {
      _show('Enter a positive amount');
      return;
    }

    setState(() => _saving = true);
    try {
      await context.read<BudgetProvider>().createTransfer(
            fromAccountId: from.id,
            toAccountId: to.id,
            amount: amount,
            date: _date,
            note: _noteCtrl.text.trim(),
          );
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (e) {
      _show('Transfer failed: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _show(String msg) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }
}
