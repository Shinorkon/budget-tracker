import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';
import 'theme/app_theme.dart';
import 'models/budget_provider.dart';
import 'models/receipt_provider.dart';
import 'models/theme_provider.dart';
import 'screens/main_layout.dart';
import 'screens/auth_screen.dart';
import 'screens/lock_screen.dart';
import 'services/api_service.dart';
import 'services/hive_encryption_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();

  // Obtain encryption cipher for Hive boxes.
  final cipher = await HiveEncryptionService.getCipher();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => BudgetProvider(cipher: cipher)),
        ChangeNotifierProvider(create: (_) => ReceiptProvider(cipher: cipher)),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
      ],
      child: const BudgetApp(),
    ),
  );
}

class BudgetApp extends StatelessWidget {
  const BudgetApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, _) => MaterialApp(
        title: 'Budget Tracker',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: themeProvider.mode,
        home: const _AppEntry(),
      ),
    );
  }
}

class _AppEntry extends StatefulWidget {
  const _AppEntry();

  @override
  State<_AppEntry> createState() => _AppEntryState();
}

class _AppEntryState extends State<_AppEntry> with WidgetsBindingObserver {
  final _api = ApiService();
  bool _isLoading = true;
  bool _isAuthenticatedOrSkipped = false;
  bool _isLocked = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _bootstrap();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _isAuthenticatedOrSkipped) {
      _checkBiometricLock();
    }
  }

  Future<void> _checkBiometricLock() async {
    final enabled = await BiometricPrefs.isEnabled();
    if (enabled && mounted) {
      setState(() => _isLocked = true);
    }
  }

  Future<void> _bootstrap() async {
    final loggedIn = await _api.isLoggedIn;
    final biometricEnabled = await BiometricPrefs.isEnabled();
    if (!mounted) return;
    setState(() {
      _isLoading = false;
      _isAuthenticatedOrSkipped = loggedIn;
      _isLocked = loggedIn && biometricEnabled;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: Theme.of(context).colorScheme.primary),
        ),
      );
    }

    if (_isLocked) {
      return LockScreen(
        onUnlocked: () {
          if (!mounted) return;
          setState(() => _isLocked = false);
        },
      );
    }

    if (_isAuthenticatedOrSkipped) {
      return const MainLayout();
    }

    return AuthScreen(
      onAuthenticated: () {
        if (!mounted) return;
        setState(() => _isAuthenticatedOrSkipped = true);
      },
    );
  }
}
