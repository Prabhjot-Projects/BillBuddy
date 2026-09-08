import 'app/di/service_locator.dart';
import 'app/theme/theme_controller.dart';
import 'app/theme/app_colors.dart';
import 'package:billbuddy/firebase_options.dart';
import 'processes/receipt/receipt_repository.dart';
import 'services/storage/local/database_service.dart';
import 'services/currency/currency_controller.dart';
import 'services/storage/local/app_settings_service.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'presentation/screens/dashboard/home_screen.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:flutter/foundation.dart';

/// How long an unconfirmed draft receipt is kept before being treated as
/// abandoned and deleted on startup. See ReceiptRepository.deleteStaleDrafts.
const _draftRetention = Duration(days: 14);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  await FirebaseAppCheck.instance.activate(
    providerAndroid: kReleaseMode
        ? const AndroidPlayIntegrityProvider()
        : const AndroidDebugProvider(),
    providerApple: kReleaseMode
        ? const AppleDeviceCheckProvider()
        : const AppleDebugProvider(),
  );

  // DatabaseService must finish opening the DB (and creating tables on
  // first launch) before setupServiceLocator() runs, since
  // SqliteReceiptRepository is constructed eagerly inside it and reads
  // the database instance immediately.
  final databaseService = DatabaseService();
  await databaseService.initialize();
  getIt.registerSingleton<DatabaseService>(databaseService);

  final themeController = ThemeController();
  getIt.registerSingleton<ThemeController>(themeController);
  await themeController.load();

  setupServiceLocator(); // Setup Services required before app starts.
  final savedCurrency = await getIt<AppSettingsService>().getCurrency();
  final currency = savedCurrency.valueOrNull;
  if (currency != null) {
    getIt<CurrencyController>().setCurrency(currency);
  }

  // Fire-and-forget cleanup: not awaited because there's no reason to
  // delay app startup for it, and a failure here shouldn't block the
  // user from using the app. Errors are swallowed via Result rather than
  // thrown, so this is safe to leave unawaited.
  getIt<ReceiptRepository>().deleteStaleDrafts(_draftRetention);

  runApp(const BillBuddy());
}

class BillBuddy extends StatelessWidget {
  const BillBuddy({super.key});

  @override
  Widget build(BuildContext context) {
    final themeController = getIt<ThemeController>();

    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeController,
      builder: (context, mode, _) {
        return ValueListenableBuilder<String>(
          valueListenable: getIt<CurrencyController>(),
          builder: (context, _, _) => MaterialApp(
            title: 'Bill Buddy',
            theme: ThemeData(
              brightness: Brightness.light,
              colorScheme: ColorScheme.fromSeed(
                seedColor: const Color(0xff4f46e5),
              ),
              extensions: const [AppColors.light],
              scaffoldBackgroundColor: AppColors.light.surfaceAlt,
              appBarTheme: AppBarTheme(
                backgroundColor: AppColors.light.surfaceAlt,
                foregroundColor: AppColors.light.textPrimary,
                elevation: 0,
                centerTitle: true,
              ),
              elevatedButtonTheme: ElevatedButtonThemeData(
                style: ButtonStyle(
                  minimumSize: WidgetStatePropertyAll(Size(220, 52)),
                  shape: WidgetStatePropertyAll(
                    RoundedRectangleBorder(
                      borderRadius: BorderRadius.all(Radius.circular(16)),
                    ),
                  ),
                ),
              ),
            ),
            darkTheme: ThemeData(
              brightness: Brightness.dark,
              colorScheme: ColorScheme.fromSeed(
                seedColor: const Color(0xff818cf8),
                brightness: Brightness.dark,
              ),
              extensions: const [AppColors.dark],
              scaffoldBackgroundColor: AppColors.dark.surfaceAlt,
              appBarTheme: AppBarTheme(
                backgroundColor: AppColors.dark.surfaceAlt,
                foregroundColor: AppColors.dark.textPrimary,
                elevation: 0,
                centerTitle: true,
              ),
            ),
            themeMode: mode,
            home: const HomeScreen(),
          ),
        );
      },
    );
  }
}
