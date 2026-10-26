import 'package:flutter/material.dart';
import 'screens/books_screen.dart';
import 'theme/app_theme.dart';

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (context, currentMode, child) {
        return MaterialApp(
          title: 'MyBookShelf',
          debugShowCheckedModeBanner: false,
          themeMode: currentMode,
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          home: const BooksScreen(),
        );
      },
    );
  }
}
