import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart'; // Para obtener el UID actual
import 'create_user_page.dart';
import 'advisor_dashboard_app.dart';

class UserManagementPage extends StatelessWidget {
  const UserManagementPage({super.key});

  // Función para cambiar el estado 'isActive'
  Future<void> _toggleUserStatus(BuildContext context, String userId, bool currentStatus) async {
    // Evita que el superadmin se desactive a sí mismo (seguridad extra)
    if (userId == FirebaseAuth.instance.currentUser?.uid) {
       ScaffoldMessenger.of(context).showSnackBar(
         const SnackBar(content: Text('No puedes desactivar tu propia cuenta.'), backgroundColor: Colors.orangeAccent),
       );
       return;
    }

    try {
      await FirebaseFirestore.instance.collection('users').doc(userId).update({
        'isActive': !currentStatus, // Invierte el estado
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Usuario ${!currentStatus ? "activado" : "desactivado"} con éxito.'),
          backgroundColor: accentColor,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al actualizar estado: $e'), backgroundColor: Colors.redAccent),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final String currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestionar Usuarios'),
        // elevation: 0, // Puedes mantenerlo
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('users').orderBy('email').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: primaryColor));
          }
          if (snapshot.hasError) {
             print("Error cargando usuarios: ${snapshot.error}");
            return const Center(child: Text('Error al cargar usuarios.'));
          }
          final users = snapshot.data?.docs ?? [];

          if (users.isEmpty) {
             return const Center(child: Text('No hay usuarios registrados.')); // Mensaje si solo está el admin
          }

          return ListView.builder(
            padding: const EdgeInsets.only(bottom: 80), // Padding inferior para el FAB
            itemCount: users.length,
            itemBuilder: (context, index) {
              final userData = users[index].data() as Map<String, dynamic>;
              final userId = users[index].id;
              final userEmail = userData['email'] ?? 'Sin email';
              final userRole = userData['role'] ?? 'Sin rol';
              final bool isActive = userData.containsKey('isActive') ? userData['isActive'] : false;

              final bool isCurrentUser = (userId == currentUserId);

              IconData roleIcon = Icons.person_outline;
              String roleDisplay = 'Asesor';
              if (userRole == 'superadmin') {
                 roleIcon = Icons.shield_outlined;
                 roleDisplay = 'Super Admin';
              }

              return Card( // Usa tema
                 color: isActive ? Colors.white : Colors.grey.shade100,
                 child: ListTile(
                   leading: Icon(roleIcon, color: isActive ? primaryColor : Colors.grey.shade400),
                   title: Text(userEmail, style: TextStyle(color: isActive ? Colors.black87 : Colors.grey)),
                   subtitle: Text('Rol: $roleDisplay', style: TextStyle(color: isActive ? Colors.black54 : Colors.grey)),
                   trailing: isCurrentUser
                     ? const Chip(label: Text('Tú'), avatar: Icon(Icons.star, size: 16, color: Colors.amber), padding: EdgeInsets.all(4))
                     : Switch(
                         value: isActive,
                         onChanged: (newValue) {
                           _toggleUserStatus(context, userId, isActive);
                         },
                       ),
                 ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const CreateUserPage()),
          );
        },
        label: const Text('Nuevo Usuario'),
        icon: const Icon(Icons.add),
        // backgroundColor: accentColor, // Usa tema
        // foregroundColor: Colors.white, // Usa tema
      ),
    );
  }
}