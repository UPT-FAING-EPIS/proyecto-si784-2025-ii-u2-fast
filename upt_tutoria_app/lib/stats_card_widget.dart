import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'advisor_dashboard_app.dart'; // Para los colores

class StatsCard extends StatelessWidget {
  final Map<String, int> attentionCounts;
  final VoidCallback? onTap; // Para hacerlo clickeable opcionalmente

  StatsCard({
    super.key,
    required this.attentionCounts,
    this.onTap,
  });

  final List<Color> _colors = const [
    Color(0xFF18BC9C), Color(0xFF3498DB), Color(0xFFF1C40F),
    Color(0xFFE74C3C), Color(0xFF9B59B6), Color(0xFF34495E),
  ];

  @override
  Widget build(BuildContext context) {
    final totalAttentions = attentionCounts.values.fold(0, (sum, item) => sum + item);

    return Card(
      elevation: 2,
      // Margen vertical reducido
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        // Padding vertical reducido
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 18.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Estadísticas de Atenciones',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: primaryColor),
                  ),
                  if (onTap != null)
                    Icon(Icons.filter_alt, color: Colors.grey.shade600),
                ],
              ),
              // SizedBox vertical reducido
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: SizedBox(
                      // Altura del gráfico reducida
                      height: 100,
                      child: PieChart(
                        PieChartData(
                          sections: _buildChartSections(attentionCounts),
                          sectionsSpace: 2,
                          // Radio del centro reducido
                          centerSpaceRadius: 25,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    flex: 3,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ..._buildLegendWidgets(attentionCounts),
                        const SizedBox(height: 8),
                        Text(
                          'Total: $totalAttentions',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: primaryColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Radio de las secciones reducido
  List<PieChartSectionData> _buildChartSections(Map<String, int> data) {
    int colorIndex = 0;
    final total = data.values.fold(0, (sum, item) => sum + item);
    if (total == 0) return [];

    return data.entries.map((entry) {
      final percentage = (entry.value / total * 100);
      return PieChartSectionData(
        color: _colors[colorIndex++ % _colors.length],
        value: entry.value.toDouble(),
        title: '${percentage.toStringAsFixed(0)}%',
        // Radio reducido
        radius: 35,
        titleStyle: const TextStyle(
          fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white,
          shadows: [Shadow(color: Colors.black, blurRadius: 1)],
        ),
      );
    }).toList();
  }

  // (El resto de _buildLegendWidgets y la clase Indicator no cambian)
  List<Widget> _buildLegendWidgets(Map<String, int> data) {
    int colorIndex = 0;
    return data.entries.map((entry) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 4.0),
        child: Indicator(
          color: _colors[colorIndex++ % _colors.length],
          text: '${entry.key}: ${entry.value}',
        ),
      );
    }).toList();
  }
}

class Indicator extends StatelessWidget {
  const Indicator({
    super.key, required this.color, required this.text, this.size = 14,
  });
  final Color color;
  final String text;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Container(
          width: size, height: size,
          decoration: BoxDecoration(
            shape: BoxShape.rectangle,
            borderRadius: BorderRadius.circular(3),
            color: color,
          ),
        ),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            text,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: primaryColor),
            overflow: TextOverflow.ellipsis,
          ),
        )
      ],
    );
  }
}