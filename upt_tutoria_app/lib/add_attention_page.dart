import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'advisor_dashboard_app.dart'; // Para los colores

// Copiamos el enum de web_form_page
enum UserType { student, external }

class AddAttentionPage extends StatefulWidget {
  const AddAttentionPage({super.key});

  @override
  State<AddAttentionPage> createState() => _AddAttentionPageState();
}

class _AddAttentionPageState extends State<AddAttentionPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _identifierController = TextEditingController();
  String? _selectedAttentionType;
  UserType? _selectedUserType;
  bool _isLoading = false;

  final List<String> attentionTypes = [
    'Motivo personal', 'Reforzamiento', 'Bajas calificaciones',
    'Llamado del asesor', 'Otros'
  ];

  Future<void> _saveNewAttention() async {
    if (_formKey.currentState!.validate()) {
      if (_selectedUserType == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Selecciona el tipo de usuario.'), backgroundColor: Colors.orangeAccent),
        );
        return;
      }

      setState(() { _isLoading = true; });

      try {
        Map<String, dynamic> dataToSave = {
          'userType': _selectedUserType == UserType.student ? 'Estudiante' : 'Externo',
          'studentName': _nameController.text.trim(),
          'studentLastName': _lastNameController.text.trim(),
          'attentionType': _selectedAttentionType,
          'timestamp': FieldValue.serverTimestamp(),
          'advisorNotes': '', // Notas iniciales vacías
        };

        if (_selectedUserType == UserType.student) {
          dataToSave['studentCode'] = _identifierController.text.trim();
          dataToSave['dni'] = null;
        } else {
          dataToSave['dni'] = _identifierController.text.trim();
          dataToSave['studentCode'] = null;
        }

        await FirebaseFirestore.instance.collection('attentions').add(dataToSave);

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Atención registrada con éxito.'), backgroundColor: accentColor),
        );
        if (mounted) Navigator.of(context).pop(); // Vuelve al dashboard

      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al guardar: $e'), backgroundColor: Colors.redAccent),
        );
      } finally {
         if (mounted) {
           setState(() { _isLoading = false; });
         }
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _lastNameController.dispose();
    _identifierController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
     String identifierLabel = 'Identificador';
     TextInputType identifierKeyboardType = TextInputType.text;
     IconData identifierIcon = Icons.badge; // Icono por defecto

     if (_selectedUserType == UserType.student) {
       identifierLabel = 'Código de Estudiante';
       identifierIcon = Icons.school_outlined;
     } else if (_selectedUserType == UserType.external) {
       identifierLabel = 'DNI';
       identifierKeyboardType = TextInputType.number;
       identifierIcon = Icons.badge_outlined;
     }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Registrar Nueva Atención'),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              // --- Selección de Tipo de Usuario ---
              const Text('Tipo de Usuario:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: primaryColor)),
              Row(
                children: <Widget>[
                  Expanded(
                    child: RadioListTile<UserType>(
                      title: const Text('Estudiante'), value: UserType.student, groupValue: _selectedUserType,
                      onChanged: (v) => setState(() => _selectedUserType = v), activeColor: accentColor,
                    ),
                  ),
                  Expanded(
                    child: RadioListTile<UserType>(
                      title: const Text('Externo'), value: UserType.external, groupValue: _selectedUserType,
                      onChanged: (v) => setState(() => _selectedUserType = v), activeColor: accentColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // --- Campos Comunes ---
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: 'Nombres',
                  prefixIcon: const Icon(Icons.person_outline),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  filled: true, fillColor: Colors.white,
                ),
                validator: (v) => (v == null || v.isEmpty) ? 'Ingresa nombres' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _lastNameController,
                 decoration: InputDecoration(
                   labelText: 'Apellidos',
                   prefixIcon: const Icon(Icons.person),
                   border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                   filled: true, fillColor: Colors.white,
                 ),
                validator: (v) => (v == null || v.isEmpty) ? 'Ingresa apellidos' : null,
              ),
              const SizedBox(height: 16),

              // --- Campo Condicional ---
              if (_selectedUserType != null)
                TextFormField(
                  controller: _identifierController,
                  decoration: InputDecoration(
                    labelText: identifierLabel,
                    prefixIcon: Icon(identifierIcon),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    filled: true, fillColor: Colors.white,
                  ),
                  keyboardType: identifierKeyboardType,
                  validator: (v) {
                     if (v == null || v.isEmpty) return 'Ingresa el $identifierLabel';
                     if (_selectedUserType == UserType.external && v.length != 8) return 'El DNI debe tener 8 dígitos';
                     return null;
                  },
                ),
              const SizedBox(height: 16),

              // --- Tipo de Atención ---
              DropdownButtonFormField<String>(
                value: _selectedAttentionType,
                decoration: InputDecoration(
                  labelText: 'Tipo de Atención',
                  prefixIcon: const Icon(Icons.category_outlined),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  filled: true, fillColor: Colors.white,
                ),
                hint: const Text('Selecciona el motivo'),
                items: attentionTypes.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                onChanged: (v) => setState(() => _selectedAttentionType = v),
                validator: (v) => v == null ? 'Selecciona un tipo' : null,
              ),
              const SizedBox(height: 32),

              // --- Botón Guardar ---
               _isLoading
                  ? const Center(child: CircularProgressIndicator(color: accentColor))
                  : ElevatedButton.icon(
                      onPressed: _saveNewAttention,
                      icon: const Icon(Icons.save),
                      label: const Text('Guardar Atención'),
                      style: ElevatedButton.styleFrom( // Estilo consistente
                        backgroundColor: accentColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
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