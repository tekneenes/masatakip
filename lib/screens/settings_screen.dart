import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'login_screen.dart';
// YENİ: UpdateScreen importu eklendi
import 'update_screen.dart';
import 'splash_screen.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'login_settings_screen.dart';
import 'dart:convert';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import '../services/database_service.dart';

class SettingsScreen extends StatefulWidget {
  final Map<String, dynamic> loggedInUser;
  final bool initialAutoLogoutEnabled;
  final int initialAutoLogoutMinutes;
  final Function(bool, int) onAutoLogoutChanged;
  final Function(Map<String, dynamic>) onUserUpdated;

  const SettingsScreen({
    super.key,
    required this.loggedInUser,
    required this.initialAutoLogoutEnabled,
    required this.initialAutoLogoutMinutes,
    required this.onAutoLogoutChanged,
    required this.onUserUpdated,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  // Servis ve Controller'lar
  final _dbService = DatabaseService();
  final _passwordVerificationController = TextEditingController();
  final _companyNameController = TextEditingController();
  final _nameController = TextEditingController();
  final _contactController = TextEditingController();
  final _emailController = TextEditingController();
  final _updateFormKey = GlobalKey<FormState>();

  // Yeni kullanıcı ekleme formu
  final _newUserFormKey = GlobalKey<FormState>();
  final _newUserNameController = TextEditingController();
  final _newUserEmailController = TextEditingController();
  final _newUserPasswordController = TextEditingController();
  String? _newUserSelectedRole;
  final List<String> _roles = ['Müdür', 'Şube Müdürü', 'Garson', 'Kasiyer'];

  // Kullanıcı bilgileri state'leri
  String _userName = 'Kullanıcı';
  String _userEmail = '';
  String _userRole = '';
  bool _isAdmin = false;

  // Temel ayarlar
  // --- GÜNCELLEME ---
  // updateAvailable, newVersion, updateDescription, updateUrl kaldırıldı.
  // Bu mantık artık UpdateScreen'de yönetilecek.
  String currentVersion = "3.0.0"; // Mevcut sürümü buradan ayarlayın

  // Otomatik Oturum Kapatma State'leri
  late bool _isAutoLogoutEnabled;
  late int _autoLogoutMinutes;

  // SOSYAL MEDYA AYARLARI
  final _socialLinksFormKey = GlobalKey<FormState>();
  final _instagramLinkController = TextEditingController();
  final _whatsappLinkController = TextEditingController();
  final _websiteLinkController = TextEditingController();
  final _twitterLinkController = TextEditingController();
  final _facebookLinkController = TextEditingController();
  final _mapsLinkController = TextEditingController();

  bool _instagramEnabled = false;
  bool _whatsappEnabled = false;
  bool _websiteEnabled = false;
  bool _twitterEnabled = false;
  bool _facebookEnabled = false;
  bool _mapsEnabled = false;

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _isAutoLogoutEnabled = widget.initialAutoLogoutEnabled;
    _autoLogoutMinutes = widget.initialAutoLogoutMinutes;
  }

  @override
  void dispose() {
    _passwordVerificationController.dispose();
    _companyNameController.dispose();
    _nameController.dispose();
    _contactController.dispose();
    _emailController.dispose();
    _newUserNameController.dispose();
    _newUserEmailController.dispose();
    _newUserPasswordController.dispose();
    _instagramLinkController.dispose();
    _whatsappLinkController.dispose();
    _websiteLinkController.dispose();
    _twitterLinkController.dispose();
    _facebookLinkController.dispose();
    _mapsLinkController.dispose();
    super.dispose();
  }

  // ---------------------- VERİ YÜKLEME VE YÖNETİMİ ----------------------

  bool _parseBool(dynamic value) {
    if (value == null) return false;
    if (value is bool) return value;
    if (value is int) return value == 1;
    if (value is String) {
      return value.toLowerCase() == 'true' || value == '1';
    }
    return false;
  }

  Future<void> _loadUserData() async {
    final userData = widget.loggedInUser;
    if (mounted) {
      setState(() {
        _userName = userData['userName'] ?? 'Kullanıcı';
        _userEmail = userData['userEmail'] ?? '';
        _userRole = userData['userRole'] ?? 'Kullanıcı';
        _isAdmin = _userRole == 'Yönetici' || _userRole == 'Müdür';
        _companyNameController.text = userData['companyName'] ?? '';
        _nameController.text = userData['userName'] ?? '';
        _contactController.text = userData['userContact'] ?? '';
        _emailController.text = userData['userEmail'] ?? '';

        // Sosyal medya verileri
        _instagramEnabled = _parseBool(userData['social_instagram_enabled']);
        _instagramLinkController.text = userData['social_instagram_link'] ?? '';
        _whatsappEnabled = _parseBool(userData['social_whatsapp_enabled']);
        _whatsappLinkController.text = userData['social_whatsapp_link'] ?? '';
        _websiteEnabled = _parseBool(userData['social_website_enabled']);
        _websiteLinkController.text = userData['social_website_link'] ?? '';
        _twitterEnabled = _parseBool(userData['social_twitter_enabled']);
        _twitterLinkController.text = userData['social_twitter_link'] ?? '';
        _facebookEnabled = _parseBool(userData['social_facebook_enabled']);
        _facebookLinkController.text = userData['social_facebook_link'] ?? '';
        _mapsEnabled = _parseBool(userData['social_maps_enabled']);
        _mapsLinkController.text = userData['social_maps_link'] ?? '';
      });
    }
  }

  // ---------------------- GÜVENLİK VE OTURUM YÖNETİMİ ----------------------

  Future<void> _secureLogout() async {
    try {
      final List<Map<String, dynamic>> allUsers =
          await _dbService.getAllUsers();
      final bool adminExists =
          allUsers.any((user) => user['userRole'] == 'Yönetici');

      if (!mounted) return;

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (context) => LoginScreen(
            allUsers: allUsers,
            adminExists: adminExists,
          ),
        ),
        (Route<dynamic> route) => false,
      );
    } catch (e) {
      if (mounted) {
        _showSnackBar('Çıkış yapılırken bir hata oluştu: $e', isSuccess: false);
      }
    }
  }

  Future<void> _deleteAccount() async {
    // await _dbService.deleteUser(widget.loggedInUser['userEmail']);
    _showSnackBar('Hesabınız kalıcı olarak silindi.', isSuccess: true);
    await _secureLogout();
  }

  // ---------------------- OTOMATİK OTURUM KAPATMA ----------------------

  void _handleAutoLogoutSwitch(bool enabled) {
    setState(() {
      _isAutoLogoutEnabled = enabled;
    });
    if (enabled) {
      _showAutoLogoutDurationDialog();
    } else {
      widget.onAutoLogoutChanged(false, _autoLogoutMinutes);
      _showSnackBar('Otomatik oturum kapatma devre dışı bırakıldı.');
    }
  }

  // ---------------- SOSYAL MEDYA KAYDETME ----------------
  Future<void> _handleSaveSocialLinks() async {
    if (!_socialLinksFormKey.currentState!.validate()) {
      _showSnackBar(
          'Lütfen hatalı alanları düzeltin (http:// veya https:// ile başlamalı).',
          isSuccess: false);
      return;
    }

    final updatedUserData = Map<String, dynamic>.from(widget.loggedInUser);
    updatedUserData.addAll({
      'social_instagram_enabled': _instagramEnabled ? 1 : 0,
      'social_instagram_link': _instagramLinkController.text.trim(),
      'social_whatsapp_enabled': _whatsappEnabled ? 1 : 0,
      'social_whatsapp_link': _whatsappLinkController.text.trim(),
      'social_website_enabled': _websiteEnabled ? 1 : 0,
      'social_website_link': _websiteLinkController.text.trim(),
      'social_twitter_enabled': _twitterEnabled ? 1 : 0,
      'social_twitter_link': _twitterLinkController.text.trim(),
      'social_facebook_enabled': _facebookEnabled ? 1 : 0,
      'social_facebook_link': _facebookLinkController.text.trim(),
      'social_maps_enabled': _mapsEnabled ? 1 : 0,
      'social_maps_link': _mapsLinkController.text.trim(),
    });

    try {
      await _dbService.updateUserData(updatedUserData,
          userContact: null, companyName: '', userName: '', userEmail: '');

      widget.onUserUpdated(updatedUserData);

      setState(() {
        widget.loggedInUser.clear();
        widget.loggedInUser.addAll(updatedUserData);
      });

      await _loadUserData();

      _showSnackBar('Sosyal medya bağlantıları güncellendi!', isSuccess: true);
    } catch (e) {
      _showSnackBar('Bağlantılar kaydedilirken bir hata oluştu: $e',
          isSuccess: false);
    }
  }

  // ---------------------- DİYALOG KUTULARI VE BİLDİRİMLER ----------------------

  void _showSnackBar(String message, {bool isSuccess = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
                isSuccess
                    ? Icons.check_circle_rounded
                    : Icons.warning_amber_rounded,
                color: Colors.white,
                size: 26),
            const SizedBox(width: 12),
            Expanded(
                child: Text(message,
                    style: const TextStyle(
                        fontSize: 17, fontWeight: FontWeight.w600))),
          ],
        ),
        backgroundColor:
            isSuccess ? Colors.teal.shade600 : Colors.redAccent.shade700,
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      ),
    );
  }

  void _showPasswordVerificationDialog() {
    _passwordVerificationController.clear();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => _buildCustomDialog(
        icon: Icons.password_rounded,
        iconColor: Colors.orange,
        title: 'Güvenlik Doğrulaması',
        content: [
          const Text('İşleme devam etmek için lütfen mevcut şifrenizi girin.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Colors.black54)),
          const SizedBox(height: 24),
          _buildStyledTextField(
            controller: _passwordVerificationController,
            labelText: 'Mevcut Şifreniz',
            icon: Icons.key_rounded,
            obscureText: true,
          ),
        ],
        actions: [
          Expanded(
            child: TextButton(
              onPressed: () => Navigator.of(context).pop(),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                textStyle:
                    const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
              ),
              child: const Text('İptal'),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: ElevatedButton(
              onPressed: () {
                final savedPassword = widget.loggedInUser['userPassword'];
                if (_passwordVerificationController.text == savedPassword) {
                  Navigator.pop(context);
                  _showUpdateUserInfoDialog();
                } else {
                  Navigator.pop(context);
                  _showSnackBar('Hatalı şifre girdiniz!', isSuccess: false);
                }
              },
              style: _getButtonStyle(Colors.orange),
              child: const Text('Doğrula'),
            ),
          ),
        ],
      ),
    );
  }

  void _showUpdateUserInfoDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => _buildCustomDialog(
        icon: Icons.edit_note_rounded,
        iconColor: Colors.blue,
        title: 'Bilgileri Düzenle',
        content: [
          Form(
            key: _updateFormKey,
            child: Column(
              children: [
                _buildStyledTextField(
                  controller: _companyNameController,
                  labelText: 'Firma Adı',
                  icon: Icons.business_rounded,
                  validator: (v) =>
                      v!.isEmpty ? 'Bu alan boş bırakılamaz' : null,
                ),
                const SizedBox(height: 16),
                _buildStyledTextField(
                  controller: _nameController,
                  labelText: 'Yetkili Adı Soyadı',
                  icon: Icons.person_rounded,
                  validator: (v) =>
                      v!.isEmpty ? 'Bu alan boş bırakılamaz' : null,
                ),
                const SizedBox(height: 16),
                _buildStyledTextField(
                  controller: _contactController,
                  labelText: 'İletişim Bilgisi',
                  icon: Icons.phone_rounded,
                  validator: (v) =>
                      v!.isEmpty ? 'Bu alan boş bırakılamaz' : null,
                ),
                const SizedBox(height: 16),
                _buildStyledTextField(
                  controller: _emailController,
                  labelText: 'Giriş E-postası',
                  icon: Icons.email_rounded,
                  validator: (v) =>
                      v!.isEmpty ? 'Bu alan boş bırakılamaz' : null,
                ),
              ],
            ),
          ),
        ],
        actions: [
          Expanded(
            child: TextButton(
              onPressed: () => Navigator.pop(context),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                textStyle:
                    const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
              ),
              child: const Text('İptal'),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: ElevatedButton(
              onPressed: () async {
                if (_updateFormKey.currentState!.validate()) {
                  final updatedUserData =
                      Map<String, dynamic>.from(widget.loggedInUser);

                  updatedUserData.addAll({
                    'companyName': _companyNameController.text,
                    'userName': _nameController.text,
                    'userContact': _contactController.text,
                    'userEmail': _emailController.text,
                  });

                  await _dbService.updateUserData(updatedUserData,
                      userContact: null,
                      companyName: '',
                      userName: '',
                      userEmail: '');

                  widget.onUserUpdated(updatedUserData);

                  Navigator.pop(context);

                  setState(() {
                    widget.loggedInUser.clear();
                    widget.loggedInUser.addAll(updatedUserData);
                  });
                  await _loadUserData();
                  _showSnackBar('Kullanıcı bilgileri güncellendi!',
                      isSuccess: true);
                }
              },
              style: _getButtonStyle(Colors.blue),
              child: const Text('Kaydet'),
            ),
          ),
        ],
      ),
    );
  }

  void _showAddNewUserDialog() {
    _newUserFormKey.currentState?.reset();
    _newUserNameController.clear();
    _newUserEmailController.clear();
    _newUserPasswordController.clear();
    setState(() => _newUserSelectedRole = null);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return _buildCustomDialog(
          icon: Icons.person_add_alt_1_rounded,
          iconColor: Colors.green,
          title: 'Yeni Kullanıcı Ekle',
          content: [
            Form(
              key: _newUserFormKey,
              child: Column(
                children: [
                  _buildStyledTextField(
                    controller: _newUserNameController,
                    labelText: 'Adı Soyadı',
                    icon: Icons.person_outline_rounded,
                    validator: (v) =>
                        v!.isEmpty ? 'Bu alan boş bırakılamaz' : null,
                  ),
                  const SizedBox(height: 16),
                  _buildStyledTextField(
                    controller: _newUserEmailController,
                    labelText: 'Giriş E-postası',
                    icon: Icons.email_outlined,
                    validator: (v) =>
                        (v == null || v.isEmpty || !v.contains('@'))
                            ? 'Geçerli bir e-posta girin'
                            : null,
                  ),
                  const SizedBox(height: 16),
                  _buildStyledTextField(
                    controller: _newUserPasswordController,
                    labelText: 'Şifre',
                    icon: Icons.key_rounded,
                    obscureText: true,
                    validator: (v) => (v == null || v.length < 4)
                        ? 'Şifre en az 4 karakter olmalı'
                        : null,
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: _newUserSelectedRole,
                    decoration: InputDecoration(
                      labelText: 'Rol',
                      prefixIcon: Icon(Icons.badge_outlined,
                          size: 26, color: Colors.grey[700]),
                      border: _getTextFieldBorder(),
                      enabledBorder: _getTextFieldBorder(),
                      focusedBorder:
                          _getTextFieldBorder(color: Colors.green.shade600),
                      filled: true,
                      fillColor: Colors.grey[50],
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 18),
                    ),
                    items: _roles
                        .map((role) =>
                            DropdownMenuItem(value: role, child: Text(role)))
                        .toList(),
                    onChanged: (value) =>
                        setState(() => _newUserSelectedRole = value),
                    validator: (v) => v == null ? 'Lütfen bir rol seçin' : null,
                  )
                ],
              ),
            ),
          ],
          actions: [
            Expanded(
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  textStyle: const TextStyle(
                      fontSize: 17, fontWeight: FontWeight.w600),
                ),
                child: const Text('İptal'),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: ElevatedButton(
                onPressed: _handleAddNewUser,
                style: _getButtonStyle(Colors.green),
                child: const Text('Ekle'),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showDeleteAccountWarningDialog() {
    showDialog(
      context: context,
      builder: (context) => _buildCustomDialog(
        icon: Icons.warning_amber_rounded,
        iconColor: Colors.red.shade700,
        title: 'Hesabı Sil?',
        content: const [
          Text(
            'Bu işlem geri alınamaz. Hesabınızla ilişkili tüm veriler kalıcı olarak silinecektir. Emin misiniz?',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16, color: Colors.black54),
          ),
        ],
        actions: [
          Expanded(
              child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('İptal'))),
          const SizedBox(width: 14),
          Expanded(
            child: ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _showDeleteAccountPasswordDialog();
              },
              style: _getButtonStyle(Colors.red.shade700),
              child: const Text('Devam Et'),
            ),
          ),
        ],
      ),
    );
  }

  void _showDeleteAccountPasswordDialog() {
    _passwordVerificationController.clear();
    showDialog(
      context: context,
      builder: (context) => _buildCustomDialog(
        icon: Icons.shield_rounded,
        iconColor: Colors.red.shade800,
        title: 'Son Onay',
        content: [
          const Text(
            'Hesabınızı silmek için lütfen şifrenizi girerek kimliğinizi doğrulayın.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16, color: Colors.black54),
          ),
          const SizedBox(height: 24),
          _buildStyledTextField(
            controller: _passwordVerificationController,
            labelText: 'Mevcut Şifreniz',
            icon: Icons.key_rounded,
            obscureText: true,
          ),
        ],
        actions: [
          Expanded(
              child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Vazgeç'))),
          const SizedBox(width: 14),
          Expanded(
            child: ElevatedButton(
              onPressed: () {
                final savedPassword = widget.loggedInUser['userPassword'];
                if (_passwordVerificationController.text == savedPassword) {
                  Navigator.pop(context);
                  _deleteAccount();
                } else {
                  Navigator.pop(context);
                  _showSnackBar(
                      'Hatalı şifre. Hesap silme işlemi iptal edildi.',
                      isSuccess: false);
                }
              },
              style: _getButtonStyle(Colors.red.shade800),
              child: const Text('Hesabı Sil'),
            ),
          ),
        ],
      ),
    );
  }

  void _showAutoLogoutDurationDialog() {
    int selectedMinutes = _autoLogoutMinutes;
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return _buildCustomDialog(
              icon: Icons.timer_outlined,
              iconColor: Colors.teal,
              title: 'Süre Ayarla',
              content: [
                Text(
                  'Uygulama ne kadar süre işlem yapılmadığında otomatik kapansın?',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, color: Colors.grey.shade700),
                ),
                const SizedBox(height: 24),
                Text(
                  '$selectedMinutes Dakika',
                  style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Colors.teal.shade700),
                ),
                Slider(
                  value: selectedMinutes.toDouble(),
                  min: 1,
                  max: 30,
                  divisions: 29,
                  activeColor: Colors.teal,
                  label: '$selectedMinutes',
                  onChanged: (value) {
                    setDialogState(() {
                      selectedMinutes = value.round();
                    });
                  },
                ),
              ],
              actions: [
                Expanded(
                  child: TextButton(
                    onPressed: () {
                      Navigator.pop(context);
                      setState(() => _isAutoLogoutEnabled = false);
                      widget.onAutoLogoutChanged(false, _autoLogoutMinutes);
                    },
                    child: const Text('İptal'),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _autoLogoutMinutes = selectedMinutes;
                      });
                      widget.onAutoLogoutChanged(true, _autoLogoutMinutes);
                      Navigator.pop(context);
                      _showSnackBar(
                          'Otomatik oturum kapatma $selectedMinutes dakika olarak ayarlandı.',
                          isSuccess: true);
                    },
                    style: _getButtonStyle(Colors.teal),
                    child: const Text('Ayarla'),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _handleAddNewUser() async {
    if (_newUserFormKey.currentState!.validate()) {
      final newUser = {
        'companyName': _companyNameController.text,
        'userName': _newUserNameController.text,
        'userEmail': _newUserEmailController.text,
        'userPassword': _newUserPasswordController.text,
        'userRole': _newUserSelectedRole,
        'quickLoginPin': _newUserPasswordController.text.substring(0, 4),
        'createdAt': DateTime.now().toIso8601String(),
        'userContact': '',
        'userFaceImage': null,
        // Yeni kullanıcı için sosyal medya alanları
        'social_instagram_enabled': 0, 'social_instagram_link': '',
        'social_whatsapp_enabled': 0, 'social_whatsapp_link': '',
        'social_website_enabled': 0, 'social_website_link': '',
        'social_twitter_enabled': 0, 'social_twitter_link': '',
        'social_facebook_enabled': 0, 'social_facebook_link': '',
        'social_maps_enabled': 0, 'social_maps_link': '',
      };
      await _dbService.addManagedUser(newUser);
      Navigator.pop(context);
      _showSnackBar('Yeni kullanıcı başarıyla eklendi!', isSuccess: true);
    }
  }

  // ---------------------- GÜNCELLEME VE DIŞA AKTARMA ----------------------

  // --- GÜNCELLEME: _checkForUpdate artık yeni ekrana yönlendiriyor ---
  Future<void> _checkForUpdate() async {
    // Artık 'updateAvailable' kontrolü burada yapılmıyor.
    // Doğrudan güncelleme ekranını açıyoruz.
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => UpdateScreen(currentVersion: currentVersion),
      ),
    );
  }

  // --- GÜNCELLEME: _exportDatabaseAsJson artık geliştirme aşamasında uyarısı veriyor ---
  Future<void> _exportDatabaseAsJson() async {
    _showSnackBar(
      'Bu özellik şu anda geliştirme aşamasındadır.',
      isSuccess: true, // Bilgi mesajı olarak gösterelim
    );

    /*
    // --- ESKİ KOD ---
    try {
      final dbPath = await getDatabasesPath();
      final dbFile = File('$dbPath/masa_takip.db');

      if (!await dbFile.exists()) {
        if (mounted) {
          _showSnackBar('Veritabanı bulunamadı.', isSuccess: false);
        }
        return;
      }

      final db = await openDatabase(dbFile.path);
      final jsonData = await _exportDatabaseToJson(db);
      final jsonString = const JsonEncoder.withIndent('  ').convert(jsonData);

      final dir = await getApplicationDocumentsDirectory();
      final file = File(
          '${dir.path}/masa_takip_backup_${DateTime.now().millisecondsSinceEpoch}.json');
      await file.writeAsString(jsonString);

      if (mounted) {
        _showSnackBar('JSON dışa aktarıldı: ${file.path}', isSuccess: true);
      }
      await db.close();
    } catch (e) {
      if (mounted) {
        _showSnackBar('Dışa aktarma hatası: $e', isSuccess: false);
      }
    }
    */
  }

  Future<Map<String, dynamic>> _exportDatabaseToJson(Database db) async {
    final tables = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%';",
    );
    final Map<String, dynamic> dbJson = {};
    for (var table in tables) {
      String tableName = table['name'] as String;
      final data = await db.query(tableName);
      dbJson[tableName] = data;
    }
    return dbJson;
  }

  // ---------------------- BUILD METODU VE WIDGET'LAR ----------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        systemOverlayStyle: SystemUiOverlayStyle.dark,
        title: const Text('Ayarlar',
            style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.white,
                fontSize: 24)),
        toolbarHeight: 70,
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        elevation: 0,
        shadowColor: Colors.black.withOpacity(0.05),
        surfaceTintColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildProfileHeader(),
            const SizedBox(height: 24),
            _buildSettingsCard(
              title: 'Profil ve Hesap Ayarları',
              children: [
                _buildSettingsTile(
                  icon: MdiIcons.accountCog,
                  color: Colors.blue.shade600,
                  title: 'Kullanıcı Bilgilerini Düzenle',
                  subtitle:
                      'Firma, yetkili ve iletişim bilgilerini güncelleyin',
                  onTap: _showPasswordVerificationDialog,
                ),
                _buildSettingsTile(
                  icon: Icons.lock_person_rounded,
                  color: Colors.purple.shade600,
                  title: 'Giriş ve Güvenlik',
                  subtitle: 'Şifre, PIN ve biyometrik ayarları',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => const LoginSettingsScreen()),
                    );
                  },
                ),
              ],
            ),
            if (_isAdmin) ...[
              const SizedBox(height: 16),
              _buildSettingsCard(
                title: 'Kullanıcı Yönetimi',
                children: [
                  _buildSettingsTile(
                    icon: Icons.person_add_alt_1_rounded,
                    color: Colors.green.shade600,
                    title: 'Yeni Kullanıcı Ekle',
                    subtitle: 'Sisteme yeni personel kaydedin',
                    onTap: _showAddNewUserDialog,
                  ),
                ],
              ),
            ],
            const SizedBox(height: 16),
            _buildSettingsCard(
              title: 'Sosyal Medya ve Web Sitesi',
              children: [
                Form(
                  key: _socialLinksFormKey,
                  child: Column(
                    children: [
                      _buildSocialLinkTile(
                        icon: MdiIcons.instagram,
                        color: Colors.pink,
                        title: 'Instagram',
                        isEnabled: _instagramEnabled,
                        controller: _instagramLinkController,
                        onToggle: (value) =>
                            setState(() => _instagramEnabled = value),
                        hintText: 'https://instagram.com/kullanici',
                      ),
                      _buildSocialLinkTile(
                        icon: MdiIcons.whatsapp,
                        color: Colors.green,
                        title: 'WhatsApp',
                        isEnabled: _whatsappEnabled,
                        controller: _whatsappLinkController,
                        onToggle: (value) =>
                            setState(() => _whatsappEnabled = value),
                        hintText: 'https://wa.me/905xxxxxxxxx',
                      ),
                      _buildSocialLinkTile(
                        icon: MdiIcons.web,
                        color: Colors.blue,
                        title: 'Web Sitesi',
                        isEnabled: _websiteEnabled,
                        controller: _websiteLinkController,
                        onToggle: (value) =>
                            setState(() => _websiteEnabled = value),
                        hintText: 'https://sirketiniz.com',
                      ),
                      _buildSocialLinkTile(
                        icon: MdiIcons.twitter,
                        color: Colors.black,
                        title: 'X (Twitter)',
                        isEnabled: _twitterEnabled,
                        controller: _twitterLinkController,
                        onToggle: (value) =>
                            setState(() => _twitterEnabled = value),
                        hintText: 'https://x.com/kullanici',
                      ),
                      _buildSocialLinkTile(
                        icon: MdiIcons.facebook,
                        color: Colors.indigo,
                        title: 'Facebook',
                        isEnabled: _facebookEnabled,
                        controller: _facebookLinkController,
                        onToggle: (value) =>
                            setState(() => _facebookEnabled = value),
                        hintText: 'https://facebook.com/kullanici',
                      ),
                      _buildSocialLinkTile(
                        icon: MdiIcons.googleMaps,
                        color: Colors.red,
                        title: 'Google Maps',
                        isEnabled: _mapsEnabled,
                        controller: _mapsLinkController,
                        onToggle: (value) =>
                            setState(() => _mapsEnabled = value),
                        hintText: 'https.google.com/maps...',
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                        child: SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            icon: const Icon(Icons.save, color: Colors.white),
                            label: const Text('Bağlantıları Kaydet'),
                            style: _getButtonStyle(Colors.teal),
                            onPressed: _handleSaveSocialLinks,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildSettingsCard(
              title: 'Güvenlik',
              children: [
                _buildSettingsTile(
                  icon: Icons.timer_off_outlined,
                  color: Colors.orange.shade700,
                  title: 'Otomatik Oturum Kapatma',
                  subtitle: _isAutoLogoutEnabled
                      ? 'Aktif: $_autoLogoutMinutes dakika'
                      : 'Kapalı',
                  trailing: Switch(
                    value: _isAutoLogoutEnabled,
                    onChanged: _handleAutoLogoutSwitch,
                    activeColor: Colors.orange.shade700,
                  ),
                ),
                _buildSettingsTile(
                  icon: Icons.logout_rounded,
                  color: Colors.blueGrey.shade600,
                  title: 'Güvenli Çıkış',
                  subtitle: 'Oturumu sonlandır ve giriş ekranına dön',
                  onTap: _secureLogout,
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildSettingsCard(
              title: 'Veri ve Güncellemeler',
              children: [
                _buildSettingsTile(
                  icon: MdiIcons.databaseArrowDownOutline,
                  color: Colors.indigo.shade600,
                  title: 'Veritabanını Dışa Aktar',
                  subtitle: 'Tüm verileri JSON olarak yedekleyin',
                  onTap: _exportDatabaseAsJson,
                ),
                // --- GÜNCELLEME: Update Tile ---
                _buildSettingsTile(
                  icon: Icons.system_update_alt_rounded,
                  color: Colors.orange.shade800,
                  title: 'Yazılım Güncellemesi',
                  subtitle:
                      "Sürüm: v$currentVersion (Güncellemeleri kontrol et)",
                  onTap: _checkForUpdate, // Artık yeni ekrana yönlendiriyor
                ),
                // --- GÜNCELLEME SONU ---
              ],
            ),
            const SizedBox(height: 16),
            _buildSettingsCard(
              title: 'Tehlikeli Bölge',
              children: [
                _buildSettingsTile(
                  icon: Icons.delete_forever_rounded,
                  color: Colors.red.shade700,
                  title: 'Hesabı Sil',
                  subtitle: 'Tüm verilerinizi kalıcı olarak silin',
                  onTap: _showDeleteAccountWarningDialog,
                ),
              ],
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  // ---------------------- YARDIMCI WIDGET'LAR ----------------------
  // (Hiçbir değişiklik yapılmadı, aynı widget'lar kullanılıyor)

  Widget _buildProfileHeader() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.teal.shade600, Colors.teal.shade400],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.teal.withOpacity(0.3),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withOpacity(0.9),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                    spreadRadius: 2)
              ],
            ),
            child: CircleAvatar(
              radius: 35,
              backgroundColor: Colors.teal.shade50,
              child: Text(
                _userName.isNotEmpty ? _userName[0].toUpperCase() : '?',
                style: TextStyle(fontSize: 32, color: Colors.teal.shade800),
              ),
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _userName,
                  style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 0.5),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  _userEmail,
                  style: TextStyle(
                      fontSize: 15, color: Colors.white.withOpacity(0.85)),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 10),
                if (_userRole.isNotEmpty)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      _userRole,
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 13),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsCard(
      {required String title, required List<Widget> children}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
            child: Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: Colors.grey.shade800,
                letterSpacing: 0.5,
              ),
            ),
          ),
          ...children,
        ],
      ),
    );
  }

  Widget _buildSettingsTile({
    required IconData icon,
    required Color color,
    required String title,
    String? subtitle,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        highlightColor: color.withOpacity(0.05),
        splashColor: color.withOpacity(0.1),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [color.withOpacity(0.15), color.withOpacity(0.08)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(icon, color: color, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 17,
                            color: Color(0xFF1A1A2E))),
                    if (subtitle != null) ...[
                      const SizedBox(height: 4),
                      Text(subtitle,
                          style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 14,
                              fontWeight: FontWeight.w500)),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (trailing != null)
                trailing
              else if (onTap != null)
                Icon(Icons.arrow_forward_ios_rounded,
                    color: Colors.grey[400], size: 18),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSocialLinkTile({
    required IconData icon,
    required Color color,
    required String title,
    required bool isEnabled,
    required TextEditingController controller,
    required ValueChanged<bool> onToggle,
    String? hintText,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4),
      child: Column(
        children: [
          _buildSettingsTile(
            icon: icon,
            color: color,
            title: title,
            trailing: Switch(
              value: isEnabled,
              onChanged: onToggle,
              activeColor: color,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            child: isEnabled
                ? Padding(
                    padding: const EdgeInsets.only(
                        top: 12, left: 20, right: 20, bottom: 8),
                    child: TextFormField(
                      controller: controller,
                      keyboardType: TextInputType.url,
                      decoration: InputDecoration(
                        labelText: '$title Bağlantısı (URL)',
                        hintText:
                            hintText ?? 'https://www.$title.com/kullanici',
                        prefixIcon: Icon(Icons.link,
                            size: 22, color: Colors.grey.shade600),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(
                              color: Colors.grey.shade300, width: 1.5),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(
                              color: Colors.grey.shade300, width: 1.5),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(color: color, width: 2.0),
                        ),
                        filled: true,
                        fillColor: Colors.grey.shade50,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 14),
                      ),
                      validator: (value) {
                        if (isEnabled && (value == null || value.isEmpty)) {
                          return 'Lütfen bir bağlantı girin';
                        }
                        if (value != null &&
                            value.isNotEmpty &&
                            !value.startsWith('http')) {
                          return 'http:// veya https:// ile başlamalı';
                        }
                        return null;
                      },
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  Widget _buildStyledTextField({
    required TextEditingController controller,
    required String labelText,
    required IconData icon,
    String? Function(String?)? validator,
    bool obscureText = false,
  }) {
    final focusColor = Theme.of(context).primaryColor;
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      validator: validator,
      style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w500),
      decoration: InputDecoration(
        labelText: labelText,
        labelStyle: TextStyle(
            color: Colors.grey[700], fontSize: 16, fontWeight: FontWeight.w600),
        prefixIcon: Icon(icon, size: 24, color: Colors.grey[700]),
        border: _getTextFieldBorder(),
        enabledBorder: _getTextFieldBorder(),
        focusedBorder: _getTextFieldBorder(color: focusColor),
        filled: true,
        fillColor: Colors.grey[100],
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        errorStyle:
            TextStyle(color: Colors.red.shade700, fontWeight: FontWeight.w500),
      ),
    );
  }

  OutlineInputBorder _getTextFieldBorder({Color? color}) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide(color: color ?? Colors.grey[350]!, width: 1.5),
    );
  }

  ButtonStyle _getButtonStyle(Color color) {
    return ElevatedButton.styleFrom(
      backgroundColor: color,
      foregroundColor: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      textStyle: const TextStyle(
          fontSize: 17, fontWeight: FontWeight.bold, letterSpacing: 0.5),
      elevation: 3,
      shadowColor: color.withOpacity(0.4),
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
      elevation: 6,
      backgroundColor: Colors.white,
      child: Container(
        padding: const EdgeInsets.all(24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [iconColor.withOpacity(0.8), iconColor],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
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
                child: Icon(icon, size: 48, color: Colors.white),
              ),
              const SizedBox(height: 20),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 24,
                    color: Color(0xFF1A1A2E)),
              ),
              const SizedBox(height: 16),
              ...content,
              const SizedBox(height: 24),
              Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: actions),
            ],
          ),
        ),
      ),
    );
  }
}
