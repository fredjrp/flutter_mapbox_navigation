import 'package:flutter/material.dart';
import 'onboarding_screen.dart';
import 'app.dart'; // Your SampleNavigationApp is here

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Navigation App',
      theme: ThemeData(
        fontFamily: 'Mulish', // Using your onboarding font
      ),
      home: const OnboardingScreen(),
      routes: {
        '/navigation': (context) => const SampleNavigationApp(),
      },
    );
  }
}
