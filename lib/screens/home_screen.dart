import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:masa_takip_sistemi/screens/table_detail_screen.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import 'package:reorderable_grid_view/reorderable_grid_view.dart';
import '../models/table_model.dart';
import '../providers/table_provider.dart';
import '../widgets/table_card.dart';
import 'package:shared_preferences/shared_preferences.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  final TextEditingController _tableController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadViewMode();
  }

  void _loadViewMode() async {
    final prefs = await SharedPreferences.getInstance();
    final index = prefs.getInt('viewModeIndex') ?? 1;
    Provider.of<TableProvider>(context, listen: false)
        .setViewModeByIndex(index);
  }

  @override
  void dispose() {
    _tableController.dispose();
    super.dispose();
  }

  void _showFilterDialog() {
    showDialog(
      context: context,
      builder: (context) {
        final tableProvider =
            Provider.of<TableProvider>(context, listen: false);
        return Dialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Container(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.filter_list_alt,
                  size: 48,
                  color: Theme.of(context).primaryColor,
                ),
                const SizedBox(height: 16),
                Text(
                  'Masa Filtresi',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 24),
                _buildFilterOption(
                    'Tüm Masalar', Icons.restaurant, tableProvider),
                const SizedBox(height: 12),
                _buildFilterOption(
                    'Dolu Masalar', Icons.event_seat, tableProvider),
                const SizedBox(height: 12),
                _buildFilterOption(
                    'Boş Masalar', Icons.event_available, tableProvider),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Kapat'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildFilterOption(
      String filterText, IconData icon, TableProvider tableProvider) {
    final isSelected = tableProvider.currentFilter == filterText;
    final primaryColor = Theme.of(context).primaryColor;

    return Container(
      width: double.infinity,
      child: Material(
        color: isSelected ? primaryColor.withOpacity(0.1) : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            HapticFeedback.selectionClick();
            tableProvider.setFilter(filterText);
            Navigator.of(context).pop();
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              border: Border.all(
                color: isSelected ? primaryColor : Colors.grey[300]!,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(
                  icon,
                  color: isSelected ? primaryColor : Colors.grey[600],
                  size: 24,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    filterText,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight:
                          isSelected ? FontWeight.w600 : FontWeight.normal,
                      color: isSelected ? primaryColor : Colors.grey[700],
                    ),
                  ),
                ),
                if (isSelected)
                  Icon(
                    Icons.check_circle,
                    color: primaryColor,
                    size: 20,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showAddEditTableDialog({TableModel? table}) {
    _tableController.text = table?.name ?? '';
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return Dialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          elevation: 8,
          child: Container(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  table == null
                      ? Icons.add_business_outlined
                      : Icons.edit_outlined,
                  size: 48,
                  color: Theme.of(context).primaryColor,
                ),
                const SizedBox(height: 16),
                Text(
                  table == null ? 'Yeni Masa Ekle' : 'Masa Düzenle',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 24),
                TextField(
                  controller: _tableController,
                  autofocus: true,
                  decoration: InputDecoration(
                    labelText: 'Masa Adı',
                    hintText: 'Örn: Bahçe 1',
                    prefixIcon: const Icon(Icons.table_restaurant_outlined),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: Colors.grey[50],
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () {
                          Navigator.of(context).pop();
                          _tableController.clear();
                        },
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: const Text('İptal'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          if (_tableController.text.isNotEmpty) {
                            if (table == null) {
                              Provider.of<TableProvider>(context, listen: false)
                                  .addTable(TableModel(
                                      id: const Uuid().v4(),
                                      name: _tableController.text,
                                      position: 0));
                            } else {
                              table.name = _tableController.text;
                              Provider.of<TableProvider>(context, listen: false)
                                  .updateTable(table);
                            }
                            Navigator.of(context).pop();
                            _tableController.clear();
                            _showSnackBar(
                              table == null
                                  ? 'Masa başarıyla eklendi'
                                  : 'Masa güncellendi',
                              isSuccess: true,
                            );
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Theme.of(context).primaryColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(table == null ? 'Ekle' : 'Güncelle'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showMoveTableDialog(TableModel sourceTable) {
    showDialog(
      context: context,
      builder: (context) {
        final tableProvider =
            Provider.of<TableProvider>(context, listen: false);
        final availableTables = tableProvider.tables
            .where((t) => !t.isOccupied && t.id != sourceTable.id)
            .toList();

        return Dialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Container(
            padding: const EdgeInsets.all(24),
            constraints: const BoxConstraints(maxHeight: 400),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.swap_horiz,
                  size: 48,
                  color: Theme.of(context).primaryColor,
                ),
                const SizedBox(height: 16),
                Text(
                  '${sourceTable.name} Masasını Taşı',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: availableTables.isEmpty
                      ? Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.info_outline,
                              size: 64,
                              color: Colors.grey[400],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Taşınacak boş masa bulunmamaktadır.',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey[600],
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        )
                      : ListView.builder(
                          shrinkWrap: true,
                          itemCount: availableTables.length,
                          itemBuilder: (context, index) {
                            final destTable = availableTables[index];
                            return Card(
                              margin: const EdgeInsets.only(bottom: 8),
                              child: ListTile(
                                leading: Icon(
                                  Icons.table_restaurant,
                                  color: Theme.of(context).primaryColor,
                                ),
                                title: Text(destTable.name),
                                subtitle: const Text('Boş masa'),
                                trailing: const Icon(Icons.arrow_forward_ios),
                                onTap: () {
                                  tableProvider.moveTableData(
                                      sourceTable, destTable);
                                  Navigator.of(context).pop();
                                  _showSnackBar(
                                    '${sourceTable.name} masası ${destTable.name} masasına taşındı.',
                                    isSuccess: true,
                                  );
                                },
                              ),
                            );
                          },
                        ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('İptal'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showSnackBar(String message, {bool isSuccess = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isSuccess
                  ? Icons.check_circle_outline
                  : Icons.warning_amber_outlined,
              color: Colors.white,
            ),
            const SizedBox(width: 10),
            Expanded(
                child: Text(message, style: const TextStyle(fontSize: 16))),
          ],
        ),
        backgroundColor: isSuccess ? Colors.teal[400] : Colors.redAccent,
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  Widget _buildAppBarAction(
      IconData icon, String tooltip, VoidCallback onPressed) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
      child: IconButton(
        icon: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Theme.of(context).primaryColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, size: 22, color: Theme.of(context).primaryColor),
        ),
        tooltip: tooltip,
        onPressed: () {
          HapticFeedback.lightImpact();
          onPressed();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          'Masa Takip Sistemi',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        backgroundColor: Colors.deepPurple[400],
        foregroundColor: Colors.white,
        elevation: 2,
        shadowColor: Colors.deepPurple[100],
        surfaceTintColor: Colors.transparent,
        actions: [
          _buildAppBarAction(Icons.add_circle_outline, 'Masa Ekle', () {
            _showAddEditTableDialog();
          }),
          _buildAppBarAction(Icons.filter_list, 'Filtrele', () {
            _showFilterDialog();
          }),
          Consumer<TableProvider>(
            builder: (context, tableProvider, child) {
              return _buildAppBarAction(
                  Icons.grid_view_outlined, 'Görünümü Değiştir', () {
                tableProvider.toggleViewMode();
                SharedPreferences.getInstance().then((prefs) {
                  prefs.setInt('viewModeIndex', tableProvider.viewMode.index);
                });
              });
            },
          ),
          Consumer<TableProvider>(
            builder: (context, tableProvider, child) {
              return _buildAppBarAction(
                tableProvider.showActiveTablesInfo
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined,
                'Özet Bilgileri',
                tableProvider.toggleShowActiveTablesInfo,
              );
            },
          ),
          _buildAppBarAction(Icons.refresh, 'Yenile', () {
            Provider.of<TableProvider>(context, listen: false).refreshTables();
            _showSnackBar('Masalar başarıyla yenilendi.', isSuccess: true);
          }),
        ],
      ),
      body: Consumer<TableProvider>(
        builder: (context, tableProvider, child) {
          final filteredTables = tableProvider.filteredTables;
          final viewMode = tableProvider.viewMode;

          int crossAxisCount;
          double childAspectRatio;

          if (viewMode == TableViewMode.list) {
            crossAxisCount = 1;
            childAspectRatio = 3.5;
          } else {
            crossAxisCount = viewMode.index + 1;
            childAspectRatio = 1.0;
          }

          return Column(
            children: [
              // Current Filter Info
              Container(
                margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.1),
                      spreadRadius: 1,
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.filter_alt_outlined,
                      size: 18,
                      color: Colors.grey[600],
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Aktif Filtre: ${tableProvider.currentFilter}',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey[700],
                      ),
                    ),
                  ],
                ),
              ),

              // Statistics Card
              if (tableProvider.showActiveTablesInfo)
                Container(
                  margin:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.deepPurple[300]!, Colors.teal[300]!],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.deepPurple.withOpacity(0.3),
                        spreadRadius: 2,
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.9),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              Icons.table_chart_outlined,
                              color: Colors.deepPurple[600],
                              size: 28,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Aktif Masa Sayısı',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.white70,
                                  ),
                                ),
                                Text(
                                  '${tableProvider.activeTableCount}',
                                  style: const TextStyle(
                                    fontSize: 28,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: Icon(
                              tableProvider.showDailyRevenueInfo
                                  ? Icons.expand_less
                                  : Icons.expand_more,
                              color: Colors.white,
                            ),
                            onPressed: tableProvider.toggleShowDailyRevenueInfo,
                          ),
                        ],
                      ),
                      if (tableProvider.showDailyRevenueInfo) ...[
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.9),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.account_balance_wallet_outlined,
                                color: Colors.teal[600],
                                size: 22,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Bugünkü Toplam Ciro',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                    Text(
                                      NumberFormat.currency(
                                        locale: 'tr_TR',
                                        symbol: '₺',
                                      ).format(tableProvider.todayTotalRevenue),
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.teal[700],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

              // Tables Grid
              Expanded(
                child: filteredTables.isEmpty
                    ? _buildEmptyState(tableProvider.currentFilter)
                    : Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: ReorderableGridView.builder(
                          padding: const EdgeInsets.only(bottom: 80, top: 4),
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: crossAxisCount,
                            crossAxisSpacing: 12.0,
                            mainAxisSpacing: 12.0,
                            childAspectRatio: childAspectRatio,
                          ),
                          itemCount: filteredTables.length,
                          onReorder: (oldIndex, newIndex) {
                            HapticFeedback.lightImpact();
                            tableProvider.reorderTables(oldIndex, newIndex);
                          },
                          itemBuilder: (context, index) {
                            final table = filteredTables[index];
                            return GestureDetector(
                              key: ValueKey(table.id),
                              onTap: () {
                                HapticFeedback.selectionClick();
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        TableDetailScreen(tableId: table.id),
                                  ),
                                );
                              },
                              child: TableCard(
                                table: table,
                                viewMode: viewMode,
                                onMoreOptionsPressed: () {
                                  _showTableActionBottomSheet(context, table);
                                },
                              ),
                            );
                          },
                        ),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildEmptyState(String currentFilter) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            currentFilter == 'Tüm Masalar'
                ? Icons.restaurant_menu_outlined
                : Icons.search_off_outlined,
            size: 80,
            color: Colors.grey[300],
          ),
          const SizedBox(height: 16),
          Text(
            currentFilter == 'Tüm Masalar'
                ? 'Henüz masa eklenmedi'
                : 'Gösterilecek masa bulunmamaktadır',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey[500],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            currentFilter == 'Tüm Masalar'
                ? 'Yeni masa eklemek için + ikonuna tıklayın'
                : 'Farklı bir filtre seçmeyi deneyin',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[400],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  void _showTableActionBottomSheet(BuildContext context, TableModel table) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
            ),
          ),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        table.name,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 24),
                      _buildActionTile(
                        icon: Icons.edit_outlined,
                        title: 'Düzenle',
                        subtitle: 'Masa adını değiştir',
                        color: Colors.blueAccent,
                        onTap: () {
                          Navigator.pop(context);
                          _showAddEditTableDialog(table: table);
                        },
                      ),
                      _buildActionTile(
                        icon: Icons.swap_horiz_outlined,
                        title: 'Masayı Taşı',
                        subtitle: 'Veriyi başka masaya aktar',
                        color: Colors.orangeAccent,
                        onTap: () {
                          Navigator.pop(context);
                          _showMoveTableDialog(table);
                        },
                      ),
                      _buildActionTile(
                        icon: Icons.delete_outline,
                        title: 'Sil',
                        subtitle: 'Masayı kalıcı olarak sil',
                        color: Colors.redAccent,
                        onTap: () {
                          Navigator.pop(context);
                          _showDeleteConfirmationDialog(context, table);
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildActionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color, size: 24),
        ),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(color: Colors.grey[600], fontSize: 12),
        ),
        onTap: onTap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        tileColor: Colors.grey[50],
      ),
    );
  }

  void _showDeleteConfirmationDialog(BuildContext context, TableModel table) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Masa Silme Onayı'),
          content: Text(
              '${table.name} masasını silmek istediğinizden emin misiniz? Bu işlem geri alınamaz.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('İptal'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8))),
              onPressed: () {
                Provider.of<TableProvider>(context, listen: false)
                    .deleteTable(table.id);
                Navigator.of(context).pop();
                _showSnackBar('${table.name} masası kalıcı olarak silindi.');
              },
              child: const Text('Sil'),
            ),
          ],
        );
      },
    );
  }
}
