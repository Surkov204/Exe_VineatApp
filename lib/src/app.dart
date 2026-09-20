import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'screens.dart';

class VineatApp extends StatelessWidget {
  const VineatApp({super.key});

  @override
  Widget build(BuildContext context) {
    const green = Color(0xFF079669);
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'ViNeat',
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF9FAFB),
        colorScheme: ColorScheme.fromSeed(
          seedColor: green,
          primary: green,
          surface: Colors.white,
        ),
        fontFamily: 'Roboto',
        pageTransitionsTheme: const PageTransitionsTheme(
          builders: {
            TargetPlatform.android: FadeUpwardsPageTransitionsBuilder(),
            TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          },
        ),
        splashFactory: InkSparkle.splashFactory,
        visualDensity: VisualDensity.standard,
        textTheme: const TextTheme(
          headlineSmall: TextStyle(
            fontWeight: FontWeight.w800,
            color: Color(0xFF1F2937),
          ),
          titleLarge: TextStyle(
            fontWeight: FontWeight.w800,
            color: Color(0xFF1F2937),
          ),
          titleMedium: TextStyle(
            fontWeight: FontWeight.w700,
            color: Color(0xFF253043),
          ),
          bodyMedium: TextStyle(color: Color(0xFF586477)),
        ),
        cardTheme: const CardThemeData(
          color: Colors.white,
          elevation: 0,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(14)),
            side: BorderSide(color: Color(0xFFEEF0F3)),
          ),
        ),
      ),
      home: const AppShell(),
    );
  }
}

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = 0;

  static const _pages = [
    FridgeScreen(),
    ScanScreen(),
    RecipesScreen(),
    ShoppingScreen(),
    ReportsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          for (var index = 0; index < _pages.length; index++)
            IgnorePointer(
              ignoring: index != _index,
              child: TickerMode(
                enabled: index == _index,
                child: AnimatedOpacity(
                  opacity: index == _index ? 1 : 0,
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeInOut,
                  child: AnimatedSlide(
                    offset: index == _index
                        ? Offset.zero
                        : const Offset(0.025, 0),
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeOutCubic,
                    child: _pages[index],
                  ),
                ),
              ),
            ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        height: 68,
        selectedIndex: _index,
        backgroundColor: Colors.white,
        indicatorColor: const Color(0xFFE7F8F1),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        onDestinationSelected: (value) => setState(() => _index = value),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Trang chủ',
          ),
          NavigationDestination(
            icon: Icon(Icons.document_scanner_outlined),
            label: 'Scan',
          ),
          NavigationDestination(
            icon: Icon(Icons.restaurant_menu),
            label: 'Món ăn',
          ),
          NavigationDestination(
            icon: Icon(Icons.shopping_basket_outlined),
            label: 'Đi chợ',
          ),
          NavigationDestination(
            icon: Icon(Icons.bar_chart_rounded),
            label: 'Báo cáo',
          ),
        ],
      ),
    );
  }
}
