import 'dart:async';
import 'package:masa_takip_sistemi/models/order_item_model.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../models/table_model.dart';
import '../providers/table_provider.dart';
import '../providers/product_provider.dart';

class TableDetailScreen extends StatefulWidget {
  final String tableId; // Artık sadece masa ID'sini alıyoruz
  const TableDetailScreen({super.key, required this.tableId});

  @override
  State<TableDetailScreen> createState() => _TableDetailScreenState();
}

class _TableDetailScreenState extends State<TableDetailScreen> {
  Timer? _timer;
  Duration _elapsedTime = Duration.zero;

  // Masa verisi için yerel state, Consumer ile güncel tutulacak
  TableModel? _currentTableData;

  @override
  void initState() {
    super.initState();
    // initState'te doğrudan TableProvider'dan masa verisini çekmiyoruz.
    // İlk render'da Consumer bunu halledecek ve sonra _startOrUpdateTimer çağrılacak.
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Provider verisi değiştiğinde veya widget ağacına eklendiğinde çağrılır.
    // Burada currentTableData'yı güncelleyip, eğer değiştiyse timer'ı yeniden başlatabiliriz.
    _updateTableDataAndTimer();
  }

  // TableProvider'dan en güncel masa verisini alır ve zamanlayıcıyı günceller.
  void _updateTableDataAndTimer() {
    final tableProvider = Provider.of<TableProvider>(context, listen: false);
    final newTableData = tableProvider.tables.firstWhere(
      (t) => t.id == widget.tableId,
      orElse: () => TableModel(
          id: widget.tableId,
          name: 'Bilinmeyen Masa',
          position: 0), // DÜZELTME: position eklendi
    );

    // Timer'ı kontrol etmek için yeni bir bayrak kullan
    bool shouldRestartTimer = false;

    // Sadece masa verisi gerçekten değiştiyse timer'ı güncelle
    // veya ilk kez _currentTableData null ise (ekran ilk yüklendiğinde)
    if (_currentTableData?.isOccupied != newTableData.isOccupied ||
        _currentTableData?.startTime != newTableData.startTime ||
        _currentTableData == null) {
      shouldRestartTimer = true;
    }

    // currentTableData'yı güncelle
    setState(() {
      _currentTableData = newTableData;
      // Eğer masa dolu ise ve startTime varsa, her zaman elapsed time'ı güncelle
      if (newTableData.isOccupied && newTableData.startTime != null) {
        _elapsedTime = DateTime.now().difference(newTableData.startTime!);
      } else {
        _elapsedTime = Duration.zero; // Masa boşsa süreyi sıfırla
      }
    });

    if (shouldRestartTimer) {
      _startOrUpdateTimer(newTableData);
    }
  }

