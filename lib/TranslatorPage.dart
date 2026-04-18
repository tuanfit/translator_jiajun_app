import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:http/http.dart' as http;
import 'package:lpinyin/lpinyin.dart';

class TranslatorPage extends StatefulWidget {
  @override
  _TranslatorPageState createState() => _TranslatorPageState();
}

class _TranslatorPageState extends State<TranslatorPage> {
  SpeechToText speech = SpeechToText();
  FlutterTts tts = FlutterTts();

  bool isListening = false;
  bool speechEnabled = false;
  bool reverseMode = false;

  String inputText = "";
  String translatedText = "";
  String inputPinyin = "";
  String outputPinyin = "";

  int silenceSeconds = 5;

  TextEditingController controller = TextEditingController();
  Timer? debounce;
  Timer? silenceTimer;

  @override
  void initState() {
    super.initState();
    initSpeech();
  }

  // ================= INIT =================
  void initSpeech() async {
    speechEnabled = await speech.initialize(
      onStatus: (status) async {
        print("STATUS: $status");

        // 🔥 auto restart nếu đang bật mic
        if ((status == "done" || status == "notListening") && isListening) {
          await Future.delayed(Duration(milliseconds: 300));
          if (isListening) {
            startListening();
          }
        }
      },
      onError: (error) {
        print("ERROR: $error");
        setState(() {
          isListening = false;
        });
      },
    );
  }
  List<Map<String, String>> splitChineseText(String text) {
    List<String> sentences = text
        .split(RegExp(r'[。！？,.!?]'))
        .where((e) => e.trim().isNotEmpty)
        .toList();

    return sentences.map((s) {
      return {
        "text": s,
        "pinyin": PinyinHelper.getPinyin(
          s,
          separator: " ",
          format: PinyinFormat.WITH_TONE_MARK,
        )
      };
    }).toList();
  }
  // ================= MIC =================
  void startListening() async {
    if (!speechEnabled) return;

    await speech.cancel(); // reset engine
    await Future.delayed(Duration(milliseconds: 200));

    setState(() {
      isListening = true;
      inputText = "";
      controller.clear();
    });

    startSilenceTimer(); // 🔥 bật timer

    speech.listen(
      localeId: reverseMode ? "vi_VN" : "zh_CN",
      listenMode: ListenMode.dictation,
      partialResults: true,
      cancelOnError: true,
      onResult: (result) {
        String text = result.recognizedWords;

        setState(() {
          inputText = text;
          controller.text = text;
          inputPinyin = PinyinHelper.getPinyin(text,
              separator: " ",
              format: PinyinFormat.WITH_TONE_MARK
          );
        });

        resetSilenceTimer();

        debounce?.cancel();
        debounce = Timer(Duration(milliseconds: 800), () {
          translate(text);
        });
      },
    );
  }

  void stopListening() {
    speech.stop();
    silenceTimer?.cancel();

    setState(() {
      isListening = false;
    });
  }

  // ================= TIMER =================
  void startSilenceTimer() {
    silenceTimer?.cancel();

    silenceTimer = Timer(Duration(seconds: silenceSeconds), () {
      print("⏹ Auto stop (silence)");
      stopListening();
    });
  }

  void resetSilenceTimer() {
    startSilenceTimer();
  }

  // ================= TRANSLATE =================
  Future<void> translate(String text) async {
    if (text.isEmpty) return;

    try {
      String source = reverseMode ? "vi" : "zh-CN";
      String target = reverseMode ? "zh-CN" : "vi";

      final response = await http.get(
        Uri.parse(
          "https://translate.googleapis.com/translate_a/single?client=gtx&sl=$source&tl=$target&dt=t&q=$text",
        ),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        String result = data[0][0][0];

        setState(() {
          translatedText = result;

          // 🔥 pinyin output nếu là tiếng Trung
          outputPinyin = PinyinHelper.getPinyin(
            result,
            separator: " ",
            format: PinyinFormat.WITH_TONE_MARK,
          );
        });
      }
    } catch (e) {
      setState(() {
        translatedText = "❌ Lỗi: $e";
      });
    }
  }

