import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/budget_provider.dart';
import '../models/receipt_provider.dart';
import '../theme/app_theme.dart';
import '../services/api_service.dart';
import '../services/sync_service.dart';

class AuthScreen extends StatefulWidget {
  final VoidCallback onAuthenticated;

  const AuthScreen({super.key, required this.onAuthenticated});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _api = ApiService();
  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() => setState(() => _error = null));
  }

  @override
  void dispose() {
    _tabController.dispose();
    _emailController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isLogin = _tabController.index == 0;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Logo / Title
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: AppColors.primaryGradient,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: const Icon(Icons.account_balance_wallet_rounded,
                      color: Colors.white, size: 48),
                ),
                const SizedBox(height: 24),
                Text('Budgy',
                    style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        )),
                const SizedBox(height: 4),
                const Text('Track your budget, sync everywhere',
                    style: TextStyle(
                        color: AppColors.textSecondary, fontSize: 14)),
                const SizedBox(height: 32),

                // Tabs
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.surfaceLight,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: TabBar(
                    controller: _tabController,
                    indicator: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      color: AppColors.primary,
                    ),
                    indicatorSize: TabBarIndicatorSize.tab,
                    dividerColor: Colors.transparent,
                    labelColor: Colors.white,
                    unselectedLabelColor: AppColors.textSecondary,
                    labelStyle: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 14),
                    tabs: const [
                      Tab(text: 'Sign In'),
                      Tab(text: 'Sign Up'),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Form
                Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Email
                      TextFormField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(
                          hintText: 'Email',
                          prefixIcon: Icon(Icons.email_rounded,
                              color: AppColors.textMuted),
                        ),
                        style: const TextStyle(color: AppColors.textPrimary),
                        validator: (v) {
                          if (v == null || v.isEmpty) return 'Required';
                          if (!v.contains('@')) return 'Invalid email';
                          return null;
                        },
                      ),
                      const SizedBox(height: 14),

                      // Username (register only)
                      if (!isLogin) ...[
                        TextFormField(
                          controller: _usernameController,
                          decoration: const InputDecoration(
                            hintText: 'Username',
                            prefixIcon: Icon(Icons.person_rounded,
                                color: AppColors.textMuted),
                          ),
                          style:
                              const TextStyle(color: AppColors.textPrimary),
                          validator: (v) {
                            if (!isLogin && (v == null || v.isEmpty)) {
                              return 'Required';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 14),
                      ],

                      // Password
                      TextFormField(
                        controller: _passwordController,
                        obscureText: true,
                        decoration: const InputDecoration(
                          hintText: 'Password',
                          prefixIcon: Icon(Icons.lock_rounded,
                              color: AppColors.textMuted),
                        ),
                        style: const TextStyle(color: AppColors.textPrimary),
                        validator: (v) {
                          if (v == null || v.isEmpty) return 'Required';
                          if (v.length < 6) return 'Min 6 characters';
                          return null;
                        },
                      ),
                      const SizedBox(height: 24),

                      // Error
                      if (_error != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.expense.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                  color:
                                      AppColors.expense.withValues(alpha: 0.3)),
                            ),
                            child: Text(
                              _error!,
                              style: const TextStyle(
                                  color: AppColors.expense, fontSize: 13),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),

                      // Submit
                      SizedBox(
                        height: 52,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _submit,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14)),
                          ),
                          child: _isLoading
                              ? const SizedBox(
                                  height: 22,
                                  width: 22,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2, color: Colors.white),
                                )
                              : Text(
                                  isLogin ? 'Sign In' : 'Create Account',
                                  style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white),
                                ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Skip (use offline)
                      TextButton(
                        onPressed: widget.onAuthenticated,
                        child: const Text(
                          'Continue without account',
                          style: TextStyle(
                              color: AppColors.textMuted, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final isLogin = _tabController.index == 0;
      if (isLogin) {
        await _api.login(
          _emailController.text.trim(),
          _passwordController.text,
        );
      } else {
        await _api.register(
          _emailController.text.trim(),
          _usernameController.text.trim(),
          _passwordController.text,
        );
      }

      // Push existing local Hive data to backend immediately after auth.
      await SyncService(
        api: _api,
        budgetProvider: context.read<BudgetProvider>(),
        receiptProvider: context.read<ReceiptProvider>(),
      ).sync();

      widget.onAuthenticated();
    } catch (e) {
      final msg = e.toString().replaceFirst('Exception: ', '');
      setState(() => _error = msg.contains('SocketException') || msg.contains('Connection')
          ? 'Could not connect to server. Check your internet connection.'
          : msg.contains('401') || msg.contains('Invalid credentials')
          ? 'Incorrect email or password.'
          : msg.contains('409')
          ? 'Account already exists with that email or username.'
          : 'Something went wrong. Please try again.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
}
