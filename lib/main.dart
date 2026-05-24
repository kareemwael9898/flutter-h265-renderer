import 'package:flutter/material.dart';
import 'features/renderer/view/renderer_screen.dart';

void main() {
  runApp(const H265RendererApp());
}

class H265RendererApp extends StatelessWidget {
  const H265RendererApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'H.265 Renderer',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF0A84FF),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFF1A1A1E),
        cardColor: const Color(0xFF2C2C2E),
      ),
      home: const RendererScreen(),
    );
  }
}
