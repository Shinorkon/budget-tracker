import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../theme/app_theme.dart';
import '../models/budget_provider.dart';
import '../models/receipt_provider.dart';
import '../services/api_service.dart';
import '../services/sync_service.dart';
import 'auth_screen.dart';
import 'categories_screen.dart';
import 'receipts_history_screen.dart';
import 'price_search_screen.dart';
import 'stores_screen.dart';
import 'items_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final ApiService _api = ApiService();
  bool _isSyncing = false;
  String _appVersion = 'Loading...';

  @override
  void initState() {
    super.initState();
    _loadVersion();
  }

  Future<void> _loadVersion() async {
    final info = await PackageInfo.fromPlatform();
    if (!mounted) return;
    setState(() {
      _appVersion = '${info.version} (${info.buildNumber})';
    });
  }

  @override
  Widget build(BuildContext context) {
    final budget = Provider.of<BudgetProvider>(context);
    final receiptProvider = Provider.of<ReceiptProvider>(context);

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

            // ─── Account & Sync section ──────────────────────
            SliverToBoxAdapter(
              child: _SectionHeader(title: 'Account & Sync'),
            ),

            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: FutureBuilder<bool>(
                  future: _api.isLoggedIn,
                  builder: (context, snapshot) {
                    final isLoggedIn = snapshot.data ?? false;
                    return Container(
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                            color: AppColors.border.withValues(alpha: 0.3)),
                      ),
                      child: Column(
                        children: [
                          _SettingsTile(
                            icon: isLoggedIn
                                ? Icons.verified_user_rounded
                                : Icons.person_outline_rounded,
                            iconColor: isLoggedIn
                                ? AppColors.income
                                : AppColors.textSecondary,
                            title: isLoggedIn ? 'Account Connected' : 'No Account',
                            subtitle:
                                isLoggedIn ? 'Signed in and ready to sync' : 'Sign in to enable cloud sync',
                            onTap: () => isLoggedIn
                              ? _showAccountDetails(context)
                              : _openAuth(context),
                          ),
                          _divider(),
                          _SettingsTile(
                            icon: _isSyncing
                                ? Icons.sync
                                : Icons.sync_rounded,
                            iconColor: AppColors.primary,
                            title: _isSyncing ? 'Syncing...' : 'Sync Now',
                            subtitle: 'Push local data to cloud and fetch updates',
                            onTap: _isSyncing
                                ? () {}
                                : () => _syncNow(context, budget, receiptProvider),
                          ),
                          _divider(),
                          _SettingsTile(
                            icon: isLoggedIn
                                ? Icons.logout_rounded
                                : Icons.login_rounded,
                            iconColor: isLoggedIn
                                ? AppColors.warning
                                : AppColors.accent,
                            title: isLoggedIn ? 'Sign Out' : 'Sign In / Sign Up',
                            subtitle: isLoggedIn
                                ? 'Disconnect this device from account'
                                : 'Create or connect your Budgy account',
                            onTap: () => isLoggedIn
                                ? _logout(context)
                                : _openAuth(context),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),

            // ─── Intelligence section ──────────────────────────
            SliverToBoxAdapter(
              child: _SectionHeader(title: 'Intelligence'),
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
                        icon: Icons.receipt_long_rounded,
                        iconColor: AppColors.primary,
                        title: 'Receipts History',
                        subtitle: 'View all scanned receipts',
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const ReceiptsHistoryScreen(),
                          ),
                        ),
                      ),
                      _divider(),
                      _SettingsTile(
                        icon: Icons.price_check_rounded,
                        iconColor: AppColors.accent,
                        title: 'Price Check',
                        subtitle: 'Compare item prices across stores',
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const PriceSearchScreen(),
                          ),
                        ),
                      ),
                      _divider(),
                      _SettingsTile(
                        icon: Icons.storefront_rounded,
                        iconColor: AppColors.warning,
                        title: 'Stores',
                        subtitle: 'Shops and supermarkets visited',
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const StoresScreen(),
                          ),
                        ),
                      ),
                      _divider(),
                      _SettingsTile(
                        icon: Icons.inventory_2_rounded,
                        iconColor: AppColors.accentLight,
                        title: 'Items',
                        subtitle: 'Everything you\'ve bought',
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const ItemsScreen(),
                          ),
                        ),
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
                        subtitle: _appVersion,
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

  Future<void> _openAuth(BuildContext context) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AuthScreen(
          onAuthenticated: () => Navigator.of(context).pop(),
        ),
      ),
    );

    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _showAccountDetails(BuildContext context) async {
    try {
      final account = await _api.me();
      if (!context.mounted) return;

      final lastSyncedAt = await _api.lastSyncedAt;

      showModalBottomSheet(
        context: context,
        backgroundColor: Colors.transparent,
        builder: (sheetContext) => Container(
          decoration: const BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
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
                'Account Connected',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              _detailRow('Username', account['username']?.toString() ?? '-'),
              _detailRow('Email', account['email']?.toString() ?? '-'),
              _detailRow('Currency', account['currency']?.toString() ?? '-'),
              _detailRow(
                'Last Sync',
                lastSyncedAt == null ? 'Never' : lastSyncedAt.toLocal().toString(),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        Navigator.of(sheetContext).pop();
                        _syncNow(
                          context,
                          Provider.of<BudgetProvider>(context, listen: false),
                          Provider.of<ReceiptProvider>(context, listen: false),
                        );
                      },
                      child: const Text('Sync Now'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.of(sheetContext).pop();
                        _logout(context);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.warning,
                      ),
                      child: const Text(
                        'Sign Out',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Session expired. Please sign in again.'),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      await _openAuth(context);
    }
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          SizedBox(
            width: 92,
            child: Text(
              label,
              style: const TextStyle(
                color: AppColors.textMuted,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _syncNow(
    BuildContext context,
    BudgetProvider budget,
    ReceiptProvider receiptProvider,
  ) async {
    final isLoggedIn = await _api.isLoggedIn;
    if (!isLoggedIn) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Sign in first to use cloud sync'),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      return;
    }

    setState(() => _isSyncing = true);
    final success = await SyncService(
      api: _api,
      budgetProvider: budget,
      receiptProvider: receiptProvider,
    ).sync();
    if (!mounted) return;

    setState(() => _isSyncing = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(success ? 'Sync complete' : 'Sync failed. Check connection or login status.'),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        backgroundColor: success ? AppColors.income : AppColors.expense,
      ),
    );
  }

  Future<void> _logout(BuildContext context) async {
    await _api.logout();
    if (!mounted) return;
    setState(() {});
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Signed out successfully'),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
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
