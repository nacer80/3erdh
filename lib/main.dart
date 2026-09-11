import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'app_state.dart';
import 'ui/orchestrator.dart';

void main() async {
  runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();

      if (kReleaseMode) {
        debugPrint = (String? message, {int? wrapWidth}) {
          if (message != null) print(message);
        };
      }

      await AppState.instance.load();
      runApp(const ErdhApp());
    },
    (error, stack) {
      AppLogger.log('FATAL', 'Uncaught error: $error\n$stack');
    },
    zoneSpecification: ZoneSpecification(
      print: (Zone self, ZoneDelegate parent, Zone zone, String line) {
        AppLogger.addLog(line);
        if (!kReleaseMode || kIsWeb) {
          parent.print(zone, line);
        }
      },
    ),
  );
}

/// Root application widget for 3erdh.
class ErdhApp extends StatelessWidget {
  const ErdhApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AppState.instance,
      builder: (context, child) {
        final ThemeColors c = AppState.instance.colors;

        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: AppConstants.appName,
          theme: AppTheme.buildTheme(c),
          builder: (context, child) {
            return Scaffold(
              backgroundColor: c.bg,
              body: child,
            );
          },
          home: const Orchestrator(),
        );
      },
    );
  }
}
