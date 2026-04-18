import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:http/http.dart' as http;
import 'package:lpinyin/lpinyin.dart';
import 'TranslatorPage.dart';

class SplashScreen extends StatefulWidget {
  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {

  // 🔥 animation logo xoay
  late AnimationController _controller;
  late Animation<double> _rotation;

  String fullText = "Chào mừng bạn đến với\nApp dịch Việt - Trung\ncủa Liang Jia Jun";
  String displayText = "";

  int index = 0;

  @override
  void initState() {
    super.initState();

    // 🔥 animation xoay
    _controller = AnimationController(
      vsync: this,
      duration: Duration(seconds: 4),
    )..repeat();

    _rotation = Tween<double>(begin: 0, end: 1).animate(_controller);

    // 🔥 hiệu ứng gõ chữ
    startTyping();

    // 🔥 delay 2s → vào app
    Future.delayed(Duration(seconds: 4), () {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => TranslatorPage()),
      );
    });
  }

  void startTyping() {
    Timer.periodic(Duration(milliseconds: 40), (timer) {
      if (index < fullText.length) {
        setState(() {
          displayText += fullText[index];
          index++;
        });
      } else {
        timer.cancel();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.blue.shade300, Colors.white],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),

        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [

            // 🔥 LOGO XOAY
            RotationTransition(
              turns: _rotation,
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.blueAccent.withOpacity(0.6),
                      blurRadius: 10,
                      spreadRadius: 3,
                    )
                  ],
                ),
                child: CircleAvatar(
                  radius: 100,
                  backgroundImage: AssetImage("assets/avatar.jpg"),
                ),
              ),
            ),

            SizedBox(height: 30),

            // 🔥 TEXT GÕ TỪNG CHỮ
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 30),
              child: Text(
                displayText,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),

            SizedBox(height: 10),

            // 🔥 TIẾNG TRUNG NHỎ BÊN DƯỚI
            Text(
              "越南语 - 中文 翻译应用",
              style: TextStyle(
                fontSize: 14,
                color: Colors.black54,
              ),
            ),

            SizedBox(height: 30),

            // 🔥 loading nhẹ
            CircularProgressIndicator(),
          ],
        ),
      ),
    );
  }
}