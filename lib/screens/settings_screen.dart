import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../models/budget_provider.dart';
import 'categories_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final budget = Provider.of<BudgetProvider>(context);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                child: Text(
                  'Settings',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
              ),
            ),

            // ─── App section ──────────────────────────────────
            SliverToBoxAdapter(
              child: _SectionHeader(title: 'App'),
            ),

            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                        color: AppColors.border.withValues(alpha: 0.3)),
                  ),
                  child: Column(
                    children: [
                      _SettingsTile(
                        icon: Icons.attach_money_rounded,
                        iconColor: AppColors.income,
                        title: 'Currency',
                        subtitle: budget.currency,
                        onTap: () => _showCurrencyPicker(context, budget),
                      ),
                      _divider(),
                      _SettingsTile(
                        icon: Icons.category_rounded,
                        iconColor: AppColors.primary,
                        title: 'Manage Categories',
                        subtitle: '${budget.categories.length} categories',
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const CategoriesScreen(),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // ─── Data section ─────────────────────────────────
            SliverToBoxAdapter(
              child: _SectionHeader(title: 'Data'),
            ),

            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                        color: AppColors.border.withValues(alpha: 0.3)),
                  ),
                  child: Column(
                    children: [
                      _SettingsTile(
                        icon: Icons.delete_sweep_rounded,
                        iconColor: AppColors.expense,
                        title: 'Clear All Data',
                        subtitle: 'Reset everything to defaults',
                        onTap: () => _confirmClearData(context, budget),
                        isDestructive: true,
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // ─── About section ────────────────────────────────
            SliverToBoxAdapter(
              child: _SectionHeader(title: 'About'),
            ),

            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                        color: AppColors.border.withValues(alpha: 0.3)),
                  ),
                  child: Column(
                    children: [
                      _SettingsTile(
                        icon: Icons.info_outline_rounded,
                        iconColor: AppColors.accent,
                        title: 'Version',
                        subtitle: '2.0.0',
                        onTap: () {},
                      ),
                      _divider(),
                      _SettingsTile(
                        icon: Icons.code_rounded,
                        iconColor: AppColors.primaryLight,
                        title: 'Built with Flutter',
                        subtitle: 'Dart + Hive + fl_chart',
                        onTap: () {},
                      ),
                    ],
                  ),
                ),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 100)),
          ],
        ),
      ),
    );
  }

  Widget _divider() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Divider(color: AppColors.border.withValues(alpha: 0.3), height: 1),
    );
  }

  void _showCurrencyPicker(BuildContext context, BudgetProvider budget) {
    final currencies = [
      ('MVR', 'Maldivian Rufiyaa'),
      ('USD', 'US Dollar'),
      ('EUR', 'Euro'),
      ('GBP', 'British Pound'),
      ('AED', 'UAE Dirham'),
      ('INR', 'Indian Rupee'),
      ('LKR', 'Sri Lankan Rupee'),
      ('JPY', 'Japanese Yen'),
      ('AUD', 'Australian Dollar'),
      ('CAD', 'Canadian Dollar'),
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
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
            Text('Select Currency',
                style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 16),
            ...currencies.map((c) {
              final isSelected = budget.currency == c.$1;
              return ListTile(
                title: Text(
                  c.$1,
                  style: TextStyle(
                    color:
                        isSelected ? AppColors.primary : AppColors.textPrimary,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
                subtitle: Text(
                  c.$2,
                  style:
                      const TextStyle(color: AppColors.textMuted, fontSize: 12),
                ),
                trailing: isSelected
                    ? const Icon(Icons.check_circle_rounded,
                        color: AppColors.primary)
                    : null,
                onTap: () {
                  budget.setCurrency(c.$1);
                  Navigator.pop(context);
                },
              );
            }),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  void _confirmClearData(BuildContext context, BudgetProvider budget) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded,
                color: AppColors.warning, size: 28),
            SizedBox(width: 10),
            Text('Clear All Data'),
          ],
        ),
        content: const Text(
          'This will permanently delete ALL your transactions, categories, and settings. This action cannot be undone.',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              budget.clearAllData();
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text('All data cleared'),
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.expense),
            child:
                const Text('Clear All', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 10),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          color: AppColors.textMuted,
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.5,
        ),
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool isDestructive;

  const _SettingsTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.isDestructive = false,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: iconColor.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: iconColor, size: 22),
      ),
      title: Text(
        title,
        style: TextStyle(
          color: isDestructive ? AppColors.expense : AppColors.textPrimary,
          fontWeight: FontWeight.w600,
          fontSize: 15,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
      ),
      trailing: const Icon(Icons.chevron_right_rounded,
          color: AppColors.textMuted, size: 20),
    );
  }
}
