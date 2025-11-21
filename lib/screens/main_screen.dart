import 'dart:async';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:open_file/open_file.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

// YENİ: Showcase ve Tutorial Keys importları
import 'package:showcaseview/showcaseview.dart';
import '../utils/tutorial_keys.dart'; // Bu dosyanın lib/utils/tutorial_keys.dart adresinde olduğunu varsayıyoruz

import 'home_screen.dart';
import 'product_screen.dart';
import 'report_screen.dart';
import 'settings_screen.dart';
import 'table_records_screen.dart';
import 'cameras_screen.dart';
import 'veresiye_screen.dart';
import 'splash_screen.dart'; // WelcomeScreen'in burada olduğunu varsayıyoruz
import 'ai_chat_screen.dart'; // YENİ: AI Chat ekranı import edildi
import '../services/database_helper.dart';
import '../services/pdf_report_service.dart';
import '../models/table_record_model.dart';
import '../models/top_product.dart';

final GlobalKey screenCaptureKey = GlobalKey();

class NotificationItem {
  final String id;
  final String title;
  final String subtitle;
  final File reportFile;
  final File? thumbnailFile;
  final DateTime timestamp;

  NotificationItem({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.reportFile,
    this.thumbnailFile,
    required this.timestamp,
  });
}

class MainScreen extends StatefulWidget {
  final Map<String, dynamic> loggedInUser;

  const MainScreen({super.key, required this.loggedInUser});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;
  bool _alwaysVisible = false;
  bool _dockVisible = false;
  Timer? _hideTimer;
  Timer? _autoReportTimer;

  bool _isNotificationPanelVisible = false;
  double _notificationButtonOpacity = 1.0;
  Timer? _notificationFadeTimer;
  final double _fadedOpacity = 0.4;

  final List<NotificationItem> _notifications = [];

  Timer? _inactivityTimer;
  Timer? _logoutCountdownTimer;
  int _autoLogoutMinutes = 15;
  bool _isAutoLogoutEnabled = false;
  int _countdownValue = 60;

  @override
  void initState() {
    super.initState();
    _loadDockPreference();
    _startNotificationFadeTimer();
    _initAutoReportTimer();
    _loadAutoLogoutSettings();
    _startTutorial(); // Eğitimi başlat
  }

