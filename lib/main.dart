import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app.dart';
import 'data/memo_repository.dart';
import 'database/app_database.dart';
import 'state/memo_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final database = await AppDatabase.open();
  final controller = MemoController(MemoRepository(database));
  await controller.bootstrap();
  runApp(
    ChangeNotifierProvider<MemoController>.value(
      value: controller,
      child: const OpoMemoApp(),
    ),
  );
}
