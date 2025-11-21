import 'dart:async';
import 'package:flutter/material.dart';
import 'package:animated_text_kit/animated_text_kit.dart';
import 'login_screen.dart';
import '../services/database_service.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  final _dbService = DatabaseService();

  @override
  void initState() {
    super.initState();
    _loadDataAndNavigate();
  }

  /// Gerekli verileri yükler ve ardından LoginScreen'e yönlendirir.
  Future<void> _loadDataAndNavigate() async {
    // Splash ekranının en az 3 saniye görünmesini sağla
    await Future.delayed(const Duration(seconds: 3));

    // Veritabanı kontrollerini yap
    final allUsers = await _dbService.getAllUsers();
    final adminExists = await _dbService.hasAdmin();

    // Widget'ın hala ekranda olduğundan emin ol
    if (mounted) {
      // Verileri yükleyerek LoginScreen'e git
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => LoginScreen(
            allUsers: allUsers,
            adminExists: adminExists,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // Logo ve Yükleniyor... yazısı
          AnimatedPositioned(
            duration: const Duration(milliseconds: 600),
            curve: Curves.easeInOut,
            // Başlangıçta ortada
            top: (screenHeight / 2) - 140,
            left: (screenWidth / 2) - 90,
            width: 180,
            height: 280,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  height: 180,
                  width: 180,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(25),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.15),
                        spreadRadius: 2,
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      )
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(25),
                    child: Image.asset(
                      'assets/logo.png',
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => const Icon(
                          Icons.table_bar,
                          size: 50,
                          color: Colors.teal),
                    ),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.only(top: 30.0),
                  child: Text(
                    'Yükleniyor...',
                    style: TextStyle(
                      fontFamily: 'Montserrat',
                      color: Colors.black87,
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Geliştirici Bilgisi
          AnimatedPositioned(
            duration: const Duration(milliseconds: 600),
            curve: Curves.easeInOut,
            bottom: 40,
            left: 0,
            right: 0,
            child: _buildDeveloperInfo(),
          ),
        ],
      ),
    );
  }

  /// Orijinal `WelcomeScreen`'den taşınan geliştirici bilgisi widget'ı
  Widget _buildDeveloperInfo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Image.asset(
          'assets/metsoft.png',
          height: 80,
          errorBuilder: (context, error, stackTrace) =>
              const Icon(Icons.code, size: 40, color: Colors.teal),
        ),
        const SizedBox(height: 6),
        const Text(
          'Metsoft Yazılım',
          style: TextStyle(
            fontFamily: 'Montserrat',
            color: Colors.black87,
            fontSize: 16,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 4),
        AnimatedTextKit(
          repeatForever: false,
          totalRepeatCount: 1,
          animatedTexts: [
            TypewriterAnimatedText(
              'Developed by MET • Powered by MetSoft',
              textStyle: TextStyle(
                color: Colors.black.withOpacity(0.5),
                fontSize: 12,
                fontStyle: FontStyle.italic,
                fontWeight: FontWeight.w300,
              ),
              speed: const Duration(milliseconds: 70),
              cursor: '',
            )
          ],
        ),
      ],
    );
  }
}
