import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../models/account_model.dart';
import '../models/account_provider.dart';
import '../models/budget_provider.dart';
import '../utils/formatters.dart';

class AccountsScreen extends StatelessWidget {
  const AccountsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bank Accounts'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded),
            tooltip: 'Add account',
            onPressed: () => _openEditor(context),
          ),
        ],
      ),
      body: Consumer2<AccountProvider, BudgetProvider>(
        builder: (context, accounts, budget, _) {
          final list = accounts.allAccountsIncludingArchived;
          if (list.isEmpty) {
            return const Center(child: Text('No accounts yet'));
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: list.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, i) {
              final a = list[i];
              final balance =
                  accounts.balanceFor(a.id, budget.transactions);
              return Card(
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: cs.primaryContainer,
                    child: Icon(
                      a.isSavings
                          ? Icons.savings_rounded
                          : Icons.account_balance_rounded,
                      color: cs.onPrimaryContainer,
                    ),
                  ),
                  title: Text(a.name),
                  subtitle: Text(
                    '${_bankLabel(a.bank)} · ${a.isSavings ? "Savings" : "Current"}${a.archived ? " · Archived" : ""}',
                    style: TextStyle(color: cs.outline),
                  ),
                  trailing: Text(
                    formatCurrency(balance, 'MVR'),
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: balance < 0 ? cs.error : cs.onSurface,
                    ),
                  ),
                  onTap: () => _openEditor(context, existing: a),
                ),
              );
            },
          );
        },
      ),
    );
  }

  String _bankLabel(BankType bank) {
    switch (bank) {
      case BankType.bml:
        return 'BML';
      case BankType.islamicBank:
        return 'IslamicBank';
      case BankType.other:
        return 'Other';
    }
  }

  Future<void> _openEditor(BuildContext context, {Account? existing}) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _AccountEditorSheet(existing: existing),
    );
  }
}

class _AccountEditorSheet extends StatefulWidget {
  final Account? existing;
  const _AccountEditorSheet({this.existing});

  @override
  State<_AccountEditorSheet> createState() => _AccountEditorSheetState();
}

class _AccountEditorSheetState extends State<_AccountEditorSheet> {
  late TextEditingController _nameCtrl;
  late TextEditingController _openingCtrl;
  BankType _bank = BankType.other;
  AccountType _type = AccountType.current;
  bool _includeInBudget = true;
  bool _archived = false;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _nameCtrl = TextEditingController(text: e?.name ?? '');
    _openingCtrl =
        TextEditingController(text: e?.openingBalance.toString() ?? '0');
    _bank = e?.bank ?? BankType.other;
    _type = e?.type ?? AccountType.current;
    _includeInBudget = e?.includeInBudget ?? true;
    _archived = e?.archived ?? false;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _openingCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existing != null;
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
          Text(
            isEdit ? 'Edit account' : 'Add account',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _nameCtrl,
            decoration: const InputDecoration(
              labelText: 'Name',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _openingCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Opening balance',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          const Text('Bank', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: BankType.values.map((b) {
              final label = switch (b) {
                BankType.bml => 'BML',
                BankType.islamicBank => 'IslamicBank',
                BankType.other => 'Other',
              };
              return ChoiceChip(
                label: Text(label),
                selected: _bank == b,
                onSelected: (_) => setState(() => _bank = b),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
          const Text('Type', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: AccountType.values.map((t) {
              return ChoiceChip(
                label: Text(t == AccountType.savings ? 'Savings' : 'Current'),
                selected: _type == t,
                onSelected: (_) => setState(() {
                  _type = t;
                  _includeInBudget = t == AccountType.current;
                }),
              );
            }).toList(),
          ),
          const SizedBox(height: 8),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _includeInBudget,
            onChanged: (v) => setState(() => _includeInBudget = v),
            title: const Text('Count in monthly budget'),
            subtitle: const Text(
                'Savings accounts should normally be excluded so they don\'t distort budget math.'),
          ),
          if (isEdit)
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _archived,
              onChanged: (v) => setState(() => _archived = v),
              title: const Text('Archived'),
            ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _save,
            child: Text(isEdit ? 'Save' : 'Create'),
          ),
        ],
      ),
    );
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) return;
    final opening = double.tryParse(_openingCtrl.text.trim()) ?? 0;
    final provider = context.read<AccountProvider>();
    if (widget.existing == null) {
      await provider.addAccount(Account(
        id: const Uuid().v4(),
        name: name,
        bank: _bank,
        type: _type,
        openingBalance: opening,
        includeInBudget: _includeInBudget,
        archived: _archived,
      ));
    } else {
      await provider.updateAccount(
        widget.existing!.id,
        widget.existing!.copyWith(
          name: name,
          bank: _bank,
          type: _type,
          openingBalance: opening,
          includeInBudget: _includeInBudget,
          archived: _archived,
        ),
      );
    }
    if (!mounted) return;
    Navigator.of(context).pop();
  }
}
