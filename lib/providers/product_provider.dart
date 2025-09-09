import 'package:flutter/material.dart';
import 'package:masa_takip_sistemi/models/product_model.dart';
import 'package:masa_takip_sistemi/services/database_helper.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

class ProductProvider with ChangeNotifier {
  List<ProductModel> _products = [];
  String? _fixedProductId;
  bool _showTopSelling = false;

  List<ProductModel> get products => _products;
  String? get fixedProductId => _fixedProductId;
  bool get showTopSelling => _showTopSelling;

  final DatabaseHelper _dbHelper = DatabaseHelper.instance;
  final Uuid _uuid = const Uuid();

  ProductProvider() {
    loadProducts();
    _loadSettings();
  }
  Future<void> loadProducts() async {
    _products = await _dbHelper.getProducts();
    _products.sort((a, b) => b.salesCount.compareTo(a.salesCount));
    notifyListeners();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    _fixedProductId = prefs.getString('fixedProductId');
    _showTopSelling = prefs.getBool('showTopSelling') ?? false;
    notifyListeners();
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    if (_fixedProductId != null) {
      await prefs.setString('fixedProductId', _fixedProductId!);
    } else {
      await prefs.remove('fixedProductId');
    }
    await prefs.setBool('showTopSelling', _showTopSelling);
  }

  Future<void> addProduct(String name, double price) async {
    final newProduct = ProductModel(id: _uuid.v4(), name: name, price: price);
    await _dbHelper.insertProduct(newProduct);
    await loadProducts();
  }

  Future<void> updateProduct(ProductModel product) async {
    await _dbHelper.updateProduct(product);
    await loadProducts();
  }

  Future<void> deleteProduct(String id) async {
    if (_fixedProductId == id) {
      _fixedProductId = null;
      _saveSettings();
    }
    await _dbHelper.deleteProduct(id);
    await loadProducts();
  }

  Future<void> incrementProductSalesCount(
      String productId, int quantity) async {
    ProductModel product = _products.firstWhere((p) => p.id == productId);
    product.salesCount += quantity;
    await _dbHelper.updateProduct(product);
    await loadProducts();
  }

  void toggleFixedProduct(String productId) {
    if (_fixedProductId == productId) {
      _fixedProductId = null;
    } else {
      _fixedProductId = productId;
    }
    _saveSettings();
    notifyListeners();
  }

  void toggleShowTopSelling() {
    _showTopSelling = !_showTopSelling;
    _saveSettings();
    notifyListeners();
  }

  List<ProductModel> get productsForTableSelection {
    List<ProductModel> displayedProducts = List.from(_products);

    if (_fixedProductId != null) {
      ProductModel? fixedProduct = displayedProducts.firstWhere(
        (p) => p.id == _fixedProductId,
        orElse: () => ProductModel(id: '', name: 'Not Found', price: 0.0),
      );
      if (fixedProduct.id != '') {
        displayedProducts.removeWhere((p) => p.id == _fixedProductId);
        displayedProducts.insert(0, fixedProduct);
      }
    }

    if (_showTopSelling) {
      List<ProductModel> topSelling = displayedProducts
          .where((p) => p.id != _fixedProductId)
          .take(5)
          .toList();

      if (_fixedProductId != null &&
          displayedProducts.isNotEmpty &&
          displayedProducts[0].id == _fixedProductId) {
        for (int i = 0; i < topSelling.length; i++) {
          if (!displayedProducts.contains(topSelling[i])) {
            displayedProducts.insert(1 + i, topSelling[i]);
          }
        }
      } else {
        for (int i = 0; i < topSelling.length; i++) {
          if (!displayedProducts.contains(topSelling[i])) {
            displayedProducts.insert(i, topSelling[i]);
          }
        }
      }
    }
    return displayedProducts;
  }
}
