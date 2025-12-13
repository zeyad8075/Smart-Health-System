import 'package:flutter/material.dart';
import 'package:health/wellcom_to_home.dart';

class OnboardingScreen4 extends StatelessWidget {
  const OnboardingScreen4({super.key});

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width; // تعريف أبعاد الشاشة

    return Scaffold(
      backgroundColor: const Color(0xFFEAF0FF), // لون الخلفية الأزرق الفاتح
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // الصورة
              Expanded(
                flex: 3,
                child: Image.asset(
                  'assets/images/on_4.png', // استبدل بمسار الصورة
                  width: screenWidth, // تجعل العرض يمتد لكامل الشاشة
                  fit: BoxFit.fitWidth, // ضبط الصورة لتناسب العرض
                ),
              ),
              const SizedBox(height: 20),
              // النصوص
              const Text(
                "تحسين جودة النوم",
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
                textAlign: TextAlign.center, // محاذاة النص إلى الوسط
              ),
              const SizedBox(height: 10),
              const Text(
                "حسّن جودة نومك معنا، النوم الجيد يمكن أن يجلب مزاجًا رائعًا في الصباح.",
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey,
                  height: 1.5, // زيادة المسافة بين السطور
                ),
                textAlign: TextAlign.center, // محاذاة النص إلى الوسط
              ),
              const SizedBox(height: 40),
              // زر السهم
              Align(
                alignment: Alignment.bottomRight,
                child: GestureDetector(
                  onTap: () {
                    // الانتقال إلى الشاشة التالية
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const WelcomeScreen2(),
                      ),
                    );
                  },
                  child: Container(
                    height: 60,
                    width: 60,
                    decoration: BoxDecoration(
                      color: Colors.blue,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF0000FF).withBlue(77), // شفافية الظل باستخدام withBlue
                          blurRadius: 10,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.arrow_forward,
                      color: Colors.white,
                      size: 30,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}