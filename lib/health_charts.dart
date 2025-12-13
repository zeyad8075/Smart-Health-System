import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'dart:math';

class HealthCharts {

  static int _touchedIndex = -1;
  // 1. مخطط توزيع مكونات الجسم (دائري)

static Widget bodyCompositionPieChart({
    required String bodyFatKg,
    required String muscleMass,
    required String bodyWater,
    required String weight,
    required bool isDarkMode,
    void Function(void Function())? setStateCallback,
  }) {
    final fatMass = double.tryParse(bodyFatKg) ?? 0;
    final muscleMassValue = double.tryParse(muscleMass) ?? 0;
    final waterMass = double.tryParse(bodyWater) ?? 0;
    final totalWeight = double.tryParse(weight) ?? 0;
    final otherMass = (totalWeight - fatMass - muscleMassValue - waterMass).clamp(0, double.infinity);
    final total = fatMass + muscleMassValue + waterMass + otherMass;

    final sections = [
      _buildPieSection(
        value: fatMass,
        total: total,
        color: const Color(0xFFF44336),
        label: 'الدهون',
        index: 0,
        isDarkMode: isDarkMode,
      ),
      _buildPieSection(
        value: muscleMassValue,
        total: total,
        color: const Color(0xFF4CAF50),
        label: 'العضلات',
        index: 1,
        isDarkMode: isDarkMode,
      ),
      _buildPieSection(
        value: waterMass,
        total: total,
        color: const Color(0xFF2196F3),
        label: 'الماء',
        index: 2,
        isDarkMode: isDarkMode,
      ),
      _buildPieSection(
        value: otherMass.toDouble(),
        total: total,
        color: Colors.grey,
        label: 'أخرى',
        index: 3,
        isDarkMode: isDarkMode,
      ),
    ];


  return Column(
  children: [

  Container(
  margin: const EdgeInsets.only(bottom: 12),
  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
  decoration: BoxDecoration(
  color: isDarkMode ? Colors.grey[800] : const Color(0xFFF5F6FA),
  borderRadius: BorderRadius.circular(20),
  ),
  child: Row(
  mainAxisAlignment: MainAxisAlignment.center,
  children: [
    _buildHrvLegendItem(const Color(0xFFF44336), 'الدهون', isDarkMode),
    const SizedBox(width: 20),
    _buildHrvLegendItem(const Color(0xFF4CAF50), 'العضلات', isDarkMode),
    const SizedBox(width: 20),
    _buildHrvLegendItem(const Color(0xFF2196F3), 'الماء', isDarkMode),
    const SizedBox(width: 20),
    _buildHrvLegendItem(Colors.grey, 'أخرى', isDarkMode),


  ],
  ),
  ),


  Container(
      height: 250,
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: isDarkMode ? Colors.grey[800] : const Color(0xFFF5F6FA),
        borderRadius: BorderRadius.circular(16),

      ),
      child: Column(
        children: [
          Expanded(
            child: PieChart(
              PieChartData(
                sectionsSpace: 2,
                centerSpaceRadius: 40,
                pieTouchData: PieTouchData(
                  touchCallback: (FlTouchEvent event, pieTouchResponse) {
                    if (setStateCallback != null) {
                      setStateCallback(() {
                        if (!event.isInterestedForInteractions || pieTouchResponse?.touchedSection == null) {
                          _touchedIndex = -1;
                        } else {
                          _touchedIndex = pieTouchResponse!.touchedSection!.touchedSectionIndex;
                        }
                      });
                    }
                  },
                ),
                sections: sections,
              ),
            ),
          ),

        ],
      ),
    ),
  ],
  );
  }

