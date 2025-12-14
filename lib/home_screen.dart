import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'login.dart';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:ui' as ui;
import 'package:flutter/services.dart';
import 'package:flutter_linkify/flutter_linkify.dart';
import 'package:url_launcher/url_launcher.dart';
import 'health_charts.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import 'package:flutter_health_connect/flutter_health_connect.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'custom_mood_assessment.dart'; // أو أي مسار صحيح لهذا الملف







class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {

  late TabController _tabController;
  bool _isDarkMode = false;
  bool _isSyncing = false;
  bool isSupported = false;
  bool isAvailable = false;
  File? _profileImage;
  final ImagePicker _picker = ImagePicker();
  String _healthAnalysis = '';
  bool _isAnalyzing = false;
  List<FlSpot> _stepsHistory = [];
  List<FlSpot> _caloriesHistory = [];
  List<FlSpot> _deepSleepHistory = [];
  List<FlSpot> _remSleepHistory = [];
  List<FlSpot> _lightSleepHistory = [];
  List<FlSpot> _awakeHistory = [];
  List<FlSpot> _hourlyHeartRateSpots = [];
  List<FlSpot> _sdnnSpots = [];
  List<FlSpot> _rmssdSpots = [];
  List<double> _weeklySpO2Values = [];
  bool _isAnalyzingMentalHealth = false;
  String _mentalHealthAnalysisResult = '';
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
  FlutterLocalNotificationsPlugin();
  final GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey = GlobalKey();







  // بنية الجسم
  String height = '';
  String weight = '';
  String muscleMass = '';
  String bodyFatPercentage = '';
  String bodyFatKg = '';
  String bodyWater = '';
  String bmi = '';
  String bmr = '';
  String lbm = '';


  // النشاط اليومي
  String totalCaloriesBurned = '';
  String steps = '';
  String distance = '';
  String exercise = '';

  // النوم
  String totalSleepTime = '';
  String wakeUpTime = '';
  String remSleep = '';
  String lightSleep = '';
  String deepSleep = '';
  String bloodOxygenLevelAvg = '';
  String sleepEfficiency = '';
  String sleepquality = '';

  // المؤشرات الحيوية
  String heartRateMax = '';
  String heartRateMin = '';
  String heartRateAvg = '';
  String hrvSDNN = '';
  String hrvRMSSD = '';
  String stressLevel = '';
  String bloodGlucoseBeforeMeal = '';
  String bloodGlucoseAfterMeal = '';
  String systolicBloodPressure = '';
  String diastolicBloodPressure = '';
  String _manualSystolic = '';
  String _manualDiastolic = '';
  String _manualGlucoseBefore = '';
  String _manualGlucoseAfter = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _requestNotificationPermission();
    _handleInitialData();


    const channel = MethodChannel('app.channel.notification');
    channel.setMethodCallHandler((call) async {
      if (call.method == 'showMoodAssessment') {
        final sdnn = call.arguments['sdnn'] as double?;
        final rmssd = call.arguments['rmssd'] as double?;

        if (mounted) {
          _showMoodAssessment(
            fromNotification: true,
            sdnn: sdnn,
            rmssd: rmssd,
          );
        }
      }
      return null;
    });



    // العمليات المتوازية مع تحديد النوع
    Future.wait<void>([
      _loadProfileImage(),
      _loadThemePreference(),
      _loadInitialData(),
    ]);

  }
  Future<void> _loadInitialData() async {
    await Future.wait<void>([
      _loadHourlyHeartRateData(),
      _loadHRVData(),
      _loadWeeklySleepData(),
      _loadWeeklyActivityData(),
      _loadWeeklySpO2Data(),
      _loadHealthDataFromFirestore(),
    ]);
  }
   List<HealthConnectDataType> types = [
     HealthConnectDataType.ActiveCaloriesBurned,
     HealthConnectDataType.BasalBodyTemperature,
     HealthConnectDataType.BasalMetabolicRate,
     HealthConnectDataType.BloodGlucose,
     HealthConnectDataType.BloodPressure,
     HealthConnectDataType.BodyFat,
     HealthConnectDataType.BodyTemperature,
     HealthConnectDataType.BoneMass,
     HealthConnectDataType.CervicalMucus,
     HealthConnectDataType.CyclingPedalingCadence,
     HealthConnectDataType.Distance,
     HealthConnectDataType.ElevationGained,
     HealthConnectDataType.ExerciseSession,
     HealthConnectDataType.FloorsClimbed,
     HealthConnectDataType.HeartRate,
     HealthConnectDataType.Height,
     HealthConnectDataType.Hydration,
     HealthConnectDataType.LeanBodyMass,
     HealthConnectDataType.MenstruationFlow,
     HealthConnectDataType.Nutrition,
     HealthConnectDataType.OvulationTest,
     HealthConnectDataType.OxygenSaturation,
     HealthConnectDataType.Power,
     HealthConnectDataType.RespiratoryRate,
     HealthConnectDataType.RestingHeartRate,
     HealthConnectDataType.SexualActivity,
     HealthConnectDataType.SleepSession,
     HealthConnectDataType.SleepStage,
     HealthConnectDataType.Speed,
     HealthConnectDataType.StepsCadence,
     HealthConnectDataType.Steps,
     HealthConnectDataType.TotalCaloriesBurned,
     HealthConnectDataType.Vo2Max,
     HealthConnectDataType.Weight,
     HealthConnectDataType.WheelchairPushes,
   ];

  Future<void> _requestHealthConnectPermissions(BuildContext context) async {
    try {
      final isSupported = await _isHealthConnectSupported();
      final isInstalled = await _isHealthConnectInstalled();


      if (!isSupported) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Health Connect غير مدعوم على هذا الجهاز')),
        );
        return;
      }

      if (!isInstalled) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Health Connect غير مثبت على هذا الجهاز'),
            action: SnackBarAction(
              label: 'تثبيت',
              onPressed: () {
                launchUrl(Uri.parse('market://details?id=com.google.android.apps.healthdata'));
              },
            ),
          ),
        );
        return;
      }

      final hasPermission = await HealthConnectFactory.hasPermissions(types);
      if (!context.mounted) return;

      if (hasPermission) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('الصلاحيات ممنوحة مسبقًا')),
        );
        return;
      }

      final granted = await HealthConnectFactory.requestPermissions(types );
      if (!context.mounted) return;

      if (granted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم منح الصلاحيات بنجاح')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم رفض الصلاحيات')),
        );
      }
    } catch (e, stackTrace) {
      debugPrint('خطأ في طلب صلاحيات Health Connect: $e\n$stackTrace');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('حدث خطأ أثناء طلب الصلاحيات: ${e.toString()}')),
        );
      }
    }
  }

  Future<void> _openHealthConnectSettings(BuildContext context) async {
    try {
      await HealthConnectFactory.openHealthConnectSettings();
    } catch (e, stackTrace) {
      debugPrint('خطأ في فتح إعدادات Health Connect: $e\n$stackTrace');
      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('حدث خطأ أثناء فتح الإعدادات: ${e.toString()}'),
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }
  Future<bool> _isHealthConnectSupported() async {
    try {
      return await HealthConnectFactory.isApiSupported();
    } catch (e) {
      debugPrint('Error checking Health Connect support: $e');
      return false;
    }
  }

  Future<bool> _isHealthConnectInstalled() async {
    try {
      return await HealthConnectFactory.isAvailable();
    } catch (e) {
      debugPrint('Error checking Health Connect installation: $e');
      return false;
    }
  }

  Future<void> _requestNotificationPermission() async {
    final status = await Permission.notification.status;

    if (status.isDenied) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('صلاحية الإشعارات مطلوبة'),
          content: const Text('يحتاج التطبيق إلى إذن الإشعارات لإرسال تنبيهات مهمة'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('لاحقاً'),
            ),
            TextButton(
              onPressed: () async {
                Navigator.pop(context);
                await Permission.notification.request();
                _initializeNotifications();
              },
              child: const Text('موافق'),
            ),
          ],
        ),
      );
    } else if (status.isPermanentlyDenied) {
      _openAppSettings();
    } else {
      _initializeNotifications();
    }
  }

  void _openAppSettings() async {
    await openAppSettings();
  }

  Future<void> _initializeNotifications() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
    AndroidInitializationSettings('@mipmap/ic_launcher');

    final InitializationSettings initializationSettings =
    InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: DarwinInitializationSettings(),
    );

    await flutterLocalNotificationsPlugin.initialize(initializationSettings);
  }

  Future<void> _handleInitialData() async {
    try {
      final channel = const MethodChannel('app.channel.notification');
      final data = await channel.invokeMethod<Map>('initialData');

      if (data != null && mounted) {
        setState(() {
          // تحديد التبويب المستهدف
          _tabController.index = data['tabIndex'] ?? 0;

          // معالجة بيانات التحليل الصحي
          if (data.containsKey('analysis')) {
            _healthAnalysis = data['analysis'] ?? '';
          }

          // معالجة بيانات الصحة النفسية (الجديدة)
          if (data.containsKey('mental_health_analysis')) {
            _mentalHealthAnalysisResult = data['mental_health_analysis'] ?? '';
          }

          // معالجة طلب فتح تقييم الحالة المزاجية من الإشعار
          if (data.containsKey('show_mood_assessment') &&
              data['show_mood_assessment'] == true) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _showMoodAssessment(
                fromNotification: true,
                sdnn: data['hrv_sdnn']?.toDouble(),
                rmssd: data['hrv_rmssd']?.toDouble(),
              );
            });
          }
        });
      }
    } catch (e) {
      debugPrint('Error handling initial data: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('حدث خطأ في تحميل البيانات الأولية')),
        );
      }
    }
  }
  void _showMoodAssessment({
    bool fromNotification = false,
    double? sdnn,
    double? rmssd,
  }) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CustomMoodAssessment(
          fromNotification: fromNotification,
          sdnn: sdnn,
          rmssd: rmssd,
          isDarkMode: _isDarkMode,
        ),
      ),
    );
  }




  Future<void> _loadWeeklySpO2Data() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final now = DateTime.now();

      // حساب السبت الماضي بدقة
      final startOfWeek = now.subtract(Duration(days: (now.weekday + 1) % 7));
      final endOfWeek = now;

      debugPrint('🔍 نطاق البحث: من ${DateFormat('EEEE yyyy-MM-dd').format(startOfWeek)} إلى ${DateFormat('EEEE yyyy-MM-dd').format(endOfWeek)}');

      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('VitalSigns')
          .where('timestamp', isGreaterThanOrEqualTo: startOfWeek)
          .where('timestamp', isLessThanOrEqualTo: endOfWeek)
          .orderBy('timestamp', descending: true) // الأحدث أولاً
          .get();

      debugPrint('📊 عدد السجلات المسترجعة: ${snapshot.docs.length}');

      final Map<int, double> dailyReadings = {};

      for (final doc in snapshot.docs) {
        final data = doc.data();
        final timestamp = (data['timestamp'] as Timestamp?)?.toDate();
        if (timestamp == null) continue;

        // حساب يوم الأسبوع (0=السبت، 6=الجمعة)
        final dayOfWeek = (timestamp.weekday + 1) % 7;
        final spo2Value = (data['spo2'] as num?)?.toDouble();

        if (spo2Value != null && !dailyReadings.containsKey(dayOfWeek)) {
          dailyReadings[dayOfWeek] = spo2Value;
          debugPrint('✅ يوم ${_getDayName(dayOfWeek)}: $spo2Value%');
        }
      }

      // تعبئة القيم الأسبوعية (0 للايام بدون بيانات)
      final weeklySpO2Values = List.generate(7, (i) => dailyReadings[i] ?? 0.0);

      debugPrint('📈 القيم النهائية: ${weeklySpO2Values.asMap().entries.map((e) => '${_getDayName(e.key)}: ${e.value}%').join(', ')}');

      setState(() {
        _weeklySpO2Values = weeklySpO2Values;
      });

    } catch (e) {
      debugPrint('❌ خطأ: ${e.toString()}');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('فشل تحميل بيانات SpO2'),
          backgroundColor: Colors.red[800],
        ),
      );
    }
  }

