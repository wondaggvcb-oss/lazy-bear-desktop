import "package:flutter/material.dart";
import "pages/home_page.dart";

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const BearApp());
}

class BearApp extends StatelessWidget {
  const BearApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: "熊",
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: const Color(0xFF8B6914),
        useMaterial3: true,
        brightness: Brightness.light,
        scaffoldBackgroundColor: const Color(0xFFFFF8EC),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFFFFF0D0),
          foregroundColor: Color(0xFF5C3D00),
          elevation: 0,
        ),
      ),
      darkTheme: ThemeData(
        colorSchemeSeed: const Color(0xFFE8C56D),
        useMaterial3: true,
        brightness: Brightness.dark,
      ),
      home: const HomePage(),
    );
  }
}
