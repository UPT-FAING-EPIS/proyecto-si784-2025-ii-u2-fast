import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'advisor_dashboard_app.dart'; // Para colores y LoginPage

class CreateUserPage extends StatefulWidget {
  // Ya no necesita el rol del creador, siempre es superadmin
  const CreateUserPage({super.key});

  @override
  State<CreateUserPage> createState() => _CreateUserPageState();
}

class _CreateUserPageState extends State<CreateUserPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  String? _selectedRole; // Roles posibles: 'advisor', 'superadmin'
  bool _isLoading = false;

  // Roles que el superadmin puede crear
  final List<String> availableRoles = ['advisor', 'superadmin'];

  Future<void> _createNewUser() async {
    // Validar formulario y rol seleccionado
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_selectedRole == null) {
       ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Debes seleccionar un rol.'), backgroundColor: Colors.orangeAccent)
       );
       return;
    }

    setState(() { _isLoading = true; });

    User? createdUser; // Para manejar el cierre de sesión en caso de error

    try {
      // 1. Crear usuario en Firebase Authentication
      UserCredential userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
      createdUser = userCredential.user; // Guarda el usuario recién creado

      // 2. Guardar en Firestore
      if (createdUser != null) {
        await FirebaseFirestore.instance.collection('users').doc(createdUser.uid).set({
          'email': createdUser.email,
          'role': _selectedRole,
          'isActive': true, // Empieza activo
        });

        // 3. Mostrar éxito, cerrar sesión del NUEVO usuario y volver al Login
        if (mounted) {
           ScaffoldMessenger.of(context).showSnackBar(
             const SnackBar(content: Text('Usuario creado y activado con éxito.'), backgroundColor: accentColor),
           );
           // Cierra la sesión del usuario recién creado
           await FirebaseAuth.instance.signOut();
           // Vuelve a la pantalla de Login, eliminando las pantallas anteriores
           Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (context) => const LoginPage()),
              (Route<dynamic> route) => false, // Elimina todas las rutas anteriores
           );
        }
        // No necesitamos poner isLoading = false aquí porque ya hemos navegado

      } else {
         throw Exception('No se pudo obtener el usuario creado.');
      }

    } on FirebaseAuthException catch (e) {
      String message = 'Error al crear usuario.';
       if (e.code == 'weak-password') message = 'Contraseña débil (mín. 6 caracteres).';
       else if (e.code == 'email-already-in-use') message = 'El correo ya está registrado.';
       else if (e.code == 'invalid-email') message = 'Formato de correo inválido.';
      // Si el error es que el email ya existe y accidentalmente se inició sesión, ciérrala.
      if (FirebaseAuth.instance.currentUser != null && FirebaseAuth.instance.currentUser?.email != _emailController.text.trim()) {
           await FirebaseAuth.instance.signOut();
      }
      if (mounted) {
         ScaffoldMessenger.of(context).showSnackBar(
           SnackBar(content: Text(message), backgroundColor: Colors.redAccent),
         );
      }
    } catch (e) {
       // Si hay error después de crear en Auth pero antes de Firestore, cierra sesión
       // Asegúrate de cerrar sesión solo si el usuario actual es el que acabamos de crear
       if (createdUser != null && FirebaseAuth.instance.currentUser?.uid == createdUser.uid) {
         await FirebaseAuth.instance.signOut();
       }
       if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
           SnackBar(content: Text('Error inesperado: $e'), backgroundColor: Colors.redAccent),
         );
       }
    } finally {
       // Solo actualiza isLoading si todavía estamos en esta pantalla
       // (es decir, si no navegamos a LoginPage por éxito)
       if (mounted && Navigator.canPop(context)) {
         setState(() { _isLoading = false; });
       }
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Crear Nuevo Usuario'),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _emailController,
                 decoration: InputDecoration(
                   labelText: 'Correo Electrónico', prefixIcon: const Icon(Icons.email_outlined),
                   border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)), filled: true, fillColor: Colors.white,
                 ),
                keyboardType: TextInputType.emailAddress,
                validator: (v) => (v == null || !v.contains('@')) ? 'Ingresa un correo válido' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _passwordController,
                 decoration: InputDecoration(
                   labelText: 'Contraseña (mín. 6 caracteres)', prefixIcon: const Icon(Icons.lock_outline),
                   border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)), filled: true, fillColor: Colors.white,
                 ),
                obscureText: true,
                validator: (v) => (v == null || v.length < 6) ? 'Mínimo 6 caracteres' : null,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _selectedRole,
                 decoration: InputDecoration(
                   labelText: 'Rol del Usuario', prefixIcon: const Icon(Icons.shield_outlined),
                   border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)), filled: true, fillColor: Colors.white,
                 ),
                hint: const Text('Selecciona un rol'),
                items: availableRoles.map((role) {
                  String displayRole = role == 'superadmin' ? 'Super Admin' : 'Asesor';
                  return DropdownMenuItem(value: role, child: Text(displayRole));
                }).toList(),
                onChanged: (value) {
                   setState(() { _selectedRole = value; });
                },
                validator: (v) => v == null ? 'Debes seleccionar un rol' : null,
              ),
              const SizedBox(height: 32),
              _isLoading
                ? const Center(child: CircularProgressIndicator(color: accentColor))
                : ElevatedButton.icon(
                    onPressed: _createNewUser,
                    icon: const Icon(Icons.person_add_alt_1),
                    label: const Text('Crear Usuario'),
                     style: ElevatedButton.styleFrom(
                       backgroundColor: accentColor, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 16),
                       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                       textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                     ),
                  ),
            ],
          ),
        ),
      ),
    );
  }
}