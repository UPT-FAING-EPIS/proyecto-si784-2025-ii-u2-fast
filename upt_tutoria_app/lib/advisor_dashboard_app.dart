import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // Importación necesaria

import 'dashboard_page.dart';

// Paleta de Colores
const Color primaryColor = Color(0xFF2C3E50);
const Color accentColor = Color(0xFF18BC9C);
const Color backgroundColor = Color(0xFFECF0F1);

class AdvisorDashboardApp extends StatelessWidget {
  const AdvisorDashboardApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Dashboard del Asesor',
      theme: ThemeData( // Tema consistente
        primaryColor: primaryColor,
        scaffoldBackgroundColor: backgroundColor,
        colorScheme: ColorScheme.fromSwatch().copyWith(
          secondary: accentColor,
          primary: primaryColor,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          elevation: 0, // AppBar sin sombra
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: accentColor,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder( // Usar OutlineInputBorder por defecto
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: Colors.grey.shade300), // Borde sutil
          ),
          enabledBorder: OutlineInputBorder( // Borde cuando está habilitado
             borderRadius: BorderRadius.circular(10),
             borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          focusedBorder: OutlineInputBorder( // Borde cuando tiene foco
             borderRadius: BorderRadius.circular(10),
             borderSide: const BorderSide(color: primaryColor, width: 2), // Borde más grueso y color primario
          ),
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(vertical: 14.0, horizontal: 12.0), // Padding ajustado
        ),
         // Estilo para el Switch
        switchTheme: SwitchThemeData(
          thumbColor: MaterialStateProperty.resolveWith<Color?>((Set<MaterialState> states) {
            if (states.contains(MaterialState.selected)) {
              return accentColor; // Color cuando está activo
            }
            return null; // Usa el color por defecto cuando está inactivo
          }),
          trackColor: MaterialStateProperty.resolveWith<Color?>((Set<MaterialState> states) {
            if (states.contains(MaterialState.selected)) {
              return accentColor.withOpacity(0.5);
            }
            return null;
          }),
        ),
         textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(foregroundColor: primaryColor)
        ),
         // Estilo para Card
         cardTheme: CardThemeData(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
         ),
          // Estilo para FloatingActionButton
          floatingActionButtonTheme: const FloatingActionButtonThemeData(
             backgroundColor: accentColor, // Color de acento por defecto
             foregroundColor: Colors.white,
          )
      ),
      home: const LoginPage(),
    );
  }
}

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoading = false;
  String? _userRole; // Para guardar el rol

  // --- FUNCIÓN _signIn ACTUALIZADA ---
  Future<void> _signIn() async {
    // Ocultar teclado si está abierto
    FocusScope.of(context).unfocus();

    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _isLoading = true);
    _userRole = null; // Reinicia el rol en cada intento

    try {
      // 1. Inicia sesión en Firebase Auth
      UserCredential userCredential = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      // 2. Verifica si el usuario existe y está activo en Firestore
      if (userCredential.user != null) {
        DocumentSnapshot userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(userCredential.user!.uid)
            .get();

        if (userDoc.exists) {
          final userData = userDoc.data() as Map<String, dynamic>; // Obtener datos
          // Verificar si el campo 'isActive' existe y es true
          if (userData.containsKey('isActive') && userData['isActive'] == true) {
             _userRole = userData['role']; // Si existe y está activo, guarda el rol
          } else {
             // Si no existe 'isActive' o es false
             await FirebaseAuth.instance.signOut(); // Cierra sesión
             if (mounted) {
               ScaffoldMessenger.of(context).showSnackBar(
                 const SnackBar(
                   content: Text('Tu cuenta está deshabilitada. Contacta al administrador.'),
                   backgroundColor: Colors.orangeAccent,
                 ),
               );
             }
          }
        } else {
          // Si no existe en Firestore
          await FirebaseAuth.instance.signOut(); // Cierra sesión
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('No se encontró registro de usuario. Contacta al administrador.'),
                backgroundColor: Colors.orangeAccent,
              ),
            );
          }
        }
      }

      // 3. Navega al Dashboard SOLO si el usuario está activo y tenemos rol
      if (mounted && _userRole != null) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => DashboardPage(userRole: _userRole!)),
        );
      }
      // Si _userRole es null (inactivo o no encontrado), no navega

    } on FirebaseAuthException catch (e) {
      // Manejo específico para credenciales incorrectas
      String message = 'Correo o contraseña incorrectos.';
      // Podrías añadir más códigos de error si quisieras: 'user-not-found', 'wrong-password'
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message), backgroundColor: Colors.redAccent),
        );
      }
    } catch (e) { // Captura otros errores (Firestore, red, etc.)
      print("Error en _signIn: $e"); // Imprime el error para depuración
       if (mounted) {
         ScaffoldMessenger.of(context).showSnackBar(
           SnackBar(content: Text('Ocurrió un error inesperado al verificar usuario.'), backgroundColor: Colors.redAccent),
         );
       }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
  // --- FIN FUNCIÓN _signIn ---

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [primaryColor, Color(0xFF34495E)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center, // Centrar verticalmente
              children: [
                const Icon(Icons.school_outlined, size: 80, color: accentColor),
                const SizedBox(height: 20),
                const Text(
                  'Portal de Asesores',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 40),
                Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextFormField(
                        controller: _emailController,
                        decoration: const InputDecoration(
                          hintText: 'Correo Electrónico',
                          prefixIcon: Icon(Icons.email_outlined, color: primaryColor),
                        ),
                        keyboardType: TextInputType.emailAddress,
                        validator: (value) => (value == null || !value.contains('@'))
                            ? 'Ingresa un correo válido' : null,
                      ),
                      const SizedBox(height: 20),
                      TextFormField(
                        controller: _passwordController,
                        decoration: const InputDecoration(
                          hintText: 'Contraseña',
                          prefixIcon: Icon(Icons.lock_outline, color: primaryColor),
                        ),
                        obscureText: true,
                        validator: (value) => (value == null || value.isEmpty)
                            ? 'Ingresa tu contraseña' : null,
                      ),
                      const SizedBox(height: 30),
                      _isLoading
                          ? const Center(child: CircularProgressIndicator(color: accentColor))
                          : ElevatedButton(
                              onPressed: _signIn,
                              child: const Text('Iniciar Sesión'),
                            ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}