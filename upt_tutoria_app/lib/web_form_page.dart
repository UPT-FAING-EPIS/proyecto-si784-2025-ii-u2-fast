import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'notas_service.dart';
import 'notas_response.dart';

// Define los colores de la app del asesor para consistencia si es necesario
const Color primaryColor = Color(0xFF2C3E50);
const Color accentColor = Color(0xFF18BC9C);
const Color backgroundColor = Color(0xFFECF0F1);

class WebFormPage extends StatefulWidget {
  const WebFormPage({super.key});

  @override
  State<WebFormPage> createState() => _WebFormPageState();
}

class _WebFormPageState extends State<WebFormPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _codigoController = TextEditingController();
  final TextEditingController _contrasenaController = TextEditingController();
  String? _selectedAttentionType;
  bool _isExternalVisitor = false;
  
  bool _isLoading = false;
  bool _isLoadingNotas = false;
  NotasResponse? _notasResponse;
  List<String> _motivosSugeridos = [];
  String? _nombreEstudiante;

  final List<String> defaultAttentionTypes = [
    'Motivo personal',
    'Reforzamiento',
    'Bajas calificaciones',
    'Llamado del asesor',
    'Otros'
  ];

  final List<String> externalVisitorAttentionTypes = [
    'Consulta sobre estudiante',
    'Información académica',
    'Proceso de matrícula',
    'Situación académica',
    'Otros'
  ];

  @override
  void initState() {
    super.initState();
    // Agregar listeners para actualizar el estado del botón
    _codigoController.addListener(() => setState(() {}));
    _contrasenaController.addListener(() => setState(() {}));
  }

  Future<void> _obtenerNotas() async {
    // Validar campos específicos con mensajes más claros
    if (_codigoController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor, ingresa tu código de estudiante'),
          backgroundColor: Colors.orangeAccent,
        ),
      );
      return;
    }

    if (_codigoController.text.trim().length != 10 || !RegExp(r'^\d{10}$').hasMatch(_codigoController.text.trim())) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('El código de estudiante debe tener exactamente 10 dígitos (ej: 2022073503)'),
          backgroundColor: Colors.orangeAccent,
        ),
      );
      return;
    }

    if (_contrasenaController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor, ingresa tu contraseña de intranet'),
          backgroundColor: Colors.orangeAccent,
        ),
      );
      return;
    }

    setState(() { _isLoadingNotas = true; });

    try {
      // Mostrar mensaje de inicio de carga
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Conectando con la intranet UPT...'),
          backgroundColor: primaryColor,
          duration: Duration(seconds: 2),
        ),
      );

      final notasResponse = await NotasService.obtenerNotas(
        codigo: _codigoController.text.trim(),
        contrasena: _contrasenaController.text.trim(),
      );

      if (notasResponse != null && notasResponse.success) {
        setState(() {
          _notasResponse = notasResponse;
          _motivosSugeridos = NotasService.sugerirMotivosAtencion(notasResponse);
          // Extraer nombre del estudiante del primer curso si está disponible
          _nombreEstudiante = 'Estudiante ${_codigoController.text.trim()}';
          
          // Seleccionar automáticamente el primer motivo sugerido
          if (_motivosSugeridos.isNotEmpty) {
            _selectedAttentionType = _motivosSugeridos.first;
          }
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Notas obtenidas exitosamente. Se han sugerido motivos de atención.'),
            backgroundColor: accentColor,
            duration: const Duration(seconds: 4),
            action: SnackBarAction(
              label: 'Ver Detalle',
              textColor: Colors.white,
              onPressed: _mostrarModalCalificaciones,
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Error al obtener notas: Credenciales incorrectas o problema de conexión, intente nuevamente.'),
            backgroundColor: Colors.redAccent,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      print('Error detallado: $e'); // Para debug
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error de conexión: Verifica tu conexión a internet\nDetalle: $e'),
          backgroundColor: Colors.redAccent,
          duration: const Duration(seconds: 5),
        ),
      );
    } finally {
      setState(() { _isLoadingNotas = false; });
    }
  }

  Future<void> _submitForm() async {
    if (_formKey.currentState!.validate()) {
      if (_selectedAttentionType == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Por favor, selecciona un motivo de atención.'),
            backgroundColor: Colors.orangeAccent,
          ),
        );
        return;
      }

      // VALIDACIÓN OBLIGATORIA: Debe haber obtenido notas primero
      if (!_isExternalVisitor && _notasResponse == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Debes hacer clic en "Obtener Notas y Sugerir Motivos" antes de registrar tu atención.'),
            backgroundColor: Colors.orangeAccent,
            duration: Duration(seconds: 4),
          ),
        );
        return;
      }

      setState(() { _isLoading = true; });

      try {
        // Prepara los datos a guardar
        Map<String, dynamic> dataToSave = {
          'userType': 'Estudiante',
          'studentCode': _codigoController.text.trim(),
          'studentName': _nombreEstudiante ?? 'Estudiante ${_codigoController.text.trim()}',
          'studentLastName': '', 
          'attentionType': _selectedAttentionType,
          'dni': '',
          'timestamp': FieldValue.serverTimestamp(),
          'advisorNotes': '',
          'hasGrades': _notasResponse != null,
          'gradesData': _notasResponse != null ? {
            'totalCursos': _notasResponse!.totalCursos,
            'promedioGeneral': _calcularPromedioGeneral(),
            'cursosConNotasBajas': _contarCursosConNotasBajas(),
          } : null,
        };

        await FirebaseFirestore.instance.collection('attentions').add(dataToSave);

        // Limpiar formulario
        _codigoController.clear();
        _contrasenaController.clear();
        setState(() {
          _selectedAttentionType = null;
          _notasResponse = null;
          _motivosSugeridos = [];
          _nombreEstudiante = null;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Atención registrada con éxito!'),
            backgroundColor: accentColor,
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

  double _calcularPromedioGeneral() {
    if (_notasResponse == null || _notasResponse!.notas.isEmpty) return 0.0;
    
    List<double> promedios = _notasResponse!.notas
        .map((curso) => curso.promedioNumerico)
        .where((promedio) => promedio > 0)
        .toList();
    
    if (promedios.isEmpty) return 0.0;
    return promedios.reduce((a, b) => a + b) / promedios.length;
  }

  int _contarCursosConNotasBajas() {
    if (_notasResponse == null) return 0;
    
    return _notasResponse!.notas
        .where((curso) => curso.promedioNumerico > 0 && curso.promedioNumerico < 11)
        .length;
  }

  void _mostrarModalCalificaciones() {
    if (_notasResponse == null) return;

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(16),
          child: Container(
            width: MediaQuery.of(context).size.width,
            height: MediaQuery.of(context).size.height * 0.85,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: primaryColor.withOpacity(0.3),
                  spreadRadius: 3,
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  spreadRadius: 1,
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                // Header del modal
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [primaryColor, primaryColor.withOpacity(0.8)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(20),
                      topRight: Radius.circular(20),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: primaryColor.withOpacity(0.3),
                        spreadRadius: 1,
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.school, color: Colors.white, size: 28),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Mis Calificaciones',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              'Estudiante: ${_codigoController.text.trim()}',
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close, color: Colors.white),
                      ),
                    ],
                  ),
                ),
                
                // Resumen estadístico
                Container(
                  padding: const EdgeInsets.all(16),
                  color: backgroundColor,
                  child: Row(
                    children: [
                      Expanded(
                        child: _buildStatCard(
                          'Promedio General',
                          _calcularPromedioGeneral().toStringAsFixed(2),
                          Icons.trending_up,
                          _calcularPromedioGeneral() >= 11 ? accentColor : Colors.redAccent,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildStatCard(
                          'Total Cursos',
                          _notasResponse!.totalCursos.toString(),
                          Icons.book,
                          primaryColor,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildStatCard(
                          'Cursos en Riesgo',
                          _contarCursosConNotasBajas().toString(),
                          Icons.warning,
                          Colors.orangeAccent,
                        ),
                      ),
                    ],
                  ),
                ),

                // Lista de cursos
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _notasResponse!.notas.length,
                    itemBuilder: (context, index) {
                      final curso = _notasResponse!.notas[index];
                      return _buildCursoCard(curso);
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildCursoCard(Curso curso) {
    final promedio = curso.promedioNumerico;
    final colorPromedio = promedio >= 11 ? accentColor : Colors.redAccent;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorPromedio.withOpacity(0.2)),
        boxShadow: [
          BoxShadow(
            color: colorPromedio.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [colorPromedio, colorPromedio.withOpacity(0.8)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: colorPromedio.withOpacity(0.3),
                spreadRadius: 1,
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Center(
            child: Text(
              promedio.toStringAsFixed(1),
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
        ),
        title: Text(
          curso.nombreCurso,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
        ),
        subtitle: Container(
          margin: const EdgeInsets.only(top: 4),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: colorPromedio.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Promedio: ${curso.promedioFinal}',
                  style: TextStyle(
                    color: colorPromedio,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${curso.unidades.length} unidades',
                  style: TextStyle(
                    color: primaryColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
        children: curso.unidades.map((unidad) => _buildUnidadTile(unidad)).toList(),
      ),
    );
  }

  Widget _buildUnidadTile(Unidad unidad) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: backgroundColor.withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: primaryColor.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: primaryColor.withOpacity(0.1),
                  spreadRadius: 1,
                  blurRadius: 4,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.folder_open, color: primaryColor, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        unidad.nombre,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: primaryColor,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'Peso: ${unidad.pesoUnidad}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
                if (unidad.promedioUnidad != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Promedio de unidad: ${unidad.promedioUnidad}',
                    style: TextStyle(
                      color: accentColor,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                ...unidad.evaluaciones.map((evaluacion) => _buildEvaluacionRow(evaluacion)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEvaluacionRow(Evaluacion evaluacion) {
    final nota = evaluacion.notaNumerica;
    final colorNota = nota >= 11 ? accentColor : (nota > 0 ? Colors.orangeAccent : Colors.grey);
    
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colorNota.withOpacity(0.2)),
        boxShadow: [
          BoxShadow(
            color: colorNota.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 3,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 45,
            height: 45,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [colorNota.withOpacity(0.2), colorNota.withOpacity(0.1)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: colorNota.withOpacity(0.3)),
            ),
            child: Center(
              child: Text(
                evaluacion.nota.isEmpty ? '-' : evaluacion.nota,
                style: TextStyle(
                  color: colorNota,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  evaluacion.criterio,
                  style: const TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: 13,
                  ),
                ),
                if (evaluacion.descripcion.isNotEmpty)
                  Text(
                    evaluacion.descripcion,
                    style: const TextStyle(
                      color: Colors.grey,
                      fontSize: 12,
                    ),
                  ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Peso: ${evaluacion.pesoCriterio}',
                  style: TextStyle(
                    fontSize: 12,
                    color: primaryColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              if (evaluacion.fecha.isNotEmpty) ...[
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.grey.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    evaluacion.fecha,
                    style: const TextStyle(
                      fontSize: 11,
                      color: Colors.grey,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _codigoController.dispose();
    _contrasenaController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    List<String> availableAttentionTypes = _motivosSugeridos.isNotEmpty 
        ? _motivosSugeridos 
        : defaultAttentionTypes;

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: const Text('Registro de Atención - Tutoría UPT'),
        backgroundColor: primaryColor,
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

                  // --- Credenciales de Intranet ---
                  TextFormField(
                    controller: _codigoController,
                    decoration: const InputDecoration(
                      labelText: 'Código de Estudiante',
                      prefixIcon: Icon(Icons.school_outlined),
                      hintText: 'Ej: 2022073503',
                    ),
                    validator: (value) => (value == null || value.isEmpty) 
                        ? 'Ingresa tu código de estudiante' : null,
                  ),
                  const SizedBox(height: 16),

                  TextFormField(
                    controller: _contrasenaController,
                    decoration: const InputDecoration(
                      labelText: 'Contraseña de Intranet',
                      prefixIcon: Icon(Icons.lock_outline),
                      hintText: 'Tu contraseña de la intranet UPT',
                    ),
                    obscureText: true,
                    validator: (value) => (value == null || value.isEmpty) 
                        ? 'Ingresa tu contraseña' : null,
                  ),
                  const SizedBox(height: 20),

                  // --- Botón para Obtener Notas ---
                  _isLoadingNotas
                      ? const Center(
                          child: Column(
                            children: [
                              CircularProgressIndicator(color: accentColor),
                              SizedBox(height: 8),
                              Text('Obteniendo notas...', style: TextStyle(color: primaryColor)),
                            ],
                          ),
                        )
                      : ElevatedButton.icon(
                          onPressed: (_codigoController.text.trim().isNotEmpty && 
                                     _contrasenaController.text.trim().isNotEmpty) 
                              ? _obtenerNotas 
                              : null,
                          icon: const Icon(Icons.download_outlined),
                          label: const Text('Obtener Notas y Sugerir Motivos'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: (_codigoController.text.trim().isNotEmpty && 
                                             _contrasenaController.text.trim().isNotEmpty) 
                                ? primaryColor 
                                : Colors.grey,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                  
                  // Texto de ayuda
                  if (_codigoController.text.trim().isEmpty || _contrasenaController.text.trim().isEmpty)
                    const Padding(
                      padding: EdgeInsets.only(top: 8.0),
                      child: Text(
                        '💡 Completa tu código y contraseña para obtener las notas',
                        style: TextStyle(
                          color: Colors.grey,
                          fontSize: 12,
                          fontStyle: FontStyle.italic,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),

                  // --- Información del Estudiante ---
                  if (_notasResponse != null) ...[
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [accentColor.withOpacity(0.1), primaryColor.withOpacity(0.05)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: accentColor.withOpacity(0.3)),
                        boxShadow: [
                          BoxShadow(
                            color: accentColor.withOpacity(0.1),
                            spreadRadius: 1,
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: accentColor,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(
                                  Icons.school,
                                  color: Colors.white,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 12),
                              const Text(
                                'Resumen Académico',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: primaryColor,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          
                          // Estadísticas en tarjetas
                          Row(
                            children: [
                              Expanded(
                                child: _buildInfoCard(
                                  'Promedio',
                                  _calcularPromedioGeneral().toStringAsFixed(2),
                                  Icons.trending_up,
                                  _calcularPromedioGeneral() >= 11 ? accentColor : Colors.redAccent,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildInfoCard(
                                  'Cursos',
                                  _notasResponse!.totalCursos.toString(),
                                  Icons.book,
                                  primaryColor,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: _buildInfoCard(
                                  'En Riesgo',
                                  _contarCursosConNotasBajas().toString(),
                                  Icons.warning,
                                  Colors.orangeAccent,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildInfoCard(
                                  'Código',
                                  _codigoController.text,
                                  Icons.badge,
                                  Colors.blueAccent,
                                ),
                              ),
                            ],
                          ),
                          
                          const SizedBox(height: 16),
                          
                          // Botón para ver detalles
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: _mostrarModalCalificaciones,
                              icon: const Icon(Icons.visibility),
                              label: const Text('Ver Todas las Calificaciones'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: primaryColor,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 20),

                  // --- Tipo de Atención ---
                  DropdownButtonFormField<String>(
                    value: _selectedAttentionType,
                    decoration: InputDecoration(
                      labelText: 'Motivo de Atención',
                      prefixIcon: const Icon(Icons.category_outlined),
                      helperText: _motivosSugeridos.isNotEmpty 
                          ? 'Motivos sugeridos basados en tus notas' 
                          : 'Selecciona un motivo',
                    ),
                    hint: const Text('Selecciona el motivo'),
                    items: availableAttentionTypes.map((String type) {
                      bool isSuggested = _motivosSugeridos.contains(type);
                      return DropdownMenuItem<String>(
                        value: type,
                        child: Text(
                          isSuggested ? '⭐ $type' : type,
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    }).toList(),
                    onChanged: (String? newValue) {
                      setState(() { _selectedAttentionType = newValue; });
                    },
                    validator: (value) => (value == null) ? 'Selecciona un motivo' : null,
                  ),
                  const SizedBox(height: 24),

                  // --- Botón de Envío ---
                  _isLoading
                      ? const Center(child: CircularProgressIndicator(color: accentColor))
                      : ElevatedButton.icon(
                          onPressed: _submitForm,
                          icon: const Icon(Icons.send_outlined),
                          label: const Text('Registrar Atención'),
                          style: ElevatedButton.styleFrom(
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

  Widget _buildInfoCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.2)),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(
            icon,
            color: color,
            size: 24,
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}