// lib/screens/report_screen.dart
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../providers/daily_revenue_provider.dart';
import '../providers/product_provider.dart';

class ReportScreen extends StatefulWidget {
  const ReportScreen({super.key});

  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<DailyRevenueProvider>(context, listen: false)
          .loadDailyRevenues();
      Provider.of<ProductProvider>(context, listen: false).loadProducts();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Raporlar'),
        backgroundColor: Colors.blueGrey[800],
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Günlük Ciro Raporu (Son 30 Gün)',
              style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.blueGrey),
            ),
            const SizedBox(height: 15),
            Consumer<DailyRevenueProvider>(
              builder: (context, dailyRevenueProvider, child) {
                if (dailyRevenueProvider.dailyRevenues.isEmpty) {
                  return const Center(child: Text('Ciro verisi bulunamadı.'));
                }

                // BarChart verilerini hazırla
                List<BarChartGroupData> barGroups = [];
                double maxRevenue = 0;
                Map<String, double> revenueMap = {};

                // Son 30 günü doldur, veri olmayan günler için 0 göster
                for (int i = 29; i >= 0; i--) {
                  DateTime date = DateTime.now().subtract(Duration(days: i));
                  String formattedDate = DateFormat('yyyy-MM-dd').format(date);
                  revenueMap[formattedDate] = 0.0;
                }

                for (var dailyRevenue in dailyRevenueProvider.dailyRevenues) {
                  revenueMap[dailyRevenue.date] =
                      (revenueMap[dailyRevenue.date] ?? 0.0) +
                          dailyRevenue.revenue;
                }

                List<String> sortedDates = revenueMap.keys.toList()..sort();

                for (int i = 0; i < sortedDates.length; i++) {
                  String date = sortedDates[i];
                  double revenue = revenueMap[date]!;
                  if (revenue > maxRevenue) maxRevenue = revenue;

                  barGroups.add(
                    BarChartGroupData(
                      x: i, // X ekseni için index
                      barRods: [
                        BarChartRodData(
                          toY: revenue,
                          color: Colors.blueGrey,
                          width: 15,
                          borderRadius: BorderRadius.circular(5),
                          backDrawRodData: BackgroundBarChartRodData(
                            show: true,
                            toY: maxRevenue == 0
                                ? 100
                                : maxRevenue *
                                    1.1, // Max ciroya göre arka planı ayarla
                            color: Colors.blueGrey.withOpacity(0.1),
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return SizedBox(
                  height: 250,
                  child: BarChart(
                    BarChartData(
                      barGroups: barGroups,
                      borderData: FlBorderData(
                        show: false,
                      ),
                      gridData: FlGridData(show: false),
                      alignment: BarChartAlignment.spaceAround,
                      titlesData: FlTitlesData(
                        show: true,
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            getTitlesWidget: (value, meta) {
                              // Her 5 günde bir tarih etiketi göster
                              if (value.toInt() % 5 == 0) {
                                return Padding(
                                  padding: const EdgeInsets.only(top: 8.0),
                                  child: Text(
                                    DateFormat('dd/MM').format(DateTime.parse(
                                        sortedDates[value.toInt()])),
                                    style: const TextStyle(fontSize: 10),
                                  ),
                                );
                              }
                              return Container();
                            },
                            interval:
                                1, // Her bir çubuk için başlık gösterme aralığı
                            reservedSize: 30,
                          ),
                        ),
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            getTitlesWidget: (value, meta) {
                              return Text(
                                NumberFormat.compact(locale: 'tr_TR')
                                    .format(value), // Kısaltılmış sayı formatı
                                style: const TextStyle(fontSize: 10),
                              );
                            },
                            reservedSize: 40,
                          ),
                        ),
                        topTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false)),
                        rightTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false)),
                      ),
                      barTouchData: BarTouchData(
                        touchTooltipData: BarTouchTooltipData(
                          getTooltipColor: (group) => Colors.blueGrey,
                          getTooltipItem: (group, groupIndex, rod, rodIndex) {
                            return BarTooltipItem(
                              '${DateFormat('dd/MM').format(DateTime.parse(sortedDates[group.x.toInt()]))}\n',
                              const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold),
                              children: [
                                TextSpan(
                                  text: NumberFormat.currency(
                                          locale: 'tr_TR', symbol: '₺')
                                      .format(rod.toY),
                                  style: const TextStyle(
                                      color: Colors.white, fontSize: 16),
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 30),
            const Text(
              'En Çok Satan Ürünler',
              style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.blueGrey),
            ),
            const SizedBox(height: 15),
            Consumer<ProductProvider>(
              builder: (context, productProvider, child) {
                final topSellingProducts = productProvider.products
                    .where((p) => p.salesCount > 0)
                    .toList();

                if (topSellingProducts.isEmpty) {
                  return const Center(
                      child: Text('Henüz satış verisi bulunamadı.'));
                }

                // Pasta grafik verileri
                List<PieChartSectionData> pieSections = [];
                double totalSales = topSellingProducts.fold(
                    0.0, (sum, product) => sum + product.salesCount);

                List<Color> pieColors = [
                  Colors.red,
                  Colors.blue,
                  Colors.green,
                  Colors.orange,
                  Colors.purple,
                  Colors.teal,
                  Colors.amber,
                  Colors.deepOrange,
                  Colors.indigo,
                  Colors.brown
                ];
                int colorIndex = 0;

                for (var product in topSellingProducts) {
                  double percentage = (product.salesCount / totalSales) * 100;
                  pieSections.add(
                    PieChartSectionData(
                      color: pieColors[colorIndex % pieColors.length],
                      value: product.salesCount.toDouble(),
                      title:
                          '${product.name} (%${percentage.toStringAsFixed(1)})',
                      radius: 80,
                      titleStyle: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ), // Adet gösterimi
                      badgeWidget: Text('${product.salesCount}'),
                    ),
                  );
                  colorIndex++;
                }

                return Column(
                  children: [
                    SizedBox(
                      height: 250,
                      child: PieChart(
                        PieChartData(
                          sections: pieSections,
                          centerSpaceRadius: 40,
                          sectionsSpace: 2,
                          pieTouchData: PieTouchData(
                            touchCallback:
                                (FlTouchEvent event, pieTouchResponse) {
                              // Dokunma olaylarını burada işleyebilirsiniz
                            },
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    // En çok satanlar liste görünümü
                    ListView.builder(
                      shrinkWrap: true,
                      physics:
                          const NeverScrollableScrollPhysics(), // Kaydırmayı engelle
                      itemCount: topSellingProducts.length,
                      itemBuilder: (context, index) {
                        final product = topSellingProducts[index];
                        return Card(
                          margin: const EdgeInsets.symmetric(vertical: 4.0),
                          elevation: 2,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8)),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor:
                                  pieColors[index % pieColors.length],
                              child: Text('${index + 1}',
                                  style: const TextStyle(color: Colors.white)),
                            ),
                            title: Text(product.name),
                            trailing: Text(
                              '${product.salesCount} Adet',
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blueGrey),
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
