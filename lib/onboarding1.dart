import 'package:flutter/material.dart';
import 'onboarding2.dart';

class OnboardingScreen1 extends StatelessWidget {
  const OnboardingScreen1({super.key});

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
                  'assets/images/on_1.png', // استبدل بمسار الصورة
                  width: screenWidth, // تجعل العرض يمتد لكامل الشاشة
                  fit: BoxFit.fitWidth, // ضبط الصورة لتناسب العرض
                ),
              ),
              const SizedBox(height: 20),
              // النصوص
              const Text(
                "تتبع أهدافك",
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
                textAlign: TextAlign.center, // محاذاة النص إلى الوسط
              ),
              const SizedBox(height: 10),
              const Text(
                "لا تقلق إذا كنت تواجه صعوبة في تحديد أهدافك، "
                    "يمكننا مساعدتك في تحديد أهدافك وتتبعها",
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
                        builder: (context) => const OnboardingScreen2(),
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