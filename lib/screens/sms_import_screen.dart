import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../models/budget_model.dart';
import '../models/budget_provider.dart';
import '../services/sms_transaction_service.dart';
import '../utils/formatters.dart';

class SmsImportScreen extends StatefulWidget {
  const SmsImportScreen({super.key});

  @override
  State<SmsImportScreen> createState() => _SmsImportScreenState();
}

class _SmsImportScreenState extends State<SmsImportScreen> {
  List<ParsedSmsTransaction>? _transactions;
  List<ParsedSmsTransaction>? _filteredTransactions;
  bool _loading = true;
  String? _error;
  bool _showAll = false;
  String _currentSender = SmsTransactionService.defaultSender;
  DateTime _dateRangeStart = DateTime.now().subtract(const Duration(days: 30));
  DateTime _dateRangeEnd = DateTime.now();
  bool _dateFilterEnabled = false;

  @override
  void initState() {
    super.initState();
    _loadSms();
  }

  Future<void> _loadSms() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      _currentSender = await SmsTransactionService.getSender();
      final all = await SmsTransactionService.fetchBankTransactions();

      if (!mounted) return;
      final budget = Provider.of<BudgetProvider>(context, listen: false);
      final categories = budget.categories;

      for (final tx in all) {
        tx.categoryId ??=
            SmsTransactionService.suggestCategory(tx.merchant, categories);
      }

      final newOnly = SmsTransactionService.filterNew(all, budget.transactions);

      setState(() {
        _transactions = _showAll ? all : newOnly;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  int get _selectedCount =>
      _getDisplayedTransactions()?.where((t) => t.selected).length ?? 0;

  List<ParsedSmsTransaction>? _getDisplayedTransactions() {
    if (_dateFilterEnabled && _filteredTransactions != null) {
      return _filteredTransactions;
    }
    return _transactions;
  }

  void _applyDateFilter() {
    if (_transactions == null) return;
    final filtered = SmsTransactionService.filterByDateRange(
      _transactions!,
      _dateRangeStart,
      _dateRangeEnd,
    );
    setState(() {
      _filteredTransactions = filtered;
    });
  }

  void _clearDateFilter() {
    setState(() {
      _dateFilterEnabled = false;
      _filteredTransactions = null;
    });
  }

  Future<void> _importSelected() async {
    final budget = Provider.of<BudgetProvider>(context, listen: false);
    final displayed = _getDisplayedTransactions();
    if (displayed == null) return;

    final selected = displayed.where((t) => t.selected).toList();

    int imported = 0;
    int skipped = 0;
    for (final parsed in selected) {
      final tx = await SmsTransactionService.toTransaction(
        parsed,
        primaryCurrency: budget.currency,
      );

      final alreadyExists = budget.isDuplicateTransaction(tx);
      if (alreadyExists) {
        skipped++;
        continue;
      }

      await budget.addTransaction(tx);
      imported++;
    }

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          skipped > 0
              ? 'Imported $imported, skipped $skipped duplicate${skipped == 1 ? '' : 's'}'
              : 'Imported $imported transaction${imported == 1 ? '' : 's'}',
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        backgroundColor: AppColors.income,
      ),
    );

    Navigator.of(context).pop();
  }

