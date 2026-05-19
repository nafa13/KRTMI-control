import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'mqtt_service.dart';
import 'screens/home_screen.dart';

void main() {
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => MqttService()),
      ],
      child: MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'KRTMI Controller',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        primaryColor: Color(0xFF2D2D44),
        scaffoldBackgroundColor: Color(0xFF1E1E2C),
        colorScheme: ColorScheme.dark(
          primary: Colors.blueAccent,
          secondary: Colors.orange,
        ),
        fontFamily: 'Roboto',
      ),
      home: HomeScreen(),
    );
  }
}
