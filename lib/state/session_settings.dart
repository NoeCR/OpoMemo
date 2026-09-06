import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SessionSettings extends ChangeNotifier {
  static const sizes = [10, 15, 20, 30];
  static const themeOptions = [
    (ThemeMode.system, 'Como el sistema'),
    (ThemeMode.light, 'Claro'),
    (ThemeMode.dark, 'Oscuro'),
  ];
  static const _key = 'session_size';
  static const _reverseKey = 'session_reversed';
  static const _themeKey = 'theme_mode';

  var size = 20;
  var reversed = false;
  var themeMode = ThemeMode.system;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getInt(_key) ?? 20;
    size = sizes.contains(stored) ? stored : 20;
    reversed = prefs.getBool(_reverseKey) ?? false;
    themeMode = _themeFromStorage(prefs.getString(_themeKey));
    notifyListeners();
  }

  Future<void> setSize(int value) async {
    if (!sizes.contains(value) || value == size) return;
    size = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_key, value);
  }

  Future<void> setReversed(bool value) async {
    if (value == reversed) return;
    reversed = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_reverseKey, value);
  }

  Future<void> setThemeMode(ThemeMode value) async {
    if (value == themeMode) return;
    themeMode = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_themeKey, value.name);
  }

  static ThemeMode _themeFromStorage(String? raw) {
    return ThemeMode.values.firstWhere(
      (item) => item.name == raw,
      orElse: () => ThemeMode.system,
    );
  }
}

Future<void> showSessionSizePicker(BuildContext context) {
  final settings = context.read<SessionSettings>();
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (context) {
      return ListenableBuilder(
        listenable: settings,
        builder: (context, _) {
          return SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.fromLTRB(16, 4, 16, 8),
                    child: Text(
                      'Ajustes',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.fromLTRB(16, 8, 16, 4),
                    child: Text(
                      'Apariencia',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                  for (final option in SessionSettings.themeOptions)
                    ListTile(
                      title: Text(option.$2),
                      selected: settings.themeMode == option.$1,
                      onTap: () => settings.setThemeMode(option.$1),
                    ),
                  SwitchListTile(
                    title: const Text('Empezar por la respuesta'),
                    subtitle: const Text('Ves el dorso y tienes que producir el término.'),
                    value: settings.reversed,
                    onChanged: settings.setReversed,
                  ),
                  const Padding(
                    padding: EdgeInsets.fromLTRB(16, 8, 16, 4),
                    child: Text(
                      'Cartas por sesión',
                      style: TextStyle(fontWeight: FontWeight.w700),
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
