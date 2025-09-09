import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:intl/intl.dart';

import '../models/table_model.dart';
import '../models/product_model.dart';
import '../models/order_item_model.dart';
import '../models/order_model.dart';
import '../models/daily_revenue_model.dart';

class DatabaseHelper {
  static Database? _database;
  static const _databaseName = "masa_takip_app.db";
  // DİKKAT: Şema değiştiği için veritabanı versiyonunu artırın
  static const _databaseVersion = 2; // Bu, şu anki en güncel versiyon olmalı

  // Tablo isimleri
  static const tableTables = 'tables';
  static const tableProducts = 'products';
  static const tableMainOrders = 'main_orders';
  static const tableOrderItems = 'order_items';
  static const tableDailyRevenues = 'daily_revenues';

  DatabaseHelper._privateConstructor();
  static final DatabaseHelper instance = DatabaseHelper._privateConstructor();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  _initDatabase() async {
    String path = join(await getDatabasesPath(), _databaseName);
    return await openDatabase(
      path,
      version: _databaseVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade, // Bu metodun aktif olduğundan emin olun
    );
  }

  // Veritabanı şemasını oluşturma
  Future _onCreate(Database db, int version) async {
    // Masalar tablosu
    await db.execute('''
      CREATE TABLE $tableTables (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        isOccupied INTEGER NOT NULL,
        startTime TEXT,
        totalRevenue REAL NOT NULL DEFAULT 0.0,
        position INTEGER NOT NULL DEFAULT 0 -- 'position' sütunu burada tanımlı olmalı
      )
    ''');

    // Ürünler tablosu
    await db.execute('''
      CREATE TABLE $tableProducts (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        price REAL NOT NULL,
        salesCount INTEGER NOT NULL DEFAULT 0
      )
    ''');

    // Ana Siparişler tablosu (OrderModel için)
    await db.execute('''
      CREATE TABLE $tableMainOrders (
        id INTEGER PRIMARY KEY,
        tableId TEXT NOT NULL,
        createdAt TEXT NOT NULL,
        FOREIGN KEY (tableId) REFERENCES $tableTables(id) ON DELETE CASCADE
      )
    ''');

    // Sipariş Ürün Kalemleri tablosu (OrderItem için)
    await db.execute('''
      CREATE TABLE $tableOrderItems (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        orderId INTEGER NOT NULL,
        productId TEXT NOT NULL,
        productName TEXT NOT NULL,
        productPrice REAL NOT NULL,
        quantity INTEGER NOT NULL,
        isSpecialProduct INTEGER NOT NULL,
        FOREIGN KEY (orderId) REFERENCES $tableMainOrders(id) ON DELETE CASCADE
      )
    ''');

    // Günlük Cirolar tablosu
    await db.execute('''
      CREATE TABLE $tableDailyRevenues (
        id TEXT PRIMARY KEY,
        date TEXT NOT NULL UNIQUE,
        revenue REAL NOT NULL
      )
    ''');
  }

