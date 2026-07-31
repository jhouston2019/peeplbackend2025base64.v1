import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import 'peepl_merchant_tokens.dart';

class MerchantAnalyticsChart extends StatelessWidget {
  const MerchantAnalyticsChart({
    super.key,
    required this.title,
    required this.labels,
    required this.values,
    this.secondaryValues,
    this.primaryLabel = 'Primary',
    this.secondaryLabel = 'Secondary',
    this.primaryColor = PeeplMerchantTokens.accentBlue,
    this.secondaryColor = PeeplMerchantTokens.success,
    this.chartType = MerchantChartType.line,
  });

  final String title;
  final List<String> labels;
  final List<double> values;
  final List<double>? secondaryValues;
  final String primaryLabel;
  final String secondaryLabel;
  final Color primaryColor;
  final Color secondaryColor;
  final MerchantChartType chartType;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: PeeplMerchantTokens.cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: PeeplMerchantTokens.sectionTitle(context),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 200,
            child: chartType == MerchantChartType.bar
                ? _buildBarChart()
                : _buildLineChart(),
          ),
          if (secondaryValues != null) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                _LegendItem(color: primaryColor, label: primaryLabel),
                const SizedBox(width: 16),
                _LegendItem(color: secondaryColor, label: secondaryLabel),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildLineChart() {
    return LineChart(
      LineChartData(
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (v) => FlLine(
            color: PeeplMerchantTokens.border,
            strokeWidth: 1,
          ),
        ),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 36,
              getTitlesWidget: (v, _) => Text(
                v.toInt().toString(),
                style: const TextStyle(
                  color: PeeplMerchantTokens.textMuted,
                  fontSize: 10,
                ),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 28,
              interval: labels.length > 7 ? 2 : 1,
              getTitlesWidget: (v, _) {
                final i = v.toInt();
                if (i < 0 || i >= labels.length) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    labels[i],
                    style: const TextStyle(
                      color: PeeplMerchantTokens.textMuted,
                      fontSize: 10,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        lineBarsData: [
          LineChartBarData(
            spots: [
              for (var i = 0; i < values.length; i++)
                FlSpot(i.toDouble(), values[i]),
            ],
            isCurved: true,
            color: primaryColor,
            barWidth: 3,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  primaryColor.withValues(alpha: 0.25),
                  primaryColor.withValues(alpha: 0),
                ],
              ),
            ),
          ),
          if (secondaryValues != null)
            LineChartBarData(
              spots: [
                for (var i = 0; i < secondaryValues!.length; i++)
                  FlSpot(i.toDouble(), secondaryValues![i]),
              ],
              isCurved: true,
              color: secondaryColor,
              barWidth: 2.5,
              dotData: const FlDotData(show: false),
            ),
        ],
      ),
      duration: const Duration(milliseconds: 450),
      curve: Curves.easeOutCubic,
    );
  }

  Widget _buildBarChart() {
    return BarChart(
      BarChartData(
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (v) => FlLine(
            color: PeeplMerchantTokens.border,
            strokeWidth: 1,
          ),
        ),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 36,
              getTitlesWidget: (v, _) => Text(
                v.toInt().toString(),
                style: const TextStyle(
                  color: PeeplMerchantTokens.textMuted,
                  fontSize: 10,
                ),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 28,
              getTitlesWidget: (v, _) {
                final i = v.toInt();
                if (i < 0 || i >= labels.length) return const SizedBox.shrink();
                return Text(
                  labels[i],
                  style: const TextStyle(
                    color: PeeplMerchantTokens.textMuted,
                    fontSize: 10,
                  ),
                );
              },
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        barGroups: [
          for (var i = 0; i < values.length; i++)
            BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(
                  toY: values[i],
                  width: 14,
                  borderRadius: BorderRadius.circular(6),
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      primaryColor.withValues(alpha: 0.6),
                      primaryColor,
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
      duration: const Duration(milliseconds: 450),
      curve: Curves.easeOutCubic,
    );
  }
}

class MerchantHeatmapChart extends StatelessWidget {
  const MerchantHeatmapChart({
    super.key,
    required this.title,
    required this.data,
  });

  final String title;
  final List<List<double>> data;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: PeeplMerchantTokens.cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: PeeplMerchantTokens.sectionTitle(context)),
          const SizedBox(height: 16),
          ...data.asMap().entries.map((row) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: row.value.map((v) {
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: AspectRatio(
                        aspectRatio: 1.2,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          decoration: BoxDecoration(
                            color: PeeplMerchantTokens.accentBlue
                                .withValues(alpha: 0.15 + (v * 0.75)),
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  const _LegendItem({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(
            color: PeeplMerchantTokens.textSecondary,
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}

enum MerchantChartType { line, bar }
