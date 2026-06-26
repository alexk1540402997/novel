import 'package:flutter/material.dart';
import 'app/app.dart';
import 'utils/config_service.dart';
import 'domain/services/logger_service.dart';
import 'data/repositories/genre_repository.dart';
import 'data/repositories/template_repository.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await LoggerService().init();
  await ConfigService().init();
  await GenreRepository().init();
  await TemplateRepository().init();
  runApp(const NovelGeneratorApp());
}
