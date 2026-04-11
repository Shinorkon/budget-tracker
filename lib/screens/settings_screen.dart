import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../theme/app_theme.dart';
import '../models/budget_provider.dart';
import '../models/receipt_provider.dart';
import '../services/api_service.dart';
import '../services/sync_service.dart';
import '../models/theme_provider.dart';
import '../services/sms_transaction_service.dart';
import '../services/live_sms_listener_service.dart';
import 'auth_screen.dart';
import 'categories_screen.dart';
import 'receipts_history_screen.dart';
import 'price_search_screen.dart';
import 'stores_screen.dart';
import 'items_screen.dart';
import 'sms_import_screen.dart';
import 'lock_screen.dart';

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

    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
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
                    color: colorScheme.surface,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                        color: Theme.of(context).dividerColor.withValues(alpha: 0.3)),
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
                      _divider(),
                      Consumer<ThemeProvider>(
                        builder: (context, themeProvider, _) {
                          return _SettingsTile(
                            icon: themeProvider.isDark
                                ? Icons.dark_mode_rounded
                                : Icons.light_mode_rounded,
                            iconColor: themeProvider.isDark
                                ? AppColors.accent
                                : AppColors.warning,
                            title: 'Theme',
                            subtitle: themeProvider.isDark ? 'Dark' : 'Light',
                            trailing: Switch.adaptive(
                              value: themeProvider.isDark,
                              activeTrackColor: AppColors.primary,
                              onChanged: (_) => themeProvider.toggle(),
                            ),
                            onTap: () => themeProvider.toggle(),
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

            // ─── Security section ──────────────────────────────
            SliverToBoxAdapter(
              child: _SectionHeader(title: 'Security'),
            ),

            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Container(
                  decoration: BoxDecoration(
                    color: colorScheme.surface,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                        color: Theme.of(context).dividerColor.withValues(alpha: 0.3)),
                  ),
                  child: FutureBuilder<bool>(
                    future: BiometricPrefs.isEnabled(),
                    builder: (context, snapshot) {
                      final enabled = snapshot.data ?? false;
                      return _SettingsTile(
                        icon: Icons.fingerprint_rounded,
                        iconColor: AppColors.primary,
                        title: 'Biometric Lock',
                        subtitle: enabled ? 'Enabled' : 'Disabled',
                        trailing: Switch.adaptive(
                          value: enabled,
                          activeTrackColor: AppColors.primary,
                          onChanged: (val) async {
                            await BiometricPrefs.setEnabled(val);
                            setState(() {});
                          },
                        ),
                        onTap: () async {
                          await BiometricPrefs.setEnabled(!enabled);
                          setState(() {});
                        },
                      );
                    },
                  ),
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
                    color: colorScheme.surface,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                        color: Theme.of(context).dividerColor.withValues(alpha: 0.3)),
                  ),
                  child: Column(
                    children: [
                      _SettingsTile(
                        icon: Icons.sms_rounded,
                        iconColor: AppColors.income,
                        title: 'Import from SMS',
                        subtitle: 'Auto-detect bank transactions from messages',
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const SmsImportScreen(),
                          ),
                        ),
                      ),
                      _divider(),
                      _SettingsTile(
                        icon: Icons.tune_rounded,
                        iconColor: AppColors.primaryLight,
                        title: 'SMS Listener Config',
                        subtitle: 'Senders, regex pattern, and live listening',
                        onTap: () => _showSmsListenerConfig(context, budget),
                      ),
                      _divider(),
                      _SettingsTile(
                        icon: Icons.refresh_rounded,
                        iconColor: AppColors.accent,
                        title: 'Refresh SMS',
                        subtitle: 'Re-scan inbox for missed transactions',
                        onTap: () => _refreshSms(context, budget),
                      ),
                      _divider(),
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
                    color: colorScheme.surface,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                        color: Theme.of(context).dividerColor.withValues(alpha: 0.3)),
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
                    color: colorScheme.surface,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                        color: Theme.of(context).dividerColor.withValues(alpha: 0.3)),
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
    return Builder(
      builder: (context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Divider(color: Theme.of(context).dividerColor.withValues(alpha: 0.3), height: 1),
      ),
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
          decoration: BoxDecoration(
            color: Theme.of(sheetContext).colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
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
                    color: Theme.of(sheetContext).textTheme.bodySmall?.color,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'Account Connected',
                style: Theme.of(sheetContext).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              _detailRow(sheetContext, 'Username', account['username']?.toString() ?? '-'),
              _detailRow(sheetContext, 'Email', account['email']?.toString() ?? '-'),
              _detailRow(sheetContext, 'Currency', account['currency']?.toString() ?? '-'),
              _detailRow(
                sheetContext,
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

  Widget _detailRow(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          SizedBox(
            width: 92,
            child: Text(
              label,
              style: TextStyle(
                color: Theme.of(context).textTheme.bodySmall?.color,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface,
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
    final syncService = SyncService(
      api: _api,
      budgetProvider: budget,
      receiptProvider: receiptProvider,
    );

    // Show progress updates via snackbar
    syncService.progress.addListener(() {
      if (!mounted) return;
      final p = syncService.progress.value;
      if (p.state == SyncState.uploading || p.state == SyncState.downloading || p.state == SyncState.merging) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const SizedBox(
                  width: 16, height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                ),
                const SizedBox(width: 12),
                Text(p.message ?? 'Syncing...'),
              ],
            ),
            duration: const Duration(seconds: 30),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    });

    final (success, error) = await syncService.sync();
    if (!mounted) return;

    setState(() => _isSyncing = false);
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    final errorMsg = error != null && error.length > 80
        ? '${error.substring(0, 80)}...'
        : error ?? 'Unknown error';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(success ? 'Sync complete' : 'Sync failed: $errorMsg'),
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
      builder: (sheetCtx) => Container(
        decoration: BoxDecoration(
          color: Theme.of(sheetCtx).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Theme.of(sheetCtx).textTheme.bodySmall?.color,
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
                    color: isSelected
                        ? AppColors.primary
                        : Theme.of(sheetCtx).colorScheme.onSurface,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
                subtitle: Text(
                  c.$2,
                  style: TextStyle(
                    color: Theme.of(sheetCtx).textTheme.bodySmall?.color,
                    fontSize: 12,
                  ),
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

  Future<void> _showSmsListenerConfig(
    BuildContext context,
    BudgetProvider budget,
  ) async {
    final currentSenders = await SmsTransactionService.getSenders();
    final currentPattern = await SmsTransactionService.getPattern();
    final currentAutoListen = await SmsTransactionService.getAutoListenEnabled();

    if (!context.mounted) return;

    final sendersCtrl = TextEditingController(text: currentSenders.join(', '));
    final patternCtrl = TextEditingController(text: currentPattern);
    bool autoListen = currentAutoListen;

    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
          ),
          child: Container(
            decoration: BoxDecoration(
              color: Theme.of(sheetContext).colorScheme.surface,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Theme.of(sheetContext).textTheme.bodySmall?.color,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'SMS Listener Configuration',
                    style: Theme.of(sheetContext).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Configure who to listen to and how transactions are parsed from SMS.',
                    style: TextStyle(color: Theme.of(sheetContext).textTheme.bodySmall?.color, fontSize: 12),
                  ),
                  const SizedBox(height: 18),
                  SwitchListTile(
                    value: autoListen,
                    activeThumbColor: AppColors.income,
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      'Enable Live SMS Listener',
                      style: TextStyle(color: Theme.of(sheetContext).colorScheme.onSurface),
                    ),
                    subtitle: Text(
                      'Automatically process incoming SMS in real-time.',
                      style: TextStyle(color: Theme.of(sheetContext).textTheme.bodySmall?.color, fontSize: 12),
                    ),
                    onChanged: (v) => setSheetState(() => autoListen = v),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: sendersCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Allowed Senders',
                      hintText: '455, BML, BANKNAME',
                      helperText: 'Comma-separated sender IDs or names.',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: patternCtrl,
                    maxLines: 4,
                    minLines: 3,
                    decoration: InputDecoration(
                      labelText: 'SMS Regex Pattern',
                      hintText: SmsTransactionService.defaultPattern,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(sheetContext),
                          child: const Text('Cancel'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () async {
                            final senders = sendersCtrl.text
                                .split(',')
                                .map((e) => e.trim())
                                .where((e) => e.isNotEmpty)
                                .toList();

                            await SmsTransactionService.setSenders(senders);
                            final patternValid = await SmsTransactionService.setPattern(patternCtrl.text);
                            if (!patternValid) {
                              if (!sheetContext.mounted) return;
                              ScaffoldMessenger.of(sheetContext).showSnackBar(
                                SnackBar(
                                  content: const Text('Invalid regex pattern. Settings not saved.'),
                                  backgroundColor: Colors.red,
                                  behavior: SnackBarBehavior.floating,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                              );
                              return;
                            }
                            await SmsTransactionService.setAutoListenEnabled(autoListen);

                            if (autoListen) {
                              await LiveSmsListenerService.instance.start(budget);
                            }

                            if (!sheetContext.mounted) return;
                            Navigator.pop(sheetContext);

                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: const Text('SMS listener settings saved'),
                                behavior: SnackBarBehavior.floating,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                backgroundColor: AppColors.income,
                              ),
                            );
                          },
                          child: const Text('Save'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _refreshSms(BuildContext context, BudgetProvider budget) async {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
            SizedBox(width: 12),
            Text('Scanning SMS inbox...'),
          ],
        ),
        duration: const Duration(seconds: 30),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );

    final count = await LiveSmsListenerService.instance.refresh(budget);

    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(count > 0 ? '$count new transactions imported' : 'No new transactions found'),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        backgroundColor: count > 0 ? AppColors.income : null,
      ),
    );
  }

  void _confirmClearData(BuildContext context, BudgetProvider budget) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded,
                color: AppColors.warning, size: 28),
            SizedBox(width: 10),
            Text('Clear All Data'),
          ],
        ),
        content: Text(
          'This will permanently delete ALL your transactions, categories, and settings. This action cannot be undone.',
          style: TextStyle(color: Theme.of(ctx).textTheme.bodyMedium?.color),
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
        style: TextStyle(
          color: Theme.of(context).textTheme.bodySmall?.color,
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
  final Widget? trailing;

  const _SettingsTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.isDestructive = false,
    this.trailing,
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
          color: isDestructive
              ? AppColors.expense
              : Theme.of(context).colorScheme.onSurface,
          fontWeight: FontWeight.w600,
          fontSize: 15,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          color: Theme.of(context).textTheme.bodySmall?.color,
          fontSize: 12,
        ),
      ),
      trailing: trailing ?? Icon(Icons.chevron_right_rounded,
          color: Theme.of(context).textTheme.bodySmall?.color, size: 20),
    );
  }
}
