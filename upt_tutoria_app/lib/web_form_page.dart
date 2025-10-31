import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart'; // Asegúrate de tener esta importación si usas fechas

// Define los colores de la app del asesor para consistencia si es necesario
const Color primaryColor = Color(0xFF2C3E50);
const Color accentColor = Color(0xFF18BC9C);
const Color backgroundColor = Color(0xFFECF0F1);

class WebFormPage extends StatefulWidget {
  const WebFormPage({super.key});

  @override
  State<WebFormPage> createState() => _WebFormPageState();
}

// Enum para manejar los tipos de usuario de forma segura
enum UserType { student, external }

class _WebFormPageState extends State<WebFormPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _identifierController = TextEditingController(); // Único controlador para Código o DNI
  String? _selectedAttentionType;
  UserType? _selectedUserType; // Variable para almacenar el tipo de usuario

  bool _isLoading = false; // Para mostrar indicador de carga al enviar

  final List<String> attentionTypes = [
    'Motivo personal',
    'Reforzamiento',
    'Bajas calificaciones',
    'Llamado del asesor',
    'Otros'
  ];

  Future<void> _submitForm() async {
    if (_formKey.currentState!.validate()) {
      // Validar que se haya seleccionado un tipo de usuario
      if (_selectedUserType == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Por favor, selecciona si eres Estudiante o Externo.'),
            backgroundColor: Colors.orangeAccent,
          ),
        );
        return;
      }

      setState(() { _isLoading = true; });

      try {
        // Prepara los datos a guardar
        Map<String, dynamic> dataToSave = {
          'userType': _selectedUserType == UserType.student ? 'Estudiante' : 'Externo',
          'studentName': _nameController.text.trim(),
          'studentLastName': _lastNameController.text.trim(),
          'attentionType': _selectedAttentionType,
          'timestamp': FieldValue.serverTimestamp(), // Hora automática de Firebase
          'advisorNotes': '',
        };

        // Añade el identificador correcto según el tipo de usuario
        if (_selectedUserType == UserType.student) {
          dataToSave['studentCode'] = _identifierController.text.trim();
          dataToSave['dni'] = null; // Asegura que el otro campo sea nulo
        } else {
          dataToSave['dni'] = _identifierController.text.trim();
          dataToSave['studentCode'] = null; // Asegura que el otro campo sea nulo
        }

        await FirebaseFirestore.instance.collection('attentions').add(dataToSave);

        // Limpiar formulario
        _nameController.clear();
        _lastNameController.clear();
        _identifierController.clear();
        setState(() {
          _selectedAttentionType = null;
          _selectedUserType = null;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Atención registrada con éxito!'),
            backgroundColor: accentColor, // Usa el color de acento
          ),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al registrar atención: $e'),
            backgroundColor: Colors.redAccent,
          ),
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
    // Determina la etiqueta y el tipo de teclado para el campo identificador
    String identifierLabel = 'Código de Estudiante';
    TextInputType identifierKeyboardType = TextInputType.text; // Puede ser alfanumérico
    if (_selectedUserType == UserType.external) {
      identifierLabel = 'DNI';
      identifierKeyboardType = TextInputType.number; // DNI suele ser numérico
    }

    return Scaffold(
      backgroundColor: backgroundColor, // Fondo gris claro
      appBar: AppBar(
        title: const Text('Registro de Atención - Tutoría UPT'),
        backgroundColor: primaryColor, // Azul oscuro
        elevation: 0,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 600),
            padding: const EdgeInsets.all(24.0),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.15),
                  spreadRadius: 3,
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Text(
                    'Registra tu Atención',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(color: primaryColor),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),

                  // --- Selección de Tipo de Usuario ---
                  const Text('Tipo de Usuario:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: primaryColor)),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: <Widget>[
                      Expanded(
                        child: RadioListTile<UserType>(
                          title: const Text('Estudiante'),
                          value: UserType.student,
                          groupValue: _selectedUserType,
                          onChanged: (UserType? value) {
                            setState(() { _selectedUserType = value; });
                          },
                          activeColor: accentColor,
                        ),
                      ),
                      Expanded(
                        child: RadioListTile<UserType>(
                          title: const Text('Externo'),
                          value: UserType.external,
                          groupValue: _selectedUserType,
                          onChanged: (UserType? value) {
                            setState(() { _selectedUserType = value; });
                          },
                           activeColor: accentColor,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // --- Campos Comunes ---
                  TextFormField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: 'Nombres',
                      prefixIcon: Icon(Icons.person_outline),
                    ),
                    validator: (value) => (value == null || value.isEmpty) ? 'Ingresa tus nombres' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _lastNameController,
                    decoration: const InputDecoration(
                      labelText: 'Apellidos',
                      prefixIcon: Icon(Icons.person),
                    ),
                    validator: (value) => (value == null || value.isEmpty) ? 'Ingresa tus apellidos' : null,
                  ),
                  const SizedBox(height: 16),

                  // --- Campo Condicional: Código o DNI ---
                  // Solo se muestra si se ha seleccionado un tipo de usuario
                  if (_selectedUserType != null)
                    TextFormField(
                      controller: _identifierController,
                      decoration: InputDecoration(
                        labelText: identifierLabel,
                        prefixIcon: (_selectedUserType == UserType.student)
                            ? const Icon(Icons.school_outlined)
                            : const Icon(Icons.badge_outlined),
                      ),
                      keyboardType: identifierKeyboardType,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Ingresa tu $identifierLabel';
                        }
                        // Validación simple para DNI (8 dígitos)
                        if (_selectedUserType == UserType.external && value.length != 8) {
                           return 'El DNI debe tener 8 dígitos';
                        }
                        return null;
                      },
                    ),
                  const SizedBox(height: 16),

                  // --- Tipo de Atención ---
                  DropdownButtonFormField<String>(
                    value: _selectedAttentionType,
                    decoration: const InputDecoration(
                      labelText: 'Tipo de Atención',
                      prefixIcon: Icon(Icons.category_outlined),
                    ),
                    hint: const Text('Selecciona el motivo'),
                    items: attentionTypes.map((String type) {
                      return DropdownMenuItem<String>(value: type, child: Text(type));
                    }).toList(),
                    onChanged: (String? newValue) {
                      setState(() { _selectedAttentionType = newValue; });
                    },
                    validator: (value) => (value == null) ? 'Selecciona un tipo' : null,
                  ),
                  const SizedBox(height: 24),

                  // --- Botón de Envío ---
                  _isLoading
                      ? const Center(child: CircularProgressIndicator(color: accentColor))
                      : ElevatedButton.icon(
                          onPressed: _submitForm,
                          icon: const Icon(Icons.send_outlined),
                          label: const Text('Registrar Atención'),
                          style: ElevatedButton.styleFrom( // Estilo consistente con la app del asesor
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
        ),
      ),
    );
  }
}