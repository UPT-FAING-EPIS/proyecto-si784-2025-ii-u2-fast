import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'firebase_options.dart'; // Generado por flutterfire configure

// Importamos las vistas que crearemos
import 'web_form_page.dart';
import 'advisor_dashboard_app.dart'; // Será la app móvil

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // La app principal decide qué mostrar basado en la ruta inicial
    // Cuando se compila para web, la ruta por defecto es '/'
    // Cuando se compila para móvil, la ruta por defecto es '/'
    // Usaremos esto para diferenciar

    return MaterialApp(
      title: 'UPT Tutoría App',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => const WebFormPage(), // Por defecto, el formulario web
        '/advisor': (context) => const AdvisorDashboardApp(), // La app para el asesor
      },
      // Si la plataforma es Android/iOS, queremos que la app principal sea la del asesor.
      // Si es web, queremos que sea el formulario.
      // Esto es una simplificación, en un caso real se separaría en dos proyectos
      // o se usarían conditional imports/exports.
      // Para este ejemplo, lo manejaremos así:
      onGenerateRoute: (settings) {
        if (settings.name == '/') {
          // Si estamos en web, mostramos el formulario
          // Si estamos en mobile, idealmente mostraríamos el dashboard del asesor.
          // Para este demo, usaremos el mismo entry point, pero en un entorno real
          // tendrías dos main.dart o lógica más compleja.
          // Por simplicidad, aquí definimos que la raíz es el formulario web.
          // Más adelante, el "main" de la app del asesor será su propio widget.
          return MaterialPageRoute(builder: (context) => const WebFormPage());
        } else if (settings.name == '/advisor') {
          return MaterialPageRoute(builder: (context) => const AdvisorDashboardApp());
        }
        return null; // Ruta no encontrada
      },
    );
  }
}