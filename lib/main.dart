import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'screens/date_selection_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Worker Payments',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.teal,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        fontFamily: 'Arial',
      ),
      home: const DateSelectionScreen(
        storeType: '', // لم تعد هذه القيم مستخدمة ولكن يجب تمريرها
        storeName: '', // لم تعد هذه القيم مستخدمة ولكن يجب تمريرها
      ),
    );
  }
}
