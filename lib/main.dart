import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/services/app_logger.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Log Flutter errors
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    AppLogger.e('FlutterError', details.exceptionAsString(), details.exception, details.stack);
  };

  // Log platform errors (not caught by Flutter)
  PlatformDispatcher.instance.onError = (error, stack) {
    AppLogger.e('PlatformError', error.toString(), error, stack);
    return true;
  };

  AppLogger.i('App', 'StudyTracker starting up...');
  runApp(const ProviderScope(child: StudyTrackerApp()));
}
