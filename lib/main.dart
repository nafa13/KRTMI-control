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
        brightness: Brightness.light,
        primaryColor: Colors.blueAccent,
        scaffoldBackgroundColor: Colors.white,
        colorScheme: ColorScheme.light(
          primary: Colors.blueAccent,
          secondary: Colors.orangeAccent,
          surface: Colors.white,
        ),
        fontFamily: 'Roboto',
      ),
      home: HomeScreen(),
    );
  }
}
