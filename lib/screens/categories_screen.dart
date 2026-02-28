import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import '../theme/app_theme.dart';
import '../models/budget_provider.dart';
import '../models/budget_model.dart';
import '../utils/formatters.dart';

class CategoriesScreen extends StatelessWidget {
  const CategoriesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final budget = Provider.of<BudgetProvider>(context);
    final canPop = Navigator.of(context).canPop();

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
                    // Back button (only when pushed as a route)
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
                      'Categories',
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const Spacer(),
                    // Add category button
                    GestureDetector(
                      onTap: () => _showCategoryDialog(context, budget),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: AppColors.primary.withValues(alpha: 0.3)),
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

            // Info
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                child: Text(
                  '${budget.categories.length} categories • Tap to edit, swipe left to delete',
                  style:
                      const TextStyle(color: AppColors.textMuted, fontSize: 13),
                ),
              ),
            ),

            // ─── Category list ────────────────────────────────
            budget.categories.isEmpty
                ? SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(40),
                      child: Center(
                        child: Column(
                          children: [
                            Icon(Icons.category_rounded,
                                color: AppColors.textMuted, size: 48),
                            const SizedBox(height: 12),
                            Text(
                              'No categories yet',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(
                                    color: AppColors.textMuted,
                                  ),
                            ),
                            const SizedBox(height: 8),
                            GestureDetector(
                              onTap: () => _showCategoryDialog(context, budget),
                              child: Text(
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
                : SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final cat = budget.categories[index];
                          final spent = budget.expensesForCategory(cat.id);
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: Slidable(
                              key: ValueKey(cat.id),
                              endActionPane: ActionPane(
                                motion: const DrawerMotion(),
                                extentRatio: 0.25,
                                children: [
                                  SlidableAction(
                                    onPressed: (_) =>
                                        _confirmDelete(context, budget, cat),
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
                                onTap: () => _showCategoryDialog(
                                    context, budget,
                                    existing: cat),
                                child: _CategoryListItem(
                                  category: cat,
                                  spent: spent,
                                  currency: budget.currency,
                                ),
                              ),
                            ),
                          );
                        },
                        childCount: budget.categories.length,
                      ),
                    ),
                  ),
          ],
        ),
      ),
    );
  }

  void _showCategoryDialog(BuildContext context, BudgetProvider budget,
      {Category? existing}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CategoryFormSheet(existing: existing),
    );
  }

  void _confirmDelete(
      BuildContext context, BudgetProvider budget, Category cat) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete Category'),
        content: Text(
          'Delete "${cat.name}"? All transactions in this category will also be removed.',
          style: const TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              budget.deleteCategory(cat.id);
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('"${cat.name}" deleted'),
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

class _CategoryListItem extends StatelessWidget {
  final Category category;
  final double spent;
  final String currency;

  const _CategoryListItem({
    required this.category,
    required this.spent,
    required this.currency,
  });

  @override
  Widget build(BuildContext context) {
    final hasLimit = category.budgetLimit > 0;
    final progress =
        hasLimit ? (spent / category.budgetLimit).clamp(0.0, 1.0) : 0.0;
    final isOver = hasLimit && spent > category.budgetLimit;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isOver
              ? AppColors.expense.withValues(alpha: 0.5)
              : AppColors.border.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: category.color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(category.icon, color: category.color, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      category.name,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                    if (hasLimit)
                      Text(
                        'Budget: ${formatCurrency(category.budgetLimit, currency)}',
                        style: const TextStyle(
                            color: AppColors.textMuted, fontSize: 12),
                      ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    formatCurrency(spent, currency),
                    style: TextStyle(
                      color: isOver ? AppColors.expense : AppColors.textPrimary,
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                  Text(
                    'spent this month',
                    style: const TextStyle(
                        color: AppColors.textMuted, fontSize: 11),
                  ),
                ],
              ),
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right_rounded,
                  color: AppColors.textMuted, size: 20),
            ],
          ),
          if (hasLimit) ...[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress,
                backgroundColor: AppColors.surfaceHighlight,
                valueColor: AlwaysStoppedAnimation(
                  isOver ? AppColors.expense : category.color,
                ),
                minHeight: 5,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${(progress * 100).toStringAsFixed(0)}% used',
                  style: TextStyle(
                    color: isOver ? AppColors.expense : AppColors.textMuted,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  hasLimit
                      ? '${formatCurrencyShort(category.budgetLimit - spent, currency)} ${isOver ? "over" : "left"}'
                      : '',
                  style: TextStyle(
                    color: isOver ? AppColors.expense : AppColors.textMuted,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _CategoryFormSheet extends StatefulWidget {
  final Category? existing;

  const _CategoryFormSheet({this.existing});

  @override
  State<_CategoryFormSheet> createState() => _CategoryFormSheetState();
}

class _CategoryFormSheetState extends State<_CategoryFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _limitController;
  late IconData _selectedIcon;
  late Color _selectedColor;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.existing?.name ?? '');
    _limitController = TextEditingController(
      text: (widget.existing?.budgetLimit ?? 0) > 0
          ? widget.existing!.budgetLimit.toStringAsFixed(0)
          : '',
    );
    _selectedIcon = widget.existing?.icon ?? Icons.category_rounded;
    _selectedColor = widget.existing?.color ?? AppColors.categoryColors[0];
  }

  @override
  void dispose() {
    _nameController.dispose();
    _limitController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.existing != null;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
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
            isEditing ? 'Edit Category' : 'New Category',
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
                    // Name
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: 'Category Name',
                        hintText: 'e.g. Groceries',
                        prefixIcon: Icon(Icons.label_rounded,
                            color: AppColors.textMuted),
                      ),
                      style: const TextStyle(color: AppColors.textPrimary),
                      validator: (v) =>
                          v == null || v.trim().isEmpty ? 'Enter a name' : null,
                    ),
                    const SizedBox(height: 16),

                    // Budget limit
                    TextFormField(
                      controller: _limitController,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'Monthly Budget Limit (optional)',
                        hintText: '0 = no limit',
                        prefixIcon: Icon(Icons.account_balance_wallet_rounded,
                            color: AppColors.textMuted),
                      ),
                      style: const TextStyle(color: AppColors.textPrimary),
                    ),
                    const SizedBox(height: 20),

                    // Icon picker
                    const Text(
                      'Icon',
                      style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 13,
                          fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      height: 160,
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceLight,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: GridView.builder(
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 6,
                          mainAxisSpacing: 6,
                          crossAxisSpacing: 6,
                        ),
                        itemCount: availableCategoryIcons.length,
                        itemBuilder: (context, index) {
                          final icon = availableCategoryIcons[index];
                          final isSelected =
                              _selectedIcon.codePoint == icon.codePoint;
                          return GestureDetector(
                            onTap: () => setState(() => _selectedIcon = icon),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 150),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? _selectedColor.withValues(alpha: 0.2)
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(10),
                                border: isSelected
                                    ? Border.all(
                                        color: _selectedColor, width: 2)
                                    : null,
                              ),
                              child: Icon(
                                icon,
                                color: isSelected
                                    ? _selectedColor
                                    : AppColors.textMuted,
                                size: 22,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Color picker
                    const Text(
                      'Color',
                      style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 13,
                          fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: AppColors.categoryColors.map((color) {
                        final isSelected =
                            _selectedColor.toARGB32() == color.toARGB32();
                        return GestureDetector(
                          onTap: () => setState(() => _selectedColor = color),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: color,
                              borderRadius: BorderRadius.circular(10),
                              border: isSelected
                                  ? Border.all(color: Colors.white, width: 3)
                                  : null,
                              boxShadow: isSelected
                                  ? [
                                      BoxShadow(
                                        color: color.withValues(alpha: 0.5),
                                        blurRadius: 10,
                                        offset: const Offset(0, 3),
                                      ),
                                    ]
                                  : null,
                            ),
                            child: isSelected
                                ? const Icon(Icons.check_rounded,
                                    color: Colors.white, size: 18)
                                : null,
                          ),
                        );
                      }).toList(),
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
                          isEditing ? 'Save Changes' : 'Create Category',
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
    );
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final budget = Provider.of<BudgetProvider>(context, listen: false);
    final isEditing = widget.existing != null;
    final limit = double.tryParse(_limitController.text) ?? 0;

    if (isEditing) {
      final updated = widget.existing!.copyWith(
        name: _nameController.text.trim(),
        icon: _selectedIcon,
        color: _selectedColor,
        budgetLimit: limit,
      );
      budget.updateCategory(widget.existing!.id, updated);
    } else {
      final category = Category(
        id: const Uuid().v4(),
        name: _nameController.text.trim(),
        icon: _selectedIcon,
        color: _selectedColor,
        budgetLimit: limit,
      );
      budget.addCategory(category);
    }

    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(isEditing ? 'Category updated' : 'Category created'),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }
}
