import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/app_colors.dart';
import 'models/case_record.dart';
import 'screens/home_screen.dart';
import 'screens/cases_screen.dart';
import 'screens/settings_screen.dart';

const _hiveKeyName = 'hive_encryption_key';

Future<List<int>> _getEncryptionKey() async {
  const storage = FlutterSecureStorage();
  final existing = await storage.read(key: _hiveKeyName);
  if (existing != null) {
    return List<int>.from(jsonDecode(existing));
  }
  final key = List<int>.generate(32, (_) => Random.secure().nextInt(256));
  await storage.write(key: _hiveKeyName, value: jsonEncode(key));
  return key;
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ),
  );

  await Hive.initFlutter();
  Hive.registerAdapter(CaseRecordAdapter());

  final encryptionKey = await _getEncryptionKey();
  final cipher = HiveAesCipher(encryptionKey);

  try {
    await Hive.openBox<CaseRecord>('cases', encryptionCipher: cipher);
  } catch (_) {
    await Hive.deleteBoxFromDisk('cases');
    await Hive.openBox<CaseRecord>('cases', encryptionCipher: cipher);
  }

  runApp(const PoliceApp());
}

class PoliceApp extends StatelessWidget {
  const PoliceApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Police Case Docs',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: const AppShell(),
    );
  }
}

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  static void switchToTab(BuildContext context, int index) {
    context.findAncestorStateOfType<_AppShellState>()?.switchTab(index);
  }

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _currentIndex = 0;

  void switchTab(int index) {
    setState(() => _currentIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    final screens = [
      const HomeScreen(),
      const CasesScreen(),
      const SettingsScreen(),
    ];

    return Scaffold(
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 350),
        switchInCurve: Curves.easeOut,
        switchOutCurve: Curves.easeIn,
        transitionBuilder: (child, animation) {
          return FadeTransition(opacity: animation, child: child);
        },
        child: KeyedSubtree(
          key: ValueKey<int>(_currentIndex),
          child: screens[_currentIndex],
        ),
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: AppColors.surfaceCard,
          boxShadow: [
            BoxShadow(
              color: AppColors.shadowLight,
              blurRadius: 20,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: NavigationBar(
          selectedIndex: _currentIndex,
          onDestinationSelected: (i) => setState(() => _currentIndex = i),
          animationDuration: const Duration(milliseconds: 400),
          height: 72,
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.edit_document, size: 24),
              selectedIcon:
                  Icon(Icons.edit_document, color: AppColors.accent, size: 26),
              label: 'Document',
            ),
            NavigationDestination(
              icon: Icon(Icons.folder_outlined, size: 24),
              selectedIcon:
                  Icon(Icons.folder_rounded, color: AppColors.accent, size: 26),
              label: 'Cases',
            ),
            NavigationDestination(
              icon: Icon(Icons.settings_outlined, size: 24),
              selectedIcon: Icon(Icons.settings_rounded,
                  color: AppColors.accent, size: 26),
              label: 'Settings',
            ),
          ],
        ),
      ),
    );
  }
}
