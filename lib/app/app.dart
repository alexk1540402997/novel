import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'routes.dart';
import 'localizations/app_localizations.dart';
import '../presentation/theme/theme.dart';
import '../presentation/pages/novel_architecture_page.dart';

class ThemeModeProvider extends ChangeNotifier {
  ThemeMode _mode = ThemeMode.system;
  ThemeMode get mode => _mode;
  bool get isDark => _mode == ThemeMode.dark;

  void toggle() {
    _mode = _mode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    notifyListeners();
  }

  void setMode(ThemeMode m) { _mode = m; notifyListeners(); }
}

class NovelGeneratorApp extends StatelessWidget {
  const NovelGeneratorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => SelectedNovelProvider()),
        ChangeNotifierProvider(create: (_) => ThemeModeProvider()),
      ],
      child: Consumer<ThemeModeProvider>(
        builder: (ctx, themeProvider, _) => MaterialApp(
          title: '妙笔小说',
          theme: lightTheme,
          darkTheme: darkTheme,
          themeMode: themeProvider.mode,
          initialRoute: '/',
          onGenerateRoute: RouteGenerator.generateRoute,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [
            Locale('en', ''),
            Locale('zh', ''),
          ],
        ),
      ),
    );
  }
}