  // ================= TTS =================
  void speak(String text, {bool isChinese = true}) async {
    if (text.isEmpty) return;

    await tts.setLanguage(isChinese ? "zh-CN" : "vi-VN");
    await tts.speak(text);
  }

  // ================= UI =================
  Widget silenceSelector() {
    return DropdownButton<int>(
      value: silenceSeconds,
      items: [5, 10, 30, 60]
          .map((e) => DropdownMenuItem(
        value: e,
        child: Text("Stop sau $e giây"),
      ))
          .toList(),
      onChanged: (value) {
        setState(() {
          silenceSeconds = value!;
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true, // 🔥 cho phép overlay đẹp
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        centerTitle: true,
        title: Text(
          reverseMode ? "VN → 中文" : "中文 → VN",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.swap_horiz),
            onPressed: () {
              if (isListening) {
                stopListening();
              }

              setState(() {
                reverseMode = !reverseMode;
                translatedText = "";
                inputText = "";
                controller.clear();
                inputPinyin = "";
                outputPinyin = "";
              });
            },
          )
        ],
      ),

      body: Stack(
        children: [
          // 🔥 BACKGROUND (cho đẹp)
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.blue.shade200, Colors.white],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),

          // 🔥 UI CHÍNH
          SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.fromLTRB(16, 16, 16, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        silenceSelector(),
                        SizedBox(height: 10),

                        // INPUT BOX
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                blurRadius: 8,
                                color: Colors.black12,
                              )
                            ],
                          ),
                          child: TextField(
                            controller: controller,
                            maxLines: null,
                            decoration: InputDecoration(
                              hintText: "Nhập hoặc nói...",
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.all(12),
                              suffixIcon: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: Icon(Icons.volume_up),
                                    onPressed: () => speak(
                                      inputText,
                                      isChinese: !reverseMode,
                                    ),
                                  ),
                                  IconButton(
                                    icon: Icon(Icons.clear),
                                    onPressed: () {
                                      controller.clear();
                                      setState(() {
                                        inputText = "";
                                        translatedText = "";
                                        inputPinyin = "";
                                        outputPinyin = "";
                                      });
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),

                        SizedBox(height: 10),

                        if (inputPinyin.isNotEmpty)
                          Text("📘 Pinyin: $inputPinyin"),

                        SizedBox(height: 20),

                        Text(
                          "🌏 Translation:",
                          style: TextStyle(fontSize: 18),
                        ),

                        SizedBox(height: 10),

                        // OUTPUT BOX
                        Container(
                          padding: EdgeInsets.all(12),
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                blurRadius: 8,
                                color: Colors.black12,
                              )
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                translatedText,
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),

                              SizedBox(height: 8),

                              if (outputPinyin.isNotEmpty)
                                Text("📘 $outputPinyin"),

                              Align(
                                alignment: Alignment.centerRight,
                                child: IconButton(
                                  icon: Icon(Icons.volume_up),
                                  onPressed: () => speak(
                                    translatedText,
                                    isChinese: reverseMode,
                                  ),
                                ),
                              )
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // 🔥 BUTTON CỐ ĐỊNH
                Container(
                  padding: EdgeInsets.all(16),
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      padding: EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () {
                      if (isListening) {
                        stopListening();
                      } else {
                        startListening();
                      }
                    },
                    child: Text(
                      isListening ? "Stop Mic" : "Start Mic",
                      style: TextStyle(fontSize: 18),
                    ),
                  ),
                )
              ],
            ),
          ),

          // 🔥 LOGO GÓC PHẢI (FIX CHUẨN)
          Positioned(
            bottom: 90, // 👈 né nút mic phía dưới
            right: 16,
            child: IgnorePointer(
              child: Opacity(
                opacity: 0.4,
                child: CircleAvatar(
                  radius: 28,
                  backgroundImage: AssetImage("assets/avatar.jpg"),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}