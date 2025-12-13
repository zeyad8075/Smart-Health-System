import 'package:flutter/material.dart';
import 'onboarding1.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF6A74CF), // لون التدرج العلوي
              Color(0xFF89D3FB), // لون التدرج السفلي
            ],
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Spacer(),
            Column(
              children: [
                // إضافة الصورة هنا
                Image.asset(
                  "assets/icons/health.png", // مسار الصورة
                  height: 200, // ارتفاع الصورة
                  width: 200, // عرض الصورة
                ),
                const SizedBox(height: 20), // مسافة بين الصورة والنص
                const Text(
                  'صحتك', // اسم التطبيق
                  style: TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'اهتم بصحتك، فهي حياتك', // النص التعريفي
                  style: TextStyle(
                    fontSize: 18,
                    color: Colors.black54,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 180),

            Padding(
              padding: const EdgeInsets.all(16.0),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white, // لون الزر
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30), // زوايا مستديرة
                    ),
                  ),
                  onPressed: () {
                    // التنقل إلى شاشة التعريف الأولى
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const OnboardingScreen1(),
                      ),
                    );
                  },
                  child: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16.0),
                    child: Text(
                      'ابدأ الآن', // نص الزر
                      style: TextStyle(
                        fontSize: 18,
                        color: Color(0xFF6C82F5), // لون النص داخل الزر
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}