// دالة مساعدة للحصول على اسم اليوم
  String _getDayName(int dayIndex) {
    const days = ['السبت', 'الأحد', 'الإثنين', 'الثلاثاء', 'الأربعاء', 'الخميس', 'الجمعة'];
    return days[dayIndex];
  }
  // دالة لجلب بيانات معدل ضربات القلب اليومية
  Future<void> _loadHourlyHeartRateData() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final now = DateTime.now();
      final startOfDay = DateTime(now.year, now.month, now.day);

      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('VitalSigns')
          .where('timestamp', isGreaterThanOrEqualTo: startOfDay)
          .orderBy('timestamp')
          .get();

      final hourlyAverages = List<double?>.filled(24, null);
      final hourlyCounts = List<int>.filled(24, 0);

      for (final doc in snapshot.docs) {
        final data = doc.data();
        final timestamp = (data['timestamp'] as Timestamp).toDate();
        final hour = timestamp.hour;

        final heartRateAvg = (data['heartRateAvg'] as num?)?.toDouble();
        if (heartRateAvg != null) {
          hourlyAverages[hour] = (hourlyAverages[hour] ?? 0) + heartRateAvg;
          hourlyCounts[hour]++;
        }
      }

      setState(() {
        _hourlyHeartRateSpots = hourlyAverages.asMap().entries.map((entry) {
          final hour = entry.key;
          final total = entry.value;
          final count = hourlyCounts[hour];
          final avg = (total != null && count > 0) ? total / count : 72.0;
          return FlSpot(hour.toDouble(), avg);
        }).toList();
      });
    } catch (e) {
      debugPrint('خطأ في جلب بيانات معدل ضربات القلب: $e');
    }
  }

  Future<void> _loadHRVData() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final now = DateTime.now();
      final startOfDay = DateTime(now.year, now.month, now.day);

      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('VitalSigns')
          .where('timestamp', isGreaterThanOrEqualTo: startOfDay)
          .where('timestamp', isLessThanOrEqualTo: now)
          .orderBy('timestamp')
          .get();

      final List<FlSpot> sdnnSpots = [];
      final List<FlSpot> rmssdSpots = [];

      for (final doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>?;
        if (data == null) continue;

        final timestamp = (data['timestamp'] as Timestamp?)?.toDate();
        if (timestamp == null) continue;

        // تحويل الوقت إلى قيمة عشرية (0.0 إلى 24.0)
        final hour = timestamp.hour;
        final minute = timestamp.minute;
        final timeOfDay = hour + minute / 60.0;

        final sdnn = (data['hrvSDNN'] as num?)?.toDouble();
        final rmssd = (data['hrvRMSSD'] as num?)?.toDouble();

        if (sdnn != null && sdnn > 0) {
          sdnnSpots.add(FlSpot(timeOfDay, sdnn));
        }

        if (rmssd != null && rmssd > 0) {
          rmssdSpots.add(FlSpot(timeOfDay, rmssd));
        }
      }

      // ترتيب النقاط حسب الوقت
      sdnnSpots.sort((a, b) => a.x.compareTo(b.x));
      rmssdSpots.sort((a, b) => a.x.compareTo(b.x));

      setState(() {
        _sdnnSpots = sdnnSpots;
        _rmssdSpots = rmssdSpots;
      });

      debugPrint('تم تحميل ${sdnnSpots.length} قراءة SDNN');
      debugPrint('تم تحميل ${rmssdSpots.length} قراءة RMSSD');
    } catch (e) {
      debugPrint('خطأ في جلب بيانات HRV: $e');
      setState(() {
        _sdnnSpots = [];
        _rmssdSpots = [];
      });
    }
  }

  Future<void> _loadWeeklySleepData() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final now = DateTime.now();
      // حساب السبت الماضي (بداية الأسبوع الحالي)
      final startOfWeek = now.subtract(Duration(days: (now.weekday + 1) % 7));
      // النهاية تكون اليوم الحالي
      final endOfWeek = now;

      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('SleepData')
          .where('timestamp', isGreaterThanOrEqualTo: startOfWeek)
          .where('timestamp', isLessThanOrEqualTo: endOfWeek)
          .orderBy('timestamp')
          .get();

      final Map<int, QueryDocumentSnapshot<Map<String, dynamic>>> lastDocsPerDay = {};

      for (final doc in snapshot.docs) {
        final data = doc.data();
        final timestamp = (data['timestamp'] as Timestamp?)?.toDate();
        if (timestamp == null) continue;

        // حساب يوم الأسبوع (0 = السبت، 6 = الجمعة)
        final dayOfWeek = (timestamp.weekday + 1) % 7;

        // الاحتفاظ بأحدث سجل لكل يوم
        final existingDoc = lastDocsPerDay[dayOfWeek];
        final existingTimestamp = existingDoc?.data()['timestamp'] as Timestamp?;

        if (existingDoc == null || (existingTimestamp?.toDate().isBefore(timestamp) ?? false)) {
          lastDocsPerDay[dayOfWeek] = doc;
        }
      }

      // إعداد مصفوفة لأيام الأسبوع (7 أيام × 4 مراحل نوم)
      final dailySleepStages = List.generate(7, (_) => [0.0, 0.0, 0.0, 0.0]);

      // ملء البيانات من أحدث السجلات
      lastDocsPerDay.forEach((day, doc) {
        final data = doc.data();
        dailySleepStages[day][0] = (data['sleepDeepMinutes'] as num?)?.toDouble() ?? 0;
        dailySleepStages[day][1] = (data['sleepREMMinutes'] as num?)?.toDouble() ?? 0;
        dailySleepStages[day][2] = (data['sleepLightMinutes'] as num?)?.toDouble() ?? 0;
        dailySleepStages[day][3] = (data['sleepAwakeMinutes'] as num?)?.toDouble() ?? 0;
      });

      // تحديث حالة التطبيق بالبيانات الجديدة
      setState(() {
        _deepSleepHistory = dailySleepStages.asMap().entries
            .map((e) => FlSpot(e.key.toDouble(), e.value[0]))
            .toList();
        _remSleepHistory = dailySleepStages.asMap().entries
            .map((e) => FlSpot(e.key.toDouble(), e.value[1]))
            .toList();
        _lightSleepHistory = dailySleepStages.asMap().entries
            .map((e) => FlSpot(e.key.toDouble(), e.value[2]))
            .toList();
        _awakeHistory = dailySleepStages.asMap().entries
            .map((e) => FlSpot(e.key.toDouble(), e.value[3]))
            .toList();
      });

    } catch (e) {
      debugPrint('خطأ في جلب بيانات النوم: $e');
    }
  }


  Future<void> _loadWeeklyActivityData() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final now = DateTime.now();

      // حساب السبت الماضي (بداية الأسبوع الحالي)
      final startOfWeek = now.subtract(Duration(days: (now.weekday + 1) % 7));
      // النهاية تكون اليوم الحالي
      final endOfWeek = now;

      final querySnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('DailyActivity')
          .where('timestamp', isGreaterThanOrEqualTo: startOfWeek)
          .where('timestamp', isLessThanOrEqualTo: endOfWeek)
          .orderBy('timestamp')
          .get();

      debugPrint('Total activity records found: ${querySnapshot.docs.length}');

      final Map<int, QueryDocumentSnapshot<Map<String, dynamic>>> lastDocsPerDay = {};

      for (final doc in querySnapshot.docs) {
        final data = doc.data();
        final timestamp = data['timestamp'] is String
            ? DateTime.parse(data['timestamp'])
            : (data['timestamp'] as Timestamp?)?.toDate();

        if (timestamp == null) continue;

        // حساب يوم الأسبوع (0 = السبت، 6 = الجمعة)
        final dayIndex = (timestamp.weekday + 1) % 7;
        debugPrint('Processing day $dayIndex with timestamp $timestamp');

        final existingDoc = lastDocsPerDay[dayIndex];
        final existingTimestamp = existingDoc?.data()['timestamp'] is String
            ? DateTime.parse(existingDoc?.data()['timestamp'])
            : (existingDoc?.data()['timestamp'] as Timestamp?)?.toDate();

        if (existingDoc == null || (existingTimestamp?.isBefore(timestamp) ?? false)) {
          lastDocsPerDay[dayIndex] = doc;
        }
      }

      // إعداد مصفوفات للبيانات (7 أيام)
      final dailySteps = List<double>.filled(7, 0);
      final dailyCalories = List<double>.filled(7, 0);

      // ملء البيانات من أحدث السجلات
      lastDocsPerDay.forEach((day, doc) {
        final data = doc.data();
        debugPrint('Day $day data: ${data.toString()}');

        if (day >= 0 && day < 7) {
          dailySteps[day] = (data['steps'] as num?)?.toDouble() ?? 0;
          dailyCalories[day] = (data['calories'] as num?)?.toDouble() ?? 0;
        }
      });

      setState(() {
        _stepsHistory = dailySteps.asMap().entries
            .map((e) => FlSpot(e.key.toDouble(), e.value))
            .toList();
        _caloriesHistory = dailyCalories.asMap().entries
            .map((e) => FlSpot(e.key.toDouble(), e.value))
            .toList();
      });

    } catch (e) {
      debugPrint('خطأ في جلب بيانات النشاط: $e');
      // يمكن إضافة رسالة للمستخدم هنا
    }
  }




  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }


  Future<void> _loadThemePreference() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isDarkMode = prefs.getBool('isDarkMode') ?? false;
    });
  }

  Future<void> _saveThemePreference(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isDarkMode', value);
  }

  void _toggleDarkMode(bool value) {
    setState(() {
      _isDarkMode = value;
    });
    _saveThemePreference(value);
  }



  void _showBloodPressureInputDialog() {
    setState(() {
      _manualSystolic = systolicBloodPressure;
      _manualDiastolic = diastolicBloodPressure;
    });
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('إدخال ضغط الدم'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                decoration: const InputDecoration(labelText: 'الانقباضي (mmHg)'),
                keyboardType: TextInputType.number,
                onChanged: (value) => _manualSystolic = value,
                controller: TextEditingController(text: _manualSystolic),
              ),
              TextField(
                decoration: const InputDecoration(labelText: 'الانبساطي (mmHg)'),
                keyboardType: TextInputType.number,
                onChanged: (value) => _manualDiastolic = value,
                controller: TextEditingController(text: _manualDiastolic),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('إلغاء'),
            ),
            TextButton(
              onPressed: () {
                _saveBloodPressureData();
                Navigator.pop(context);
              },
              child: const Text('حفظ'),
            ),
          ],
        );
      },
    )..then((_) => setState(() {}));
  }


  void _showBloodSugarInputDialog() {
    setState(() {
      _manualGlucoseBefore = bloodGlucoseBeforeMeal;
      _manualGlucoseAfter = bloodGlucoseAfterMeal;
    });
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('إدخال مستوى السكر'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                decoration: const InputDecoration(labelText: 'قبل الوجبة (mg/dl)'),
                keyboardType: TextInputType.number,
                onChanged: (value) => _manualGlucoseBefore = value,
                controller: TextEditingController(text: _manualGlucoseBefore),
              ),
              TextField(
                decoration: const InputDecoration(labelText: 'بعد الوجبة (mg/dl)'),
                keyboardType: TextInputType.number,
                onChanged: (value) => _manualGlucoseAfter = value,
                controller: TextEditingController(text: _manualGlucoseAfter),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('إلغاء'),
            ),
            TextButton(
              onPressed: () {
                _saveBloodSugarData();
                Navigator.pop(context);
              },
              child: const Text('حفظ'),
            ),
          ],
        );
      },
    ).then((_) => setState(() {}));
  }

  Future<void> _saveBloodPressureData() async {
    if (_manualSystolic.isNotEmpty && _manualDiastolic.isNotEmpty) {
      setState(() {
        systolicBloodPressure = _manualSystolic;
        diastolicBloodPressure = _manualDiastolic;
      });

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('systolic', _manualSystolic);
      await prefs.setString('diastolic', _manualDiastolic);
      await _sendBloodPressureToAndroid(_manualSystolic, _manualDiastolic);


      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم حفظ بيانات ضغط الدم بنجاح')),
      );
    }
  }

  Future<void> _saveBloodSugarData() async {
    if (_manualGlucoseBefore.isNotEmpty || _manualGlucoseAfter.isNotEmpty) {
      setState(() {
        if (_manualGlucoseBefore.isNotEmpty) bloodGlucoseBeforeMeal = _manualGlucoseBefore;
        if (_manualGlucoseAfter.isNotEmpty) bloodGlucoseAfterMeal = _manualGlucoseAfter;
      });

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('glucoseBefore', _manualGlucoseBefore);
      await prefs.setString('glucoseAfter', _manualGlucoseAfter);
      await _sendBloodSugarToAndroid(_manualGlucoseBefore, _manualGlucoseAfter);


      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم حفظ بيانات السكر بنجاح')),
      );
    }
  }

  Future<void> _sendBloodPressureToAndroid(String systolic, String diastolic) async {
    const platform = MethodChannel('app.channel.notification');
    try {
      await platform.invokeMethod('saveBloodPressure', {
        'systolic': systolic,
        'diastolic': diastolic,
      });
    } catch (e) {
      print('Failed to send blood pressure to Android: $e');
    }
  }

  Future<void> _sendBloodSugarToAndroid(String glucoseBefore, String glucoseAfter) async {
    const platform = MethodChannel('app.channel.notification');
    try {
      await platform.invokeMethod('saveBloodSugar', {
        'glucoseBefore': glucoseBefore,
        'glucoseAfter': glucoseAfter,
      });
    } catch (e) {
      print('Failed to send blood pressure to Android: $e');
    }
  }


  Future<void> _loadHealthDataFromFirestore() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('المستخدم غير مسجل دخول');
      }

      final db = FirebaseFirestore.instance;
      final userRef = db.collection('users').doc(user.uid);

      // جلب أحدث سجل من كل مجموعة
      final latestDataFutures = {
        'body': userRef.collection('BodyComposition')
            .orderBy('timestamp', descending: true)
            .limit(1)
            .get(),
        'activity': userRef.collection('DailyActivity')
            .orderBy('timestamp', descending: true)
            .limit(1)
            .get(),
        'sleep': userRef.collection('SleepData')
            .orderBy('timestamp', descending: true)
            .limit(1)
            .get(),
        'vitals': userRef.collection('VitalSigns')
            .orderBy('timestamp', descending: true)
            .limit(1)
            .get(),
      };


      // تنفيذ جميع الاستعلامات بشكل متوازي
      final latestResults = await Future.wait(latestDataFutures.values);

      // معالجة أحدث البيانات
      final bodyData = latestResults[0].docs.isNotEmpty ? latestResults[0].docs.first.data() : {};
      final activityData = latestResults[1].docs.isNotEmpty ? latestResults[1].docs.first.data() : {};
      final sleepData = latestResults[2].docs.isNotEmpty ? latestResults[2].docs.first.data() : {};
      final vitalsData = latestResults[3].docs.isNotEmpty ? latestResults[3].docs.first.data() : {};

      // تحديث حالة التطبيق
      setState(() {
        // بنية الجسم
        if (bodyData.isNotEmpty) {
          height = bodyData['height']?.toString() ?? '';
          weight = bodyData['weight']?.toString() ?? '';
          muscleMass = bodyData['muscleMassKg']?.toString() ?? '';
          bodyFatPercentage = bodyData['bodyFat']?.toString() ?? '';
          bodyFatKg = bodyData['fatMassKg']?.toString() ?? '';
          bodyWater = bodyData['totalBodyWaterKg']?.toString() ?? '';
          bmi = bodyData['bmi']?.toString() ?? '';
          bmr = bodyData['bmr']?.toString() ?? '';
          lbm = bodyData['leanBodyMassKg']?.toString() ?? '';
        }

        // النشاط اليومي
        if (activityData.isNotEmpty) {
          double bmrValue = double.tryParse(bmr) ?? 0;
          double activityCalories = (activityData['calories'] as num?)?.toDouble() ?? 0;
          totalCaloriesBurned = (bmrValue + activityCalories).toString();

          steps = activityData['steps']?.toString() ?? '';
          distance = (activityData['distanceMeters'] as double?)?.toStringAsFixed(2) ?? '';
          exercise = activityData.entries
              .where((entry) => entry.key.startsWith('exerciseDuration_'))
              .map((entry) => '${entry.key.replaceAll('exerciseDuration_', '')}: ${entry.value ?? 0} min')
              .join('\n');
        }

        // النوم - الجزء المعدل بالكامل
        if (sleepData.isNotEmpty) {
          totalSleepTime = sleepData['sleepTotalMinutes']?.toString() ?? '0';
          deepSleep = sleepData['sleepDeepMinutes']?.toString() ?? '0';
          remSleep = sleepData['sleepREMMinutes']?.toString() ?? '0';
          lightSleep = sleepData['sleepLightMinutes']?.toString() ?? '0';
          wakeUpTime = sleepData['sleepAwakeMinutes']?.toString() ?? '0';
          bloodOxygenLevelAvg = sleepData['spo2']?.toString() ?? '0';

        }

        // المؤشرات الحيوية
        if (vitalsData.isNotEmpty) {
          heartRateMax = vitalsData['heartRateMax']?.toString() ?? '';
          heartRateMin = vitalsData['heartRateMin']?.toString() ?? '';
          heartRateAvg = vitalsData['heartRateAvg']?.toString() ?? '';
          hrvSDNN = vitalsData['hrvSDNN']?.toString() ?? '';
          hrvRMSSD = vitalsData['hrvRMSSD']?.toString() ?? '';
          bloodOxygenLevelAvg = vitalsData['spo2']?.toString() ?? '';
          systolicBloodPressure = vitalsData['systolicBloodPressure']?.toString() ?? '';
          diastolicBloodPressure = vitalsData['diastolicBloodPressure']?.toString() ?? '';
          bloodGlucoseBeforeMeal = vitalsData['bloodGlucoseBeforeMeal']?.toString() ?? '';
          bloodGlucoseAfterMeal = vitalsData['bloodGlucoseAfterMeal']?.toString() ?? '';
        }


      });
    } catch (e) {
      debugPrint('فشل تحميل البيانات: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('حدث خطأ في جلب البيانات: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData darkTheme = ThemeData.dark().copyWith(
      primaryColor: const Color(0xFF6A74CF),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.grey[900],
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF6A74CF)),
      ),
    );

    final ThemeData lightTheme = ThemeData(
      primarySwatch: Colors.blue,
      scaffoldBackgroundColor: Colors.white,
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: IconThemeData(color: Color(0xFF6A74CF)),
      ),
    );

    return MaterialApp(
      theme: _isDarkMode ? darkTheme : lightTheme,
      home: DefaultTabController(
        key: scaffoldMessengerKey,
        length: 2,
        child: Scaffold(
          backgroundColor: _isDarkMode ? Colors.grey[900] : Colors.white,
          appBar: AppBar(
            title:  Text(
              "صحتـــــــك",
              style: TextStyle(
                color: _isDarkMode ? Colors.white : Colors.grey[600],
                fontWeight: FontWeight.bold,
              ),
            ),
            backgroundColor: _isDarkMode ? Colors.grey[900] : Colors.white,
            elevation: 0,
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(48.0),
              child: Theme(
                data: Theme.of(context).copyWith(
                  tabBarTheme: const TabBarThemeData(
                    labelColor: Color(0xFF6A74CF),
                    unselectedLabelColor: Colors.grey,
                    indicator: UnderlineTabIndicator(
                      borderSide: BorderSide(
                        width: 2.0,
                        color: Color(0xFF6A74CF),
                      ),
                    ),
                  ),
                ),
                child: TabBar(
                  controller: _tabController,
                  tabs: const [
                    Tab(icon: Icon(Icons.monitor_heart)), // البيانات الحيوية
                    Tab(icon: Icon(Icons.analytics)), // تحليل صحي
                    Tab(icon: Icon(Icons.psychology)),
                    Tab(icon: Icon(Icons.settings)),
                  ],
                ),
              ),
            ),
          ),
          body: TabBarView(
            controller: _tabController,
            children: [
              _buildVitalDataTab(),
              _buildAnalysisTab(),
              _buildMentalHealthTab(),
              _buildSettingsTab(context),
            ],
          ),

        ),
      ),
    );
  }

  Widget _buildAnalysisTab() {
    Widget buildContentWithYoutubeSupport(String text) {
      final youtubeRegex = RegExp(r'https?://(?:www\.)?(?:youtube\.com/watch\?v=|youtu\.be/)\S+');
      final match = youtubeRegex.firstMatch(text);

      if (match != null) {
        final videoId = YoutubePlayer.convertUrlToId(match.group(0)!);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Linkify(
              onOpen: (link) async {
                final uri = Uri.parse(link.url);
                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                }
              },
              text: text,
              style: TextStyle(
                fontSize: 16,
                color: _isDarkMode ? Colors.white : Colors.black,
              ),
              linkStyle: const TextStyle(
                color: Colors.blue,
                decoration: TextDecoration.underline,
              ),
              textDirection: ui.TextDirection.rtl,
            ),
            const SizedBox(height: 10),
            YoutubePlayer(
              controller: YoutubePlayerController(
                initialVideoId: videoId!,
                flags: const YoutubePlayerFlags(autoPlay: false),
              ),
              showVideoProgressIndicator: true,
            ),
          ],
        );
      } else {
        return Linkify(
          onOpen: (link) async {
            final uri = Uri.parse(link.url);
            if (await canLaunchUrl(uri)) {
              await launchUrl(uri, mode: LaunchMode.externalApplication);
            }
          },
          text: text,
          style: TextStyle(
            fontSize: 16,
            color: _isDarkMode ? Colors.white : Colors.black,
          ),
          linkStyle: const TextStyle(
            color: Colors.blue,
            decoration: TextDecoration.underline,
          ),
          textDirection: ui.TextDirection.rtl,
        );
      }
    }

    return Scaffold(
        body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
      child: Column(
        children: [
          _buildGroupTitle("التقارير الصحية"),
          Container(
            margin: const EdgeInsets.only(bottom: 15),
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              color: _isDarkMode ? Colors.grey[800] : const Color(0xFFF5F6FA),
              borderRadius: BorderRadius.circular(15),
            ),
            child: Column(
              children: [
                _healthAnalysis.isEmpty
                    ? const Text("انقر لمعرفة مستواك الصحي")
                    : buildContentWithYoutubeSupport(_healthAnalysis),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: _isAnalyzing ? null : _analyzeHealthData,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6A74CF),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: _isAnalyzing
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text("تحليل البيانات", style: TextStyle(color: Colors.white)),
                ),
              ],
            ),
          ),
          _buildGroupTitle("التقارير اليومية"),
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('users')
                .doc(FirebaseAuth.instance.currentUser?.uid) // 1. قد يكون null
                .collection('HealthAnalysis')
                .where(FieldPath.documentId, isGreaterThanOrEqualTo: DateFormat('yyyy-MM-dd').format(DateTime.now()))
                .where(FieldPath.documentId, isLessThan: DateFormat('yyyy-MM-dd').format(DateTime.now().add(const Duration(days: 1))))
                .orderBy(FieldPath.documentId, descending: true)
                .snapshots(),
            builder: (context, snapshot) {
              // 2. التحقق من حالة الاتصال أولاً
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              // 3. التحقق من الأخطاء
              if (snapshot.hasError) {
                return Text("حدث خطأ: ${snapshot.error.toString()}");
              }

              // 4. التحقق من وجود المستخدم
              if (FirebaseAuth.instance.currentUser == null) {
                return const Text("يجب تسجيل الدخول لعرض التقارير");
              }

              // 5. التحقق من وجود البيانات بشكل آمن
              final docs = snapshot.data?.docs ?? []; // تجنب استخدام !

              if (docs.isEmpty) {
                return const Text("لا توجد تقارير لهذا اليوم");
              }

              return Column(
                children: docs.map((doc) {
                  // 6. التحقق من بيانات المستند
                  final data = doc.data() as Map<String, dynamic>? ?? {}; // قيمة افتراضية فارغة

                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(15),
                    decoration: BoxDecoration(
                      color: _isDarkMode ? Colors.grey[700] : Colors.grey[200],
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        buildContentWithYoutubeSupport(
                          data['analysis'] ?? data['recommendations'] ?? 'لا يوجد محتوى',
                        ),
                        const SizedBox(height: 10),
                        Text(
                          doc.id,
                          style: TextStyle(
                            color: _isDarkMode ? Colors.grey[400] : Colors.grey[600],
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    ),
    );
  }

  Widget _buildMentalHealthTab() {
    Widget buildContentWithYoutubeSupport(String text) {
      final youtubeRegex = RegExp(r'https?://(?:www\.)?(?:youtube\.com/watch\?v=|youtu\.be/)\S+');
      final match = youtubeRegex.firstMatch(text);

      if (match != null) {
        final videoId = YoutubePlayer.convertUrlToId(match.group(0)!);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Linkify(
              onOpen: (link) async {
                final uri = Uri.parse(link.url);
                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                }
              },
              text: text,
              style: TextStyle(
                fontSize: 16,
                color: _isDarkMode ? Colors.white : Colors.black,
              ),
              linkStyle: const TextStyle(
                color: Colors.blue,
                decoration: TextDecoration.underline,
              ),
              textDirection: ui.TextDirection.rtl,
            ),
            const SizedBox(height: 10),
            YoutubePlayer(
              controller: YoutubePlayerController(
                initialVideoId: videoId!,
                flags: const YoutubePlayerFlags(autoPlay: false),
              ),
              showVideoProgressIndicator: true,
            ),
          ],
        );
      } else {
        return Linkify(
          onOpen: (link) async {
            final uri = Uri.parse(link.url);
            if (await canLaunchUrl(uri)) {
              await launchUrl(uri, mode: LaunchMode.externalApplication);
            }
          },
          text: text,
          style: TextStyle(
            fontSize: 16,
            color: _isDarkMode ? Colors.white : Colors.black,
          ),
          linkStyle: const TextStyle(
            color: Colors.blue,
            decoration: TextDecoration.underline,
          ),
          textDirection: ui.TextDirection.rtl,
        );
      }
    }

    return Scaffold(
      floatingActionButton: GestureDetector(
        onTap: () {
          _showMentalHealthQuestions();

        },

        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF6A74CF), Color(0xFF89D3FB)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(30),
            boxShadow: [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 8,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: const Text(
            "DASS Test",
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,

      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
      child: Column(
        children: [
          _buildGroupTitle("تقارير الصحة النفسية"),
          Container(
            margin: const EdgeInsets.only(bottom: 15),
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              color: _isDarkMode ? Colors.grey[800] : const Color(0xFFF5F6FA),
              borderRadius: BorderRadius.circular(15),
            ),
            child: Column(
              children: [
                _mentalHealthAnalysisResult.isEmpty
                    ? const Text("انقر لمعرفة مستوى صحتك النفسية")
                    : buildContentWithYoutubeSupport(_mentalHealthAnalysisResult),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: _isAnalyzingMentalHealth ? null : _analyzeMentalHealthData,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6A74CF),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: _isAnalyzingMentalHealth
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text("تحليل البيانات", style: TextStyle(color: Colors.white)),
                ),
              ],
            ),
          ),
          _buildGroupTitle("التقارير اليومية"),
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('users')
                .doc(FirebaseAuth.instance.currentUser?.uid) // 1. قد يكون null
                .collection('MentalHealthReports')
                .where(FieldPath.documentId, isGreaterThanOrEqualTo: DateFormat('yyyy-MM-dd').format(DateTime.now()))
                .where(FieldPath.documentId, isLessThan: DateFormat('yyyy-MM-dd').format(DateTime.now().add(const Duration(days: 1))))
                .orderBy(FieldPath.documentId, descending: true)
                .snapshots(),
            builder: (context, snapshot) {
              // 2. التحقق من حالة الاتصال أولاً
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              // 3. التحقق من الأخطاء
              if (snapshot.hasError) {
                return Text("حدث خطأ: ${snapshot.error.toString()}");
              }

              // 4. التحقق من وجود المستخدم
              if (FirebaseAuth.instance.currentUser == null) {
                return const Text("يجب تسجيل الدخول لعرض التقارير");
              }

              // 5. التحقق من وجود البيانات بشكل آمن
              final docs = snapshot.data?.docs ?? []; // تجنب استخدام !

              if (docs.isEmpty) {
                return const Text("لا توجد تقارير لهذا اليوم");
              }

              return Column(
                children: docs.map((doc) {
                  // 6. التحقق من بيانات المستند
                  final data = doc.data() as Map<String, dynamic>? ?? {}; // قيمة افتراضية فارغة

                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(15),
                    decoration: BoxDecoration(
                      color: _isDarkMode ? Colors.grey[700] : Colors.grey[200],
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        buildContentWithYoutubeSupport(data['analysis'] ?? 'لا يوجد محتوى'), // 7. قيمة افتراضية
                        const SizedBox(height: 10),
                        Text(
                          doc.id,
                          style: TextStyle(
                            color: _isDarkMode ? Colors.grey[400] : Colors.grey[600],
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    ),
    );
  }



  Future<void> _analyzeHealthData() async {
    setState(() => _isAnalyzing = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('المستخدم غير مسجل دخول');
      }

      final db = FirebaseFirestore.instance;
      final userRef = db.collection('users').doc(user.uid);

      // جلب أحدث سجل من كل مجموعة مع تحويل صريح للنوع
      final bodySnapshot = await userRef.collection('BodyComposition')
          .orderBy('timestamp', descending: true)
          .limit(1)
          .get();

      final activitySnapshot = await userRef.collection('DailyActivity')
          .orderBy('timestamp', descending: true)
          .limit(1)
          .get();

      final sleepSnapshot = await userRef.collection('SleepData')
          .orderBy('timestamp', descending: true)
          .limit(1)
          .get();

      final vitalsSnapshot = await userRef.collection('VitalSigns')
          .orderBy('timestamp', descending: true)
          .limit(1)
          .get();

      // تحويل النتائج إلى Map<String, dynamic> بشكل صريح
      final bodyData = bodySnapshot.docs.isNotEmpty
          ? Map<String, dynamic>.from(bodySnapshot.docs.first.data())
          : <String, dynamic>{};

      final activityData = activitySnapshot.docs.isNotEmpty
          ? Map<String, dynamic>.from(activitySnapshot.docs.first.data())
          : <String, dynamic>{};

      final sleepData = sleepSnapshot.docs.isNotEmpty
          ? Map<String, dynamic>.from(sleepSnapshot.docs.first.data())
          : <String, dynamic>{};

      final vitalsData = vitalsSnapshot.docs.isNotEmpty
          ? Map<String, dynamic>.from(vitalsSnapshot.docs.first.data())
          : <String, dynamic>{};

      if (bodyData.isEmpty && activityData.isEmpty && sleepData.isEmpty && vitalsData.isEmpty) {
        throw Exception('لا توجد بيانات صحية مخزنة');
      }

      // بناء رسالة التحليل
      final prompt = '''
أنا مساعد صحي ذكي ومتخصص.  
أرجو منك تحليل البيانات الصحية التالية بشكل دقيق:

🔹 **بنية الجسم**:
- الطول: ${_safeGetString(bodyData, 'height')} متر
- الوزن: ${_safeGetString(bodyData, 'weight')} كجم
- مؤشر كتلة الجسم (BMI): ${_safeGetString(bodyData, 'bmi')}
- نسبة الدهون: ${_safeGetBodyFatPercentage(bodyData)}%
- كتلة الدهون: ${_safeGetString(bodyData, 'fatMassKg')} كجم
- الكتلة العضلية: ${_safeGetString(bodyData, 'muscleMassKg')} كجم
- الكتلة الخالية من الدهون (LBM): ${_safeGetString(bodyData, 'leanBodyMassKg')} كجم
- ماء الجسم: ${_safeGetString(bodyData, 'totalBodyWaterKg')} كجم
- معدل الأيض الأساسي (BMR): ${_safeGetString(bodyData, 'bmr')} سعرة حرارية/يوم

🔹 **النشاط اليومي**:
- السعرات الحرارية المحروقة: ${_safeGetString(activityData, 'calories')} سعرة
- عدد الخطوات: ${_safeGetString(activityData, 'steps')}
- المسافة المقطوعة: ${_safeGetString(activityData, 'distanceMeters')} متر
${_formatExerciseData(activityData)}

🔹 **النوم**:
- إجمالي مدة النوم: ${_safeGetString(sleepData, 'sleepTotalMinutes')} دقيقة
- نوم عميق: ${_safeGetString(sleepData, 'sleepDeepMinutes')} دقيقة
- نوم خفيف: ${_safeGetString(sleepData, 'sleepLightMinutes')} دقيقة
- نوم مرحلة REM: ${_safeGetString(sleepData, 'sleepREMMinutes')} دقيقة
- وقت الاستيقاظ: ${_safeGetString(sleepData, 'sleepAwakeMinutes')} دقيقة

🔹 **المؤشرات الحيوية**:
- معدل ضربات القلب (متوسط): ${_safeGetString(vitalsData, 'heartRateAvg')} نبضة/دقيقة
- معدل ضربات القلب (أعلى قيمة): ${_safeGetString(vitalsData, 'heartRateMax')} نبضة/دقيقة
- معدل ضربات القلب (أدنى قيمة): ${_safeGetString(vitalsData, 'heartRateMin')} نبضة/دقيقة
- تقلب معدل ضربات القلب (SDNN): ${_safeGetString(vitalsData, 'hrvSDNN')} مللي ثانية
- تقلب معدل ضربات القلب (RMSSD): ${_safeGetString(vitalsData, 'hrvRMSSD')} مللي ثانية
- مستوى تشبع الأكسجين بالدم: ${_safeGetString(vitalsData, 'spo2')}%
- ضغط الدم: ${_safeGetString(vitalsData, 'systolicBloodPressure', '--')}/${_safeGetString(vitalsData, 'diastolicBloodPressure', '--')} mmHg
- سكر الدم: ${_safeGetString(vitalsData, 'bloodGlucoseBeforeMeal', '--')}/${_safeGetString(vitalsData, 'bloodGlucoseAfterMeal', '--')} mg/dl

✅ **المطلوب منك**:
1. تقديم تقييم شامل ومفصل للحالة الصحية بناءً على جميع البيانات.
2. تحليل الترابط والتكامل بين المؤشرات الحيوية والنشاط والنوم.
3. تقديم ثلاث توصيات رئيسية لتحسين الصحة العامة.
4. الإشارة إلى أي مخاطر صحية محتملة تستدعي الانتباه.
5. اقتراح خطة أسبوعية عملية لتحسين اللياقة والصحة.

**ملاحظات مهمة**:
- استخدم لغة طبية عربية فصحى، واضحة ودقيقة.
- نظم الإجابة باستخدام عناوين فرعية وفقرات واضحة.
- اجعل الإجابة مفهومة لغير المختصين أيضًا.
- الخطة الأسبوعية أجعلها على هيئة نقاط وليس جدول.
''';

      final analysis = await _callDeepSeekAPI(prompt);
      final healthVideos = await _searchYouTubeVideos('نصائح صحية ${_safeGetString(bodyData, 'bmi')}');
      final analysisWithVideos = _combineAnalysisWithVideos(analysis, healthVideos['videos']);
      await _saveAnalysisToFirestore(user.uid, analysis);
      setState(() => _healthAnalysis = analysisWithVideos);

    } catch (e) {
      setState(() {
        _healthAnalysis = 'حدث خطأ أثناء التحليل: ${e is SocketException ? 'فشل الاتصال بالخادم' : e.toString()}';
      });
    } finally {
      setState(() => _isAnalyzing = false);
    }
  }

// دالة مساعدة لاستخراج القيم بشكل آمن
  String _safeGetString(Map<String, dynamic> data, String key, [String defaultValue = 'غير متوفر']) {
    return data.containsKey(key) ? data[key]?.toString() ?? defaultValue : defaultValue;
  }

// دالة خاصة لمعالجة نسبة الدهون
  String _safeGetBodyFatPercentage(Map<String, dynamic> data) {
    if (!data.containsKey('bodyFat')) return 'غير متوفر';

    try {
      final value = data['bodyFat'] is double ? data['bodyFat'] : double.tryParse(data['bodyFat'].toString());
      return value != null ? (value * 100).toStringAsFixed(1) : 'غير متوفر';
    } catch (e) {
      return 'غير متوفر';
    }
  }

// دالة مساعدة لصياغة بيانات التمارين
  String _formatExerciseData(Map<String, dynamic> activityData) {
    try {
      final exercises = activityData.entries
          .where((entry) => entry.key.startsWith('exerciseDuration_'))
          .map((entry) => '  - ${entry.key.replaceAll('exerciseDuration_', '')}: ${entry.value?.toString() ?? '0'} دقيقة')
          .join('\n');

      return exercises.isNotEmpty
          ? 'التمارين الرياضية:\n$exercises'
          : 'التمارين الرياضية: غير متوفر';
    } catch (e) {
      return 'التمارين الرياضية: غير متوفر';
    }
  }

  Future<void> _analyzeMentalHealthData() async {
    setState(() => _isAnalyzingMentalHealth = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('المستخدم غير مسجل دخول');
      }

      final db = FirebaseFirestore.instance;
      final userRef = db.collection('users').doc(user.uid);
      final now = DateTime.now();
      final startOfDay = DateTime(now.year, now.month, now.day);
      final endOfDay = DateTime(now.year, now.month, now.day, 23, 59, 59);

      // جلب أحدث سجل للنوم
      final sleepSnapshot = await userRef.collection('SleepData')
          .orderBy('timestamp', descending: true)
          .limit(1)
          .get();

      // جلب أحدث سجل للنشاط اليومي
      final activitySnapshot = await userRef.collection('DailyActivity')
          .orderBy('timestamp', descending: true)
          .limit(1)
          .get();

      // جلب جميع قراءات HRV (SDNN, RMSSD) لليوم الحالي
      final hrvSnapshot = await userRef.collection('VitalSigns')
          .where('timestamp', isGreaterThanOrEqualTo: startOfDay)
          .where('timestamp', isLessThanOrEqualTo: endOfDay)
          .where('hrvSDNN', isNotEqualTo: null)
          .where('hrvRMSSD', isNotEqualTo: null)
          .orderBy('timestamp')
          .get();

      // تحويل النتائج إلى Map<String, dynamic>
      final sleepData = sleepSnapshot.docs.isNotEmpty
          ? Map<String, dynamic>.from(sleepSnapshot.docs.first.data())
          : <String, dynamic>{};

      final activityData = activitySnapshot.docs.isNotEmpty
          ? Map<String, dynamic>.from(activitySnapshot.docs.first.data())
          : <String, dynamic>{};

      // حساب متوسطات HRV لليوم
      double sdnnSum = 0;
      double rmssdSum = 0;
      int hrvCount = 0;

      for (final doc in hrvSnapshot.docs) {
        final data = doc.data();
        final sdnn = (data['hrvSDNN'] as num?)?.toDouble();
        final rmssd = (data['hrvRMSSD'] as num?)?.toDouble();

        if (sdnn != null && rmssd != null) {
          sdnnSum += sdnn;
          rmssdSum += rmssd;
          hrvCount++;
        }
      }

      final avgSDNN = hrvCount > 0 ? (sdnnSum / hrvCount) : null;
      final avgRMSSD = hrvCount > 0 ? (rmssdSum / hrvCount) : null;

      if (sleepData.isEmpty && activityData.isEmpty && hrvCount == 0) {
        throw Exception('لا توجد بيانات كافية للتحليل النفسي');
      }

      // بناء رسالة التحليل النفسي
      final prompt = '''
أنا مساعد الصحة النفسية الذكية. أرجو تحليل الحالة النفسية بناءً على البيانات التالية:

🔹 **بيانات النوم (آخر ليلة)**:
- إجمالي مدة النوم: ${_safeGetString(sleepData, 'sleepTotalMinutes', '0')} دقيقة
- نوم عميق: ${_safeGetString(sleepData, 'sleepDeepMinutes', '0')} دقيقة (${_calculatePercentage(sleepData, 'sleepDeepMinutes', 'sleepTotalMinutes')}%)
- نوم خفيف: ${_safeGetString(sleepData, 'sleepLightMinutes', '0')} دقيقة (${_calculatePercentage(sleepData, 'sleepLightMinutes', 'sleepTotalMinutes')}%)
- نوم حركة العين السريعة (REM): ${_safeGetString(sleepData, 'sleepREMMinutes', '0')} دقيقة (${_calculatePercentage(sleepData, 'sleepREMMinutes', 'sleepTotalMinutes')}%)
- وقت الاستيقاظ: ${_safeGetString(sleepData, 'sleepAwakeMinutes', '0')} دقيقة

🔹 **النشاط اليومي**:
- عدد الخطوات: ${_safeGetString(activityData, 'steps', '0')}
- السعرات الحرارية المحروقة: ${_safeGetString(activityData, 'calories', '0')}
- مستوى النشاط: ${_calculateActivityLevel(activityData)}

🔹 **تقلب معدل ضربات القلب (HRV)**:
- متوسط SDNN (المؤشر العام للتوتر): ${avgSDNN?.toStringAsFixed(1) ?? 'غير متوفر'} مللي ثانية
- متوسط RMSSD (المؤشر العام للاسترخاء): ${avgRMSSD?.toStringAsFixed(1) ?? 'غير متوفر'} مللي ثانية
- عدد القراءات اليومية: $hrvCount

✅ **المطلوب منك**:
1. تحليل الحالة النفسية بناءً على جودة النوم ومستويات النشاط وتقلب معدل ضربات القلب.
2. تقييم مستوى التوتر والقلق بناءً على المؤشرات الحيوية.
3. تحديد العلاقة بين جودة النوم والمزاج العام.
4. تقديم 3 توصيات لتحسين الصحة النفسية بناءً على البيانات.
5. اقتراح تمارين استرخاء مناسبة بناءً على مستوى التوتر.
6. تحذير من أي مؤشرات خطيرة تستدعي استشارة مختص.

**ملاحظات مهمة**:
- استخدم لغة عربية واضحة وسهلة الفهم.
- قدم النتائج في نقاط محددة.
- تجنب المصطلحات الطبية المعقدة.
- ركز على الجوانب العملية القابلة للتطبيق.
''';

      final analysis = await _callDeepSeekAPI(prompt);
      final mentalHealthVideos = await _searchYouTubeVideos('تحسين الصحة النفسية نصائح');
      final analysisWithVideos = _combineAnalysisWithVideos(analysis, mentalHealthVideos['videos']);
      await _saveMentalHealthAnalysisToFirestore(user.uid, analysis);
      setState(() {
        _mentalHealthAnalysisResult = analysisWithVideos;
        _isAnalyzingMentalHealth = true;
      });

    } catch (e) {
      setState(() {
        _mentalHealthAnalysisResult = 'حدث خطأ أثناء التحليل النفسي: ${e.toString()}';
      });
    } finally {
      setState(() => _isAnalyzingMentalHealth = false);
    }
  }
  String _combineAnalysisWithVideos(String analysis, List<Map<String, String>> videos) {
    if (videos.isEmpty) return analysis;

    final videosText = videos.map((video) {
      return '${video['title']}\n🔗 ${video['url']}';
    }).join('\n\n');

    return '$analysis\n\nفيديوهات مقترحة:\n$videosText';
  }

// دالة مساعدة لحساب النسب المئوية لمراحل النوم
  String _calculatePercentage(Map<String, dynamic> data, String partKey, String totalKey) {
    try {
      final part = (data[partKey] as num?)?.toDouble() ?? 0;
      final total = (data[totalKey] as num?)?.toDouble() ?? 1;
      return ((part / total) * 100).toStringAsFixed(1);
    } catch (e) {
      return '0.0';
    }
  }

// دالة لتقييم مستوى النشاط
  String _calculateActivityLevel(Map<String, dynamic> activityData) {
    final steps = (activityData['steps'] as num?)?.toInt() ?? 0;

    if (steps >= 10000) return 'عالي جداً';
    if (steps >= 7500) return 'عالي';
    if (steps >= 5000) return 'متوسط';
    if (steps >= 2500) return 'منخفض';
    return 'قليل جداً';
  }

  /// دالة مساعدة لحفظ التحليل في Firestore
  Future<void> _saveMentalHealthAnalysisToFirestore(String userId, String analysis) async {
    final now = DateTime.now();
    final documentId = DateFormat('yyyy-MM-dd_HH-mm-ss').format(now);

    // استخراج روابط YouTube من التحليل
    final youtubeLinks = analysis.split('\n')
        .where((line) => line.startsWith('🔗'))
        .map((line) => line.substring(2).trim())
        .toList();

    await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('MentalHealthReports')
        .doc(documentId)
        .set({
      'analysis': analysis,
      'youtube_links': youtubeLinks,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  Future<String> _callDeepSeekAPI(String prompt) async {
    const apiUrl = 'https://openrouter.ai/api/v1/chat/completions';
    const apiKey = ''; // مفتاح OpenRouter API

    final response = await http.post(
      Uri.parse(apiUrl),
      headers: {
        'Content-Type': 'application/json',
        'HTTP-Referer': 'health',
        'X-Title': 'HealthAnalysisApp',
      },
      body: jsonEncode({
        'model': 'deepseek/deepseek-r1:free',
        'messages': [
          {
            'role': 'user',
            'content': prompt,
          }
        ],
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('فشل الاتصال بـ DeepSeek: ${response.statusCode}');
    }

    final decodedBody = utf8.decode(response.bodyBytes);
    final responseData = jsonDecode(decodedBody);

    String answer = responseData['choices'][0]['message']['content'] ?? 'لا توجد إجابة متوفرة';

    // تنظيف الرموز غير المهمة مثل * و #
    answer = answer.replaceAll(RegExp(r'[*#]'), '');

    // فصل الجمل كل جملة في سطر جديد
    answer = answer.replaceAllMapped(RegExp(r'([!؟])'), (match) => '${match.group(0)}\n');

    // إزالة المسافات الزائدة بداية كل سطر
    answer = answer.split('\n').map((line) => line.trim()).join('\n');

    return answer;
  }
  Future<Map<String, dynamic>> _searchYouTubeVideos(String query, {String? pageToken}) async {
    const apiKey = '';
    final url = 'https://www.googleapis.com/youtube/v3/search?'
        'part=snippet'
        '&maxResults=3'
        '&q=$query'
        '&type=video'
        '&key=$apiKey'
        '&order=relevance'
        '${pageToken != null ? '&pageToken=$pageToken' : ''}';

    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body) as Map<String, dynamic>;
        final items = jsonData['items'] as List<dynamic>;

        final videos = items.map<Map<String, String>>((item) {
          final id = item['id'] as Map<String, dynamic>;
          final snippet = item['snippet'] as Map<String, dynamic>;

          return {
            'videoId': id['videoId'] as String,
            'title': snippet['title'] as String,
            'url': 'https://www.youtube.com/watch?v=${id['videoId']}',
          };
        }).toList();

        return {
          'videos': videos,
          'nextPageToken': jsonData['nextPageToken'],
        };
      }
      return {
        'videos': [],
        'nextPageToken': null,
      };
    } catch (e) {
      debugPrint('Error searching YouTube: $e');
      return {
        'videos': [],
        'nextPageToken': null,
      };
    }
  }

// دالة مساعدة لحفظ التحليل في Firestore
  Future<void> _saveAnalysisToFirestore(String userId, String analysis) async {
    final now = DateTime.now();
    final documentId = DateFormat('yyyy-MM-dd_HH-mm-ss').format(now);

    // استخراج روابط YouTube من التحليل
    final youtubeLinks = analysis.split('\n')
        .where((line) => line.startsWith('🔗'))
        .map((line) => line.substring(2).trim())
        .toList();

    await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('HealthAnalysis')
        .doc(documentId)
        .set({
      'analysis': analysis,
      'youtube_links': youtubeLinks,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }




  Widget _buildVitalDataTab() {

    return Scaffold(
      floatingActionButton: GestureDetector(
        onTap: _isSyncing
            ? null
            : () async {
          setState(() => _isSyncing = true);
          try {
            await _loadHealthDataFromFirestore();
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('تمت مزامنة البيانات بنجاح'),
                backgroundColor: Color(0xFF6A74CF),
              ),
            );
          } catch (e) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('خطأ في المزامنة: $e'),
                backgroundColor: Colors.red,
              ),
            );
          } finally {
            setState(() => _isSyncing = false);
          }
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF6A74CF), Color(0xFF89D3FB)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(30),
            boxShadow: [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 8,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: _isSyncing
              ? const SizedBox(
            height: 20,
            width: 20,
            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
          )
              : const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.sync, color: Colors.white),
              SizedBox(width: 8),
              Text("Sync", style: TextStyle(color: Colors.white)),
            ],
          ),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      body: SingleChildScrollView(
    padding: const EdgeInsets.all(20.0),
    child: Column(
    children: [
          // بنية الجسم
          _buildGroupTitle("بنية الجسم"),
          _buildBodyCompositionChartSection(),
          _buildHealthCard("الطول", height, "m", Icons.height),
          _buildHealthCard("الوزن", weight, "kg", Icons.line_weight),
          _buildHealthCard("الكتلة العضلية", muscleMass, "kg", Icons.fitness_center),
          _buildHealthCard("نسبة الدهون", bodyFatPercentage, "%", Icons.pie_chart),
          _buildHealthCard("كتلة الدهون", bodyFatKg, "kg", Icons.monitor_weight),
          _buildHealthCard("كتلة المياه", bodyWater, "kg", Icons.water_drop),
          _buildHealthCard("مؤشر كتلة الجسم(BMI)", bmi, "", Icons.calculate),
          _buildHealthCard("(BMR)معدل الأيض الأساسي", bmr, "kcal/day", Icons.local_fire_department),
          _buildHealthCard("الكتلة العضلية(LBM)", lbm, "kg", Icons.fitness_center),


          // النشاط اليومي
          _buildGroupTitle("النشاط اليومي"),
          _buildDailyActivityChartSection(),
          _instatenousData(),
          _buildHealthCard("السعرات المحروقة", totalCaloriesBurned, "cal", Icons.local_fire_department),
          _buildHealthCard("الخطوات", steps, "steps", Icons.directions_walk),
          _buildHealthCard("المسافة المقطوعة", distance, "m", Icons.directions_run),
          _buildHealthCard("التمارين", exercise, "", Icons.fitness_center),

          // النوم
          _buildGroupTitle("النوم"),
          _buildSleepChartSection(),
          _instatenousData(),
          _buildHealthCard("وقت النوم الكلي", totalSleepTime, "min", Icons.bedtime),
          _buildHealthCard("وقت الاستيقاظ", wakeUpTime, "min", Icons.alarm_add_outlined),
          _buildHealthCard("نوم حركة العين السريعة", remSleep, "min", Icons.visibility),
          _buildHealthCard("النوم الخفيف", lightSleep, "min", Icons.bedtime),
          _buildHealthCard("النوم العميق", deepSleep, "min", Icons.hotel),


          // المؤشرات الحيوية
          _buildGroupTitle("المؤشرات الحيوية"),
          _buildHrChartSection(),
          _instatenousData(),
          _buildHealthCard("معدل ضربات القلب (Avg)", heartRateAvg, "bpm", Icons.favorite),
          _buildHealthCard("معدل ضربات القلب (Max)", heartRateMax, "bpm", Icons.favorite),
          _buildHealthCard("معدل ضربات القلب (Min)", heartRateMin, "bpm", Icons.favorite),
          _buildHrvChartSection(),
          _instatenousData(),
          _buildHealthCard("تغير ضربات القلب (SDNN)", hrvSDNN, "ms", Icons.monitor_heart),
          _buildHealthCard("تغير ضربات القلب (RMSSD)", hrvRMSSD, "ms", Icons.monitor_heart),
          _buildSpo2ChartSection(),
          _instatenousData(),
          _buildHealthCard("نسبة الأكسجين", bloodOxygenLevelAvg, "%", Icons.air),
          _buildEditableHealthCard(
            "ضغط الدم (الانقباضي/الانبساطي)",
            "${systolicBloodPressure.isEmpty ? '--' : systolicBloodPressure}/${diastolicBloodPressure.isEmpty ? '--' : diastolicBloodPressure}",
            "mmHg",
            Icons.speed,
            _showBloodPressureInputDialog,
          ),

          _buildEditableHealthCard(
            "سكر الدم (قبل/بعد الأكل)",
            "${bloodGlucoseBeforeMeal.isEmpty ? '--' : bloodGlucoseBeforeMeal}/${bloodGlucoseAfterMeal.isEmpty ? '--' : bloodGlucoseAfterMeal}",
            "mg/dl",
            Icons.opacity,
            _showBloodSugarInputDialog,
          ),
        ],
      ),
    ),
    );
  }

  // في واجهة المستخدم
  _instatenousData() {
    return Column(
      children: [
        const SizedBox(height: 16),
        Text(
          'القراءة اللحظية',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: _isDarkMode ? Colors.white : Colors.grey[800],

          ),
        ),
        const SizedBox(height: 8),

      ],
    );
  }

  _buildBodyCompositionChartSection() {
    return Column(
      children: [
        const SizedBox(height: 16),
        Text(
          'بيان ملخص بنية الجسم (Body Composition) ',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: _isDarkMode ? Colors.white : Colors.grey[800],
          ),
        ),
        const SizedBox(height: 8),
        HealthCharts.bodyCompositionPieChart(
          bodyFatKg: bodyFatKg,
          muscleMass: muscleMass,
          bodyWater: bodyWater,
          weight: weight,
          isDarkMode: _isDarkMode,
        ),
      ],
    );
  }
  _buildDailyActivityChartSection() {
    return Column(
      children: [
        const SizedBox(height: 16),
        Text(
          'بيان أسبوعي للنشاط اليومي',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: _isDarkMode ? Colors.white : Colors.grey[800],
          ),
        ),
        const SizedBox(height: 8),
        HealthCharts.activityProgressChart(
          stepsSpots: _stepsHistory,
          caloriesSpots: _caloriesHistory,
          isDarkMode: _isDarkMode,
        ),
      ],
    );
  }
  _buildHrChartSection() {
    return Column(
      children: [
        const SizedBox(height: 16),
        Text(
          'بيان يومي لتقلب معدل ضربات القلب (bpm)',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: _isDarkMode ? Colors.white : Colors.grey[800],
          ),
        ),
        const SizedBox(height: 8),
        HealthCharts.heartRateChart(
          hourlySpots: _hourlyHeartRateSpots,
          isDarkMode: _isDarkMode,
        ),
      ],
    );
  }
  _buildHrvChartSection() {
    return Column(
      children: [
        const SizedBox(height: 16),
        Text(
          'بيان يومي لتقلب معدل ضربات القلب (HRV)',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: _isDarkMode ? Colors.white : Colors.grey[800],
          ),
        ),
        const SizedBox(height: 8),
        HealthCharts.hrvChart(
          sdnnSpots: _sdnnSpots,
          rmssdSpots: _rmssdSpots,
          isDarkMode: _isDarkMode,
        ),
      ],
    );
  }
  _buildSpo2ChartSection() {
    return Column(
      children: [
        const SizedBox(height: 16),
        Text(
          'بيان أسبوعي لنسبة الأكسجين في الدم (Spo2)',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: _isDarkMode ? Colors.white : Colors.grey[800],
          ),
        ),
        const SizedBox(height: 8),
        HealthCharts.spo2WeeklyChart(
          weeklySpO2Values: _weeklySpO2Values,
          isDarkMode: _isDarkMode,
        ),
      ],
    );
  }

  _buildSleepChartSection() {
    return Column(
      children: [
        const SizedBox(height: 16),
        Text(
          'بيان أسبوعي لمراحل النوم (Sleep Stages)',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: _isDarkMode ? Colors.white : Colors.grey[800],
          ),
        ),
        const SizedBox(height: 8),
        HealthCharts.sleepProgressChart(
          deepSleepSpots: _deepSleepHistory,
          remSleepSpots: _remSleepHistory,
          lightSleepSpots: _lightSleepHistory,
          awakeSpots: _awakeHistory,
          isDarkMode: _isDarkMode,
        ),
      ],
    );
  }

  Widget _buildHealthCard(String title, String value, String unit, IconData icon) {
    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: _isDarkMode ? Colors.grey[800] : const Color(0xFFF5F6FA),
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Color.fromRGBO(158, 158, 158, 0.1),
            spreadRadius: 1,
            blurRadius: 5,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF6A74CF), Color(0xFF89D3FB)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: Colors.white),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  value.isEmpty ? "غير متوفر" : "$value $unit",
                  style:  TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: _isDarkMode ? Colors.grey[400] : Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  Widget _buildEditableHealthCard(String title, String value, String unit, IconData icon, VoidCallback onEdit) {
    return GestureDetector(
      onTap: onEdit,
      child: Container(
        margin: const EdgeInsets.only(bottom: 15),
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: _isDarkMode ? Colors.grey[800] : const Color(0xFFF5F6FA),
          borderRadius: BorderRadius.circular(15),
          boxShadow: [
            BoxShadow(
              color: Color.fromRGBO(158, 158, 158, 0.1),
              spreadRadius: 1,
              blurRadius: 5,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF6A74CF), Color(0xFF89D3FB)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: Colors.white),
            ),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    value.isEmpty ? "غير متوفر" : "$value $unit",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: _isDarkMode ? Colors.grey[400] : Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: Icon(Icons.edit, color: Color(0xFF6A74CF)),
              onPressed: onEdit,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingsTab(BuildContext context) {
    return Scaffold(
      body: Builder(
        builder: (scaffoldContext) => SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              _buildProfileSection(),
              const SizedBox(height: 30),
              _buildSettingOption(
                scaffoldContext, // استخدام scaffoldContext الآمن
                Icons.health_and_safety,
                "Health Connect",
                "Health Connect Get Permission",
                _requestHealthConnectPermissions,
              ),
              _buildSettingOption(
                scaffoldContext, // استخدام scaffoldContext الآمن
                Icons.settings,
                "Health Connect",
                "Health Connect Setting",
                _openHealthConnectSettings,
              ),
              // باقي العناصر بدون تغيير...
              Container(
                margin: const EdgeInsets.only(bottom: 15),
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(
                  color: _isDarkMode ? Colors.grey[800] : const Color(0xFFF5F6FA),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF6A74CF), Color(0xFF89D3FB)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            _isDarkMode ? Icons.nightlight : Icons.wb_sunny,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 15),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "الوضع الليلي",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: _isDarkMode ? Colors.white : Colors.black,
                              ),
                            ),
                            Text(
                              _isDarkMode ? "مفعل" : "معطل",
                              style: TextStyle(
                                color: _isDarkMode ? Colors.grey[400] : Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    Switch(
                      value: _isDarkMode,
                      onChanged: _toggleDarkMode,
                      activeThumbColor: const Color(0xFF6A74CF),
                    ),
                  ],
                ),
              ),
              _buildLogoutButton(),
            ],
          ),
        ),
      ),
    );
  }
  Widget _buildLogoutButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _signOut,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          foregroundColor: Colors.white,
          shadowColor: Colors.transparent,
          padding: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
        ),
        child: Container(
          width: double.infinity,
          height: 50,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF6A74CF), Color(0xFF89D3FB)],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
            borderRadius: BorderRadius.circular(30),
          ),
          child: const Center(
            child: Text(
              "تسجيل الخروج",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGroupTitle(String title,
      {
        double fontSize = 20.0,
        EdgeInsets margin = const EdgeInsets.only(top: 20, bottom: 15)}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [

        Container(
          margin: margin,
          height: 50,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF6A74CF), Color(0xFF89D3FB)],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Center(
            child: Text(
              title,
              style: TextStyle(
                fontSize: fontSize,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
        ),

      ],
    );
  }



  Widget _buildSettingOption(
      BuildContext context, // أضف هذا المعامل
      IconData icon,
      String title,
      String subtitle,
      Future<void> Function(BuildContext)? onTap, // عدل التوقيع ليقبل context
      ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      decoration: BoxDecoration(
        color: _isDarkMode ? Colors.grey[800] : const Color(0xFFF5F6FA),
        borderRadius: BorderRadius.circular(15),
      ),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                onTap != null ? const Color(0xFF6A74CF) : Colors.grey,
                onTap != null ? const Color(0xFF89D3FB) : Colors.grey,
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: Colors.white),
        ),
        title: Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: _isDarkMode ? Colors.white : Colors.black,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(
            color: _isDarkMode ? Colors.grey[400] : Colors.grey[600],
          ),
        ),
        trailing: onTap != null
            ? const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey)
            : null,
        onTap: onTap != null
            ? () async {
          try {
            await onTap(context); // تمرير context هنا
          } catch (e) {
            debugPrint('حدث خطأ في onTap: $e');
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('حدث خطأ: ${e.toString()}')),
            );
          }
        }
            : null,
      ),
    );
  }

  Widget _buildProfileSection() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return Center(
        child: Text(
          'المستخدم غير مسجل دخول',
          style: TextStyle(
            color: _isDarkMode ? Colors.white : Colors.black,
          ),
        ),
      );
    }

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(
            child: CircularProgressIndicator(
              color: _isDarkMode ? Colors.white : const Color(0xFF6A74CF),
            ),
          );
        }

        if (snapshot.hasError) {
          return Center(
            child: Text(
              'حدث خطأ في تحميل البيانات',
              style: TextStyle(
                color: _isDarkMode ? Colors.white : Colors.black,
              ),
            ),
          );
        }

        final userData = snapshot.data?.data() as Map<String, dynamic>? ?? {};
        final name = '${userData['firstName'] ?? ''} ${userData['lastName'] ?? ''}'.trim();
        final email = userData['email'] ?? 'غير معروف';

        return Column(
          children: [
            const SizedBox(height: 20),
            Stack(
              alignment: Alignment.bottomRight,
              children: [
                _buildProfileImage(),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF6A74CF),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white,
                      width: 2,
                    ),
                  ),
                  child: const Icon(
                    Icons.edit,
                    size: 18,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Text(
              name.isNotEmpty ? name : 'غير معروف',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: _isDarkMode ? Colors.white : Colors.black,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              email,
              style: TextStyle(
                fontSize: 16,
                color: _isDarkMode ? Colors.grey[400] : Colors.grey[600],
              ),
            ),

          ],
        );
      },
    );
  }


  Widget _buildProfileImage() {
    return GestureDetector(
      onTap: _pickImage,
      child: Container(
        width: 120,
        height: 120,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: _isDarkMode ? Colors.grey[600]! : Colors.grey[300]!,
            width: 2,
          ),
        ),
        child: ClipOval(
          child: _profileImage != null
              ? Image.file(_profileImage!, fit: BoxFit.cover)
              : Image.asset(
            "assets/default_profile.jpg",
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Center(
              child: Icon(
                Icons.person,
                size: 50,
                color: _isDarkMode ? Colors.grey[400] : Colors.grey[500],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _pickImage() async {
    try {
      final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
      if (image == null) return;

      final appDir = await getApplicationDocumentsDirectory();
      final fileName = 'profile_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final savedImage = await File(image.path).copy('${appDir.path}/$fileName');

      setState(() {
        _profileImage = savedImage;
      });

      await _saveProfileImage(savedImage.path);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('حدث خطأ: ${e.toString()}')),
      );
    }
  }

  Future<void> _saveProfileImage(String path) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('profile_image_path', path);
  }

  Future<void> _loadProfileImage() async {
    final prefs = await SharedPreferences.getInstance();
    final imagePath = prefs.getString('profile_image_path');

    if (imagePath != null && File(imagePath).existsSync()) {
      setState(() {
        _profileImage = File(imagePath);
      });
    }
  }
  // دالة تسجيل الخروج
  Future<void> _signOut() async {
    try {
      await FirebaseAuth.instance.signOut();
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => const LoginScreen(),
        ),
      );
    } catch (e) {
      print("حدث خطأ أثناء تسجيل الخروج: $e");
    }
  }
  ///////////////////////////////////DASS- 42 Test ////////////////////////////////////////////

  void _showMentalHealthQuestions() {
    final List<String> options = [
      'لا ينطبق علي أبدًا',
      'ينطبق علي إلى حد ما',
      'ينطبق علي إلى حد كبير',
      'ينطبق علي تمامًا',
    ];
    // قائمة أسئلة DASS-42 الكاملة
    final List<Map<String, dynamic>> dass42Questions = [
      {'question': 'وجدت صعوبة في تهدئة نفسي', 'options': options},
      {'question': 'أحسست بجفاف في فمي', 'options': options},
      {'question': 'لم أستطع الشعور بأي مشاعر إيجابية', 'options': options},
      {'question': 'واجهت صعوبة في التنفس بدون بذل مجهود بدني', 'options': options},
      {'question': 'وجدت صعوبة في اتخاذ المبادرة للقيام بالأشياء', 'options': options},
      {'question': 'أفرطت في رد فعلي تجاه المواقف', 'options': options},
      {'question': 'عانيت من ارتعاش (مثل في اليدين)', 'options': options},
      {'question': 'شعرت أنني أستخدم الكثير من طاقتي العصبية', 'options': options},
      {'question': 'قلقت من أن أكون في مواقف قد أذعر فيها وأبدو أحمق', 'options': options},
      {'question': 'شعرت أنني ليس لدي ما أتطلع إليه', 'options': options},
      {'question': 'وجدت نفسي مضطربًا', 'options': options},
      {'question': 'وجدت صعوبة في الاسترخاء', 'options': options},
      {'question': 'شعرت بالاكتئاب والكآبة', 'options': options},
      {'question': 'كنت غير متسامح مع المعيقات أثناء تنفيذ المهام', 'options': options},
      {'question': 'شعرت أنني على وشك الذعر', 'options': options},
      {'question': 'لم أستطع أن أتحمس لأي شيء', 'options': options},
      {'question': 'شعرت أنني لا أساوي شيئًا كشخص', 'options': options},
      {'question': 'شعرت أنني سريع الانفعال', 'options': options},
      {'question': 'شعرت بصعوبة في التركيز', 'options': options},
      {'question': 'شعرت بعدم الاستقرار الداخلي', 'options': options},
      {'question': 'شعرت أنني قريب من الذعر بدون سبب واضح', 'options': options},
      {'question': 'شعرت أن الحياة ليس لها معنى', 'options': options},
      {'question': 'شعرت بصعوبة في بدء القيام بأعمالي', 'options': options},
      {'question': 'شعرت بالرعب دون سبب وجيه', 'options': options},
      {'question': 'شعرت بأنني لا أستحق شيئًا', 'options': options},
      {'question': 'شعرت بالدوار أو الدوخة', 'options': options},
      {'question': 'شعرت أنني لا أهتم بما يجري من حولي', 'options': options},
      {'question': 'شعرت أنني على وشك البكاء', 'options': options},
      {'question': 'واجهت صعوبة في الاستمتاع بأي شيء', 'options': options},
      {'question': 'شعرت أنني أواجه صعوبة في اتخاذ القرارات', 'options': options},
      {'question': 'شعرت بالعجز أمام المعيقات اليومية', 'options': options},
      {'question': 'شعرت أنني لا أستطيع أن أهدأ', 'options': options},
      {'question': 'شعرت أنني لا أقدر على الشعور بمشاعر إيجابية تجاه الآخرين', 'options': options},
      {'question': 'شعرت أنني لا أتحمل العقبات أثناء قيامي بمهامي', 'options': options},
      {'question': 'شعرت أنني قريب من فقدان السيطرة على أعصابي', 'options': options},
      {'question': 'شعرت أنني لا أستطيع التحمس لأي شيء إطلاقًا', 'options': options},
      {'question': 'شعرت بأنني بلا قيمة تمامًا', 'options': options},
      {'question': 'شعرت أن قلقي يعوقني عن أداء مهامي', 'options': options},
      {'question': 'لاحظت تغيرًا في معدل ضربات قلبي (مثل تسارع أو عدم انتظام)', 'options': options},
      {'question': 'شعرت بالخوف دون سبب واضح', 'options': options},
      {'question': 'شعرت أنني مستنزف ذهنيًا', 'options': options},
      {'question': 'شعرت أنني بحاجة إلى أن أكون وحيدًا باستمرار', 'options': options},
    ];



    // قائمة أسئلة الشخصية (TIPI)
    final List<Map<String, dynamic>> tipiQuestions = [
      {'question': 'أنا شخص متحمس، مفعم بالحيوية', 'options': ['غير موافق بشدة', 'غير موافق الى حد ما','غير موافق قليلا', 'محايد', 'موافق قليلا','موافق الى حد ما', 'موافق بشدة']},
      {'question': 'أنا شخص متشكك، يميل إلى انتقاد الآخرين', 'options': ['غير موافق بشدة', 'غير موافق الى حد ما','غير موافق قليلا', 'محايد', 'موافق قليلا','موافق الى حد ما', 'موافق بشدة']},
      {'question': 'أنا شخص موثوق به، منضبط', 'options': ['غير موافق بشدة', 'غير موافق الى حد ما','غير موافق قليلا', 'محايد', 'موافق قليلا','موافق الى حد ما', 'موافق بشدة']},
      {'question': 'أنا شخص قلِق، سريع الانفعال', 'options': ['غير موافق بشدة', 'غير موافق الى حد ما','غير موافق قليلا', 'محايد', 'موافق قليلا','موافق الى حد ما', 'موافق بشدة']},
      {'question': 'أنا شخص مفتوح لتجارب جديدة، متنوع', 'options': ['غير موافق بشدة', 'غير موافق الى حد ما','غير موافق قليلا', 'محايد', 'موافق قليلا','موافق الى حد ما', 'موافق بشدة']},
      {'question': 'أنا شخص محجوز، هادئ', 'options': ['غير موافق بشدة', 'غير موافق الى حد ما','غير موافق قليلا', 'محايد', 'موافق قليلا','موافق الى حد ما', 'موافق بشدة']},
      {'question': 'أنا شخص متعاطف، دافئ', 'options': ['غير موافق بشدة', 'غير موافق الى حد ما','غير موافق قليلا', 'محايد', 'موافق قليلا','موافق الى حد ما', 'موافق بشدة']},
      {'question': 'أنا شخص غير منظم، مهمل', 'options': ['غير موافق بشدة', 'غير موافق الى حد ما','غير موافق قليلا', 'محايد', 'موافق قليلا','موافق الى حد ما', 'موافق بشدة']},
      {'question': 'أنا شخص هادئ، متعقل', 'options': ['غير موافق بشدة', 'غير موافق الى حد ما','غير موافق قليلا', 'محايد', 'موافق قليلا','موافق الى حد ما', 'موافق بشدة']},
      {'question': 'أنا شخص تقليدي، مبدع', 'options': ['غير موافق بشدة', 'غير موافق الى حد ما','غير موافق قليلا', 'محايد', 'موافق قليلا','موافق الى حد ما', 'موافق بشدة']},
    ];

    // متغيرات ديموغرافية
    final Map<String, dynamic> demographics = {
      'education': ['أقل من ثانوي', 'ثانوي', 'جامعي', 'دراسات عليا'],
      'urban': ['ريفي', 'ضواحي', 'حضري'],
      'gender': ['ذكر', 'أنثى', 'آخر'],
      'religion': ['اللأدرية','ملحد','بوذي','مسيحي _ كاتوليكي','مسيحي _ مورمون','مسيحي - بروتستانتي','مسيحي _ اخر','هندوسي', 'يهودي', 'مسلم', 'سيخي', 'آخر'],
      'race': ['آسيوي', 'عربي', 'أسود / أفريقي الأصل', 'أسترالي أصلي', 'الأمريكي الأصلي / السكان الأصليون لأمريكا الشمالية', 'بيض / من أصول أوروبية','فئة أخرى - لا تنتمي للفئات السابقة'],
      'married': ['لم يتزوج أبداً', 'متزوج حالياً', 'متزوج سابقاً'],
      'familysize': List.generate(20, (index) => (index + 1).toString()),
      'age_group': ['أقل من 10', '10-16', '17-21', '22-35', '36-48', 'أكثر من 49'],
    };

    int currentSlide = 0;
    List<int?> dassAnswers = List.filled(42, null);
    List<int?> tipiAnswers = List.filled(10, null);
    Map<String, dynamic> demoAnswers = {};
    final PageController pageController = PageController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Container(
              height: MediaQuery.of(context).size.height * 0.9,
              decoration: BoxDecoration(
                color: _isDarkMode ? Colors.grey[900] : Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(25)),
              ),
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  // شريط التقدم
                  LinearProgressIndicator(
                    value: currentSlide / (dass42Questions.length + tipiQuestions.length + 1),
                    backgroundColor: _isDarkMode ? Colors.grey[800] : Colors.grey[200],
                    color: const Color(0xFF6A74CF),
                  ),
                  const SizedBox(height: 20),

                  Expanded(
                    child: PageView(
                      physics: const NeverScrollableScrollPhysics(),
                      controller: pageController,
                      onPageChanged: (index) {
                        setState(() => currentSlide = index);
                      },
                      children: [
                        // الشريحة الأولى: مقدمة عن الاختبار
                        _buildIntroSlide(_isDarkMode),

                        // شرائح أسئلة DASS-42
                        ...dass42Questions.asMap().entries.map((entry) {
                          final index = entry.key;
                          final question = entry.value;
                          return _buildQuestionSlide(
                            _isDarkMode,
                            question['question'],
                            question['options'],
                                (value) {
                              dassAnswers[index] = value;
                              setState(() {});
                            },
                            dassAnswers[index],
                          );
                        }).toList(),

                        // شرائح أسئلة الشخصية
                        ...tipiQuestions.asMap().entries.map((entry) {
                          final index = entry.key;
                          final question = entry.value;
                          return _buildQuestionSlide(
                            _isDarkMode,
                            question['question'],
                            question['options'],
                                (value) {
                              tipiAnswers[index] = value;
                              setState(() {});
                            },
                            tipiAnswers[index],
                          );
                        }).toList(),

                        // شريحة البيانات الديموغرافية
                        _buildDemographicsSlide(_isDarkMode, demographics, demoAnswers, (key, value) {
                          demoAnswers[key] = value;
                          setState(() {});
                        }),
                      ],
                    ),
                  ),

                  // أزرار التنقل
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      if (currentSlide > 0)
                        ElevatedButton(
                          onPressed: () {
                            pageController.previousPage(
                              duration: const Duration(milliseconds: 300),
                              curve: Curves.easeInOut,
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _isDarkMode ? Colors.grey[800] : Colors.grey[200],
                          ),
                          child: Text('السابق', style: TextStyle(color: _isDarkMode ? Colors.white : Colors.black)),
                        )
                      else
                        const SizedBox(width: 100),

                      if (currentSlide < dass42Questions.length + tipiQuestions.length + 1)
                        ElevatedButton(
                          onPressed: () {
                            // التحقق من الإجابة الحالية
                            if (currentSlide > 0 && currentSlide <= dass42Questions.length) {
                              if (dassAnswers[currentSlide - 1] == null) {
                                scaffoldMessengerKey.currentState?.showSnackBar(
                                    const SnackBar(content: Text('الرجاء اختيار إجابة'))
                                );
                                return;
                              }
                            } else if (currentSlide > dass42Questions.length) {
                              final tipiIndex = currentSlide - dass42Questions.length - 1;
                              if (tipiAnswers[tipiIndex] == null) {
                                scaffoldMessengerKey.currentState?.showSnackBar(
                                    const SnackBar(content: Text('الرجاء اختيار إجابة'))
                                );
                                return;
                              }
                            }

                            pageController.nextPage(
                              duration: const Duration(milliseconds: 300),
                              curve: Curves.easeInOut,
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF6A74CF),
                          ),
                          child: const Text('التالي', style: TextStyle(color: Colors.white)),
                        )
                      else
                        ElevatedButton(
                          onPressed: () async {
                            final navigatorContext = scaffoldMessengerKey.currentContext;
                            if (navigatorContext == null) {
                              debugPrint('خطأ: لا يوجد context متاح');
                              return;
                            }

                            final confirmed = await showDialog<bool>(
                              context: navigatorContext,
                              barrierDismissible: false,
                              builder: (dialogContext) => AlertDialog(
                                title: const Text('تأكيد الإرسال'),
                                content: const Text('هل أنت متأكد من إرسال النتائج؟'),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.of(dialogContext).pop(false),
                                    child: const Text('إلغاء'),
                                  ),
                                  TextButton(
                                    onPressed: () => Navigator.of(dialogContext).pop(true),
                                    child: const Text('تأكيد'),
                                  ),
                                ],
                              ),
                            ) ?? false;

                            if (!confirmed) return;

                            showDialog(
                              context: navigatorContext,
                              barrierDismissible: false,
                              builder: (_) => const Center(child: CircularProgressIndicator()),
                            );

                            try {
                              final analysis = await _submitTestResults(
                                  dassAnswers.map((a) => a ?? 0).toList(),
                                  tipiAnswers.map((a) => a ?? 0).toList(),
                                  demoAnswers
                              );
                              Navigator.of(navigatorContext, rootNavigator: true).pop();

                              if (analysis != null) {
                                await _showResultsDialog(_isDarkMode ,analysis);
                                Navigator.of(context).pop();
                              }


                            } catch (e) {
                              debugPrint('حدث خطأ: $e');
                              if (navigatorContext.mounted) {
                                Navigator.of(navigatorContext, rootNavigator: true).pop();
                                scaffoldMessengerKey.currentState?.showSnackBar(
                                    SnackBar(content: Text('حدث خطأ: ${e.toString()}'))
                                );
                              }
                            }
                          },

                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF6A74CF),
                          ),
                          child: const Text('إرسال النتائج', style: TextStyle(color: Colors.white)),
                        ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildIntroSlide(bool isDarkMode) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'اختبار DASS-42',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: isDarkMode ? Colors.white : Colors.black,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'هذا الاختبار مصمم لقياس مستويات الاكتئاب والقلق والتوتر. '
                'سيتم عرض 42 عبارة عليك تقييم مدى انطباقها عليك خلال الأسبوع الماضي.',
            style: TextStyle(
              fontSize: 16,
              color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'تعليمات:',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: isDarkMode ? Colors.white : Colors.black,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            '1. اقرأ كل عبارة بعناية\n'
                '2. اختر الإجابة التي تعبر عن حالتك خلال الأسبوع الماضي\n'
                '3. لا توجد إجابات صحيحة أو خاطئة\n'
                '4. كن صادقاً مع نفسك للحصول على نتائج دقيقة',
            style: TextStyle(
              fontSize: 16,
              color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
            ),
          ),
          const SizedBox(height: 30),
          Center(
            child: Icon(
              Icons.psychology,
              size: 60,
              color: const Color(0xFF6A74CF),
            ),
          ),
        ],
      ),
    );
  }


  Widget _buildQuestionSlide(
      bool isDarkMode,
      String question,
      List<String> options,
      Function(int) onChanged,
      int? selectedValue,
      ) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            question,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: isDarkMode ? Colors.white : Colors.black,
            ),
          ),
          const SizedBox(height: 30),

          Column(
            children: options.asMap().entries.map<Widget>((entry) {
              final index = entry.key;
              final option = entry.value;

              return RadioListTile<int>(
                value: index,
                groupValue: selectedValue,
                onChanged: (int? value) {
                  if (value != null) {
                    onChanged(value);
                  }
                },
                title: Text(
                  option,
                  style: TextStyle(
                    fontSize: 16,
                    color: isDarkMode ? Colors.white : Colors.black,
                  ),
                ),
                activeColor: const Color(0xFF6A74CF),
                contentPadding: EdgeInsets.zero,
                visualDensity: const VisualDensity(horizontal: -4, vertical: -4),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildDemographicsSlide(bool isDarkMode, Map<String, dynamic> demographics, Map<String, dynamic> answers, Function(String, dynamic) onChanged) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'البيانات الديموغرافية',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: isDarkMode ? Colors.white : Colors.black,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'الرجاء تقديم بعض المعلومات الأساسية لمساعدتنا في تحليل النتائج:',
            style: TextStyle(
              fontSize: 16,
              color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
            ),
          ),
          const SizedBox(height: 30),

          // مستوى التعليم
          _buildDemographicDropdown(
            isDarkMode,
            label: 'مستوى التعليم',
            value: answers['education'],
            items: demographics['education'],
            onChanged: (value) => onChanged('education', value),
          ),

          // منطقة السكن
          _buildDemographicDropdown(
            isDarkMode,
            label: 'منطقة السكن',
            value: answers['urban'],
            items: demographics['urban'],
            onChanged: (value) => onChanged('urban', value),
          ),

          // الجنس
          _buildDemographicDropdown(
            isDarkMode,
            label: 'الجنس',
            value: answers['gender'],
            items: demographics['gender'],
            onChanged: (value) => onChanged('gender', value),
          ),

          // الديانة
          _buildDemographicDropdown(
            isDarkMode,
            label: 'الديانة',
            value: answers['religion'],
            items: demographics['religion'],
            onChanged: (value) => onChanged('religion', value),
          ),

          // العرق
          _buildDemographicDropdown(
            isDarkMode,
            label: 'العرق',
            value: answers['race'],
            items: demographics['race'],
            onChanged: (value) => onChanged('race', value),
          ),

          // الحالة الاجتماعية
          _buildDemographicDropdown(
            isDarkMode,
            label: 'الحالة الاجتماعية',
            value: answers['married'],
            items: demographics['married'],
            onChanged: (value) => onChanged('married', value),
          ),

          // عدد أفراد الأسرة
          _buildDemographicDropdown(
            isDarkMode,
            label: 'عدد أفراد الأسرة',
            value: answers['familysize'],
            items: demographics['familysize'],
            onChanged: (value) => onChanged('familysize', value),
          ),

          // الفئة العمرية
          _buildDemographicDropdown(
            isDarkMode,
            label: 'الفئة العمرية',
            value: answers['age_group'],
            items: demographics['age_group'],
            onChanged: (value) => onChanged('age_group', value),
          ),
        ],
      ),
    );
  }

  Widget _buildDemographicDropdown(bool isDarkMode, {
    required String label,
    required dynamic value,
    required List<dynamic> items,
    required Function(dynamic) onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 16,
              color: isDarkMode ? Colors.white : Colors.black,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: isDarkMode ? Colors.grey[800] : Colors.grey[200],
              borderRadius: BorderRadius.circular(10),
            ),
            child: DropdownButton<dynamic>(
              value: value,
              isExpanded: true,
              underline: const SizedBox(),
              dropdownColor: _isDarkMode ? Colors.grey[800] : Colors.white, // لون الخلفية
              items: items.map<DropdownMenuItem<dynamic>>((dynamic item) {
                return DropdownMenuItem<dynamic>(
                  value: item,
                  child: Text(
                    item.toString(),
                    style: TextStyle(
                      color: isDarkMode ? Colors.white : Colors.black,
                    ),
                  ),
                );
              }).toList(),
              onChanged: (dynamic newValue) {
                onChanged(newValue);
              },
              hint: Text(
                'اختر $label',
                style: TextStyle(
                  color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<String?> _submitTestResults(
      List<int> dassAnswers,
      List<int> tipiAnswers,
      Map<String, dynamic> demoAnswers,
      ) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('يجب تسجيل الدخول أولاً');

    try {
      // 1. التحقق من صحة البيانات
      if (dassAnswers.length != 42 || tipiAnswers.length != 10) {
        throw Exception('عدد الإجابات غير صحيح');
      }

      // 2. إرسال البيانات إلى Hugging Face
      final hfResponse = await _sendToHuggingFace(dassAnswers, tipiAnswers, demoAnswers);

      // 3. الحصول على التحليل من OpenRouter
      final analysis = await _getAnalysisFromOpenRouter(hfResponse);

      // 4. حفظ النتائج في Firestore
      final now = DateTime.now();
      final documentId = DateFormat('yyyy-MM-dd_HH-mm-ss').format(now);

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('mental_Health_Tests_analysis')
          .doc(documentId)
          .set({
        'HF_Prediction': hfResponse,
        'Analysis': analysis,
        'timestamp': FieldValue.serverTimestamp(),
      });

      return analysis; // ✅ ترجيع النتيجة هنا
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('فشل في إرسال النتائج: ${e.toString()}')),
        );
      }
      return null; // ✅ في حال الخطأ، ترجع null
    }
  }

  Future<Map<String, dynamic>> _sendToHuggingFace(
      List<int> dassAnswers,
      List<int> tipiAnswers,
      Map<String, dynamic> demoAnswers
      ) async {
    try {
      // 1. تحويل البيانات الديموغرافية إلى أرقام
      final List<int> numericDemoData = _convertDemographicsToNumbers(demoAnswers);

      // 2. دمج جميع البيانات في مصفوفة واحدة (DASS + TIPI + Demographics)
      final List<int> allInputs = [
        ...dassAnswers,    // 42 إجابة (DASS)
        ...tipiAnswers,    // 10 إجابة (TIPI)
        ...numericDemoData // 8 بيانات ديموغرافية (مثال)
      ];

      // 3. التأكد من أن الطول الإجمالي 60 (42 + 10 + 8)
      if (allInputs.length != 60) {
        throw Exception('يجب أن تحتوي البيانات على 60 عنصرًا (42 DASS + 10 TIPI + 8 ديموغرافيا)');
      }

      // 4. إرسال البيانات إلى Hugging Face
      final response = await http.post(
        Uri.parse('https://zeyad995-dass-42-test.hf.space/predict'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'inputs': allInputs,
        }),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('فشل في الحصول على استجابة من Hugging Face: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('خطأ في الاتصال بـ Hugging Face API: $e');
    }
  }
  List<int> _convertDemographicsToNumbers(Map<String, dynamic> demoAnswers) {
    // تعيين رموز رقمية لكل قيمة ديموغرافية
    const Map<String, Map<String, int>> demographicEncoding = {
      'education': {
        'أقل من ثانوي': 1,
        'ثانوي': 2,
        'جامعي': 3,
        'دراسات عليا': 4,
      },
      'urban': {
        'ريفي': 1,
        'ضواحي': 2,
        'حضري': 3,
      },
      'gender': {
        'ذكر': 1,
        'أنثى': 2,
        'آخر': 3,
      },
      'religion': {
        'اللأدرية': 1,
        'ملحد': 2,
        'بوذي': 3,
        'مسيحي _ كاتوليكي': 4,
        'مسيحي _ مورمون': 5,
        'مسيحي - بروتستانتي': 6,
        'مسيحي _ اخر': 7,
        'هندوسي': 8,
        'يهودي': 9,
        'مسلم': 10,
        'سيخي': 11,
        'آخر': 12,
      },
      'race': {
        'آسيوي': 1,
        'عربي': 2,
        'أسود / أفريقي الأصل': 3,
        'أسترالي أصلي': 4,
        'الأمريكي الأصلي / السكان الأصليون لأمريكا الشمالية': 5,
        'بيض / من أصول أوروبية': 6,
        'فئة أخرى - لا تنتمي للفئات السابقة': 7,
      },
      'married': {
        'لم يتزوج أبداً': 1,
        'متزوج حالياً': 2,
        'متزوج سابقاً': 3,
      },
      // familysize و age_group يتم استخدامها كما هي (رقمية)
    };

    return [
      // التعليم (مثال: 2)
      demographicEncoding['education']![demoAnswers['education']] ?? 0,

      // منطقة السكن (مثال: 3)
      demographicEncoding['urban']![demoAnswers['urban']] ?? 0,

      // الجنس (مثال: 1)
      demographicEncoding['gender']![demoAnswers['gender']] ?? 0,

      // الديانة (مثال: 10 للإسلام)
      demographicEncoding['religion']![demoAnswers['religion']] ?? 0,

      // العرق (مثال: 2 للعرب)
      demographicEncoding['race']![demoAnswers['race']] ?? 0,

      // الحالة الاجتماعية (مثال: 2 للمتزوج)
      demographicEncoding['married']![demoAnswers['married']] ?? 0,

      // حجم الأسرة (يستخدم القيمة كما هي)
      int.tryParse(demoAnswers['familysize']?.toString() ?? '1') ?? 1,

      // الفئة العمرية (يتم تحويل النص إلى رقم)
      _encodeAgeGroup(demoAnswers['age_group']),
    ];
  }

// دالة مساعدة لتحويل الفئة العمرية إلى رقم
  int _encodeAgeGroup(String? ageGroup) {
    const Map<String, int> ageEncoding = {
      'أقل من 10': 1,
      '10-16': 2,
      '17-21': 3,
      '22-35': 4,
      '36-48': 5,
      'أكثر من 49': 6,
    };
    return ageEncoding[ageGroup] ?? 4; // القيمة الافتراضية: 22-35
  }
  Future<String> _getAnalysisFromOpenRouter(Map<String, dynamic> hfResponse) async {
    try {
      final response = await http.post(
        Uri.parse('https://openrouter.ai/api/v1/chat/completions'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'model': 'deepseek/deepseek-r1:free',
          'messages': [
            {
              'role': 'system',
              'content': '''
أنت طبيب نفسي محترف. سيتم تزويدك بتقييم لفظي ناتج عن نموذج ذكاء صناعي لمقياس DASS-42، مثل:
- Normal
- Mild
- Moderate
- Severe
- Extremely Severe

قم بإنشاء تقرير احترافي باللغة العربية يشمل:
- شرح مستوى التقييم ومعناه النفسي
- مؤشرات الأعراض المرتبطة بهذا التقييم
- توصيات مهنية (نمط حياة، دعم نفسي، متى يوصى بزيارة مختص)
- اللغة يجب أن تكون واضحة، داعمة، وغير مخيفة، مع الحفاظ على الجدية المهنية
'''
            },
            {
              'role': 'user',
              'content': '''
تقييم النموذج لحالة المستخدم النفسية بناءً على اختبار DASS-42 هو: "$hfResponse"

يرجى تقديم تحليل نفسي مفصل بناءً على هذا التقييم.
'''
            }
          ],
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['choices'][0]['message']['content'];
      } else {
        throw Exception(
            'فشل الاتصال بـ OpenRouter (رمز الحالة: ${response.statusCode})\n${response.body}');
      }
    } catch (e) {
      return 'حدث خطأ أثناء تحليل النتائج: $e';
    }
  }
  Future<void> _showResultsDialog(bool isDarkMode, String analysis) async {

    String cleanText = analysis
        .replaceAll('**', '')
        .replaceAll('***', '')
        .replaceAll('##', '')
        .replaceAll('###', '')
        .replaceAll('####', '')
        .replaceAll('#', '')
        .replaceAll('*', '');

    final textColor = isDarkMode ? Colors.white : Colors.black;
    final buttonColor = isDarkMode ? Colors.blue[200] : Colors.blue;
    final backgroundColor = isDarkMode ? Colors.grey[900] : Colors.white;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: backgroundColor,
        title: Text(
          'نتائج التقييم',
          style: TextStyle(
            color: textColor,
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.right,
          textDirection: ui.TextDirection.rtl,
        ),
        content: SingleChildScrollView(
          child: Text(
            cleanText,
            style: TextStyle(
              color: textColor,
              height: 1.5,
            ),
            textAlign: TextAlign.right,
            textDirection: ui.TextDirection.rtl,

          ),
        ),
        actionsAlignment: MainAxisAlignment.start,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'حسنًا',
              style: TextStyle(
                color: buttonColor,
                fontSize: 16,
              ),
            ),
          ),
        ],
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }


}
class HeartRateStats {
  final double avg;
  final double min;
  final double max;

  HeartRateStats({
    required this.avg,
    required this.min,
    required this.max,
  });
}