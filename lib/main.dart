import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:mibondiuy/screens/map_screen.dart';
import 'package:mibondiuy/services/theme_service.dart' as theme_service;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load environment variables
  try {
    await dotenv.load(fileName: "assets/.env");
  } catch (e) {
    // Use debugPrint instead of print for production-safe logging
    debugPrint('Warning: Could not load .env file: $e');
    // Continue anyway, the app should handle missing env vars gracefully
  }

  final themeService = theme_service.ThemeService();
  await themeService.initialize();
  runApp(MiBondiUY(themeService: themeService));
}

class MiBondiUY extends StatelessWidget {
  final theme_service.ThemeService themeService;

  const MiBondiUY({super.key, required this.themeService});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: themeService,
      builder: (context, child) {
        return MaterialApp(
          title: 'MiBondiUY',
          theme: themeService.lightTheme,
          darkTheme: themeService.darkTheme,
          themeMode: themeService.isDarkMode ? ThemeMode.dark : ThemeMode.light,
          home: MapScreen(themeService: themeService),
          debugShowCheckedModeBanner: false,
        );
      },
    );
  }
}
