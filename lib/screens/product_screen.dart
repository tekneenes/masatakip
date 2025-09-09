// lib/screens/product_screen.dart
import '../providers/daily_revenue_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../models/product_model.dart';
import '../providers/product_provider.dart';

class ProductScreen extends StatefulWidget {
  const ProductScreen({super.key});

  @override
  State<ProductScreen> createState() => _ProductScreenState();
}

class _ProductScreenState extends State<ProductScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();

  // Ürün ekleme veya düzenleme dialog'u
  void _showAddEditProductDialog({ProductModel? product}) {
    _nameController.text = product?.name ?? '';
    _priceController.text = product?.price.toStringAsFixed(2) ?? '';
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(product == null ? 'Ürün Ekle' : 'Ürün Düzenle'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(hintText: 'Ürün Adı'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _priceController,
                keyboardType: TextInputType.number,
                decoration:
                    const InputDecoration(hintText: 'Fiyat (örn: 12.50)'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _nameController.clear();
                _priceController.clear();
              },
              child: const Text('İptal'),
            ),
            ElevatedButton(
              onPressed: () {
                final name = _nameController.text;
                final price = double.tryParse(_priceController.text);
                if (name.isNotEmpty && price != null && price > 0) {
                  if (product == null) {
                    Provider.of<ProductProvider>(context, listen: false)
                        .addProduct(name, price);
                  } else {
                    product.name = name;
                    product.price = price;
                    Provider.of<ProductProvider>(context, listen: false)
                        .updateProduct(product);
                  }
                  Navigator.of(context).pop();
                  _nameController.clear();
                  _priceController.clear();
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content:
                            Text('Lütfen geçerli ürün adı ve fiyatı girin.')),
                  );
                }
              },
              child: Text(product == null ? 'Ekle' : 'Güncelle'),
            ),
          ],
        );
      },
    );
  }

  void _showDeleteConfirmationDialog(
      BuildContext context, ProductModel product) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Ürün Silme Onayı'),
          content: Text(
              '${product.name} ürününü silmek istediğinizden emin misiniz?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('İptal'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () {
                Provider.of<ProductProvider>(context, listen: false)
                    .deleteProduct(product.id);
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('${product.name} ürünü silindi.')),
                );
              },
              child: const Text('Sil', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ürün Yönetimi'),
        backgroundColor: Colors.blueGrey[800],
        foregroundColor: Colors.white,
      ),
      body: Consumer<ProductProvider>(
        builder: (context, productProvider, child) {
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: ElevatedButton.icon(
                  onPressed: () => _showAddEditProductDialog(),
                  icon:
                      const Icon(Icons.add_shopping_cart, color: Colors.white),
                  label: const Text('Yeni Ürün Ekle',
                      style: TextStyle(color: Colors.white)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    minimumSize: const Size(
                        double.infinity, 50), // Butonun genişliğini tam yap
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
              Expanded(
                child: productProvider.products.isEmpty
                    ? const Center(
                        child: Text('Henüz ürün eklenmedi.',
                            style:
                                TextStyle(fontSize: 18, color: Colors.black54)))
                    : ListView.builder(
                        padding: const EdgeInsets.all(8.0),
                        itemCount: productProvider.products.length,
                        itemBuilder: (context, index) {
                          final product = productProvider.products[index];
                          return Card(
                            margin: const EdgeInsets.symmetric(vertical: 6.0),
                            elevation: 3,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16.0, vertical: 8.0),
                              leading: CircleAvatar(
                                backgroundColor: Colors.blueGrey[100],
                                child: Text(
                                  product.name[0].toUpperCase(),
                                  style: TextStyle(
                                      color: Colors.blueGrey[800],
                                      fontWeight: FontWeight.bold),
                                ),
                              ),
                              title: Text(
                                product.name,
                                style: const TextStyle(
                                    fontSize: 18, fontWeight: FontWeight.bold),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    NumberFormat.currency(
                                            locale: 'tr_TR', symbol: '₺')
                                        .format(product.price),
                                    style: const TextStyle(
                                        fontSize: 16, color: Colors.green),
                                  ),
                                  Text(
                                    'Satış Sayısı: ${product.salesCount}',
                                    style: const TextStyle(
                                        fontSize: 14, color: Colors.grey),
                                  ),
                                ],
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.edit,
                                        color: Colors.orange),
                                    onPressed: () => _showAddEditProductDialog(
                                        product: product),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete,
                                        color: Colors.red),
                                    onPressed: () =>
                                        _showDeleteConfirmationDialog(
                                            context, product),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}