  // Veritabanı yükseltme metodu - Mevcut veritabanı versiyonu düşükse çalışır
  Future _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // Eğer eski versiyon 1 ise ve yeni versiyon 2 ise bu kodu çalıştır
      // 'position' sütununu ekle
      await db.execute(
          "ALTER TABLE $tableTables ADD COLUMN position INTEGER NOT NULL DEFAULT 0;");
    }
    // Gelecekteki yükseltmeler için buraya 'else if' blokları eklenebilir
  }

  // ---- Masa CRUD İşlemleri ----
  Future<int> insertTable(TableModel table) async {
    Database db = await instance.database;
    // Masa eklenirken otomatik olarak en sona atacak bir position ver
    // Bunu TableProvider'dan kontrol etmek daha mantıklı olabilir
    return await db.insert(tableTables, table.toMap());
  }

  Future<List<TableModel>> getTables() async {
    Database db = await instance.database;
    // Masaları pozisyona göre sırala
    final List<Map<String, dynamic>> maps = await db.query(
      tableTables,
      orderBy: 'position ASC', // Pozisyona göre sıralama burada uygulanır
    );

    List<TableModel> tables = [];
    for (var map in maps) {
      TableModel table = TableModel.fromMap(map);
      tables.add(table);
    }
    return tables;
  }

  Future<int> updateTable(TableModel table) async {
    Database db = await instance.database;
    return await db.update(
      tableTables,
      table.toMap(),
      where: 'id = ?',
      whereArgs: [table.id],
    );
  }

  // Birden fazla masanın pozisyonunu güncellemek için
  Future<void> updateTablePositions(List<TableModel> tables) async {
    Database db = await instance.database;
    await db.transaction((txn) async {
      for (int i = 0; i < tables.length; i++) {
        final table = tables[i];
        // Sadece pozisyon alanını güncelle
        await txn.update(
          tableTables,
          {'position': i},
          where: 'id = ?',
          whereArgs: [table.id],
        );
      }
    });
  }

  Future<int> deleteTable(String id) async {
    Database db = await instance.database;
    return await db.delete(
      tableTables,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // --- Ürün CRUD İşlemleri ---
  Future<int> insertProduct(ProductModel product) async {
    Database db = await instance.database;
    return await db.insert(tableProducts, product.toMap());
  }

  Future<List<ProductModel>> getProducts() async {
    Database db = await instance.database;
    final List<Map<String, dynamic>> maps = await db.query(tableProducts);
    return List.generate(maps.length, (i) {
      return ProductModel.fromMap(maps[i]);
    });
  }

  Future<int> updateProduct(ProductModel product) async {
    Database db = await instance.database;
    return await db.update(
      tableProducts,
      product.toMap(),
      where: 'id = ?',
      whereArgs: [product.id],
    );
  }

  Future<int> deleteProduct(String id) async {
    Database db = await instance.database;
    return await db.delete(
      tableProducts,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // ---- Ana Sipariş (OrderModel) İşlemleri ----
  Future<OrderModel> insertMainOrder(OrderModel order) async {
    final db = await database;
    final int newId = await db.insert(
      tableMainOrders,
      order.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    // OrderModel'in ID'sini güncelleyip geri döndürmek önemlidir
    return OrderModel(
      id: newId,
      tableId: order.tableId,
      createdAt: order.createdAt,
      orders: order.orders, // orders listesi de kopyalanmalı
    );
  }

  Future<OrderModel?> getActiveOrderByTableId(String tableId) async {
    final db = await database;
    final result = await db.query(
      tableMainOrders,
      where: 'tableId = ?',
      whereArgs: [tableId],
      orderBy: 'createdAt DESC',
      limit: 1,
    );
    if (result.isNotEmpty) {
      return OrderModel.fromMap(result.first);
    }
    return null;
  }

  Future<int> deleteMainOrder(int orderId) async {
    final db = await database;
    return await db.delete(
      tableMainOrders,
      where: 'id = ?',
      whereArgs: [orderId],
    );
  }

  // ---- Sipariş Ürün Kalemi (OrderItem) İşlemleri ----
  Future<int> insertOrderItem(OrderItem item) async {
    final db = await database;
    return await db.insert(
      tableOrderItems,
      item.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<OrderItem>> getOrderItemsForOrder(int orderId) async {
    final db = await database;
    final maps = await db.query(
      tableOrderItems,
      where: 'orderId = ?',
      whereArgs: [orderId],
    );
    return maps.map((map) => OrderItem.fromMap(map)).toList();
  }

  Future<int> updateOrderItem(OrderItem item) async {
    final db = await database;
    if (item.id == null) {
      throw Exception("OrderItem ID cannot be null for update operation.");
    }
    return await db.update(
      tableOrderItems,
      item.toMap(),
      where: 'id = ?',
      whereArgs: [item.id],
    );
  }

  Future<int> deleteOrderItem(int orderItemId) async {
    final db = await database;
    return await db.delete(
      tableOrderItems,
      where: 'id = ?',
      whereArgs: [orderItemId],
    );
  }

  Future<int> deleteOrderItemsByOrderId(int orderId) async {
    final db = await database;
    return await db.delete(
      tableOrderItems,
      where: 'orderId = ?',
      whereArgs: [orderId],
    );
  }

  // ---- Günlük Ciro İşlemleri ----
  Future<void> insertOrUpdateDailyRevenue(DailyRevenue dailyRevenue) async {
    Database db = await instance.database;
    await db.transaction((txn) async {
      int count = await txn.rawUpdate(
        'UPDATE $tableDailyRevenues SET revenue = revenue + ? WHERE date = ?',
        [dailyRevenue.revenue, dailyRevenue.date],
      );
      if (count == 0) {
        await txn.insert(tableDailyRevenues, dailyRevenue.toMap());
      }
    });
  }

  Future<void> addRevenueToToday(double amount) async {
    final db = await instance.database;
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());

    final result = await db.query(
      tableDailyRevenues,
      where: 'date = ?',
      whereArgs: [today],
      limit: 1,
    );

    if (result.isNotEmpty) {
      final current = result.first['revenue'] as double;
      await db.update(
        tableDailyRevenues,
        {'revenue': current + amount},
        where: 'date = ?',
        whereArgs: [today],
      );
    } else {
      await db.insert(tableDailyRevenues, {
        'date': today,
        'revenue': amount,
      });
    }
  }

  Future<List<DailyRevenue>> getDailyRevenues() async {
    Database db = await instance.database;
    final List<Map<String, dynamic>> maps = await db.query(
      tableDailyRevenues,
      orderBy: 'date ASC',
    );
    return List.generate(maps.length, (i) {
      return DailyRevenue.fromMap(maps[i]);
    });
  }

  Future<double> getTodayRevenue() async {
    final db = await instance.database;
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final result = await db.query(
      tableDailyRevenues,
      where: 'date = ?',
      whereArgs: [today],
      limit: 1,
    );

    if (result.isNotEmpty) {
      return result.first['revenue'] as double;
    }
    return 0.0;
  }

  Future<List<DailyRevenue>> getDailyRevenuesLast30Days() async {
    Database db = await instance.database;
    DateTime thirtyDaysAgo = DateTime.now().subtract(const Duration(days: 30));
    String formattedDate = DateFormat('yyyy-MM-dd').format(thirtyDaysAgo);

    final List<Map<String, dynamic>> maps = await db.query(
      tableDailyRevenues,
      where: 'date >= ?',
      whereArgs: [formattedDate],
      orderBy: 'date ASC',
    );
    return List.generate(maps.length, (i) {
      return DailyRevenue.fromMap(maps[i]);
    });
  }
  // Daha önce eklenmiş ancak gereksiz tekrar eden metotlar yorum satırı yapıldı
  // veya kaldırıldı.

  // Tüm masaları getirir (Zaten getTables() bu işlevi görüyor)
  /*
  Future<List<TableModel>> getAllTables() async {
    return await getTables();
  }
  */

  // Tüm ürünleri getirir (Aynı şekilde)
  /*
  Future<List<ProductModel>> getAllProducts() async {
    return await getProducts();
  }
  */

  // Belirli bir masanın tüm siparişlerini siler
  // Bu metodun doğru çalıştığından emin olmak için düzenlendi.
  Future<void> clearOrdersForTable(String tableId) async {
    final db = await database;

    // Masaya ait en son aktif ana siparişi bul
    final activeOrderResult = await db.query(
      tableMainOrders,
      where: 'tableId = ?',
      whereArgs: [tableId],
      orderBy: 'createdAt DESC',
      limit: 1,
    );

    if (activeOrderResult.isNotEmpty) {
      final orderId = activeOrderResult.first['id'] as int;

      await db.transaction((txn) async {
        // İlgili sipariş kalemlerini sil
        await txn.delete(
          tableOrderItems,
          where: 'orderId = ?',
          whereArgs: [orderId],
        );
        // Ana siparişi sil
        await txn.delete(
          tableMainOrders,
          where: 'id = ?',
          whereArgs: [orderId],
        );
      });
    }
  }

  // Masaya yeni sipariş kalemi ekler
  // Bu metodun doğru çalıştığından emin olmak için düzenlendi.
  Future<void> insertOrder(String tableId, OrderItem newOrderItem) async {
    final db = await database;

    // Masanın mevcut aktif siparişini bul
    final existingOrderResult = await db.query(
      tableMainOrders,
      where: 'tableId = ?',
      whereArgs: [tableId],
      orderBy: 'createdAt DESC',
      limit: 1,
    );

    int orderId;

    if (existingOrderResult.isEmpty) {
      // Eğer aktif sipariş yoksa, yeni bir ana sipariş başlat
      final newOrder = OrderModel(
        tableId: tableId,
        createdAt: DateTime.now(),
        orders: [], // Yeni siparişin başlangıçta ürünleri yoktur
      );
      // insertMainOrder metodunun OrderModel döndürdüğünü varsayarak
      final insertedOrder = await insertMainOrder(newOrder);
      orderId = insertedOrder.id!;
    } else {
      orderId = existingOrderResult.first['id'] as int;
    }

    // Sipariş ürününü bu siparişe ekle veya güncelle
    // newItem.toMap() içinde orderId olmayabilir, bu yüzden burada ekliyoruz.
    await db.insert(
      tableOrderItems,
      {
        ...newOrderItem.toMap(), // Mevcut item verilerini al
        'orderId': orderId, // orderId'yi ekle/üstüne yaz
      },
      conflictAlgorithm: ConflictAlgorithm.replace, // Mevcutsa günceller
    );
  }
}
