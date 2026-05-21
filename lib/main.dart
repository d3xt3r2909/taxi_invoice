import 'package:app_taxi_invoice/firebase_options.dart';
import 'package:app_taxi_invoice/src/auth/app_auth_controller.dart';
import 'package:app_taxi_invoice/src/settings/app_settings_controller.dart';
import 'package:app_taxi_invoice/src/store/invoice_store_controller.dart';
import 'package:app_taxi_invoice/src/store/invoice_store_encryption.dart';
import 'package:app_taxi_invoice/src/store/invoice_store_repository.dart';
import 'package:app_taxi_invoice/src/ui/auth_gate.dart';
import 'package:app_taxi_invoice/src/ui/invoice_date_formats.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';

const _seedLight = Color(0xFF1B5E20);
const _seedDarkNeutral = Color(0xFF8D8D8D);
const _darkAccentGreen = Color(0xFF66BB6A);
const _darkOnAccentGreen = Color(0xFF03140A);

ColorScheme _taxiInvoiceColorScheme(Brightness brightness) {
  if (brightness == Brightness.light) {
    return ColorScheme.fromSeed(seedColor: _seedLight, brightness: brightness);
  }
  final neutral = ColorScheme.fromSeed(
    seedColor: _seedDarkNeutral,
    brightness: Brightness.dark,
    contrastLevel: 0.08,
  );
  return neutral.copyWith(
    secondary: _darkAccentGreen,
    onSecondary: _darkOnAccentGreen,
    secondaryContainer: const Color(0xFF1A3320),
    onSecondaryContainer: const Color(0xFFC8E6C9),
  );
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting(invoiceUiDateLocale);
  final firebaseConfigured = DefaultFirebaseOptions.isConfigured;
  if (firebaseConfigured) {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  }
  final auth = firebaseConfigured
      ? AppAuthController.configured(firebaseAuth: FirebaseAuth.instance)
      : AppAuthController.notConfigured();
  final encryption = firebaseConfigured
      ? InvoiceStoreEncryptionController(
          storage: InvoiceStoreRepository.createFirebaseTextStorage(
            database: FirebaseDatabase.instance,
          ),
        )
      : null;
  final store = firebaseConfigured
      ? InvoiceStoreController(
          repository: InvoiceStoreRepository.firebase(
            database: FirebaseDatabase.instance,
            encryption: encryption,
          ),
        )
      : InvoiceStoreController();
  final settings = AppSettingsController();
  await Future.wait([auth.load(), settings.load()]);
  runApp(
    TaxiInvoiceApp(
      store: store,
      settings: settings,
      auth: auth,
      encryption: encryption,
    ),
  );
}

final class TaxiInvoiceApp extends StatelessWidget {
  const TaxiInvoiceApp({
    required this.store,
    required this.settings,
    required this.auth,
    this.encryption,
    super.key,
  });

  final InvoiceStoreController store;
  final AppSettingsController settings;
  final AppAuthController auth;
  final InvoiceStoreEncryptionController? encryption;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([store, settings]),
      builder: (context, _) {
        return MaterialApp(
          title: 'Taxi račun',
          locale: const Locale('bs', 'BA'),
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [Locale('bs', 'BA'), Locale('en')],
          theme: _taxiInvoiceTheme(Brightness.light),
          darkTheme: _taxiInvoiceTheme(Brightness.dark),
          themeMode: settings.themeMode,
          builder: (context, child) {
            if (child == null) {
              return const SizedBox.shrink();
            }
            final mq = MediaQuery.of(context);
            final appFactor = AppSettingsController.textScaleFactorForStep(
              settings.effectiveTextScaleStep,
            );
            final systemFactor = mq.textScaler.scale(10) / 10.0;
            final combined = (systemFactor * appFactor).clamp(0.85, 2.6);
            return MediaQuery(
              data: mq.copyWith(textScaler: TextScaler.linear(combined)),
              child: child,
            );
          },
          home: AuthGate(
            auth: auth,
            store: store,
            settings: settings,
            encryption: encryption,
          ),
        );
      },
    );
  }
}

ThemeData _taxiInvoiceTheme(Brightness brightness) {
  final scheme = _taxiInvoiceColorScheme(brightness);
  final base = ThemeData(
    colorScheme: scheme,
    useMaterial3: true,
    brightness: brightness,
  );
  final isDark = brightness == Brightness.dark;
  final outlinedStyle = OutlinedButton.styleFrom(
    minimumSize: const Size.fromHeight(54),
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
    textStyle: const TextStyle(
      fontSize: 17,
      fontWeight: FontWeight.w600,
      height: 1.2,
    ),
    side: BorderSide(
      color: isDark ? scheme.onSurface.withValues(alpha: 0.42) : scheme.outline,
      width: isDark ? 1.5 : 1,
    ),
    foregroundColor: isDark ? scheme.onSurface : null,
  );
  return base.copyWith(
    visualDensity: VisualDensity.standard,
    textTheme: _scaledTextTheme(base.textTheme),
    cardTheme: CardThemeData(
      color: isDark ? scheme.surfaceContainerHigh : scheme.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(54),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        textStyle: const TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w600,
          height: 1.2,
        ),
        backgroundColor: isDark ? scheme.secondary : null,
        foregroundColor: isDark ? scheme.onSecondary : null,
      ),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: isDark ? scheme.secondary : null,
      foregroundColor: isDark ? scheme.onSecondary : null,
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(style: outlinedStyle),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(
        minimumSize: const Size(48, 48),
        padding: const EdgeInsets.all(10),
      ),
    ),
  );
}

/// Slightly larger base type for readability. Avoids [TextTheme.apply] because M3
/// styles may use null [TextStyle.fontSize], which triggers a framework assert
/// when combined with fontSizeFactor / fontSizeDelta.
TextTheme _scaledTextTheme(TextTheme t) {
  TextStyle? bump(TextStyle? style) {
    if (style == null) {
      return null;
    }
    final size = style.fontSize;
    if (size == null) {
      return style;
    }
    return style.copyWith(fontSize: size * 1.06 + 1.5);
  }

  return t.copyWith(
    displayLarge: bump(t.displayLarge),
    displayMedium: bump(t.displayMedium),
    displaySmall: bump(t.displaySmall),
    headlineLarge: bump(t.headlineLarge),
    headlineMedium: bump(t.headlineMedium),
    headlineSmall: bump(t.headlineSmall),
    titleLarge: bump(t.titleLarge),
    titleMedium: bump(t.titleMedium),
    titleSmall: bump(t.titleSmall),
    bodyLarge: bump(t.bodyLarge)?.copyWith(height: 1.45),
    bodyMedium: bump(t.bodyMedium)?.copyWith(height: 1.45),
    bodySmall: bump(t.bodySmall),
    labelLarge: bump(t.labelLarge),
    labelMedium: bump(t.labelMedium),
    labelSmall: bump(t.labelSmall),
  );
}
