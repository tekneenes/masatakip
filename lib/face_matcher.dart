import 'dart:typed_data';
import 'dart:convert';
import 'package:image/image.dart' as img;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'dart:ui';

class FaceMatcher {
  static const _storageKey = 'face_hashes_v1';

  Future<Map<String, List<String>>> _readStorage() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    if (raw == null) return {};
    final Map parsed = jsonDecode(raw);
    return parsed.map((k, v) => MapEntry(k as String, List<String>.from(v)));
  }

  Future<void> _writeStorage(Map<String, List<String>> data) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_storageKey, jsonEncode(data));
  }

  Uint8List _cropAndResizeFace(Uint8List imageBytes, Rect box,
      {int size = 64}) {
    final image = img.decodeImage(imageBytes);
    if (image == null) throw Exception('Image decode failed');

    final x = box.left.toInt().clamp(0, image.width - 1);
    final y = box.top.toInt().clamp(0, image.height - 1);
    final w = box.width.toInt().clamp(1, image.width - x);
    final h = box.height.toInt().clamp(1, image.height - y);

    final face = img.copyCrop(image, x: x, y: y, width: w, height: h);
    final resized = img.copyResize(face, width: size, height: size);
    final gray = img.grayscale(resized);
    return Uint8List.fromList(img.encodePng(gray));
  }

  String _aHashFromGrayImage(img.Image gray) {
    final small = img.copyResize(gray,
        width: 8, height: 8, interpolation: img.Interpolation.average);
    int sum = 0;
    List<int> pixels = [];

    for (int y = 0; y < 8; y++) {
      for (int x = 0; x < 8; x++) {
        final pixel = small.getPixel(x, y);
        final int r =
            pixel.r.toInt(); // yeni Pixel API: pixel.r, pixel.g, pixel.b
        pixels.add(r);
        sum += r;
      }
    }

    final int avg = (sum / pixels.length).round();
    int hash = 0;
    for (int i = 0; i < pixels.length; i++) {
      if (pixels[i] >= avg) hash |= (1 << i);
    }

    return hash.toRadixString(16).padLeft(16, '0');
  }

  int _hammingDistance(String hex1, String hex2) {
    final a = BigInt.parse(hex1, radix: 16);
    final b = BigInt.parse(hex2, radix: 16);
    final x = a ^ b;
    final bits = x.toRadixString(2);
    return bits.replaceAll('0', '').length;
  }

  Future<bool> registerFaceFromImage(
      Uint8List imageBytes, Face face, String name) async {
    try {
      final cropped =
          _cropAndResizeFace(imageBytes, face.boundingBox, size: 64);
      final image = img.decodePng(cropped)!;
      final hash = _aHashFromGrayImage(image);

      final storage = await _readStorage();
      final list = storage[name] ?? [];
      list.add(hash);
      storage[name] = list;
      await _writeStorage(storage);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<String?> matchFaceFromImage(Uint8List imageBytes, Face face,
      {int threshold = 12}) async {
    try {
      final cropped =
          _cropAndResizeFace(imageBytes, face.boundingBox, size: 64);
      final image = img.decodePng(cropped)!;
      final hash = _aHashFromGrayImage(image);

      final storage = await _readStorage();
      String? bestName;
      int bestScore = 999;
      storage.forEach((name, hashes) {
        for (var h in hashes) {
          final d = _hammingDistance(hash, h);
          if (d < bestScore) {
            bestScore = d;
            bestName = name;
          }
        }
      });

      if (bestName != null && bestScore <= threshold) {
        return bestName;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<void> removeUser(String name) async {
    final storage = await _readStorage();
    if (storage.containsKey(name)) {
      storage.remove(name);
      await _writeStorage(storage);
    }
  }

  Future<List<String>> listUsers() async {
    final storage = await _readStorage();
    return storage.keys.toList();
  }
}
