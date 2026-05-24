import 'package:flutter/material.dart';
import 'package:kolo/app/kolo_app.dart';
import 'package:kolo/data/services/firebase_bootstrap.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final firebaseBootstrapResult = await FirebaseBootstrap.tryInitialize();
  runApp(KoloApp(firebaseBootstrapResult: firebaseBootstrapResult));
}