  Future<void> _showDateFilter() async {
    DateTime tempStart = _dateRangeStart;
    DateTime tempEnd = _dateRangeEnd;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: Container(
            decoration: const BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.textMuted,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  'Filter by Date Range',
                  style: Theme.of(ctx).textTheme.titleLarge,
                ),
                const SizedBox(height: 20),
                // Quick filters
                const Text(
                  'Quick Filters',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildQuickFilterChip(
                        ctx,
                        '7 Days',
                        () {
                          setModalState(() {
                            tempEnd = DateTime.now();
                            tempStart =
                                tempEnd.subtract(const Duration(days: 7));
                          });
                        },
                      ),
                      const SizedBox(width: 8),
                      _buildQuickFilterChip(
                        ctx,
                        '14 Days',
                        () {
                          setModalState(() {
                            tempEnd = DateTime.now();
                            tempStart =
                                tempEnd.subtract(const Duration(days: 14));
                          });
                        },
                      ),
                      const SizedBox(width: 8),
                      _buildQuickFilterChip(
                        ctx,
                        '30 Days',
                        () {
                          setModalState(() {
                            tempEnd = DateTime.now();
                            tempStart =
                                tempEnd.subtract(const Duration(days: 30));
                          });
                        },
                      ),
                      const SizedBox(width: 8),
                      _buildQuickFilterChip(
                        ctx,
                        '90 Days',
                        () {
                          setModalState(() {
                            tempEnd = DateTime.now();
                            tempStart =
                                tempEnd.subtract(const Duration(days: 90));
                          });
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                // Custom date range
                const Text(
                  'Custom Range',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () async {
                          final date = await showDatePicker(
                            context: ctx,
                            initialDate: tempStart,
                            firstDate: DateTime(2000),
                            lastDate: tempEnd,
                          );
                          if (date != null) {
                            setModalState(() => tempStart = date);
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              vertical: 12, horizontal: 16),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceLight,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.primary),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'From',
                                style: TextStyle(
                                  color: AppColors.textMuted,
                                  fontSize: 11,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${tempStart.year}-${tempStart.month.toString().padLeft(2, '0')}-${tempStart.day.toString().padLeft(2, '0')}',
                                style: const TextStyle(
                                  color: AppColors.textPrimary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: GestureDetector(
                        onTap: () async {
                          final date = await showDatePicker(
                            context: ctx,
                            initialDate: tempEnd,
                            firstDate: tempStart,
                            lastDate: DateTime.now(),
                          );
                          if (date != null) {
                            setModalState(() => tempEnd = date);
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              vertical: 12, horizontal: 16),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceLight,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.primary),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'To',
                                style: TextStyle(
                                  color: AppColors.textMuted,
                                  fontSize: 11,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${tempEnd.year}-${tempEnd.month.toString().padLeft(2, '0')}-${tempEnd.day.toString().padLeft(2, '0')}',
                                style: const TextStyle(
                                  color: AppColors.textPrimary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(ctx),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          side:
                              const BorderSide(color: AppColors.textSecondary),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          setState(() {
                            _dateRangeStart = tempStart;
                            _dateRangeEnd = tempEnd;
                            _dateFilterEnabled = true;
                          });
                          _applyDateFilter();
                          Navigator.pop(ctx);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text('Apply Filter',
                            style: TextStyle(fontWeight: FontWeight.w600)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildQuickFilterChip(
    BuildContext ctx,
    String label,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.surfaceLight,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.primary),
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: AppColors.primary,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  void _showSettings() {
    final senderCtrl = TextEditingController(text: _currentSender);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding:
            EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: Container(
          decoration: const BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.textMuted,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'SMS Settings',
                style: Theme.of(ctx).textTheme.titleLarge,
              ),
              const SizedBox(height: 6),
              const Text(
                'Configure which SMS sender to read bank transactions from.',
                style: TextStyle(color: AppColors.textMuted, fontSize: 13),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: senderCtrl,
                style: const TextStyle(color: AppColors.textPrimary),
                decoration: InputDecoration(
                  labelText: 'Sender Address',
                  hintText: 'e.g. 455, BML, BANKNAME',
                  hintStyle: const TextStyle(color: AppColors.textMuted),
                  labelStyle:
                      const TextStyle(color: AppColors.textSecondary),
                  filled: true,
                  fillColor: AppColors.surfaceLight,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  prefixIcon: const Icon(Icons.sms_rounded,
                      color: AppColors.primary, size: 20),
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Only SMS matching the bank transaction format will be shown. OTPs and other messages are automatically filtered out.',
                style: TextStyle(color: AppColors.textMuted, fontSize: 11),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    await SmsTransactionService.setSender(senderCtrl.text);
                    if (!ctx.mounted) return;
                    Navigator.pop(ctx);
                    _loadSms();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('Save & Reload',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final budget = Provider.of<BudgetProvider>(context);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        title: const Text('Import from SMS'),
        actions: [
          IconButton(
            onPressed: _dateFilterEnabled ? _clearDateFilter : _showDateFilter,
            icon: Icon(
              _dateFilterEnabled ? Icons.calendar_today : Icons.calendar_today_outlined,
              size: 20,
              color: _dateFilterEnabled ? AppColors.income : AppColors.accent,
            ),
            tooltip: _dateFilterEnabled ? 'Clear Date Filter' : 'Filter by Date',
          ),
          IconButton(
            onPressed: _showSettings,
            icon: const Icon(Icons.tune_rounded, size: 20),
            tooltip: 'SMS Settings',
          ),
          TextButton.icon(
            onPressed: () {
              setState(() => _showAll = !_showAll);
              _loadSms();
            },
            icon: Icon(
              _showAll ? Icons.filter_list_off : Icons.filter_list,
              size: 18,
              color: AppColors.accent,
            ),
            label: Text(
              _showAll ? 'New Only' : 'Show All',
              style: const TextStyle(color: AppColors.accent, fontSize: 13),
            ),
          ),
        ],
      ),
      body: _loading
          ? const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: AppColors.primary),
                  SizedBox(height: 16),
                  Text(
                    'Reading SMS...',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                ],
              ),
            )
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.sms_failed_rounded,
                            color: AppColors.expense, size: 48),
                        const SizedBox(height: 16),
                        Text(
                          'Could not read SMS',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _error!,
                          style: const TextStyle(
                              color: AppColors.textMuted, fontSize: 13),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton.icon(
                          onPressed: _loadSms,
                          icon: const Icon(Icons.refresh_rounded),
                          label: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                )
              : _transactions == null || _transactions!.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.check_circle_outline_rounded,
                                color: AppColors.income, size: 48),
                            const SizedBox(height: 16),
                            Text(
                              _showAll
                                  ? 'No bank transactions found'
                                  : 'All caught up!',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _showAll
                                  ? 'No transaction SMS found from sender $_currentSender'
                                  : 'All SMS transactions are already imported',
                              style: const TextStyle(
                                  color: AppColors.textMuted, fontSize: 13),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 20),
                            OutlinedButton.icon(
                              onPressed: _showSettings,
                              icon: const Icon(Icons.tune_rounded, size: 18),
                              label: const Text('Change Sender'),
                            ),
                          ],
                        ),
                      ),
                    )
                  : Column(
                      children: [
                        // Select all / count header
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 12),
                          color: AppColors.surface,
                          child: Row(
                            children: [
                              GestureDetector(
                                onTap: () {
                                  final displayed = _getDisplayedTransactions();
                                  if (displayed == null) return;
                                  final allSelected =
                                      _selectedCount == displayed.length;
                                  setState(() {
                                    for (final t in displayed) {
                                      t.selected = !allSelected;
                                    }
                                  });
                                },
                                child: Icon(
                                  _selectedCount == _getDisplayedTransactions()?.length
                                      ? Icons.check_box_rounded
                                      : _selectedCount > 0
                                          ? Icons
                                              .indeterminate_check_box_rounded
                                          : Icons
                                              .check_box_outline_blank_rounded,
                                  color: AppColors.primary,
                                  size: 22,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${_getDisplayedTransactions()?.length ?? 0} transaction${(_getDisplayedTransactions()?.length ?? 0) == 1 ? '' : 's'} found',
                                    style: const TextStyle(
                                      color: AppColors.textSecondary,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  if (_dateFilterEnabled)
                                    Text(
                                      'Filtered: ${_dateRangeStart.year}-${_dateRangeStart.month}-${_dateRangeStart.day} to ${_dateRangeEnd.year}-${_dateRangeEnd.month}-${_dateRangeEnd.day}',
                                      style: const TextStyle(
                                        color: AppColors.income,
                                        fontSize: 11,
                                      ),
                                    ),
                                ],
                              ),
                              const Spacer(),
                              Text(
                                '$_selectedCount selected',
                                style: const TextStyle(
                                  color: AppColors.textMuted,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Transaction list
                        Expanded(
                          child: ListView.builder(
                            padding:
                                const EdgeInsets.fromLTRB(16, 8, 16, 100),
                            itemCount: _getDisplayedTransactions()?.length ?? 0,
                            itemBuilder: (context, index) {
                              final displayed = _getDisplayedTransactions();
                              if (displayed == null || index >= displayed.length)
                                return null;
                              final tx = displayed[index];
                              return _SmsTxCard(
                                tx: tx,
                                categories: budget.categories,
                                onToggle: () => setState(
                                    () => tx.selected = !tx.selected),
                                onCategoryChanged: (catId) =>
                                    setState(() => tx.categoryId = catId),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
      bottomSheet: (_getDisplayedTransactions() != null &&
              (_getDisplayedTransactions()?.isNotEmpty ?? false) &&
              _selectedCount > 0)
          ? Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
              decoration: const BoxDecoration(
                color: AppColors.surface,
                border: Border(
                  top: BorderSide(color: AppColors.border, width: 0.5),
                ),
              ),
              child: ElevatedButton(
                onPressed: _importSelected,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: Text(
                  'Import $_selectedCount Transaction${_selectedCount == 1 ? '' : 's'}',
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 15),
                ),
              ),
            )
          : null,
    );
  }
}

class _SmsTxCard extends StatelessWidget {
  final ParsedSmsTransaction tx;
  final List<Category> categories;
  final VoidCallback onToggle;
  final ValueChanged<String?> onCategoryChanged;

  const _SmsTxCard({
    required this.tx,
    required this.categories,
    required this.onToggle,
    required this.onCategoryChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: tx.selected
              ? AppColors.primary.withValues(alpha: 0.4)
              : AppColors.border.withValues(alpha: 0.3),
        ),
      ),
      child: InkWell(
        onTap: onToggle,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top row: checkbox, merchant, amount
              Row(
                children: [
                  Icon(
                    tx.selected
                        ? Icons.check_circle_rounded
                        : Icons.circle_outlined,
                    color:
                        tx.selected ? AppColors.primary : AppColors.textMuted,
                    size: 22,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      tx.merchant,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                  ),
                  Text(
                    '${tx.currency} ${tx.amount.toStringAsFixed(2)}',
                    style: const TextStyle(
                      color: AppColors.expense,
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // Date row
              Padding(
                padding: const EdgeInsets.only(left: 34),
                child: Text(
                  formatDateTime(tx.date),
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 12,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              // Category selector
              Padding(
                padding: const EdgeInsets.only(left: 34),
                child: SizedBox(
                  height: 32,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      _categoryChip(
                        label: 'None',
                        icon: Icons.block_rounded,
                        color: AppColors.textMuted,
                        isSelected: tx.categoryId == null,
                        onTap: () => onCategoryChanged(null),
                      ),
                      ...categories.map((c) => _categoryChip(
                            label: c.name,
                            icon: c.icon,
                            color: c.color,
                            isSelected: tx.categoryId == c.id,
                            onTap: () => onCategoryChanged(c.id),
                          )),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _categoryChip({
    required String label,
    required IconData icon,
    required Color color,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: isSelected
                ? color.withValues(alpha: 0.2)
                : AppColors.surfaceLight,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected
                  ? color.withValues(alpha: 0.5)
                  : Colors.transparent,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? color : AppColors.textSecondary,
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
