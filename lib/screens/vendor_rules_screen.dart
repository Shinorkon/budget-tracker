import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import '../theme/app_theme.dart';
import '../models/budget_provider.dart';
import '../models/budget_model.dart';

/// Settings screen for managing user-defined VendorRules.
///
/// Rules map a merchant / store pattern (substring or regex) to a Category
/// and are evaluated in ascending [VendorRule.priority] order before the
/// built-in keyword map and Gemini fallback. Incoming SMS transactions and
/// scanned receipts both consult these rules, so they are the primary knob
/// users have to fix mis-categorized transactions.
class VendorRulesScreen extends StatelessWidget {
  const VendorRulesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final budget = Provider.of<BudgetProvider>(context);
    final canPop = Navigator.of(context).canPop();
    final rules = budget.vendorRules;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            // ─── Header ───────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                child: Row(
                  children: [
                    if (canPop) ...[
                      GestureDetector(
                        onTap: () => Navigator.of(context).pop(),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceLight,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: const Icon(Icons.arrow_back_rounded,
                              color: AppColors.textPrimary, size: 20),
                        ),
                      ),
                      const SizedBox(width: 12),
                    ],
                    Text(
                      'Vendor Rules',
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const Spacer(),
                    GestureDetector(
                      onTap: () => _showRuleSheet(context),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color:
                                  AppColors.primary.withValues(alpha: 0.3)),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.add_rounded,
                                color: AppColors.primary, size: 18),
                            SizedBox(width: 4),
                            Text(
                              'Add',
                              style: TextStyle(
                                color: AppColors.primary,
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ─── Info / empty-state hint ──────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                child: Text(
                  rules.isEmpty
                      ? 'Rules override the default categorization — great for fixing "gym → Rent" or "shop → Food" bugs.'
                      : '${rules.length} rule${rules.length == 1 ? "" : "s"} • Evaluated in priority order • Tap to edit, swipe to delete',
                  style: const TextStyle(
                      color: AppColors.textMuted, fontSize: 13),
                ),
              ),
            ),

