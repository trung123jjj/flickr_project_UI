import 'package:flutter/material.dart';

class IntroScreen extends StatelessWidget {
  const IntroScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1B2A), // dark blue
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Ảnh intro phía trên
            Container(
              margin: const EdgeInsets.only(top: 57),
              width: double.infinity,
              child: Image.asset(
                'assets/images/intro_pic.png',
                fit: BoxFit.fitWidth,
              ),
            ),

            // Phần text và button phía dưới
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(32, 24, 32, 40),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [

                  // Title
                  const Text(
                    'Welcome to Nikki-Ani',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),

                  // Subtitle
                  const SizedBox(height: 8),
                  const Text(
                    'Rate by your own way',
                    style: TextStyle(
                      color: Color(0xFFB8B8B8),
                      fontSize: 15,
                      height: 1.3,
                    ),
                    textAlign: TextAlign.center,
                  ),

                  // Button Get Started
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [
                            Color(0xFFFF6B00), // cam đậm
                            Color(0xFFFFAB40), // cam nhạt
                          ],
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ElevatedButton(
                        onPressed: () {
                          // TODO: điều hướng sang Login page
                          // Navigator.pushNamed(context, '/login');
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'Get started',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),

                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
