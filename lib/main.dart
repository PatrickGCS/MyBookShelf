import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'app.dart';
import 'providers/books_provider.dart';
import 'services/file_storage.dart';
import 'services/legacy_migration.dart';
import 'services/settings_service.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('pt_BR', null);
  themeNotifier.value = await SettingsService.loadThemeMode();
  await FileStorage.init();
  try {
    await migrateLegacyFiles();
  } catch (e) {
    debugPrint('Migração de arquivos: $e');
  }
  runApp(
    ChangeNotifierProvider(
      create: (_) => BooksProvider()..load(),
      child: const MyApp(),
    ),
  );
}
