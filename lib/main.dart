import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Show errors visibly in release builds (TestFlight) instead of white screen
  ErrorWidget.builder = (FlutterErrorDetails details) {
    return Material(
      child: Container(
        color: Colors.red,
        padding: const EdgeInsets.all(16),
        child: SingleChildScrollView(
          child: Text(
            details.exception.toString(),
            style: const TextStyle(color: Colors.white, fontSize: 13),
          ),
        ),
      ),
    );
  };

  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  try {
    await dotenv.load(fileName: 'assets/.env').timeout(const Duration(seconds: 2));
  } catch (_) {
    dotenv.testLoad(fileInput: '');
  }

  runApp(const PolyArticleApp());

  MobileAds.instance.initialize();
}