            // ─── Rules list ───────────────────────────────────
            if (rules.isEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(40),
                  child: Center(
                    child: Column(
                      children: [
                        const Icon(Icons.rule_rounded,
                            color: AppColors.textMuted, size: 48),
                        const SizedBox(height: 12),
                        Text(
                          'No vendor rules yet',
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(color: AppColors.textMuted),
                        ),
                        const SizedBox(height: 8),
                        GestureDetector(
                          onTap: () => _showRuleSheet(context),
                          child: const Text(
                            'Tap "Add" to create one',
                            style: TextStyle(
                              color: AppColors.primary,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final rule = rules[index];
                      final cat = budget.getCategoryById(rule.categoryId);
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Slidable(
                          key: ValueKey(rule.id),
                          endActionPane: ActionPane(
                            motion: const DrawerMotion(),
                            extentRatio: 0.25,
                            children: [
                              SlidableAction(
                                onPressed: (_) =>
                                    _confirmDelete(context, budget, rule),
                                backgroundColor: AppColors.expense,
                                foregroundColor: Colors.white,
                                icon: Icons.delete_rounded,
                                label: 'Delete',
                                borderRadius: const BorderRadius.horizontal(
                                  right: Radius.circular(18),
                                ),
                              ),
                            ],
                          ),
                          child: GestureDetector(
                            onTap: () =>
                                _showRuleSheet(context, existing: rule),
                            child: _VendorRuleListItem(
                              rule: rule,
                              category: cat,
                            ),
                          ),
                        ),
                      );
                    },
                    childCount: rules.length,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _showRuleSheet(BuildContext context, {VendorRule? existing}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _VendorRuleFormSheet(existing: existing),
    );
  }

  void _confirmDelete(
      BuildContext context, BudgetProvider budget, VendorRule rule) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete Rule'),
        content: Text(
          'Delete rule "${rule.pattern}"? Future transactions will fall back to the default categorization.',
          style: const TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              budget.deleteVendorRule(rule.id);
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Rule "${rule.pattern}" deleted'),
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.expense),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

class _VendorRuleListItem extends StatelessWidget {
  final VendorRule rule;
  final Category? category;

  const _VendorRuleListItem({required this.rule, required this.category});

  @override
  Widget build(BuildContext context) {
    final color = category?.color ?? AppColors.textMuted;
    final icon = category?.icon ?? Icons.help_outline_rounded;
    final catName = category?.name ?? 'Unknown category';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        rule.pattern,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                          fontFamily: 'monospace',
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    _Pill(
                      label: rule.useRegex ? 'regex' : 'contains',
                      color: rule.useRegex
                          ? AppColors.accent
                          : AppColors.primaryLight,
                    ),
                    if (rule.isIncome) ...[
                      const SizedBox(width: 6),
                      const _Pill(label: 'income', color: AppColors.income),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '→ $catName  •  priority ${rule.priority}',
                  style: const TextStyle(
                      color: AppColors.textMuted, fontSize: 12),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded,
              color: AppColors.textMuted, size: 20),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final String label;
  final Color color;

  const _Pill({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

class _VendorRuleFormSheet extends StatefulWidget {
  final VendorRule? existing;

  const _VendorRuleFormSheet({this.existing});

  @override
  State<_VendorRuleFormSheet> createState() => _VendorRuleFormSheetState();
}

class _VendorRuleFormSheetState extends State<_VendorRuleFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _patternController;
  late TextEditingController _priorityController;
  late TextEditingController _testController;
  String? _selectedCategoryId;
  bool _useRegex = false;
  bool _isIncome = false;

  @override
  void initState() {
    super.initState();
    _patternController =
        TextEditingController(text: widget.existing?.pattern ?? '');
    _priorityController = TextEditingController(
        text: (widget.existing?.priority ?? 100).toString());
    _testController = TextEditingController();
    _useRegex = widget.existing?.useRegex ?? false;
    _isIncome = widget.existing?.isIncome ?? false;
    _selectedCategoryId = widget.existing?.categoryId;
  }

  @override
  void dispose() {
    _patternController.dispose();
    _priorityController.dispose();
    _testController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final budget = Provider.of<BudgetProvider>(context, listen: false);
    final categories = budget.categories;
    final isEditing = widget.existing != null;

    // If the existing category id has since been deleted, clear it so the
    // dropdown doesn't crash.
    if (_selectedCategoryId != null &&
        !categories.any((c) => c.id == _selectedCategoryId)) {
      _selectedCategoryId = null;
    }

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.9,
        ),
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.textMuted,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              isEditing ? 'Edit Vendor Rule' : 'New Vendor Rule',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 20),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Pattern
                      TextFormField(
                        controller: _patternController,
                        decoration: InputDecoration(
                          labelText: 'Pattern',
                          hintText: _useRegex
                              ? r'e.g. ^(NORTH|SOUTH) STAR$'
                              : 'e.g. FITNESS',
                          prefixIcon: const Icon(Icons.search_rounded,
                              color: AppColors.textMuted),
                          helperText: _useRegex
                              ? 'Case-insensitive regex. Must match the merchant exactly where it applies.'
                              : 'Case-insensitive substring. "FITNESS" matches "ABC FITNESS CLUB".',
                          helperMaxLines: 2,
                        ),
                        style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontFamily: 'monospace'),
                        validator: (v) => v == null || v.trim().isEmpty
                            ? 'Enter a pattern'
                            : _useRegex
                                ? _validateRegex(v)
                                : null,
                      ),
                      const SizedBox(height: 12),

                      // Regex toggle
                      SwitchListTile(
                        value: _useRegex,
                        activeThumbColor: AppColors.accent,
                        contentPadding: EdgeInsets.zero,
                        title: const Text(
                          'Use regex',
                          style: TextStyle(color: AppColors.textPrimary),
                        ),
                        subtitle: const Text(
                          'Off = plain "contains" match (recommended). On = full RegExp syntax.',
                          style: TextStyle(
                              color: AppColors.textMuted, fontSize: 12),
                        ),
                        onChanged: (v) => setState(() => _useRegex = v),
                      ),
                      const SizedBox(height: 8),

                      // Category picker
                      DropdownButtonFormField<String>(
                        initialValue: _selectedCategoryId,
                        decoration: const InputDecoration(
                          labelText: 'Category',
                          prefixIcon: Icon(Icons.category_rounded,
                              color: AppColors.textMuted),
                        ),
                        style: const TextStyle(color: AppColors.textPrimary),
                        dropdownColor: AppColors.surface,
                        items: categories
                            .map(
                              (c) => DropdownMenuItem(
                                value: c.id,
                                child: Row(
                                  children: [
                                    Icon(c.icon, color: c.color, size: 18),
                                    const SizedBox(width: 8),
                                    Text(c.name,
                                        style: const TextStyle(
                                            color: AppColors.textPrimary)),
                                  ],
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: (v) =>
                            setState(() => _selectedCategoryId = v),
                        validator: (v) =>
                            v == null ? 'Pick a category' : null,
                      ),
                      const SizedBox(height: 16),

                      // Priority
                      TextFormField(
                        controller: _priorityController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Priority',
                          hintText: '100',
                          prefixIcon: Icon(Icons.sort_rounded,
                              color: AppColors.textMuted),
                          helperText:
                              'Lower runs first. Use 10 for overrides, 100 for normal.',
                        ),
                        style: const TextStyle(color: AppColors.textPrimary),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return null;
                          final n = int.tryParse(v.trim());
                          if (n == null || n < 0) {
                            return 'Enter a non-negative integer';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 8),

                      // Income toggle
                      SwitchListTile(
                        value: _isIncome,
                        activeThumbColor: AppColors.income,
                        contentPadding: EdgeInsets.zero,
                        title: const Text(
                          'Treat matches as income',
                          style: TextStyle(color: AppColors.textPrimary),
                        ),
                        subtitle: const Text(
                          'For salary, refunds, or reimbursements from a known sender.',
                          style: TextStyle(
                              color: AppColors.textMuted, fontSize: 12),
                        ),
                        onChanged: (v) => setState(() => _isIncome = v),
                      ),
                      const SizedBox(height: 16),

                      // Live tester
                      TextField(
                        controller: _testController,
                        decoration: const InputDecoration(
                          labelText: 'Test against a merchant name',
                          hintText: 'e.g. ABC FITNESS CLUB',
                          prefixIcon: Icon(Icons.science_rounded,
                              color: AppColors.textMuted),
                        ),
                        style: const TextStyle(color: AppColors.textPrimary),
                        onChanged: (_) => setState(() {}),
                      ),
                      const SizedBox(height: 8),
                      _TestResult(
                        pattern: _patternController.text,
                        useRegex: _useRegex,
                        input: _testController.text,
                      ),
                      const SizedBox(height: 24),

                      // Submit
                      SizedBox(
                        height: 52,
                        child: ElevatedButton(
                          onPressed: _submit,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14)),
                          ),
                          child: Text(
                            isEditing ? 'Save Changes' : 'Create Rule',
                            style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.white),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String? _validateRegex(String v) {
    try {
      RegExp(v.trim());
      return null;
    } catch (_) {
      return 'Invalid regex';
    }
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final budget = Provider.of<BudgetProvider>(context, listen: false);
    final isEditing = widget.existing != null;
    final priority =
        int.tryParse(_priorityController.text.trim()) ?? 100;

    if (isEditing) {
      final updated = widget.existing!.copyWith(
        pattern: _patternController.text.trim(),
        useRegex: _useRegex,
        categoryId: _selectedCategoryId!,
        isIncome: _isIncome,
        priority: priority,
      );
      budget.updateVendorRule(widget.existing!.id, updated);
    } else {
      final rule = VendorRule(
        id: const Uuid().v4(),
        pattern: _patternController.text.trim(),
        useRegex: _useRegex,
        categoryId: _selectedCategoryId!,
        isIncome: _isIncome,
        priority: priority,
      );
      budget.addVendorRule(rule);
    }

    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(isEditing ? 'Rule updated' : 'Rule created'),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }
}

/// Live-matching preview for the rule form — reuses [VendorRule.matches] so
/// the UI can never disagree with real matching behavior.
class _TestResult extends StatelessWidget {
  final String pattern;
  final bool useRegex;
  final String input;

  const _TestResult({
    required this.pattern,
    required this.useRegex,
    required this.input,
  });

  @override
  Widget build(BuildContext context) {
    if (pattern.trim().isEmpty || input.trim().isEmpty) {
      return const SizedBox.shrink();
    }
    final probe = VendorRule(
      id: 'probe',
      pattern: pattern,
      useRegex: useRegex,
      categoryId: '',
    );
    final hit = probe.matches(input);
    final color = hit ? AppColors.income : AppColors.expense;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Icon(hit ? Icons.check_circle_rounded : Icons.cancel_rounded,
              color: color, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              hit ? 'Matches — rule would apply' : 'No match',
              style: TextStyle(color: color, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