// 2. دالة بناء جزء من المخطط الدائري
 static PieChartSectionData _buildPieSection({
    required double value,
    required double total,
    required Color color,
    required String label,
    required int index,
    required bool isDarkMode,
  }) {
    final isTouched = index == _touchedIndex;
    final percentage = total > 0 ? (value / total * 100).toStringAsFixed(0) : '0';
    final title = value > 0 ? '${value.toStringAsFixed(1)}kg\n($percentage%)' : '';

    return PieChartSectionData(
      value: value,
      color: color,
      title: title,
      radius: isTouched ? 70 : 60,
      titleStyle: TextStyle(
        fontSize: isTouched ? 14 : 12,
        fontWeight: FontWeight.bold,
        color: isDarkMode ? Colors.white : Colors.black,
      ),
    );
  }


  static Widget sleepProgressChart({
    required List<FlSpot> deepSleepSpots,
    required List<FlSpot> remSleepSpots,
    required List<FlSpot> lightSleepSpots,
    required List<FlSpot> awakeSpots,
    bool isDarkMode = false,
  }) {
    if (deepSleepSpots.isEmpty &&
        remSleepSpots.isEmpty &&
        lightSleepSpots.isEmpty &&
        awakeSpots.isEmpty) {
      return Center(child: Text("لا توجد بيانات للنوم متاحة"));
    }
    // 1. ترتيب أيام الأسبوع من السبت إلى الجمعة
    final days = ['السبت', 'الأحد', 'الإثنين', 'الثلاثاء', 'الأربعاء', 'الخميس', 'الجمعة'];

    // 2. حساب اليوم الحالي (0=السبت، 6=الجمعة)
    final now = DateTime.now();
    final currentDayIndex = (now.weekday + 1) % 7;

    // 3. تصفية البيانات لإظهار فقط الأيام حتى اليوم الحالي
    final filteredDeep = deepSleepSpots.where((spot) => spot.x <= currentDayIndex).toList();
    final filteredRem = remSleepSpots.where((spot) => spot.x <= currentDayIndex).toList();
    final filteredLight = lightSleepSpots.where((spot) => spot.x <= currentDayIndex).toList();
    final filteredAwake = awakeSpots.where((spot) => spot.x <= currentDayIndex).toList();


    // 4. حساب القيمة العظمى للمحور الصادي
    final allValues = [
      ...deepSleepSpots.map((e) => e.y),
      ...remSleepSpots.map((e) => e.y),
      ...lightSleepSpots.map((e) => e.y),
      ...awakeSpots.map((e) => e.y),
    ];

    final maxY = allValues.isNotEmpty
        ? allValues.reduce(max) * 1.2
        : 100; // قيمة افتراضية

    return Column(
      children: [
        Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
          decoration: BoxDecoration(
            color: isDarkMode ? Colors.grey[800] : const Color(0xFFF5F6FA),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildHrvLegendItem(const Color(0xFF6A74CF), 'العميق', isDarkMode),
              const SizedBox(width: 10),
              _buildHrvLegendItem(const Color(0xFF4CAF50), 'REM', isDarkMode),
              const SizedBox(width: 10),
              _buildHrvLegendItem(const Color(0xFFFFA726), 'الخفيف', isDarkMode),
              const SizedBox(width: 10),
              _buildHrvLegendItem(const Color(0xFFF44336), 'الاستيقاظ', isDarkMode),
            ],
          ),
        ),
        Container(
          height: 250,
          padding: const EdgeInsets.all(16),
          margin: const EdgeInsets.only(bottom: 20),
          decoration: BoxDecoration(
            color: isDarkMode ? Colors.grey[800] : const Color(0xFFF5F6FA),
            borderRadius: BorderRadius.circular(12),
          ),
          child: LineChart(
            LineChartData(
              minX: 0,
              maxX: 6,
              minY: 0,
              maxY: maxY.toDouble(),
              gridData: FlGridData(
                show: true,
                getDrawingHorizontalLine: (value) => FlLine(
                  color: isDarkMode ? Colors.grey[700]! : Colors.grey[200]!,
                  strokeWidth: 1,
                ),
                drawVerticalLine: false,
              ),
              titlesData: FlTitlesData(
                show: true,
                rightTitles: const AxisTitles(),
                topTitles: const AxisTitles(),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 30,
                    getTitlesWidget: (value, meta) {
                      final index = value.toInt();
                      if (index >= 0 && index < days.length) {
                        return Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Text(
                            days[index],
                            style: TextStyle(
                              fontSize: 10,
                              color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                            ),
                          ),
                        );
                      }
                      return const SizedBox();
                    },
                  ),
                ),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 40,
                    getTitlesWidget: (value, meta) {
                      return Text(
                        value.toInt().toString(),
                        style: TextStyle(
                          fontSize: 10,
                          color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                        ),
                      );
                    },
                  ),
                ),
              ),
              borderData: FlBorderData(show: false),
              lineBarsData: [
                LineChartBarData(
                  spots: filteredDeep,
                  isCurved: true,
                  color: const Color(0xFF6A74CF),
                  barWidth: 3,
                  belowBarData: BarAreaData(show: false),
                  dotData: FlDotData(
                    show: true,
                    getDotPainter: (spot, percent, barData, index) {
                      return FlDotCirclePainter(
                        radius: 4,
                        color: const Color(0xFF6A74CF),
                        strokeWidth: 2,
                        strokeColor: Colors.white,
                      );
                    },
                  ),
                ),
                LineChartBarData(
                  spots: filteredRem,
                  isCurved: true,
                  color: const Color(0xFF4CAF50),
                  barWidth: 3,
                  belowBarData: BarAreaData(show: false),
                  dotData: FlDotData(
                    show: true,
                    getDotPainter: (spot, percent, barData, index) {
                      return FlDotCirclePainter(
                        radius: 4,
                        color: const Color(0xFF4CAF50),
                        strokeWidth: 2,
                        strokeColor: Colors.white,
                      );
                    },
                  ),
                ),
                LineChartBarData(
                  spots: filteredLight,
                  isCurved: true,
                  color: const Color(0xFFFFA726),
                  barWidth: 3,
                  belowBarData: BarAreaData(show: false),
                  dotData: FlDotData(
                    show: true,
                    getDotPainter: (spot, percent, barData, index) {
                      return FlDotCirclePainter(
                        radius: 4,
                        color: const Color(0xFFFFA726),
                        strokeWidth: 2,
                        strokeColor: Colors.white,
                      );
                    },
                  ),
                ),
                LineChartBarData(
                  spots: filteredAwake,
                  isCurved: true,
                  color: const Color(0xFFF44336),
                  barWidth: 3,
                  belowBarData: BarAreaData(show: false),
                  dotData: FlDotData(
                    show: true,
                    getDotPainter: (spot, percent, barData, index) {
                      return FlDotCirclePainter(
                        radius: 4,
                        color: const Color(0xFFF44336),
                        strokeWidth: 2,
                        strokeColor: Colors.white,
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  static Widget heartRateChart({
    required List<FlSpot> hourlySpots,
    bool isDarkMode = false,
  }) {
    final now = DateTime.now();
    final currentHour = now.hour.toDouble();

    // تصفية البيانات لساعات اليوم حتى الآن فقط
    final filteredSpots = hourlySpots.where((spot) => spot.x <= currentHour).toList();

    // إعداد الألوان حسب الوضع المظلم
    final safeZoneColor = isDarkMode
        ? const Color(0xFF66BB6A).withAlpha(80)
        : const Color(0xFF4CAF50).withAlpha(30);

    final warningZoneColor = isDarkMode
        ? const Color(0xFFFFD54F).withAlpha(80)
        : const Color(0xFFFFC107).withAlpha(30);

    final dangerZoneColor = isDarkMode
        ? const Color(0xFFEF5350).withAlpha(80)
        : const Color(0xFFF44336).withAlpha(30);

    final lineColor = isDarkMode
        ? const Color(0xFF8A9BFF)
        : const Color(0xFF6A74CF);

    final textColor = isDarkMode
        ? Colors.white.withAlpha(230)
        : Colors.black87.withAlpha(204);

    final gridColor = isDarkMode
        ? Colors.grey[600]!.withAlpha(150)
        : Colors.grey[300]!;

    final tooltipColor = isDarkMode
        ? Colors.grey[800]!
        : Colors.white;

    return Column(
      children: [
        Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
          decoration: BoxDecoration(
            color: isDarkMode ? Colors.grey[800] : const Color(0xFFF5F6FA),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildHrvLegendItem(lineColor, 'Bpm', isDarkMode),
              const SizedBox(width: 20),
              _buildHrvLegendItem(safeZoneColor.withAlpha(150), 'طبيعي', isDarkMode),
              const SizedBox(width: 20),
              _buildHrvLegendItem(warningZoneColor.withAlpha(150), 'منخفض', isDarkMode),
              const SizedBox(width: 20),
              _buildHrvLegendItem(dangerZoneColor.withAlpha(150), 'مرتفع', isDarkMode),
            ],
          ),
        ),
        Container(
          height: 300,
          padding: const EdgeInsets.all(16),
          margin: const EdgeInsets.only(bottom: 20),
          decoration: BoxDecoration(
            color: isDarkMode ? Colors.grey[800] : const Color(0xFFF5F6FA),
            borderRadius: BorderRadius.circular(16),
          ),
          child: LineChart(
            LineChartData(
              minX: 0,
              maxX: 23, // يبقى المحور الأفقي كاملًا للرؤية الواضحة
              minY: 40,
              maxY: 180,
              lineTouchData: LineTouchData(
                enabled: true,
                touchTooltipData: LineTouchTooltipData(
                  getTooltipColor: (_) => tooltipColor,
                  tooltipBorder: BorderSide(
                    color: isDarkMode ? Colors.grey[600]! : Colors.grey[300]!,
                    width: 1,
                  ),
                  getTooltipItems: (List<LineBarSpot> touchedSpots) {
                    return touchedSpots.map((spot) {
                      return LineTooltipItem(
                        '${spot.y.toInt()} نبضة\nالساعة: ${spot.x.toInt()}:00',
                        TextStyle(
                          fontWeight: FontWeight.bold,
                          color: isDarkMode ? Colors.white : Colors.black,
                        ),
                      );
                    }).toList();
                  },
                ),
              ),
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                getDrawingHorizontalLine: (value) {
                  if (value == 60 || value == 100) {
                    return FlLine(
                      color: gridColor,
                      strokeWidth: 1.5,
                      dashArray: [5, 5],
                    );
                  }
                  return FlLine(
                    color: gridColor,
                    strokeWidth: 1,
                  );
                },
              ),
              titlesData: FlTitlesData(
                show: true,
                rightTitles: const AxisTitles(),
                topTitles: const AxisTitles(),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 28,
                    interval: 3,
                    getTitlesWidget: (value, meta) {
                      // إخفاء العناوين بعد الساعة الحالية
                      if (value > currentHour) return const SizedBox();
                      return Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: Text(
                          '${value.toInt()}',
                          style: TextStyle(
                            fontSize: 12,
                            color: textColor,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      );
                    },
                  ),
                ),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    interval: 20,
                    reservedSize: 40,
                    getTitlesWidget: (value, meta) {
                      return Text(
                        value.toInt().toString(),
                        style: TextStyle(
                          fontSize: 12,
                          color: textColor,
                          fontWeight: FontWeight.w500,
                        ),
                      );
                    },
                  ),
                ),
              ),
              borderData: FlBorderData(show: false),
              lineBarsData: [
                // المنطقة الخطرة (أعلى من 100)
                LineChartBarData(
                  spots: [FlSpot(0, 100), FlSpot(23, 100), FlSpot(23, 180), FlSpot(0, 180)],
                  color: Colors.transparent,
                  barWidth: 0,
                  belowBarData: BarAreaData(
                    show: true,
                    color: dangerZoneColor,
                  ),
                ),
                // المنطقة الطبيعية (60-100)
                LineChartBarData(
                  spots: [FlSpot(0, 60), FlSpot(23, 60), FlSpot(23, 100), FlSpot(0, 100)],
                  color: Colors.transparent,
                  barWidth: 0,
                  belowBarData: BarAreaData(
                    show: true,
                    color: safeZoneColor,
                  ),
                ),
                // منطقة التحذير (أقل من 60)
                LineChartBarData(
                  spots: [FlSpot(0, 40), FlSpot(23, 40), FlSpot(23, 60), FlSpot(0, 60)],
                  color: Colors.transparent,
                  barWidth: 0,
                  belowBarData: BarAreaData(
                    show: true,
                    color: warningZoneColor,
                  ),
                ),
                // الخط الرئيسي للبيانات (يظهر فقط حتى الساعة الحالية)
                LineChartBarData(
                  spots: filteredSpots,
                  isCurved: true,
                  color: lineColor,
                  barWidth: 3,
                  dotData: const FlDotData(show: false),
                  belowBarData: BarAreaData(
                    show: true,
                    color: lineColor.withAlpha(25),
                    applyCutOffY: true,
                    cutOffY: 40,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
  static List<FlSpot> _filterTodaySpots(List<FlSpot> spots) {
    final now = DateTime.now();
    final currentHour = now.hour.toDouble();
    return spots.where((spot) => spot.x <= currentHour).toList();
  }


  static Widget hrvChart({
    required List<FlSpot> sdnnSpots,
    required List<FlSpot> rmssdSpots,
    bool isDarkMode = false,
  }) {
    // تصفية النقاط لليوم الحالي وترتيبها زمنياً
    final filteredSdnn = _filterTodaySpots(sdnnSpots)..sort((a, b) => a.x.compareTo(b.x));
    final filteredRmssd = _filterTodaySpots(rmssdSpots)..sort((a, b) => a.x.compareTo(b.x));

    // الألوان
    final sdnnColor = isDarkMode ? const Color(0xFF64B5F6) : const Color(0xFF1976D2);
    final rmssdColor = isDarkMode ? const Color(0xFF81C784) : const Color(0xFF388E3C);
    final textColor = isDarkMode ? Colors.white : Colors.black87;
    final gridColor = isDarkMode ? Colors.grey[700]! : Colors.grey[300]!;

    // حساب القيم العظمى
    final maxY = () {
      try {
        return max(
          filteredSdnn.isNotEmpty ? filteredSdnn.map((s) => s.y).reduce(max) : 100,
          filteredRmssd.isNotEmpty ? filteredRmssd.map((s) => s.y).reduce(max) : 100,
        ) * 1.2;
      } catch (e) {
        return 100.0;
      }
    }();

    return Column(
      children: [
        // وسيلة الإيضاح (Legend)
        Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
          decoration: BoxDecoration(
            color: isDarkMode ? Colors.grey[800] : const Color(0xFFF5F6FA),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildHrvLegendItem(sdnnColor, 'SDNN', isDarkMode),
              const SizedBox(width: 20),
              _buildHrvLegendItem(rmssdColor, 'RMSSD', isDarkMode),
            ],
          ),
        ),

        // المخطط الرئيسي
        Container(
          height: 300,
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.only(top: 16, right: 16, left: 8, bottom: 16),
          decoration: BoxDecoration(
            color: isDarkMode ? Colors.grey[800] : const Color(0xFFF5F6FA),
            borderRadius: BorderRadius.circular(16),
          ),
          child: LineChart(
            LineChartData(
              minX: 0,
              maxX: 23,
              minY: 0,
              maxY: maxY,
              lineTouchData: LineTouchData(
                enabled: true,
                touchTooltipData: LineTouchTooltipData(
                  getTooltipColor: (_) => isDarkMode ? Colors.grey[800]! : Colors.white,
                  getTooltipItems: (touchedSpots) {
                    return touchedSpots.map((spot) {
                      final title = spot.barIndex == 0 ? 'SDNN' : 'RMSSD';
                      final hour = spot.x.toInt();
                      final label = hour < 12 ? '$hour ص' : hour == 12 ? '12 م' : '${hour-12} م';
                      return LineTooltipItem(
                        '$title: ${spot.y.toStringAsFixed(1)}\nالوقت: $label',
                        TextStyle(
                          color: isDarkMode ? Colors.white : Colors.black,
                          fontWeight: FontWeight.bold,
                        ),
                      );
                    }).toList();
                  },
                ),
              ),
              gridData: FlGridData(
                show: true,
                drawVerticalLine: true,
                verticalInterval: 3,
                getDrawingHorizontalLine: (value) => FlLine(
                  color: gridColor,
                  strokeWidth: 1,
                ),
              ),
              titlesData: FlTitlesData(
                show: true,
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 30,
                    interval: 3,
                    getTitlesWidget: (value, meta) {
                      final hour = value.toInt();
                      final labels = ['12 ص', '3', '6', '9', '12 م', '3', '6', '9'];
                      final index = hour ~/ 3;
                      return index < labels.length
                          ? Text(labels[index], style: TextStyle(fontSize: 12, color: textColor))
                          : const SizedBox();
                    },
                  ),
                ),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 40,
                    getTitlesWidget: (value, meta) {
                      return Text(
                        value.toInt().toString(),
                        style: TextStyle(fontSize: 12, color: textColor),
                      );
                    },
                  ),
                ),
              ),
              borderData: FlBorderData(show: false),
              lineBarsData: [
                LineChartBarData(
                  spots: filteredSdnn,
                  isCurved: true,
                  curveSmoothness: 0.3,
                  color: sdnnColor,
                  barWidth: 3,
                  belowBarData: BarAreaData(
                    show: true,
                    color: sdnnColor.withAlpha(50),
                  ),
                  dotData: const FlDotData(show: false),
                ),
                LineChartBarData(
                  spots: filteredRmssd,
                  isCurved: true,
                  curveSmoothness: 0.3,
                  color: rmssdColor,
                  barWidth: 3,
                  belowBarData: BarAreaData(
                    show: true,
                    color: rmssdColor.withAlpha(50),
                  ),
                  dotData: const FlDotData(show: false),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
// دالة مساعدة لبناء عناصر وسيلة الإيضاح
  static Widget _buildHrvLegendItem(Color color, String text, bool isDarkMode) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(
              color: isDarkMode ? Colors.grey[600]! : Colors.white,
              width: 2,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          text,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: isDarkMode ? Colors.white : Colors.grey[800],
          ),
        ),
      ],
    );
  }


  static Widget activityProgressChart({
    required List<FlSpot> stepsSpots,
    required List<FlSpot> caloriesSpots,
    bool isDarkMode = false,
  }) {
    // 1. ترتيب أيام الأسبوع من السبت إلى الجمعة
    final days = ['السبت', 'الأحد', 'الإثنين', 'الثلاثاء', 'الأربعاء', 'الخميس', 'الجمعة'];

    // 2. حساب اليوم الحالي في الأسبوع (0=السبت، 6=الجمعة)
    final now = DateTime.now();
    final currentDayIndex = (now.weekday + 1) % 7; // تحويل إلى 0=السبت، 6=الجمعة

    // 3. تصفية البيانات لإظهار فقط الأيام حتى اليوم الحالي
    final filteredSteps = stepsSpots.where((spot) => spot.x <= currentDayIndex).toList();
    final filteredCalories = caloriesSpots.where((spot) => spot.x <= currentDayIndex).toList();

    // 4. حساب القيم العظمى والصغرى للبيانات
    final maxSteps = filteredSteps.isNotEmpty ? filteredSteps.map((spot) => spot.y).reduce(max) : 0;
    final maxCalories = filteredCalories.isNotEmpty ? filteredCalories.map((spot) => spot.y).reduce(max) : 0;
    final absoluteMax = max(maxSteps, maxCalories);

    // 5. تحديد الحد الأقصى للمحور الرأسي بشكل ذكي
    double maxY;
    if (absoluteMax == 0) {
      maxY = 1000; // قيمة افتراضية إذا لم تكن هناك بيانات
    } else {
      // حساب الحد الأقصى مع هامش 20% أعلى من القيمة القصوى
      maxY = absoluteMax * 1.2;
      // تقريب إلى أقرب 500 إذا كانت القيمة كبيرة
      if (maxY > 5000) {
        maxY = (maxY / 500).ceil() * 500;
      }
    }

    // 6. حساب الفاصل المناسب للمحور الرأسي
    double interval;
    if (maxY <= 1000) {
      interval = 200;
    } else if (maxY <= 5000) {
      interval = 500;
    } else {
      interval = 2000;
    }

    return Column(
      children: [
        // وسيلة الإيضاح (Legend)
        Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
          decoration: BoxDecoration(
            color: isDarkMode ? Colors.grey[800] : const Color(0xFFF5F6FA),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildHrvLegendItem(const Color(0xFF6A74CF), 'الخطوات', isDarkMode),
              const SizedBox(width: 20),
              _buildHrvLegendItem(const Color(0xFFFFA726), 'السعرات', isDarkMode),
            ],
          ),
        ),

        // المخطط نفسه
        Container(
          height: 250,
          padding: const EdgeInsets.all(16),
          margin: const EdgeInsets.only(bottom: 20),
          decoration: BoxDecoration(
            color: isDarkMode ? Colors.grey[800] : const Color(0xFFF5F6FA),
            borderRadius: BorderRadius.circular(12),
          ),
          child: LineChart(
            LineChartData(
              minX: 0,
              maxX: 6,
              minY: 0,
              maxY: maxY,
              gridData: FlGridData(
                show: true,
                getDrawingHorizontalLine: (value) => FlLine(
                  color: isDarkMode ? Colors.grey[700]! : Colors.grey[200]!,
                  strokeWidth: 1,
                ),
                drawVerticalLine: false,
                horizontalInterval: interval,
              ),
              titlesData: FlTitlesData(
                show: true,
                rightTitles: const AxisTitles(),
                topTitles: const AxisTitles(),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 30,
                    getTitlesWidget: (value, meta) {
                      final index = value.toInt();
                      if (index >= 0 && index < days.length) {
                        return Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Text(
                            days[index],
                            style: TextStyle(
                              fontSize: 10,
                              color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                            ),
                          ),
                        );
                      }
                      return const SizedBox();
                    },
                  ),
                ),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 40,
                    interval: interval,
                    getTitlesWidget: (value, meta) {
                      return Text(
                        value.toInt().toString(),
                        style: TextStyle(
                          fontSize: 10,
                          color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                        ),
                      );
                    },
                  ),
                ),
              ),
              borderData: FlBorderData(show: false),
              lineBarsData: [
                LineChartBarData(
                  spots: filteredSteps,
                  isCurved: true,
                  color: const Color(0xFF6A74CF),
                  barWidth: 3,
                  belowBarData: BarAreaData(show: false),
                  dotData: FlDotData(
                    show: true,
                    getDotPainter: (spot, percent, barData, index) {
                      return FlDotCirclePainter(
                        radius: 4,
                        color: const Color(0xFF6A74CF),
                        strokeWidth: 2,
                        strokeColor: Colors.white,
                      );
                    },
                  ),
                ),
                LineChartBarData(
                  spots: filteredCalories,
                  isCurved: true,
                  color: const Color(0xFFFFA726),
                  barWidth: 3,
                  belowBarData: BarAreaData(show: false),
                  dotData: FlDotData(
                    show: true,
                    getDotPainter: (spot, percent, barData, index) {
                      return FlDotCirclePainter(
                        radius: 4,
                        color: const Color(0xFFFFA726),
                        strokeWidth: 2,
                        strokeColor: Colors.white,
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),


      ],
    );
  }

  static Widget spo2WeeklyChart({
    required List<double> weeklySpO2Values,
    bool isDarkMode = false,
  }) {
    // تحديد ألوان المناطق المختلفة
    final normalZoneColor = isDarkMode
        ? const Color(0xFF4CAF50).withAlpha(150)
        : const Color(0xFF4CAF50).withAlpha(100);
    final mildZoneColor = isDarkMode
        ? const Color(0xFFFFC107).withAlpha(150)
        : const Color(0xFFFFC107).withAlpha(100);
    final moderateZoneColor = isDarkMode
        ? const Color(0xFFFF9800).withAlpha(150)
        : const Color(0xFFFF9800).withAlpha(100);
    final severeZoneColor = isDarkMode
        ? const Color(0xFFF44336).withAlpha(150)
        : const Color(0xFFF44336).withAlpha(100);

    // أيام الأسبوع العربية (السبت إلى الجمعة)
    final days = ['السبت', 'الأحد', 'الإثنين', 'الثلاثاء', 'الأربعاء', 'الخميس', 'الجمعة'];

    return Column(
      children: [
        // وسيلة الإيضاح (Legend)
        Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
          decoration: BoxDecoration(
            color: isDarkMode ? Colors.grey[800] : const Color(0xFFF5F6FA),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // الصف الأول
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildHrvLegendItem(normalZoneColor, 'طبيعي', isDarkMode),
                  const SizedBox(width: 10),
                  _buildHrvLegendItem(mildZoneColor, 'نقص بسيط', isDarkMode),
                  const SizedBox(width: 10),
                  _buildHrvLegendItem(moderateZoneColor, 'نقص متوسط', isDarkMode),
                ],
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildHrvLegendItem(severeZoneColor, 'نقص حاد', isDarkMode),
                ],
              ),
            ],
          ),
        ),

        // المخطط نفسه
        Container(
          height: 250,
          padding: const EdgeInsets.all(16),
          margin: const EdgeInsets.only(bottom: 20),
          decoration: BoxDecoration(
            color: isDarkMode ? Colors.grey[800] : const Color(0xFFF5F6FA),
            borderRadius: BorderRadius.circular(16),
          ),
          child: BarChart(
            BarChartData(
              alignment: BarChartAlignment.spaceAround,
              maxY: 100,
              minY: 70,
              groupsSpace: 12,
              barTouchData: BarTouchData(
                enabled: true,
                touchTooltipData: BarTouchTooltipData(
                  getTooltipColor: (_) => isDarkMode ? Colors.grey[700]! : Colors.white,
                  getTooltipItem: (group, groupIndex, rod, rodIndex) {
                    return BarTooltipItem(
                      '${rod.toY.toInt()}%',
                      TextStyle(
                        color: isDarkMode ? Colors.white : Colors.black,
                        fontWeight: FontWeight.bold,
                      ),
                    );
                  },
                ),
              ),
              titlesData: FlTitlesData(
                show: true,
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (value, meta) {
                      final index = value.toInt();
                      if (index >= 0 && index < days.length) {
                        return Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Text(
                            days[index],
                            style: TextStyle(
                              fontSize: 10,
                              color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                            ),
                          ),
                        );
                      }
                      return const SizedBox();
                    },
                  ),
                ),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 40,
                    getTitlesWidget: (value, meta) {
                      return Text(
                        value.toInt().toString(),
                        style: TextStyle(
                          fontSize: 10,
                          color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                        ),
                      );
                    },
                  ),
                ),
                rightTitles: const AxisTitles(),
                topTitles: const AxisTitles(),
              ),
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                getDrawingHorizontalLine: (value) => FlLine(
                  color: isDarkMode ? Colors.grey[700]! : Colors.grey[200]!,
                  strokeWidth: 1,
                ),
              ),
              borderData: FlBorderData(show: false),
              barGroups: weeklySpO2Values.asMap().entries.map((entry) {
                final index = entry.key;
                final value = entry.value;
                Color barColor;

                // تحديد لون العمود بناءً على قيمة SpO2
                if (value >= 95) {
                  barColor = normalZoneColor;
                } else if (value >= 90) {
                  barColor = mildZoneColor;
                } else if (value >= 80) {
                  barColor = moderateZoneColor;
                } else {
                  barColor = severeZoneColor;
                }

                return BarChartGroupData(
                  x: index,
                  barRods: [
                    BarChartRodData(
                      toY: value,
                      color: barColor,
                      width: 16,
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
        ),
      ],
    );
  }





}

class LegendItem {
  final Color color;
  final String text;

  const LegendItem({required this.color, required this.text});
}