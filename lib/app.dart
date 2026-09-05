import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'screens/home_screen.dart';
import 'state/memo_controller.dart';
import 'theme/app_theme.dart';

class OpoMemoApp extends StatelessWidget {
  const OpoMemoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'OpoMemo',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      home: const _Root(),
    );
  }
}

class _Root extends StatelessWidget {
  const _Root();

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<MemoController>();
    if (controller.loading && controller.summaries.isEmpty) {
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Preparando modos y mazos…'),
            ],
          ),
        ),
      );
    }
    return const HomeScreen();
  }
}
