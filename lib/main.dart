import 'package:flutter/material.dart';
import 'Services/location.dart';

 void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Location App',
      theme: ThemeData(useMaterial3: true),
      home: const LocationPage(title: 'My Location'), // <-- here
    );
  }
}