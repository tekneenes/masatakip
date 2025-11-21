import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Bu servis, hem güvenli depolama (hassas veriler için) hem de
/// paylaşılan tercihleri (hassas olmayan bayraklar için) yönetir.
/// GÜNCELLENDİ: Artık yönetici tarafından eklenen kullanıcıları da yönetmektedir.
class DatabaseService {
  final _secureStorage = const FlutterSecureStorage();
  static const _isRegisteredKey = 'isRegistered';
  static const _adminExistsKey = 'hasAdmin';
  static const _verificationCodeKey = 'verificationCode';
  static const _managedUsersKey = 'managedUsers';

  // ... (isRegistered, hasAdmin, saveUserData vb. metotlar aynı kalacak) ...
  /// Kullanıcının kayıtlı olup olmadığını basitçe kontrol etmek için
  /// SharedPreferences kullanır.
  Future<void> _setRegistered(bool isRegistered) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_isRegisteredKey, isRegistered);
  }

  Future<bool> isRegistered() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_isRegisteredKey) ?? false;
  }

  // Sistemde bir yönetici kaydı olup olmadığını kontrol eder.
  Future<bool> hasAdmin() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_adminExistsKey) ?? false;
  }

  /// Tüm kullanıcı verilerini güvenli bir şekilde kaydeder.
  Future<void> saveUserData({
    required String companyName,
    required String userName,
    required String userContact,
    required String userEmail,
    required String userPassword,
    required String quickLoginPin,
    required String userRole,
    String? userFaceImage,
    required String termsAcceptedOn,
  }) async {
    await _secureStorage.write(key: 'companyName', value: companyName);
    await _secureStorage.write(key: 'userName', value: userName);
    await _secureStorage.write(key: 'userContact', value: userContact);
    await _secureStorage.write(key: 'userEmail', value: userEmail);
    await _secureStorage.write(key: 'userPassword', value: userPassword);
    await _secureStorage.write(key: 'quickLoginPin', value: quickLoginPin);
    await _secureStorage.write(key: 'userRole', value: userRole);
    await _secureStorage.write(key: 'termsAcceptedOn', value: termsAcceptedOn);

    if (userFaceImage != null) {
      await _secureStorage.write(key: 'userFaceImage', value: userFaceImage);
    }

    // YENİ: Sosyal medya alanları için varsayılan değerleri kaydet
    // (FlutterSecureStorage sadece string kabul ettiği için '0' kullanıyoruz)
    await _secureStorage.write(key: 'social_instagram_enabled', value: '0');
    await _secureStorage.write(key: 'social_instagram_link', value: '');
    await _secureStorage.write(key: 'social_whatsapp_enabled', value: '0');
    await _secureStorage.write(key: 'social_whatsapp_link', value: '');
    await _secureStorage.write(key: 'social_website_enabled', value: '0');
    await _secureStorage.write(key: 'social_website_link', value: '');
    await _secureStorage.write(key: 'social_twitter_enabled', value: '0');
    await _secureStorage.write(key: 'social_twitter_link', value: '');
    await _secureStorage.write(key: 'social_facebook_enabled', value: '0');
    await _secureStorage.write(key: 'social_facebook_link', value: '');
    await _secureStorage.write(key: 'social_maps_enabled', value: '0');
    await _secureStorage.write(key: 'social_maps_link', value: '');
    // YENİ EKLEME SONU

    if (userRole == 'Yönetici') {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_adminExistsKey, true);
    }
    await _setRegistered(true);
  }

  /// Belirtilen anahtara sahip tek bir değeri güvenli depolamadan okur.
  Future<String?> readValue(String key) async {
    return await _secureStorage.read(key: key);
  }

  /// Güvenli depolamadaki tüm kullanıcı verilerini okur.
  Future<Map<String, String>> readAllUserData() async {
    return await _secureStorage.readAll();
  }

  // !!!!! ÖNEMLİ DÜZELTME BURADA !!!!!
  // Bu fonksiyon artık map'teki TÜM verileri depolamaya yazar.
  Future<void> updateUserData(Map<String, dynamic> updatedUser,
      {required userContact,
      required String companyName,
      required String userName,
      required String userEmail}) async {
    // updatedUser map'indeki tüm anahtar/değer çiftlerini
    // güvenli depolamaya yaz.
    for (var entry in updatedUser.entries) {
      // Değer null değilse ve anahtar boş değilse
      if (entry.key.isNotEmpty && entry.value != null) {
        // FlutterSecureStorage SADECE String kabul eder.
        // Gelen değer int (1/0) veya String olabilir, bu yüzden
        // .toString() ile string'e çevirip kaydediyoruz.
        await _secureStorage.write(
          key: entry.key,
          value: entry.value.toString(),
        );
      }
    }
  }
  // !!!!! DÜZELTME SONU !!!!!

  Future<void> updatePassword(String newPassword, String newPin) async {
    await _secureStorage.write(key: 'userPassword', value: newPassword);
    await _secureStorage.write(key: 'quickLoginPin', value: newPin);
  }

  Future<void> setVerificationCode(String code) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_verificationCodeKey, code);
  }

  Future<String?> getVerificationCode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_verificationCodeKey);
  }

  /// Cihazdaki tüm kullanıcı verilerini temizler.
  Future<void> clearAllData() async {
    await _secureStorage.deleteAll();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_isRegisteredKey);
    await prefs.remove(_verificationCodeKey);
    await prefs.remove(_adminExistsKey);
  }

  // Yönetici tarafından eklenen yeni bir kullanıcıyı listeye ekler.
  Future<void> addManagedUser(Map<String, dynamic> newUser) async {
    final existingUsers = await getManagedUsers();
    existingUsers.add(newUser);
    final usersJson = jsonEncode(existingUsers);
    await _secureStorage.write(key: _managedUsersKey, value: usersJson);
  }

  // Yönetici tarafından eklenen tüm kullanıcıların listesini getirir.
  Future<List<Map<String, dynamic>>> getManagedUsers() async {
    final usersJson = await _secureStorage.read(key: _managedUsersKey);
    if (usersJson != null && usersJson.isNotEmpty) {
      final List<dynamic> decodedList = jsonDecode(usersJson);
      return decodedList.map((item) => item as Map<String, dynamic>).toList();
    }
    return [];
  }

  // YENİ: Hem ana kullanıcıyı (yönetici) hem de diğer kullanıcıları birleşik bir liste olarak döndürür.
  Future<List<Map<String, dynamic>>> getAllUsers() async {
    List<Map<String, dynamic>> allUsers = [];

    // 1. Ana kullanıcıyı (genellikle yönetici) al
    final mainUserData = await readAllUserData();
    if (mainUserData.isNotEmpty && mainUserData.containsKey('userEmail')) {
      // Diğer kullanıcılarla aynı formatta olması için Map'i dönüştür
      allUsers.add(Map<String, dynamic>.from(mainUserData));
    }

    // 2. Yönetici tarafından eklenen diğer kullanıcıları al
    final managedUsers = await getManagedUsers();
    allUsers.addAll(managedUsers);

    return allUsers;
  }
}
