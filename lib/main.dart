import 'package:flutter/material.dart';
import 'package:provider/provider.dart'; // Durum yönetimi için
import 'package:masa_takip_sistemi/screens/splash_screen.dart';
import 'package:masa_takip_sistemi/services/database_helper.dart'; // Veritabanı işlemleri için
import 'package:masa_takip_sistemi/providers/table_provider.dart'; // TableProvider için
import 'package:masa_takip_sistemi/providers/product_provider.dart'; // ProductProvider için
import 'package:masa_takip_sistemi/providers/daily_revenue_provider.dart'; // DailyRevenueProvider için

// lib/main.dart (ana uygulama dosyası)
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Veritabanını başlat
  await DatabaseHelper.instance.database;

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (context) => TableProvider()),
        ChangeNotifierProvider(create: (context) => ProductProvider()),
        ChangeNotifierProvider(create: (context) => DailyRevenueProvider()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Masa Takip Uygulaması',
      debugShowCheckedModeBanner: false, // Debug bandını kaldırır
      theme: ThemeData(
        primarySwatch: Colors.blueGrey,
        visualDensity: VisualDensity.adaptivePlatformDensity,
        appBarTheme: AppBarTheme(
          backgroundColor: Colors.blueGrey[800],
          foregroundColor: Colors.white,
        ),
        floatingActionButtonTheme: FloatingActionButtonThemeData(
          backgroundColor: Colors.blueGrey[700],
          foregroundColor: Colors.white,
        ),
        chipTheme: ChipThemeData(
          selectedColor: Colors.blueGrey[600],
          labelStyle: TextStyle(color: Colors.blueGrey[800]),
          secondaryLabelStyle: const TextStyle(color: Colors.white),
        ),
      ),
      home: const SplashScreen(),
    );
  }
}
