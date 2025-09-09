import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../models/table_model.dart';
import '../models/order_model.dart';
import '../models/order_item_model.dart';
import '../services/database_helper.dart';

enum TableViewMode { two, three, four, five, list, grid2, grid3 }

class TableProvider with ChangeNotifier {
  List<TableModel> _tables = [];
  final DatabaseHelper _databaseHelper = DatabaseHelper.instance;

  String _currentFilter = 'Tüm Masalar';
  TableViewMode _viewMode = TableViewMode.two;
  bool _showActiveTablesInfo = true;
  bool _showDailyRevenueInfo = true;

  List<TableModel> get tables => _tables;
  String get currentFilter => _currentFilter;
  TableViewMode get viewMode => _viewMode;
  bool get showActiveTablesInfo => _showActiveTablesInfo;
  bool get showDailyRevenueInfo => _showDailyRevenueInfo;
  double _todayTotalRevenue = 0.0;
  double get todayTotalRevenue => _todayTotalRevenue;
  double get dailyTotalRevenue => dailyTotalRevenue;

  Future<void> _loadTodayRevenue() async {
    _todayTotalRevenue = await _dbHelper.getTodayRevenue();
    notifyListeners();
  }

  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  TableProvider() {
    _loadTables();
  }
  Future<void> loadTables() async {
    _tables = await _dbHelper.getTables();
    notifyListeners();
  }

  Future<void> init() async {
    await loadTables();
    await _loadTodayRevenue();
  }

  Future<void> refreshTables() async {
    await _loadTables();
    await loadTodayRevenue(); // Günlük ciroyu da yenile
  }

  Future<void> _loadTables() async {
    _tables = await _databaseHelper.getTables();
    // Yükleme sonrası her masa için aktif siparişleri ve öğelerini çek
    for (var table in _tables) {
      await _loadActiveOrderAndItemsForTable(table);
    }
    // ensure all tables have a unique position assigned, if not already
    // This is important for reordering to work correctly from the start
    _ensureTablePositions();
    notifyListeners();
  }

  // YENİ: Masaların başlangıç pozisyonlarını ayarla veya boşlukları doldur
  void _ensureTablePositions() {
    // Önceki sıralamayı korumak için sıralıyoruz
    _tables.sort((a, b) => a.position.compareTo(b.position));

    for (int i = 0; i < _tables.length; i++) {
      if (_tables[i].position != i) {
        _tables[i].position = i;
        _databaseHelper.updateTable(_tables[i]); // Veritabanında güncelle
      }
    }
  }

  Future<void> _loadActiveOrderAndItemsForTable(TableModel table) async {
    final activeOrder = await _databaseHelper.getActiveOrderByTableId(table.id);
    if (activeOrder != null && activeOrder.id != null) {
      table.currentOrder = activeOrder;
      table.orders =
          await _databaseHelper.getOrderItemsForOrder(activeOrder.id!);
      table.totalRevenue = table.orders
          .fold(0.0, (sum, item) => sum + (item.productPrice * item.quantity));
      table.isOccupied = true;
      table.startTime ??= activeOrder.createdAt;
    } else {
      table.currentOrder = null;
      table.orders = [];
      table.totalRevenue = 0.0;
      table.isOccupied = false;
      table.startTime = null;
    }
    await _databaseHelper.updateTable(table);
  }

  Future<void> loadTodayRevenue() async {
    _todayTotalRevenue = await _databaseHelper.getTodayRevenue();
    notifyListeners();
  }

  Future<void> addTable(TableModel newTable) async {
    // Yeni masaya en son pozisyonu ver
    // Position, zaten TableModel constructor'ında ayarlanabilir veya burada dinamik olarak atanabilir.
    // Ancak veritabanı helper'ı pozisyona göre sıraladığı için, eklerken uygun bir pozisyon verilmesi önemlidir.
    // Şimdilik, TableModel'e gönderilen 0 yeterli, çünkü _ensureTablePositions bunu düzenleyecek.
    await _databaseHelper.insertTable(newTable);
    await _loadTables();
  }

  Future<void> updateTable(TableModel table) async {
    await _databaseHelper.updateTable(table);
    await _loadTables();
  }

