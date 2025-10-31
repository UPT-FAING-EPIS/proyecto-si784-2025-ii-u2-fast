import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'advisor_dashboard_app.dart'; // Importa para acceder a los colores

class AttentionDetailPage extends StatefulWidget {
  final String attentionId;
  const AttentionDetailPage({super.key, required this.attentionId});

  @override
  State<AttentionDetailPage> createState() => _AttentionDetailPageState();
}

class _AttentionDetailPageState extends State<AttentionDetailPage> {
  final TextEditingController _notesController = TextEditingController();
  bool _isLoading = false;
  bool _isEditing = false;
  Map<String, dynamic>? _initialData;
  String? _selectedAttentionType;

  final List<String> _attentionTypes = [
    'Motivo personal', 'Reforzamiento', 'Bajas calificaciones',
    'Llamado del asesor', 'Otros'
  ];

  Future<void> _saveChanges() async {
     if (_selectedAttentionType == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecciona un tipo de atención.'), backgroundColor: Colors.orangeAccent),
      );
      return;
    }
    setState(() => _isLoading = true);
    try {
      await FirebaseFirestore.instance
          .collection('attentions')
          .doc(widget.attentionId)
          .update({
              'attentionType': _selectedAttentionType,
              'advisorNotes': _notesController.text.trim(),
          });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cambios guardados.'), backgroundColor: accentColor),
      );
      setState(() { _isEditing = false; }); // Salir del modo edición

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al guardar: $e'), backgroundColor: Colors.redAccent),
      );
    } finally {
       if (mounted) {
         setState(() => _isLoading = false);
       }
    }
  }

  Future<void> _deleteAttention() async {
    final bool? confirmDelete = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
         return AlertDialog(
          title: const Text('Confirmar Eliminación'),
          content: const Text('¿Estás seguro de que deseas eliminar este registro de atención permanentemente?'),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancelar'),
              onPressed: () => Navigator.of(context).pop(false), // No eliminar
            ),
            TextButton(
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Eliminar'),
              onPressed: () => Navigator.of(context).pop(true), // Sí eliminar
            ),
          ],
        );
      },
    );

    if (confirmDelete == true) {
      setState(() => _isLoading = true);
      try {
        await FirebaseFirestore.instance
            .collection('attentions')
            .doc(widget.attentionId)
            .delete();

        await Future.delayed(const Duration(milliseconds: 100));

        if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Registro eliminado.'), backgroundColor: Colors.redAccent),
            );
            Navigator.of(context).pop();
        }

      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error al eliminar: $e'), backgroundColor: Colors.redAccent),
          );
          setState(() => _isLoading = false);
        }
      }
    }
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Editar Atención' : 'Detalle de la Atención'),
        // elevation: 0, // Puedes mantenerlo
        actions: [
          // Botón Eliminar AHORA SIEMPRE VISIBLE (si no está editando)
          if (!_isEditing)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: 'Eliminar Registro',
              onPressed: _isLoading ? null : _deleteAttention,
            ),
          // Botón Editar / Guardar
          IconButton(
            icon: Icon(_isEditing ? Icons.save_alt_outlined : Icons.edit_outlined),
            tooltip: _isEditing ? 'Guardar Cambios' : 'Editar Registro',
            onPressed: _isLoading ? null : () {
              if (_isEditing) {
                _saveChanges();
              } else {
                 // Guardar los datos actuales antes de entrar en modo edición
                 if (_initialData != null) {
                    _selectedAttentionType = _initialData!['attentionType'];
                    _notesController.text = _initialData!['advisorNotes'] ?? '';
                 }
                setState(() => _isEditing = true);
              }
            },
          ),
          // Botón Cancelar (solo en modo edición)
          if (_isEditing)
             IconButton(
               icon: const Icon(Icons.cancel_outlined),
               tooltip: 'Cancelar Edición',
               onPressed: _isLoading ? null : () {
                  setState(() {
                    _isEditing = false;
                    if (_initialData != null) {
                        _selectedAttentionType = _initialData!['attentionType'];
                        _notesController.text = _initialData!['advisorNotes'] ?? '';
                    }
                  });
               },
             ),
        ],
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('attentions').doc(widget.attentionId).snapshots(),
        builder: (context, snapshot) {
           if (snapshot.connectionState == ConnectionState.waiting && _initialData == null) {
             return const Center(child: CircularProgressIndicator(color: primaryColor));
           }
           if (snapshot.hasError) {
              print("Error en StreamBuilder Detail: ${snapshot.error}");
              return const Center(child: Text('Error al cargar los datos.'));
           }
           if (!snapshot.hasData || !snapshot.data!.exists) {
              // Si el documento ya no existe, regresa
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Este registro ya no existe.'), backgroundColor: Colors.orangeAccent),
                  );
                  Navigator.of(context).pop();
                }
              });
              return const Center(child: CircularProgressIndicator()); // Muestra carga mientras navega
           }

           // Guardar/Actualizar datos solo si NO estamos editando activamente
           if (!_isEditing) {
             _initialData = snapshot.data!.data() as Map<String, dynamic>;
             _selectedAttentionType = _initialData!['attentionType'];
             _notesController.text = _initialData!['advisorNotes'] ?? '';
           } else if (_initialData == null){
              _initialData = snapshot.data!.data() as Map<String, dynamic>;
              _selectedAttentionType = _initialData!['attentionType'];
           }

           final currentData = _initialData!;

          String formattedDate = 'Fecha no disponible';
          if (currentData['timestamp'] != null) {
            final timestamp = currentData['timestamp'] as Timestamp;
            formattedDate = DateFormat('dd/MM/yyyy, hh:mm a').format(timestamp.toDate());
          }
          String userType = currentData['userType'] ?? 'Desconocido';
          String identifierLabel = '';
          String identifierValue = 'No registrado';
          if (userType == 'Estudiante') {
            identifierLabel = 'Código:';
            identifierValue = currentData['studentCode'] ?? 'No registrado';
          } else if (userType == 'Externo') {
            identifierLabel = 'DNI:';
            identifierValue = currentData['dni'] ?? 'No registrado';
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Card( // Usa tema
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildDetailRow('Tipo Usuario:', userType),
                        _buildDetailRow('Nombres:', currentData['studentName'] ?? 'N/A'),
                        _buildDetailRow('Apellidos:', currentData['studentLastName'] ?? 'N/A'),
                        if (identifierLabel.isNotEmpty) _buildDetailRow(identifierLabel, identifierValue),
                        _buildDetailRow('Fecha y Hora:', formattedDate),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Card( // Usa tema
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Tipo de Atención:', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey.shade600, fontSize: 14)),
                        const SizedBox(height: 4),
                        _isEditing
                         ? DropdownButtonFormField<String>(
                              value: _selectedAttentionType,
                              items: _attentionTypes.map((String type) {
                                return DropdownMenuItem<String>(value: type, child: Text(type));
                              }).toList(),
                              onChanged: (newValue) { setState(() { _selectedAttentionType = newValue; }); },
                              decoration: const InputDecoration(border: OutlineInputBorder()), // Borde estándar
                              validator: (value) => value == null ? 'Selecciona un tipo' : null,
                           )
                         : Text(_selectedAttentionType ?? 'N/A', style: const TextStyle(fontSize: 16, color: primaryColor)),
                        const SizedBox(height: 16),
                         const Text(
                          'Notas del Asesor:',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: primaryColor),
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: _notesController,
                          maxLines: _isEditing ? 5 : null,
                          readOnly: !_isEditing,
                          decoration: InputDecoration(
                            hintText: _isEditing ? 'Edita aquí tus observaciones...' : (_notesController.text.isEmpty ? 'Sin notas' : null),
                            filled: false, // Sin relleno dentro de la tarjeta
                            border: _isEditing ? const OutlineInputBorder() : InputBorder.none,
                            enabledBorder: _isEditing ? const OutlineInputBorder() : InputBorder.none,
                            focusedBorder: _isEditing ? const OutlineInputBorder(borderSide: BorderSide(color: accentColor)) : InputBorder.none,
                            contentPadding: _isEditing ? const EdgeInsets.all(12) : EdgeInsets.zero,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                if (_isEditing && !_isLoading)
                    ElevatedButton.icon(
                        onPressed: _saveChanges,
                        icon: const Icon(Icons.save_alt_outlined),
                        label: const Text('Guardar Cambios'),
                        // style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)), // Usa tema
                      ),
                if (_isLoading)
                   const Center(child: Padding(
                     padding: EdgeInsets.all(16.0),
                     child: CircularProgressIndicator(color: accentColor),
                   )),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildDetailRow(String title, String value) {
     return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey.shade600, fontSize: 14)),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(fontSize: 16, color: primaryColor)),
        ],
      ),
    );
  }
}