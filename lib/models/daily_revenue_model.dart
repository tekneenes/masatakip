// lib/models/daily_revenue_model.dart
class DailyRevenue {
  String id;
  String date; // YYYY-MM-DD formatında tarih
  double revenue;

  DailyRevenue({
    required this.id,
    required this.date,
    required this.revenue,
  });

  // Veritabanından gelen Map'i DailyRevenue'a dönüştürür
  factory DailyRevenue.fromMap(Map<String, dynamic> map) {
    return DailyRevenue(
      id: map['id'] ?? '',
      date: map['date'] ?? '',
      revenue: (map['revenue'] ?? 0).toDouble(),
    );
  }

  // DailyRevenue'i veritabanına kaydetmek için Map'e dönüştürür
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'date': date,
      'revenue': revenue,
    };
  }
}
