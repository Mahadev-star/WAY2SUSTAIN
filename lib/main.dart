import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'splash_screen.dart';
import 'auth/login_page.dart';
import 'home/home_page.dart'; // Make sure this imports the actual HomePage
import 'providers/auth_provider.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [ChangeNotifierProvider(create: (_) => AuthProvider())],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Way2Sustain',
        theme: ThemeData.dark().copyWith(
          scaffoldBackgroundColor: const Color(0xFF151717),
          primaryColor: const Color(0xFF43A047),
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF43A047),
            brightness: Brightness.dark,
          ),
        ),
        home: const SplashScreen(),
        routes: {
          '/login': (context) => const LoginPage(),
          '/home': (context) => HomePage(),
        },
      ),
    );
  }
}
