// lib/models/product_model.dart
class ProductModel {
  String id;
  String name;
  double price;
  int salesCount; // En çok satanlar için satış sayısı

  ProductModel({
    required this.id,
    required this.name,
    required this.price,
    this.salesCount = 0,
  });

  // Veritabanından gelen Map'i ProductModel'e dönüştürür
  factory ProductModel.fromMap(Map<String, dynamic> map) {
    return ProductModel(
      id: map['id'],
      name: map['name'],
      price: map['price'],
      salesCount: map['salesCount'] ?? 0,
    );
  }

  // ProductModel'i veritabanına kaydetmek için Map'e dönüştürür
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'price': price,
      'salesCount': salesCount,
    };
  }
}