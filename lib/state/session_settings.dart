import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SessionSettings extends ChangeNotifier {
  static const sizes = [10, 15, 20, 30];
  static const _key = 'session_size';

  var size = 20;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getInt(_key) ?? 20;
    size = sizes.contains(stored) ? stored : 20;
    notifyListeners();
  }

  Future<void> setSize(int value) async {
    if (!sizes.contains(value) || value == size) return;
    size = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_key, value);
  }
}

Future<void> showSessionSizePicker(BuildContext context) {
  final settings = context.read<SessionSettings>();
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (context) {
      return ListenableBuilder(
        listenable: settings,
        builder: (context, _) {
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.fromLTRB(16, 4, 16, 8),
                    child: Text(
                      'Cartas por sesión',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                    ),
                  ),
                  for (final option in SessionSettings.sizes)
                    ListTile(
                      title: Text('$option cartas'),
                      selected: settings.size == option,
                      onTap: () async {
                        await settings.setSize(option);
                        if (context.mounted) Navigator.pop(context);
                      },
                    ),
                ],
              ),
            ),
          );
        },
      );
    },
  );
}
