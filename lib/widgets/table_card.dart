import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/table_model.dart';
import '../providers/table_provider.dart';
import 'package:provider/provider.dart';

class TableCard extends StatefulWidget {
  final TableModel table;
  final TableViewMode viewMode;
  final VoidCallback? onMoreOptionsPressed;
  final VoidCallback? onCardTapped;

  const TableCard({
    super.key,
    required this.table,
    required this.viewMode,
    this.onMoreOptionsPressed,
    this.onCardTapped,
  });

  @override
  State<TableCard> createState() => _TableCardState();
}

class _TableCardState extends State<TableCard> {
  Timer? _timer;
  Duration _elapsedTime = Duration.zero;

  @override
  void initState() {
    super.initState();
    _startOrUpdateTimer();
  }

  @override
  void didUpdateWidget(covariant TableCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.table.isOccupied != oldWidget.table.isOccupied ||
        widget.table.startTime != oldWidget.table.startTime) {
      _startOrUpdateTimer();
    }
  }

  void _startOrUpdateTimer() {
    _timer?.cancel();

    if (widget.table.isOccupied && widget.table.startTime != null) {
      _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (!mounted) {
          timer.cancel();
          return;
        }

        final startTime = widget.table.startTime;
        if (startTime == null || !widget.table.isOccupied) {
          timer.cancel();
          if (mounted) {
            setState(() {
              _elapsedTime = Duration.zero;
            });
          }
          return;
        }

        // _elapsedTime'ı setState içinde güncelle
        final newElapsedTime = DateTime.now().difference(startTime);
        if (mounted) {
          setState(() {
            _elapsedTime = newElapsedTime;
          });
        }
      });

      // İlk değeri hemen hesapla
      if (mounted) {
        setState(() {
          _elapsedTime = DateTime.now().difference(widget.table.startTime!);
        });
      }
    } else {
      // Masa boş ise timer'ı durdur ve süreyi sıfırla
      if (mounted) {
        setState(() {
          _elapsedTime = Duration.zero;
        });
      }
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _formatDuration(Duration d) {
    if (d.isNegative || d == Duration.zero) return "00:00:00";
    return '${d.inHours.toString().padLeft(2, '0')}:${(d.inMinutes % 60).toString().padLeft(2, '0')}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      clipBehavior: Clip.antiAlias,
      elevation: widget.table.isOccupied ? 4 : 2,
      shadowColor: Colors.grey.withOpacity(0.3),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: widget.onCardTapped,
        child: Stack(
          children: [
            widget.viewMode == TableViewMode.list
                ? _buildAnimatedListView(context)
                : _buildAnimatedGridView(context),
            if (widget.onMoreOptionsPressed != null)
              Positioned(
                top: 4,
                right: 4,
                child: IconButton(
                  icon: Icon(
                    Icons.more_vert,
                    color: widget.table.isOccupied
                        ? Colors.white.withOpacity(0.8)
                        : Colors.grey[700],
                  ),
                  onPressed: widget.onMoreOptionsPressed,
                  visualDensity: VisualDensity.compact,
                  splashRadius: 20,
                  tooltip: 'Seçenekler',
                ),
              ),
          ],
        ),
      ),
    );
  }

  // Izgara Görünümü için Animasyonlu Kapsayıcı
  Widget _buildAnimatedGridView(BuildContext context) {
    final bool isOccupied = widget.table.isOccupied;

    final String statusText = isOccupied ? 'Dolu' : 'Boş';
    final Color statusColor = isOccupied ? Colors.redAccent : Colors.green;

    final IconData icon =
        isOccupied ? Icons.restaurant_menu_rounded : Icons.table_restaurant;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: isOccupied
            ? LinearGradient(
                colors: [
                  Colors.deepPurple.shade400,
                  Colors.blueAccent.shade400
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : null,
        color: isOccupied ? null : Colors.white,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isOccupied
                      ? Colors.white.withOpacity(0.2)
                      : statusColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  statusText,
                  style: TextStyle(
                    color: isOccupied ? Colors.white : statusColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
              const SizedBox(width: 24),
            ],
          ),
          const Spacer(),
          Icon(
            icon,
            size: 48,
            color: isOccupied ? Colors.white.withOpacity(0.9) : statusColor,
          ),
          const SizedBox(height: 8),
          Text(
            widget.table.name,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: isOccupied ? Colors.white : Colors.blueGrey[900],
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          // DOLU MASALAR İÇİN HEM SÜRE HEM CİRO GÖSTERİMİ
          if (isOccupied) ...[
            Text(
              // **DÜZELTİLDİ: Artık canlı _elapsedTime değişkenini kullanıyor.**
              _formatDuration(_elapsedTime),
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              'Geçen Süre',
              style: TextStyle(
                fontSize: 12,
                color: Colors.white.withOpacity(0.8),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              NumberFormat.currency(locale: 'tr_TR', symbol: '₺')
                  .format(widget.table.totalRevenue),
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              'Mevcut Ciro',
              style: TextStyle(
                fontSize: 12,
                color: Colors.white.withOpacity(0.8),
              ),
            ),
          ] else
            // BOŞ MASALAR İÇİN ESKİ YAPI DEVAM EDİYOR
            Column(
              children: [
                Text(
                  NumberFormat.currency(locale: 'tr_TR', symbol: '₺')
                      .format(widget.table.totalRevenue),
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.green[700],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  'Toplam Ciro',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          const Spacer(),
        ],
      ),
    );
  }

  // Liste Görünümü için Animasyonlu Kapsayıcı
  Widget _buildAnimatedListView(BuildContext context) {
    final bool isOccupied = widget.table.isOccupied;

    final String statusText = isOccupied ? 'Dolu' : 'Boş';
    final Color statusColor = isOccupied ? Colors.redAccent : Colors.green;

    final IconData icon =
        isOccupied ? Icons.restaurant_menu_rounded : Icons.table_restaurant;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      decoration: BoxDecoration(
        color: isOccupied ? Colors.red[50] : Colors.white,
        border: Border(
          left: BorderSide(
            color: isOccupied
                ? Colors.redAccent.withOpacity(0.6)
                : Colors.green.withOpacity(0.6),
            width: 6,
          ),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Icon(
              icon,
              color: statusColor,
              size: 36,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    widget.table.name,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: Colors.blueGrey[900],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      statusText,
                      style: TextStyle(
                        color: statusColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            // DOLU MASALAR İÇİN HEM SÜRE HEM CİRO GÖSTERİMİ
            if (isOccupied)
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    // **DÜZELTİLDİ: Artık canlı _elapsedTime değişkenini kullanıyor.**
                    _formatDuration(_elapsedTime),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.blueGrey,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    NumberFormat.currency(locale: 'tr_TR', symbol: '₺')
                        .format(widget.table.totalRevenue),
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.green[700],
                    ),
                  ),
                ],
              )
            else
              // BOŞ MASALAR İÇİN ESKİ YAPI DEVAM EDİYOR
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    NumberFormat.currency(locale: 'tr_TR', symbol: '₺')
                        .format(widget.table.totalRevenue),
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.green[700],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Toplam Ciro',
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            const SizedBox(width: 32),
          ],
        ),
      ),
    );
  }
}