  void _startOrUpdateTimer(TableModel table) {
    _timer?.cancel(); // Önceki timer'ı iptal et

    if (table.isOccupied && table.startTime != null) {
      // **Timer Accuracy Fix:** Immediately calculate elapsed time
      // Bu kısım _updateTableDataAndTimer içinde de yapıldığı için burada sadece timer'ı başlatıyoruz
      // _elapsedTime = DateTime.now().difference(table.startTime!); // Bu satırı kaldırdık
      _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (!mounted) {
          timer.cancel();
          return;
        }
        // Hata Düzeltme: startTime'ın null olup olmadığını tekrar kontrol et
        // Masa detay ekranından masa temizlenirse startTime null olabilir.
        if (table.startTime != null) {
          // Artık widget.table yerine gelen table objesini kullanıyoruz
          setState(() {
            _elapsedTime = DateTime.now().difference(table.startTime!);
          });
        } else {
          // Eğer startTime null olduysa, timer'ı durdur ve süreyi sıfırla
          setState(() {
            _elapsedTime = Duration.zero;
          });
          timer.cancel();
        }
      });
    } else {
      setState(() {
        _elapsedTime = Duration.zero; // Masa boşaldığında süreyi sıfırla
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  // Özel ürün ekleme dialog'u
  void _showAddSpecialProductDialog(
      BuildContext context, TableModel currentTable) {
    final TextEditingController priceController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Özel Ürün Ekle'),
          content: TextField(
            controller: priceController,
            keyboardType: TextInputType.number,
            decoration:
                const InputDecoration(hintText: 'Fiyat Girin (örn: 15.50)'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('İptal'),
            ),
            ElevatedButton(
              onPressed: () {
                final price = double.tryParse(priceController.text);
                if (price != null && price > 0) {
                  final newSpecialItem = OrderItem(
                    orderId: 0, // TableProvider tarafından güncellenecek
                    productId: const Uuid().v4(), // Özel ürün için yeni ID
                    productName: 'Özel Ürün',
                    productPrice: price,
                    quantity: 1,
                    isSpecialProduct: true,
                  );
                  Provider.of<TableProvider>(context, listen: false)
                      .addOrUpdateOrder(currentTable.id, newSpecialItem);
                  Navigator.of(context).pop();
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Geçerli bir fiyat girin.')),
                  );
                }
              },
              child: const Text('Ekle'),
            ),
          ],
        );
      },
    );
  }

  // Masayı temizleme onay dialog'u
  void _showClearTableConfirmationDialog(
      BuildContext context, TableModel currentTable) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Masayı Temizle'),
          content: const Text(
              'Bu masayı temizlemek istediğinizden emin misiniz? Siparişler silinecek ve masa boş hale gelecek.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('İptal'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () {
                Provider.of<TableProvider>(context, listen: false)
                    .clearTable(currentTable.id);
                Navigator.of(context).pop(); // Dialog'u kapat
                Navigator.of(context).pop(); // Masa detay ekranından geri dön
              },
              child:
                  const Text('Temizle', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // Consumer kullanarak TableProvider'dan en güncel masa verisini al
    return Consumer<TableProvider>(
      builder: (context, tableProvider, child) {
        final currentTable = tableProvider.tables.firstWhere(
          (t) => t.id == widget.tableId,
          orElse: () => TableModel(
              id: widget.tableId,
              name: 'Bilinmeyen Masa',
              position: 0), // DÜZELTME: position eklendi
        );
        final productProvider = Provider.of<ProductProvider>(context);
        final productsToDisplay = productProvider.productsForTableSelection;

        // _currentTableData henüz ayarlanmadıysa veya güncel değilse timer'ı güncelle
        // didChangeDependencies'te çağrıldığı için burada tekrar kontrol etmeye gerek kalmayabilir.
        // Ancak ilk yüklemede gecikme yaşanmaması için bir kontrol daha ekledik.
        if (_currentTableData == null ||
            _currentTableData!.id != currentTable.id ||
            _currentTableData!.isOccupied != currentTable.isOccupied ||
            _currentTableData!.startTime != currentTable.startTime) {
          // This block is largely handled by didChangeDependencies and _updateTableDataAndTimer.
          // Removed redundant call here to avoid potential double-updates or issues.
        }

        return Scaffold(
          appBar: AppBar(
            title: Text(currentTable.name), // currentTable.name kullanıyoruz
            backgroundColor: Colors.blueGrey[800],
            foregroundColor: Colors.white,
            actions: [
              // En çok satanları gösterme/gizleme butonu
              Consumer<ProductProvider>(
                builder: (context, productProvider, child) {
                  return Tooltip(
                    message: productProvider.showTopSelling
                        ? 'En Çok Satanları Gizle'
                        : 'En Çok Satanları Göster',
                    child: IconButton(
                      icon: Icon(
                        productProvider.showTopSelling
                            ? Icons.star // Filled star when active
                            : Icons.star_border, // Bordered star when inactive
                        color: Colors.yellowAccent,
                      ),
                      onPressed: productProvider.toggleShowTopSelling,
                    ),
                  );
                },
              ),
              // Canlı toplam ciro bilgisi (AppBar'da kalmaya devam ediyor)
            ],
          ),
          body: Row(
            children: [
              // Sol Panel: Masa Bilgileri, Canlı Süre/Ciro, Sipariş Edilen Ürünler ve Temizle Butonu
              Expanded(
                flex: 3, // Sol panel için daha fazla alan
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      // Canlı Süre ve Toplam Ciro Bilgisi (Yan Yana)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Geçen Süre:',
                                  style: TextStyle(
                                      fontSize: 16, color: Colors.black54)),
                              Text(
                                '${_elapsedTime.inHours.toString().padLeft(2, '0')}:${(_elapsedTime.inMinutes % 60).toString().padLeft(2, '0')}:${(_elapsedTime.inSeconds % 60).toString().padLeft(2, '0')}',
                                style: const TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.blueGrey),
                              ),
                            ],
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              const Text('Mevcut Ciro:',
                                  style: TextStyle(
                                      fontSize: 16, color: Colors.black54)),
                              Text(
                                NumberFormat.currency(
                                        locale: 'tr_TR', symbol: '₺')
                                    .format(currentTable.totalRevenue),
                                style: TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.green[700]),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const Divider(
                          height: 20, thickness: 1, color: Colors.grey),

                      // Masaya eklenen ürünler listesi
                      Expanded(
                        child: currentTable.orders.isEmpty
                            ? const Center(
                                child: Text('Bu masada henüz sipariş yok.',
                                    style: TextStyle(
                                        fontSize: 16, color: Colors.black54)))
                            : ListView.builder(
                                itemCount: currentTable.orders.length,
                                itemBuilder: (context, index) {
                                  final orderItem = currentTable.orders[index];
                                  return Card(
                                    margin: const EdgeInsets.symmetric(
                                        vertical: 4.0),
                                    elevation: 2,
                                    shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8)),
                                    child: Padding(
                                      padding: const EdgeInsets.all(12.0),
                                      child: Row(
                                        children: [
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  orderItem.productName,
                                                  style: const TextStyle(
                                                      fontSize: 18,
                                                      fontWeight:
                                                          FontWeight.bold),
                                                ),
                                                Text(
                                                  NumberFormat.currency(
                                                          locale: 'tr_TR',
                                                          symbol: '₺')
                                                      .format(orderItem
                                                          .productPrice),
                                                  style: TextStyle(
                                                      fontSize: 14,
                                                      color: Colors.grey[700]),
                                                ),
                                              ],
                                            ),
                                          ),
                                          Row(
                                            children: [
                                              IconButton(
                                                icon: const Icon(
                                                    Icons.remove_circle,
                                                    color: Colors.red),
                                                onPressed: () {
                                                  tableProvider
                                                      .decrementOrderItem(
                                                          currentTable.id,
                                                          orderItem);
                                                  if (!orderItem
                                                      .isSpecialProduct) {
                                                    productProvider
                                                        .incrementProductSalesCount(
                                                            orderItem.productId,
                                                            -1);
                                                  }
                                                },
                                              ),
                                              Text(
                                                'x${orderItem.quantity}',
                                                style: const TextStyle(
                                                    fontSize: 18,
                                                    fontWeight:
                                                        FontWeight.bold),
                                              ),
                                              IconButton(
                                                icon: const Icon(
                                                    Icons.add_circle,
                                                    color: Colors.green),
                                                onPressed: () {
                                                  tableProvider
                                                      .incrementOrderItem(
                                                          currentTable.id,
                                                          orderItem);
                                                  if (!orderItem
                                                      .isSpecialProduct) {
                                                    productProvider
                                                        .incrementProductSalesCount(
                                                            orderItem.productId,
                                                            1);
                                                  }
                                                },
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                      ),
                      const SizedBox(height: 16),
                      // Masayı Temizle butonu
                      ElevatedButton.icon(
                        onPressed: currentTable.orders.isEmpty
                            ? null
                            : () => _showClearTableConfirmationDialog(
                                context, currentTable),
                        icon: const Icon(Icons.cleaning_services,
                            color: Colors.white),
                        label: const Text('Masayı Temizle',
                            style: TextStyle(color: Colors.white)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.redAccent,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 12),
                          minimumSize: const Size.fromHeight(
                              50), // Butonun yüksekliğini ayarla
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const VerticalDivider(
                  width: 1, thickness: 1, color: Colors.blueGrey),
              // Sağ Panel: Tüm Ürünlerin Listesi
              Expanded(
                flex: 2, // Sağ panel için daha az alan
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Ürünler:',
                            style: TextStyle(
                                fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          // "Özel Ürün Ekle" butonu (üst kısma taşıdık)
                          ElevatedButton.icon(
                            onPressed: () => _showAddSpecialProductDialog(
                                context, currentTable),
                            icon: const Icon(Icons.add_circle_outline,
                                size: 20, color: Colors.purple),
                            label: const Text('Özel Ürün',
                                style: TextStyle(color: Colors.purple)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.purple[100],
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8)),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 8),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Expanded(
                        child: productsToDisplay.isEmpty
                            ? const Center(
                                child: Text('Henüz ürün eklenmedi.',
                                    style: TextStyle(
                                        fontSize: 16, color: Colors.black54)))
                            : ListView.builder(
                                itemCount: productsToDisplay
                                    .length, // Sadece ürünleri listeler
                                itemBuilder: (context, index) {
                                  final product = productsToDisplay[index];
                                  return Card(
                                    margin: const EdgeInsets.symmetric(
                                        vertical: 4.0),
                                    elevation: 1,
                                    shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8)),
                                    color: productProvider.fixedProductId ==
                                            product.id
                                        ? Colors.blue[50]
                                        : null,
                                    child: ListTile(
                                      title: Text(product.name,
                                          style: const TextStyle(
                                              fontWeight: FontWeight.bold)),
                                      subtitle: Text(
                                        NumberFormat.currency(
                                                locale: 'tr_TR', symbol: '₺')
                                            .format(product.price),
                                      ),
                                      trailing: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          // Fiyat bilgisini buradan kaldırdık
                                          if (productProvider.fixedProductId ==
                                              product.id)
                                            const Padding(
                                              padding:
                                                  EdgeInsets.only(left: 8.0),
                                              child: Icon(Icons.push_pin,
                                                  color: Colors.blue, size: 20),
                                            ),
                                        ],
                                      ),
                                      onTap: () {
                                        // Add product to order when any part of the ListTile is tapped
                                        final newOrderItem = OrderItem(
                                          orderId:
                                              0, // TableProvider tarafından güncellenecek
                                          productId: product.id,
                                          productName: product.name,
                                          productPrice: product.price,
                                          quantity: 1,
                                          isSpecialProduct: false,
                                        );
                                        tableProvider.addOrUpdateOrder(
                                            currentTable.id, newOrderItem);
                                        productProvider
                                            .incrementProductSalesCount(
                                                product.id, 1);
                                      },
                                      onLongPress: () {
                                        productProvider
                                            .toggleFixedProduct(product.id);
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              productProvider.fixedProductId ==
                                                      product.id
                                                  ? '${product.name} sabitlendi.'
                                                  : '${product.name} sabitlemesi kaldırıldı.',
                                            ),
                                            duration:
                                                const Duration(seconds: 1),
                                          ),
                                        );
                                      },
                                    ),
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
