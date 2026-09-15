import 'package:flutter/material.dart';
import '../features/home/screens/home_screen.dart';
import 'theme/theme.dart';

class B3App extends StatelessWidget {
  const B3App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'B3 Ready',
      theme: B3Theme.lightTheme,
      home: const HomeScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}
