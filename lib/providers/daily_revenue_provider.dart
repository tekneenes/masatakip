import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:masa_takip_sistemi/models/daily_revenue_model.dart';
import 'package:masa_takip_sistemi/services/database_helper.dart';
import 'package:uuid/uuid.dart';

class DailyRevenueProvider with ChangeNotifier {
  List<DailyRevenue> _dailyRevenues = [];
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  List<DailyRevenue> get dailyRevenues => _dailyRevenues;

  DailyRevenueProvider() {
    loadDailyRevenues();
  }

  Future<void> loadDailyRevenues() async {
    _dailyRevenues = await _dbHelper.getDailyRevenuesLast30Days();
    notifyListeners();
  }

  Future<void> addRevenue(double amount) async {
    String today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    await _dbHelper.insertOrUpdateDailyRevenue(
      DailyRevenue(id: const Uuid().v4(), date: today, revenue: amount),
    );
    await loadDailyRevenues();
  }
}
