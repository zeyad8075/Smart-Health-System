import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:health/register.dart';

class WelcomeScreen2 extends StatefulWidget {
  const WelcomeScreen2({super.key});

  @override
  _WelcomeScreenState createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen2> {
  String userName = "User"; // القيمة الافتراضية

  @override
  void initState() {
    super.initState();
    fetchUserName(); // جلب اسم المستخدم عند بدء تشغيل الواجهة
  }

  Future<void> fetchUserName() async {
    try {
      // استبدل 'user_id' بالمعرف الفعلي للمستخدم
      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc('user_id') // تأكد من استبدال 'user_id' بالمعرف الصحيح
          .get();

      if (userDoc.exists && userDoc['name'] != null) {
        setState(() {
          userName = userDoc['name']; // تحديث اسم المستخدم
        });
      } else {
        setState(() {
          userName = 'User'; // إذا لم يتم العثور على الاسم
        });
      }
    } catch (e) {
      print("Error fetching user name: $e");
      setState(() {
        userName = 'User'; // في حالة حدوث خطأ
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // صورة الشخصيات
              Container(
                height: MediaQuery.of(context).size.height * 0.4, // 40% من ارتفاع الشاشة
                child: Image.asset(
                  'assets/images/on_5.png', // تأكد من المسار الصحيح للصورة
                  fit: BoxFit.contain, // الحفاظ على نسبة العرض إلى الارتفاع
                ),
              ),
              const SizedBox(height: 20),
              // النص الترحيبي
              Text(
                "مرحبًا بك، $userName",
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
              const SizedBox(height: 10),
              // النص الثانوي
              const Text(
                " لنحقق أهدافك معًا!",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 30),
              // زر الانتقال إلى الصفحة الرئيسية
              GestureDetector(
                onTap: () {
                  // فعل مناسب عند الضغط على الزر
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const RegisterPage(),
                    ),
                  );
                },
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
                    boxShadow: [
                      BoxShadow(
                        color: Colors.blue.withAlpha(77),
                        blurRadius: 10,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.arrow_forward, color: Colors.white),
                      SizedBox(width: 10),
                      Text(
                        "سجل الان",
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.white,
                        ),
                      ),
                    ],
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