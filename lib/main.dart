import 'dart:async';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'controllers/locale_controller.dart';
import 'controllers/review_prompt_controller.dart';
import 'controllers/theme_controller.dart';
import 'controllers/app_reset_controller.dart';
import 'i18n/app_localizations.dart';
import 'models/game_pick.dart';
import 'screens/aphidex_home_shell.dart';
import 'startup/startup_bootstrap.dart';
import 'startup/startup_profiler.dart';
import 'widgets/state_panels.dart';
import 'widgets/tutorial_overlay.dart';

void main() {
  runZonedGuarded(() {
    StartupProfiler.instance.startRun();
    WidgetsFlutterBinding.ensureInitialized();
    StartupProfiler.instance.mark(
      'WidgetsFlutterBinding.ensureInitialized ready',
    );

    FlutterError.onError = (details) {
      FlutterError.presentError(details);
      _reportBootstrapError(details.exception, details.stack);
    };

    PlatformDispatcher.instance.onError = (error, stack) {
      _reportBootstrapError(error, stack);
      return true;
    };

    runApp(const AphidexBootstrapApp());
  }, _reportBootstrapError);
}

void _reportBootstrapError(Object error, StackTrace? stack) {
  if (kDebugMode) {
    debugPrint('Aphidex startup error: $error');
    if (stack != null) {
      debugPrintStack(stackTrace: stack);
    }
  }
}

class AphidexBootstrapApp extends StatefulWidget {
  const AphidexBootstrapApp({super.key});

  @override
  State<AphidexBootstrapApp> createState() => _AphidexBootstrapAppState();
}

class _AphidexBootstrapAppState extends State<AphidexBootstrapApp> {
  late Future<StartupBootstrapData> _startupFuture;

  @override
  void initState() {
    super.initState();
    _startupFuture = _bootstrap();
  }

  Future<StartupBootstrapData> _bootstrap() async {
    try {
      return await StartupBootstrap.loadCriticalPath();
    } catch (error, stack) {
      _reportBootstrapError(error, stack);
      rethrow;
    }
  }

  void _retryStartup() {
    setState(() {
      _startupFuture = _bootstrap();
    });
  }

  @override
  Widget build(BuildContext context) {
    StartupProfiler.instance.markOnce('_BootstrapShell start');
    return FutureBuilder<StartupBootstrapData>(
      future: _startupFuture,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _BootstrapShell(
            child: _BootstrapErrorScreen(
              error: snapshot.error,
              onRetry: _retryStartup,
            ),
          );
        }
        if (snapshot.connectionState != ConnectionState.done) {
          return const _BootstrapShell(child: _BootstrapLoadingScreen());
        }
        StartupProfiler.instance.markOnce('first loader disappears');
        return ListenableBuilder(
          listenable: AppResetController.instance.revision,
          builder: (context, _) {
            return AphidexApp(
              key: ValueKey(AppResetController.instance.revision.value),
              startupData: snapshot.data,
            );
          },
        );
      },
    );
  }
}

class _BootstrapShell extends StatelessWidget {
  const _BootstrapShell({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF071019),
        colorScheme: ColorScheme.fromSeed(
          brightness: Brightness.dark,
          seedColor: const Color(0xFF4D8AA8),
        ),
      ),
      home: Scaffold(
        backgroundColor: const Color(0xFF071019),
        body: DecoratedBox(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF071019), Color(0xFF101C28)],
            ),
          ),
          child: SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 460),
                child: Padding(padding: const EdgeInsets.all(20), child: child),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BootstrapLoadingScreen extends StatelessWidget {
  const _BootstrapLoadingScreen();

  @override
  Widget build(BuildContext context) {
    return const AphidexLoadingPanel(
      gamePick: GamePick.all,
      title: 'Starting Aphidex',
      subtitle: 'Loading local data and services.',
    );
  }
}

class _BootstrapErrorScreen extends StatelessWidget {
  const _BootstrapErrorScreen({required this.error, required this.onRetry});

  final Object? error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Aphidex loaded',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          const Text(
            'The app could not finish startup. Please try again.',
            textAlign: TextAlign.center,
          ),
          if (error != null) ...[
            const SizedBox(height: 12),
            Text(
              '$error',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12, color: Colors.redAccent),
            ),
          ],
          const SizedBox(height: 20),
          FilledButton(onPressed: onRetry, child: const Text('Retry startup')),
        ],
      ),
    );
  }
}

class AphidexApp extends StatelessWidget {
  const AphidexApp({super.key, this.startupData});

  final StartupBootstrapData? startupData;

  @override
  Widget build(BuildContext context) {
    StartupProfiler.instance.markOnce('AphidexApp build');
    final theme = ThemeController.instance;
    final locale = LocaleController.instance;

    return ListenableBuilder(
      listenable: Listenable.merge([theme.theme, locale.preference]),
      builder: (context, _) {
        return MaterialApp(
          navigatorKey: ReviewPromptController.navigatorKey,
          locale: locale.locale,
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          builder: (context, child) =>
              TutorialHost(child: child ?? const SizedBox.shrink()),
          localeResolutionCallback: (deviceLocale, supportedLocales) {
            final resolved = LocaleController.resolveSupportedLocale(
              deviceLocale,
            );
            return supportedLocales.firstWhere(
              (item) => item.languageCode == resolved.languageCode,
              orElse: () => const Locale('en'),
            );
          },
          themeMode: theme.themeMode,
          theme: ThemeData(
            useMaterial3: true,
            brightness: Brightness.light,
            snackBarTheme: const SnackBarThemeData(
              behavior: SnackBarBehavior.floating,
            ),
          ),
          darkTheme: ThemeData(
            useMaterial3: true,
            brightness: Brightness.dark,
            snackBarTheme: const SnackBarThemeData(
              behavior: SnackBarBehavior.floating,
            ),
          ),
          home: AphidexHomeShell(startupData: startupData),
        );
      },
    );
  }
}