  // YENİ: Eğitimi başlatma fonksiyonu (AI Chat key eklendi)
  void _startTutorial() async {
    final prefs = await SharedPreferences.getInstance();
    final bool seenTutorial = prefs.getBool('seen_main_tutorial') ?? false;

    // Eğer kullanıcı eğitimi görmediyse VE widget ağacı çizildiyse
    if (!seenTutorial && mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ShowCaseWidget.of(context).startShowCase(
          [
            TutorialKeys.dockMasalar,
            TutorialKeys.dockUrunler,
            TutorialKeys.dockRaporlar,
            TutorialKeys.dockKayitlar,
            TutorialKeys.dockVeresiye,
            TutorialKeys.dockKameralar,
            TutorialKeys.dockAIChat, // YENİ: AI Chat eklendi
            TutorialKeys.dockAyarlar,
            TutorialKeys.bildirimButonu,
          ],
        );
      });
    }
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _notificationFadeTimer?.cancel();
    _autoReportTimer?.cancel();
    _inactivityTimer?.cancel();
    _logoutCountdownTimer?.cancel();
    super.dispose();
  }

  // -----------------------------------------------------------------
  // OTOMATİK OTURUM KAPATMA MANTIĞI
  // -----------------------------------------------------------------

  Future<void> _loadAutoLogoutSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isAutoLogoutEnabled = prefs.getBool('auto_logout_enabled') ?? false;
      _autoLogoutMinutes = prefs.getInt('auto_logout_minutes') ?? 15;
    });
    if (_isAutoLogoutEnabled) {
      resetInactivityTimer();
    }
  }

  Future<void> _saveAutoLogoutSettings(bool enabled, int minutes) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('auto_logout_enabled', enabled);
    await prefs.setInt('auto_logout_minutes', minutes);
  }

  void _handleAutoLogoutChanged(bool enabled, int minutes) {
    setState(() {
      _isAutoLogoutEnabled = enabled;
      _autoLogoutMinutes = minutes;
    });
    _saveAutoLogoutSettings(enabled, minutes);

    if (enabled) {
      resetInactivityTimer();
    } else {
      _inactivityTimer?.cancel();
      _logoutCountdownTimer?.cancel();
    }
  }

  void resetInactivityTimer() {
    if (!_isAutoLogoutEnabled || !mounted) return;
    _inactivityTimer?.cancel();
    _inactivityTimer = Timer(
        Duration(minutes: _autoLogoutMinutes), _showLogoutCountdownDialog);
  }

  void _secureLogout() {
    _inactivityTimer?.cancel();
    _logoutCountdownTimer?.cancel();
    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const SplashScreen()),
        (Route<dynamic> route) => false,
      );
    }
  }

  void _showLogoutCountdownDialog() {
    if (!mounted || ModalRoute.of(context)?.isCurrent != true) return;
    _logoutCountdownTimer?.cancel();
    _countdownValue = 60;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            if (_logoutCountdownTimer == null ||
                !_logoutCountdownTimer!.isActive) {
              _logoutCountdownTimer =
                  Timer.periodic(const Duration(seconds: 1), (timer) {
                if (!mounted) {
                  timer.cancel();
                  return;
                }
                if (_countdownValue > 0) {
                  setDialogState(() {
                    _countdownValue--;
                  });
                } else {
                  timer.cancel();
                  if (Navigator.of(context).canPop()) {
                    Navigator.of(context).pop();
                  }
                  _secureLogout();
                }
              });
            }

            return _buildCustomDialog(
              icon: Icons.hourglass_bottom_rounded,
              iconColor: Colors.orange.shade700,
              title: 'Oturum Kapatılıyor',
              content: [
                Text(
                  'İşlem yapılmadığı için oturumunuz sonlandırılacak.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, color: Colors.grey.shade700),
                ),
                const SizedBox(height: 24),
                Text(
                  '$_countdownValue',
                  style: TextStyle(
                      fontSize: 64,
                      fontWeight: FontWeight.bold,
                      color: Colors.orange.shade800),
                ),
                const Text(
                  'saniye',
                  style: TextStyle(fontSize: 16, color: Colors.black54),
                ),
              ],
              actions: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      _logoutCountdownTimer?.cancel();
                      Navigator.pop(context);
                      resetInactivityTimer();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Oturum sürdürülüyor.'),
                          backgroundColor: Colors.teal,
                        ),
                      );
                    },
                    style: _getButtonStyle(Colors.orange.shade700),
                    child: const Text('Oturumu Sürdür'),
                  ),
                ),
              ],
            );
          },
        );
      },
    ).whenComplete(() {
      _logoutCountdownTimer?.cancel();
    });
  }

  // -----------------------------------------------------------------
  // DİYALOG YARDIMCILARI
  // -----------------------------------------------------------------

  ButtonStyle _getButtonStyle(Color color) {
    return ElevatedButton.styleFrom(
      backgroundColor: color,
      foregroundColor: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      textStyle: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
      elevation: 4,
    );
  }

  Widget _buildCustomDialog({
    required IconData icon,
    required Color iconColor,
    required String title,
    required List<Widget> content,
    required List<Widget> actions,
  }) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      elevation: 8,
      child: Container(
        padding: const EdgeInsets.all(28),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [iconColor.withOpacity(0.8), iconColor],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: iconColor.withOpacity(0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Icon(icon, size: 58, color: Colors.white),
              ),
              const SizedBox(height: 20),
              Text(
                title,
                style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 26,
                    color: Color(0xFF1A1A2E)),
              ),
              const SizedBox(height: 20),
              ...content,
              const SizedBox(height: 28),
              Row(children: actions),
            ],
          ),
        ),
      ),
    );
  }

  // -----------------------------------------------------------------
  // MEVCUT MAİN SCREEN FONKSİYONLARI
  // -----------------------------------------------------------------

  Future<void> _loadDockPreference() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _alwaysVisible = prefs.getBool('dock_always_visible') ?? false;
      if (_alwaysVisible) {
        _dockVisible = true;
      } else if (_selectedIndex == 0) {
        _dockVisible = true;
        _startHideTimer();
      }
    });
  }

  Future<void> _saveDockPreference(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('dock_always_visible', value);
  }

  void _initAutoReportTimer() {
    _autoReportTimer = Timer.periodic(const Duration(minutes: 1), (timer) {
      _checkForAutoReport();
    });
    _checkForAutoReport();
  }

  Future<void> _checkForAutoReport() async {
    if (!mounted) return;
    final prefs = await SharedPreferences.getInstance();
    final bool isEnabled = prefs.getBool('auto_report_enabled') ?? false;
    if (!isEnabled || (Platform.isAndroid || Platform.isIOS)) {
      return;
    }

    final now = DateTime.now();
    final lastReportDateStr = prefs.getString('last_auto_report_date');
    final todayStr = DateFormat('yyyy-MM-dd').format(now);
    if (lastReportDateStr == todayStr) {
      return;
    }

    final String timeString = prefs.getString('auto_report_time') ?? '23:00';
    final reportTime = TimeOfDay(
      hour: int.parse(timeString.split(':')[0]),
      minute: int.parse(timeString.split(':')[1]),
    );

    final scheduledReportDateTime = DateTime(
        now.year, now.month, now.day, reportTime.hour, reportTime.minute);

    if (now.isAfter(scheduledReportDateTime) ||
        now.isAtSameMomentAs(scheduledReportDateTime)) {
      debugPrint(
          "${DateFormat('yyyy-MM-dd HH:mm').format(now)}: Rapor saati geldi. Otomatik gün sonu raporu oluşturuluyor...");
      await _generateAndNotify();
      await prefs.setString('last_auto_report_date', todayStr);
    }
  }

  // GÜNCELLENDİ: Artık "dün" yerine "bugün" için rapor oluşturuyor
  Future<void> _generateAndNotify() async {
    try {
      final db = DatabaseHelper.instance;
      // DEĞİŞİKLİK: 'yesterday' yerine 'today' kullanılıyor
      final today = DateTime.now();
      final startOfToday = DateTime(today.year, today.month, today.day);

      // DEĞİŞİKLİK: getOrdersForDate(today) çağrılıyor
      final todaysRecordsMaps = await db.getOrdersForDate(today);

      List<TableRecordModel> todaysRecords = [];
      if (todaysRecordsMaps != null && todaysRecordsMaps.isNotEmpty) {
        todaysRecords = todaysRecordsMaps
            .map((map) => TableRecordModel.fromSqliteMap(map))
            .where((record) =>
                !record.totalPrice.isNaN && !record.totalPrice.isInfinite)
            .toList();
      } else {
        // DEĞİŞİKLİK: Mesaj güncellendi
        debugPrint("Bugün için raporlanacak kapanmış masa kaydı bulunamadı.");
      }

      final double totalRevenue =
          todaysRecords.fold(0.0, (sum, record) => sum + record.totalPrice);

      final Map<String, int> productSales = {};
      for (var record in todaysRecords) {
        for (var item in record.items) {
          productSales.update(
            item.productName,
            (value) => (value + item.quantity).toInt(),
            ifAbsent: () => item.quantity.toInt(),
          );
        }
      }

      final sortedProducts = productSales.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));

      final List<TopProduct> topProducts = sortedProducts.map((entry) {
        return TopProduct(name: entry.key, salesCount: entry.value);
      }).toList();

      // DEĞİŞİKLİK: 'today' tarihi kullanılıyor
      final Map<String, double> dailyRevenues = {
        DateFormat('yyyy-MM-dd').format(today): totalRevenue
      };

      final reportData = ReportData(
        // DEĞİŞİKLİK: Tarihler güncellendi
        startDate: startOfToday,
        endDate: today,
        totalRevenue: totalRevenue,
        dailyRevenues: dailyRevenues,
        topProducts: topProducts,
      );

      final pdfService = PdfReportService();
      // DEĞİŞİKLİK: 'todaysRecords' parametre olarak gönderiliyor
      final reportResult =
          await pdfService.generateEndOfDayReport(reportData, todaysRecords);

      final newNotification = NotificationItem(
        id: DateTime.now().toIso8601String(),
        // DEĞİŞİKLİK: Başlık ve alt başlık metinleri güncellendi
        title: todaysRecords.isEmpty
            ? 'Gün Sonu Raporu (Boş)'
            : 'Gün Sonu Raporu Oluşturuldu',
        subtitle: todaysRecords.isEmpty
            ? 'Bugün hiç satış yapılmadı.'
            : 'Toplam Ciro: ${NumberFormat.currency(locale: 'tr_TR', symbol: '₺').format(totalRevenue)}',
        reportFile: reportResult.pdfFile,
        thumbnailFile: reportResult.thumbnailFile,
        timestamp: DateTime.now(),
      );

      if (mounted) {
        setState(() {
          _notifications.insert(0, newNotification);
          _isNotificationPanelVisible = true;
          _notificationButtonOpacity = 1.0;
          _notificationFadeTimer?.cancel();
        });
      }
    } catch (e) {
      debugPrint("Otomatik rapor oluşturma ve bildirme hatası: $e");
    }
  }

  void _onItemTapped(int index) {
    resetInactivityTimer();
    setState(() => _selectedIndex = index);
    _showDockTemporarily();
    _resetNotificationButton();
  }

  void _toggleDock(bool show) {
    if (!_alwaysVisible) {
      setState(() => _dockVisible = show);
      if (show) _startHideTimer();
    }
  }

  void _startHideTimer() {
    _hideTimer?.cancel();
    if (_alwaysVisible) return;
    _hideTimer = Timer(const Duration(seconds: 7), () {
      if (!_alwaysVisible && mounted) setState(() => _dockVisible = false);
    });
  }

  void _showDockTemporarily() {
    _toggleDock(true);
  }

  void _startNotificationFadeTimer() {
    _notificationFadeTimer?.cancel();
    _notificationFadeTimer = Timer(const Duration(seconds: 4), () {
      if (mounted) setState(() => _notificationButtonOpacity = _fadedOpacity);
    });
  }

  void _resetNotificationButton() {
    resetInactivityTimer();
    if (!_isNotificationPanelVisible) {
      setState(() => _notificationButtonOpacity = 1.0);
      _startNotificationFadeTimer();
    }
  }

  void _toggleNotificationPanel() {
    resetInactivityTimer();
    setState(() {
      _isNotificationPanelVisible = !_isNotificationPanelVisible;
      if (_isNotificationPanelVisible) {
        _notificationFadeTimer?.cancel();
        _notificationButtonOpacity = 1.0;
      } else {
        _startNotificationFadeTimer();
      }
    });
  }

  // YENİ: Bildirim silme fonksiyonu
  void _deleteNotification(String id) {
    setState(() {
      _notifications.removeWhere((item) => item.id == id);
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Bildirim silindi.'),
          backgroundColor: Colors.red.shade400,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // GÜNCELLENDİ: _widgetOptions listesi (AI Chat eklendi, Ayarlar indeksi 7 oldu)
    final List<Widget> _widgetOptions = <Widget>[
      HomeScreen(loggedInUser: widget.loggedInUser), // 0: Masalar
      ProductScreen(), // 1: Ürünler
      const ReportScreen(), // 2: Raporlar
      const TableRecordsScreen(), // 3: Kayıtlar
      const VeresiyeScreen(), // 4: Veresiye
      const CamerasScreen(), // 5: Kameralar
      const AIChatScreen(), // 6: AI Asistan (YENİ)
      SettingsScreen(
        // 7: Ayarlar (Index değişti)
        loggedInUser: widget.loggedInUser,
        initialAutoLogoutEnabled: _isAutoLogoutEnabled,
        initialAutoLogoutMinutes: _autoLogoutMinutes,
        onAutoLogoutChanged: _handleAutoLogoutChanged,
        onUserUpdated: (Map<String, dynamic> p1) {},
      ),
    ];

    return Scaffold(
      extendBody: true,
      body: GestureDetector(
        onTap: () {
          _showDockTemporarily();
          _resetNotificationButton();
          resetInactivityTimer();
        },
        onTapDown: (_) => resetInactivityTimer(),
        onPanDown: (_) => resetInactivityTimer(),
        onScaleStart: (_) => resetInactivityTimer(),
        onVerticalDragUpdate: (details) {
          _showDockTemporarily();
          _resetNotificationButton();
          resetInactivityTimer();

          final double? delta = details.primaryDelta;
          if (delta == null) return;
          if (delta < -10) {
            _toggleDock(true);
          } else if (delta > 10) _toggleDock(false);
        },
        child: RepaintBoundary(
          key: screenCaptureKey,
          child: Stack(
            children: [
              Positioned.fill(child: _widgetOptions[_selectedIndex]),
              _buildDock(),
              _buildNotificationPanel(),
              _buildNotificationButton(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNotificationButton() {
    return Positioned(
      bottom: 20,
      right: 20,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 300),
        opacity: _notificationButtonOpacity,
        // YENİ: Showcase widget'ı eklendi
        child: Showcase(
          key: TutorialKeys.bildirimButonu,
          title: 'Bildirimler',
          description:
              'Otomatik oluşturulan gün sonu raporları burada birikir.',
          // Vurgu alanını, buton gibi daire yapar.
          targetShapeBorder: const CircleBorder(),
          child: GestureDetector(
            onTap: _toggleNotificationPanel,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blueAccent.withOpacity(0.8),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 10,
                      spreadRadius: 2)
                ],
              ),
              child: Badge(
                label: Text('${_notifications.length}'),
                isLabelVisible: _notifications.isNotEmpty,
                child: Icon(
                  _isNotificationPanelVisible
                      ? Icons.close
                      : Icons.notifications,
                  color: Colors.white,
                  size: 28,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNotificationPanel() {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final panelWidth = screenWidth > 500 ? 400.0 : screenWidth * 0.9;
    final panelHeight = screenHeight * 0.6;

    Widget panelContent = Material(
      color: Colors.transparent,
      child: Container(
        width: panelWidth,
        height: panelHeight,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withOpacity(0.2)),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
            child: Container(
              color: Colors.black.withOpacity(0.3),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text("Bildirimler",
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold)),
                        IconButton(
                            icon: const Icon(Icons.close, color: Colors.white),
                            onPressed: _toggleNotificationPanel),
                      ],
                    ),
                  ),
                  const Divider(color: Colors.white24, height: 1),
                  Expanded(
                    child: _notifications.isEmpty
                        ? const Center(
                            child: Text("Yeni bildirim yok.",
                                style: TextStyle(color: Colors.white70)))
                        : ListView.builder(
                            padding: const EdgeInsets.all(8),
                            itemCount: _notifications.length,
                            itemBuilder: (context, index) {
                              final notification = _notifications[index];
                              // GÜNCELLENDİ: Kart, Dismissible ile sarıldı
                              return Dismissible(
                                key: Key(notification.id),
                                direction: DismissDirection.endToStart,
                                onDismissed: (direction) {
                                  _deleteNotification(notification.id);
                                },
                                background: Container(
                                  color: Colors.red.shade700,
                                  margin: const EdgeInsets.symmetric(
                                      vertical: 6, horizontal: 8),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 20),
                                  alignment: Alignment.centerRight,
                                  child: const Icon(Icons.delete_sweep_rounded,
                                      color: Colors.white),
                                ),
                                child: Card(
                                  color: Colors.white.withOpacity(0.1),
                                  margin: const EdgeInsets.symmetric(
                                      vertical: 6, horizontal: 8),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12)),
                                  clipBehavior: Clip.antiAlias,
                                  child: InkWell(
                                    onTap: () {
                                      resetInactivityTimer();
                                      OpenFile.open(
                                          notification.reportFile.path);
                                    },
                                    child: Padding(
                                      padding: const EdgeInsets.all(12.0),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          if (notification.thumbnailFile !=
                                              null)
                                            Container(
                                              margin: const EdgeInsets.only(
                                                  bottom: 12),
                                              decoration: BoxDecoration(
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                                border: Border.all(
                                                    color: Colors.white
                                                        .withOpacity(0.3)),
                                              ),
                                              child: ClipRRect(
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                                child: Image.file(
                                                  notification.thumbnailFile!,
                                                  fit: BoxFit.cover,
                                                  // GÜNCELLENDİ: Boyutlar düzeltildi
                                                  width: double.infinity,
                                                  height: 180,
                                                ),
                                              ),
                                            ),
                                          Text(notification.title,
                                              style: const TextStyle(
                                                  color: Colors.white,
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 16)),
                                          const SizedBox(height: 4),
                                          Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceBetween,
                                            children: [
                                              Expanded(
                                                child: Text(
                                                    notification.subtitle,
                                                    style: TextStyle(
                                                        color: Colors.white
                                                            .withOpacity(0.8),
                                                        fontSize: 14)),
                                              ),
                                              Text(
                                                  DateFormat('HH:mm').format(
                                                      notification.timestamp),
                                                  style: const TextStyle(
                                                      color: Colors.white54)),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    return Align(
      alignment: Alignment.bottomRight,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 100, right: 20),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 350),
          reverseDuration: const Duration(milliseconds: 250),
          transitionBuilder: (Widget child, Animation<double> animation) {
            return ScaleTransition(
              scale: CurvedAnimation(
                  parent: animation,
                  curve: Curves.easeOutCubic,
                  reverseCurve: Curves.easeInCubic),
              alignment: Alignment.bottomRight,
              child: FadeTransition(
                opacity:
                    CurvedAnimation(parent: animation, curve: Curves.easeOut),
                child: child,
              ),
            );
          },
          child: _isNotificationPanelVisible
              ? panelContent
              : const SizedBox.shrink(),
        ),
      ),
    );
  }

  Widget _buildDock() {
    return Align(
      alignment: Alignment.bottomCenter,
      child: AnimatedSlide(
        duration: const Duration(milliseconds: 300),
        offset: _dockVisible ? Offset.zero : const Offset(0, 1.5),
        child: GestureDetector(
          onLongPress: () {
            resetInactivityTimer();
            _showDockSettings();
          },
          child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            width: MediaQuery.of(context).size.width * 0.80,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(23),
              color: const Color.fromARGB(0, 255, 255, 255).withOpacity(0.148),
              border: Border.all(
                  color:
                      const Color.fromARGB(0, 255, 255, 255).withOpacity(0.148),
                  width: 0),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(23),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  // GÜNCELLENDİ: Dock ikonları ve sıralaması
                  children: [
                    _dockIcon(MdiIcons.tableChair, 0, TutorialKeys.dockMasalar,
                        'Masalar'),
                    _dockIcon(MdiIcons.shoppingOutline, 1,
                        TutorialKeys.dockUrunler, 'Ürünler'),
                    _dockIcon(Icons.bar_chart, 2, TutorialKeys.dockRaporlar,
                        'Raporlar'),
                    _dockIcon(Icons.receipt_long, 3, TutorialKeys.dockKayitlar,
                        'Kayıtlar'),
                    _dockIcon(Icons.article_outlined, 4,
                        TutorialKeys.dockVeresiye, 'Veresiye'),
                    _dockIcon(MdiIcons.cctv, 5, TutorialKeys.dockKameralar,
                        'Kameralar'),
                    // YENİ: AI Asistan ikonu eklendi (Index 6)
                    _dockIcon(MdiIcons.brain, 6, TutorialKeys.dockAIChat,
                        'AI Asistan'),
                    // Ayarlar ikonu (Index 7)
                    _dockIcon(MdiIcons.cogOutline, 7, TutorialKeys.dockAyarlar,
                        'Ayarlar'),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showDockSettings() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Dock Ayarları"),
        content: StatefulBuilder(
          builder: (context, setStateDialog) {
            return SwitchListTile(
              title: const Text("Sürekli görünür"),
              subtitle: const Text("Dock'un otomatik gizlenmesini kapatır."),
              value: _alwaysVisible,
              onChanged: (val) {
                resetInactivityTimer();
                setState(() {
                  _alwaysVisible = val;
                  _dockVisible = val;
                  if (!val) _startHideTimer();
                });
                _saveDockPreference(val);
                setStateDialog(() {});
                Navigator.pop(context);
              },
            );
          },
        ),
      ),
    );
  }

  Widget _dockIcon(IconData icon, int index, GlobalKey key, String title) {
    final isSelected = _selectedIndex == index;
    return Showcase(
      key: key,
      title: title,
      description: 'Uygulamanın $title bölümüne gidin.',
      targetShapeBorder: const CircleBorder(), // Baloncuk şekli
      child: GestureDetector(
        onTap: () => _onItemTapped(index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isSelected ? Colors.white : Colors.transparent,
            gradient: isSelected
                ? LinearGradient(
                    colors: [
                      Colors.white.withOpacity(0.25),
                      Colors.white.withOpacity(0.20),
                      Colors.white.withOpacity(0.15),
                      Colors.white.withOpacity(0.10),
                      Colors.white.withOpacity(0.05)
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : null,
          ),
          child: Icon(
            icon,
            size: isSelected ? 28 : 22,
            color: isSelected
                ? Colors.blueAccent
                : const Color.fromARGB(255, 85, 146, 252),
          ),
        ),
      ),
    );
  }
}
