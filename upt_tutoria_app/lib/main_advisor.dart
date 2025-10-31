import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'firebase_options.dart'; // Generado por flutterfire configure

// Importamos la app del asesor directamente
import 'advisor_dashboard_app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  // Aquí ejecutamos la aplicación del asesor como la principal
  runApp(const AdvisorDashboardApp());
}