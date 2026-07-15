import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await _initializeFirebase();

  runApp(const SharkNetHRISApp());
}

Future<void> _initializeFirebase() async {
  if (kIsWeb) {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    return;
  }

  switch (defaultTargetPlatform) {
    case TargetPlatform.android:
      await Firebase.initializeApp();
      return;
    case TargetPlatform.iOS:
      await Firebase.initializeApp();
      return;
    case TargetPlatform.macOS:
    case TargetPlatform.windows:
    case TargetPlatform.linux:
    case TargetPlatform.fuchsia:
      return;
  }
}

class SharkNetHRISApp extends StatelessWidget {
  const SharkNetHRISApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SharkNet HRIS',
      debugShowCheckedModeBanner: false,
      home: const Scaffold(
        body: Center(
          child: Text(
            'SharkNet HRIS connected to Firebase',
            style: TextStyle(fontSize: 20),
          ),
        ),
      ),
    );
  }
}
