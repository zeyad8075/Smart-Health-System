import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';
import 'dart:ui' as ui;





class CustomMoodAssessment extends StatefulWidget {
  final double? sdnn;
  final double? rmssd;
  final bool fromNotification;
  final bool isDarkMode;

  const CustomMoodAssessment({
    super.key,
    this.sdnn,
    this.rmssd,
    this.fromNotification = false,
    required this.isDarkMode,
  });

  @override
  _CustomMoodAssessmentState createState() => _CustomMoodAssessmentState();
}

class _CustomMoodAssessmentState extends State<CustomMoodAssessment> {
  int _currentQuestionIndex = 0;
  Map<int, int?> _answers = {};
  bool _isSubmitting = false;

  final List<Map<String, dynamic>> _questions = [
    {
      'question': 'كيف تقيم نومك الليلة الماضية؟',
      'options': ['ممتاز', 'جيد', 'متوسط', 'سيء', 'سيء جداً'],
    },
    {
      'question': 'هل تعرضت لأي موقف مزعج اليوم؟',
      'options': ['لا شيء', 'موقف بسيط', 'بعض المواقف', 'مواقف متعددة', 'يوم صعب جداً'],
    },
    {
      'question': 'ما هو مستوى طاقتك اليوم؟',
      'options': ['مليء بالطاقة', 'طبيعي', 'متوسط', 'منخفض', 'مرهق تماماً'],
    },
    {
      'question': 'كيف تشعر عاطفياً الآن؟',
      'options': ['مبتهج', 'مستقر', 'محايد', 'قلق', 'حزين أو مكتئب'],
    },
    {
      'question': 'هل واجهت صعوبة في التركيز اليوم؟',
      'options': ['لا إطلاقاً', 'قليلاً', 'بدرجة متوسطة', 'كثيراً', 'بشكل حاد'],
    },
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = widget.isDarkMode;

    return Scaffold(
      appBar: AppBar(
        title: Text('تقييم الحالة المزاجية'),
        backgroundColor: isDarkMode ? Colors.grey[900] : theme.primaryColor,
        foregroundColor: isDarkMode ? Colors.white : Colors.black,
      ),
      body: Container(
        color: isDarkMode ? Colors.grey[850] : Colors.white,
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            LinearProgressIndicator(
              value: (_currentQuestionIndex + 1) / _questions.length,
              backgroundColor: isDarkMode ? Colors.grey[700] : Colors.grey[300],
              color: Colors.blue,
            ),
            const SizedBox(height: 20),
            Text(
              _questions[_currentQuestionIndex]['question'],
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: isDarkMode ? Colors.white : Colors.black,
              ),
            ),
            const SizedBox(height: 30),
            ...List.generate(
              _questions[_currentQuestionIndex]['options'].length,
                  (index) => RadioListTile<int>(
                title: Text(
                  _questions[_currentQuestionIndex]['options'][index],
                  style: TextStyle(
                    fontSize: 18,
                    color: _isSubmitting
                        ? Colors.grey
                        : (isDarkMode ? Colors.white : Colors.black),
                  ),
                ),
                value: index,
                groupValue: _answers[_currentQuestionIndex],
                onChanged: _isSubmitting
                    ? null
                    : (value) {
                  setState(() {
                    _answers[_currentQuestionIndex] = value;
                  });
                },
                activeColor: Colors.blue,
                tileColor: isDarkMode ? Colors.grey[800] : Colors.white,
              ),
            ),
            const Spacer(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (_currentQuestionIndex > 0)
                  ElevatedButton(
                    onPressed: _goToPreviousQuestion,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isDarkMode ? Colors.grey[700] : Colors.grey[200],
                      foregroundColor: isDarkMode ? Colors.white : Colors.black,
                    ),
                    child: const Text('السابق'),
                  ),
                ElevatedButton(
                  onPressed: _isSubmitting || _answers[_currentQuestionIndex] == null
                      ? null
                      : _goToNextQuestion,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                  ),
                  child: _isSubmitting
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Text(
                    _currentQuestionIndex == _questions.length - 1
                        ? 'إنهاء التقييم'
                        : 'التالي',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
  void _goToPreviousQuestion() {
    setState(() {
      _currentQuestionIndex--;
    });
  }

  void _goToNextQuestion() {
    if (_currentQuestionIndex < _questions.length - 1) {
      setState(() {
        _currentQuestionIndex++;
      });
    } else {
      _submitAssessment();
    }
  }

  Future<void> _submitAssessment() async {
    setState(() => _isSubmitting = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // تحويل الإجابات إلى خريطة
      final Map<String, dynamic> answers = {};
      for (var i = 0; i < _questions.length; i++) {
        answers[_questions[i]['question']] = _questions[i]['options'][_answers[i] ?? 0];
      }

      // إذا كان الطلب من الإشعار، نرسل التحليل الفوري
      if (widget.fromNotification) {
        final prompt = '''
        المستخدم يعاني من مؤشرات توتر عالية بناءً على:
        - HRV SDNN: ${widget.sdnn} مللي ثانية
        - HRV RMSSD: ${widget.rmssd} مللي ثانية
        
        تقييم الحالة المزاجية:
        ${answers.entries.map((e) => "- ${e.key}: ${e.value}").join('\n')}
        
        قدم تحليلًا مفصلًا للحالة النفسية الحالية مع توصيات فورية للتحسين.
        ''';

        final analysis = await _callDeepSeekAPI(prompt);

        await _saveAssessmentReport(
          user.uid,
          answers,
          analysis,
          widget.sdnn,
          widget.rmssd,
        );

        _showResultsDialog(analysis);
      } else {
        // الحالة العادية (بدون إشعار)
        await _saveAssessmentReport(
          user.uid,
          answers,
          null,
          widget.sdnn,
          widget.rmssd,
        );

        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم حفظ التقييم بنجاح')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('حدث خطأ: ${e.toString()}')),
      );
    } finally {
      setState(() => _isSubmitting = false);
    }
  }

  Future<String> _callDeepSeekAPI(String prompt) async {
    // نفس دالة الاتصال بـ DeepSeek API الموجودة في الملف الرئيسي
    // يمكنك نقلها إلى ملف منفصل للخدمات
    const apiUrl = 'https://openrouter.ai/api/v1/chat/completions';
    const apiKey = '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';

    final response = await http.post(
      Uri.parse(apiUrl),
      headers: {
        'Authorization': 'Bearer $apiKey',
        'Content-Type': 'application/json',
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
      throw Exception('فشل في التحليل');
    }

    final responseData = jsonDecode(response.body);
    return responseData['choices'][0]['message']['content'];
  }

  Future<void> _saveAssessmentReport(
      String userId,
      Map<String, dynamic> answers,
      String? analysis,
      double? sdnn,
      double? rmssd,
      ) async {
    final now = DateTime.now();
    final documentId = DateFormat('yyyy-MM-dd_HH-mm-ss').format(now);

    await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('mood_assessments')
        .doc(documentId)
        .set({
      'answers': answers,
      'sdnn': sdnn,
      'rmssd': rmssd,
      'analysis': analysis,
      'from_notification': widget.fromNotification,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  void _showResultsDialog(String analysis) async {
    final isDarkMode = widget.isDarkMode;


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