  Future<void> deleteTable(String id) async {
    TableModel tableToDelete = _tables.firstWhere((t) => t.id == id);
    await clearTable(tableToDelete.id);
    await _databaseHelper.deleteTable(id);
    await _loadTables(); // Pozisyonlar tekrar düzenlenecek
  }

  // YENİ: Masa öğesini sürükle-bırak ile yeniden sıralama
  Future<void> reorderTables(int oldIndex, int newIndex) async {
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }
    // filteredTables değil, _tables listesi üzerinde işlem yapıyoruz,
    // çünkü pozisyonlar tüm masaların sıralamasını etkiler.
    final TableModel movedTable = _tables.removeAt(oldIndex);
    _tables.insert(newIndex, movedTable);

    // Pozisyonları veritabanında güncelle
    for (int i = 0; i < _tables.length; i++) {
      _tables[i].position = i; // Güncel pozisyonu atama
    }
    await _databaseHelper
        .updateTablePositions(_tables); // Tüm pozisyonları topluca güncelle
    notifyListeners();
  }

  Future<void> addOrUpdateOrder(
      String tableId, OrderItem newItemWithoutOrderId) async {
    TableModel table = _tables.firstWhere((t) => t.id == tableId);

    OrderModel? activeOrder = table.currentOrder;

    if (activeOrder == null) {
      final now = DateTime.now();
      final newOrderId = now.millisecondsSinceEpoch;
      activeOrder = OrderModel(
          id: newOrderId, tableId: tableId, createdAt: now, orders: []);
      activeOrder = await _databaseHelper.insertMainOrder(activeOrder);
      table.currentOrder = activeOrder;
      table.isOccupied = true;
      table.startTime = now;
    }

    newItemWithoutOrderId.orderId = activeOrder.id!;

    bool itemExists = false;
    for (var item in table.orders) {
      if (item.productId == newItemWithoutOrderId.productId &&
          item.isSpecialProduct == newItemWithoutOrderId.isSpecialProduct) {
        if (newItemWithoutOrderId.isSpecialProduct &&
            (item.productPrice != newItemWithoutOrderId.productPrice ||
                item.productName != newItemWithoutOrderId.productName)) {
          continue;
        }
        item.quantity += newItemWithoutOrderId.quantity;
        await _databaseHelper.updateOrderItem(item);
        itemExists = true;
        break;
      }
    }

    if (!itemExists) {
      final newOrderItemId =
          await _databaseHelper.insertOrderItem(newItemWithoutOrderId);
      newItemWithoutOrderId.id = newOrderItemId;
      table.orders.add(newItemWithoutOrderId);
    }

    table.totalRevenue = table.orders
        .fold(0.0, (sum, item) => sum + (item.productPrice * item.quantity));
    await _databaseHelper.updateTable(table);

    notifyListeners();
  }

  Future<void> incrementOrderItem(String tableId, OrderItem item) async {
    item.quantity++;
    await _databaseHelper.updateOrderItem(item);
    TableModel table = _tables.firstWhere((t) => t.id == tableId);
    table.totalRevenue = table.orders.fold(
        0.0,
        (sum, orderItem) =>
            sum + (orderItem.productPrice * orderItem.quantity));
    await _databaseHelper.updateTable(table);
    notifyListeners();
  }

  Future<void> decrementOrderItem(String tableId, OrderItem item) async {
    if (item.quantity > 1) {
      item.quantity--;
      await _databaseHelper.updateOrderItem(item);
    } else {
      await _databaseHelper.deleteOrderItem(item.id!);
      _tables
          .firstWhere((t) => t.id == tableId)
          .orders
          .removeWhere((element) => element.id == item.id);
    }
    TableModel table = _tables.firstWhere((t) => t.id == tableId);
    table.totalRevenue = table.orders.fold(
        0.0,
        (sum, orderItem) =>
            sum + (orderItem.productPrice * orderItem.quantity));
    await _databaseHelper.updateTable(table);
    notifyListeners();
  }

  Future<void> clearTable(String tableId) async {
    final table = _tables.firstWhere((t) => t.id == tableId);

    // Eğer masanın toplam ücreti sıfırdan büyükse, bugünkü ciroya ekle
    if (table.totalRevenue > 0) {
      await _dbHelper.addRevenueToToday(table.totalRevenue);
    }

    if (table.currentOrder != null && table.currentOrder!.id != null) {
      await _dbHelper.deleteOrderItemsByOrderId(table.currentOrder!.id!);
      await _dbHelper.deleteMainOrder(table.currentOrder!.id!);
    }

    table.isOccupied = false;
    table.startTime = null;
    table.totalRevenue = 0.0;
    table.orders = [];
    table.currentOrder = null;

    await _dbHelper.updateTable(table);
    notifyListeners();

    // Günlük toplam ciroyu yeniden hesapla
    await _loadTodayRevenue();
  }

  // ---- Filtreleme ve Görünüm Modu Yönetimi ----
  List<TableModel> get filteredTables {
    // Filtreleme yapmadan önce masaları pozisyona göre sırala (bu zaten _loadTables'da yapılıyor, ancak emin olmak için)
    List<TableModel> sortedTables = List.from(_tables);
    sortedTables.sort((a, b) => a.position.compareTo(b.position));

    switch (_currentFilter) {
      case 'Dolu Masalar':
        return sortedTables.where((table) => table.isOccupied).toList();
      case 'Boş Masalar':
        return sortedTables.where((table) => !table.isOccupied).toList();
      case 'Tüm Masalar':
      default:
        return sortedTables;
    }
  }

  void setFilter(String filter) {
    _currentFilter = filter;
    notifyListeners();
  }

  void toggleViewMode() {
    final nextMode = TableViewMode
        .values[(_viewMode.index + 1) % TableViewMode.values.length];
    _viewMode = nextMode;
    notifyListeners();
  }

  // Aktif masa sayısı
  int get activeTableCount => _tables.where((table) => table.isOccupied).length;

  // Aktif masaların toplam cirosu
  double get currentTotalRevenue => _tables
      .where((table) => table.isOccupied)
      .fold(0.0, (sum, table) => sum + table.totalRevenue);

  void toggleShowActiveTablesInfo() {
    _showActiveTablesInfo = !_showActiveTablesInfo;
    notifyListeners();
  }

  void toggleShowDailyRevenueInfo() {
    _showDailyRevenueInfo = !_showDailyRevenueInfo;
    notifyListeners();
  }

  // Masa taşıma mantığı (Veri transferi)
  Future<void> moveTableData(
      TableModel sourceTable, TableModel destTable) async {
    if (sourceTable.currentOrder != null &&
        sourceTable.currentOrder!.id != null) {
      sourceTable.currentOrder =
          sourceTable.currentOrder!.copyWith(tableId: destTable.id);
      await _databaseHelper.insertMainOrder(sourceTable.currentOrder!);

      destTable.isOccupied = sourceTable.isOccupied;
      destTable.startTime = sourceTable.startTime;
      destTable.totalRevenue = sourceTable.totalRevenue;
      destTable.currentOrder = sourceTable.currentOrder;
      destTable.orders = List.from(sourceTable.orders);

      await _databaseHelper.updateTable(destTable);

      sourceTable.isOccupied = false;
      sourceTable.startTime = null;
      sourceTable.totalRevenue = 0.0;
      sourceTable.orders = [];
      sourceTable.currentOrder = null;

      await _databaseHelper.updateTable(sourceTable);
    } else {
      destTable.isOccupied = false;
      destTable.startTime = null;
      destTable.totalRevenue = 0.0;
      destTable.orders = [];
      destTable.currentOrder = null;
      await _databaseHelper.updateTable(destTable);

      sourceTable.isOccupied = false;
      sourceTable.startTime = null;
      sourceTable.totalRevenue = 0.0;
      sourceTable.orders = [];
      sourceTable.currentOrder = null;
      await _databaseHelper.updateTable(sourceTable);
    }
    await _loadTables();
  }

  void setViewModeByIndex(int index) {
    if (index >= 0 && index < TableViewMode.values.length) {
      _viewMode = TableViewMode.values[index];
      notifyListeners();
    }
  }
}
