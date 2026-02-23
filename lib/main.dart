import 'package:flutter/material.dart';
import 'package:frame_sdk/bluetooth.dart';
import 'screens/glasses_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await BrilliantBluetooth.requestPermission();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'NOA AI Glasses',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: Colors.deepPurple,
        useMaterial3: true,
      ),
      home: const GlassesPage(),
    );
  }
}