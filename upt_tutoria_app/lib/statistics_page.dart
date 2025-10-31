import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'stats_card_widget.dart'; // Importa el widget reutilizable

import 'advisor_dashboard_app.dart';
import 'attention_detail_page.dart';
import 'pdf_service.dart';

class StatisticsPage extends StatefulWidget {
  const StatisticsPage({super.key});
  @override
  State<StatisticsPage> createState() => _StatisticsPageState();
}

class _StatisticsPageState extends State<StatisticsPage> {
  String _dateFilter = 'all';
  DateTime? _startDate;
  DateTime? _endDate;
  String? _selectedAttentionType;
  List<QueryDocumentSnapshot> _filteredAttentions = [];
  bool _isLoading = true;

  final List<String> _attentionTypes = [
    'Motivo personal', 'Reforzamiento', 'Bajas calificaciones',
    'Llamado del asesor', 'Otros'
  ];

  @override
  void initState() {
    super.initState();
    _applyFilters();
  }

  Future<void> _applyFilters() async {
    setState(() { _isLoading = true; });

    Query query = FirebaseFirestore.instance.collection('attentions')
        .orderBy('timestamp', descending: true);

    // Aplicar filtro de tipo PRIMERO si está seleccionado
    if (_selectedAttentionType != null) {
      query = query.where('attentionType', isEqualTo: _selectedAttentionType);
    }

    // Aplicar filtro de fecha DESPUÉS
    DateTime now = DateTime.now();
    DateTime? effectiveStartDate;
    DateTime? effectiveEndDate;

    if (_dateFilter == 'month') {
      effectiveStartDate = DateTime(now.year, now.month, 1);
      effectiveEndDate = DateTime(now.year, now.month + 1, 0, 23, 59, 59);
    } else if (_dateFilter == 'custom' && _startDate != null && _endDate != null) {
       // Asegurarse que startDate sea antes que endDate
      if (_startDate!.isAfter(_endDate!)) {
         ScaffoldMessenger.of(context).showSnackBar(
           const SnackBar(content: Text('La fecha "Desde" debe ser anterior a la fecha "Hasta".'), backgroundColor: Colors.orangeAccent,)
         );
         setState(() => _isLoading = false);
         return; // Detener si las fechas son inválidas
      }
      effectiveStartDate = _startDate;
      effectiveEndDate = DateTime(_endDate!.year, _endDate!.month, _endDate!.day, 23, 59, 59);
    }

    // Añadir los filtros de fecha a la consulta
    if (effectiveStartDate != null) {
        query = query.where('timestamp', isGreaterThanOrEqualTo: effectiveStartDate);
    }
    if (effectiveEndDate != null) {
        query = query.where('timestamp', isLessThanOrEqualTo: effectiveEndDate);
    }


    try {
      final snapshot = await query.get();
      setState(() {
        _filteredAttentions = snapshot.docs;
        _isLoading = false;
      });
    } catch (e) {
      print("Error al aplicar filtros: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error al filtrar. Es posible que necesites crear un índice en Firebase. Revisa la consola de depuración.'),
            backgroundColor: Colors.redAccent,
            duration: Duration(seconds: 5), // Dar más tiempo para leer
          )
        );
      }
      setState(() { _isLoading = false; });
    }
  }


  Future<void> _selectDate(BuildContext context, {required bool isStartDate}) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: (isStartDate ? _startDate : _endDate) ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2101),
    );
    if (picked != null) {
      setState(() {
        if (isStartDate) {
          _startDate = picked;
           // Si startDate es posterior a endDate, ajusta endDate
          if (_endDate != null && _startDate!.isAfter(_endDate!)) {
            _endDate = _startDate;
          }
        } else {
          _endDate = picked;
          // Si endDate es anterior a startDate, ajusta startDate
           if (_startDate != null && _endDate!.isBefore(_startDate!)) {
            _startDate = _endDate;
          }
        }
      });
    }
  }


  @override
  Widget build(BuildContext context) {
    final PdfService pdfService = PdfService();

    return Scaffold(
      appBar: AppBar(title: const Text('Filtros y Estadísticas'), elevation: 0),
      body: Column(
        children: [
          _buildFilterControls(),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: primaryColor))
                : _filteredAttentions.isEmpty
                    ? const Center(
                        child: Padding(
                          padding: EdgeInsets.all(20.0),
                          child: Text(
                            'No se encontraron resultados para los filtros seleccionados.',
                            style: TextStyle(fontSize: 16, color: Colors.grey),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      )
                    : Column(
                      children: [
                        StatsCard(attentionCounts: _getAttentionCounts()),
                        const Padding(
                           padding: EdgeInsets.fromLTRB(16, 8, 16, 8),
                           child: Align(
                             alignment: Alignment.centerLeft,
                             child: Text(
                               'Resultados Filtrados',
                               style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: primaryColor),
                             ),
                           ),
                         ),
                        Expanded(child: _buildResultsList()),
                      ],
                    ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          if (_filteredAttentions.isNotEmpty) {
            await pdfService.generateAndPrintPdf(
              _filteredAttentions,
              dateFilter: _dateFilter,
              startDate: _startDate,
              endDate: _endDate,
              attentionType: _selectedAttentionType,
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('No hay datos filtrados para generar un reporte.')),
            );
          }
        },
        child: const Icon(Icons.picture_as_pdf),
        tooltip: 'Generar PDF Filtrado',
      ),
    );
  }

  // --- FUNCIÓN DE CONTROLES ACTUALIZADA ---
  Widget _buildFilterControls() {
    return Card(
      margin: const EdgeInsets.all(8.0),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // SegmentedButton de Fechas
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'all', label: Text('Todas'), icon: Icon(Icons.all_inclusive)),
                ButtonSegment(value: 'month', label: Text('Este Mes'), icon: Icon(Icons.calendar_month)),
                ButtonSegment(value: 'custom', label: Text('Rango'), icon: Icon(Icons.date_range)),
              ],
              selected: {_dateFilter},
              onSelectionChanged: (Set<String> newSelection) {
                setState(() { _dateFilter = newSelection.first; });
                if (_dateFilter != 'custom') {
                  _startDate = null;
                  _endDate = null;
                }
              },
            ),
            // Botones de Rango
            if (_dateFilter == 'custom')
              Padding(
                padding: const EdgeInsets.only(top: 16.0),
                child: Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                         style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12), textStyle: const TextStyle(fontSize: 14)),
                        onPressed: () => _selectDate(context, isStartDate: true),
                        child: Text(_startDate == null ? 'Desde' : DateFormat('dd/MM/yy').format(_startDate!)),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton(
                         style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12), textStyle: const TextStyle(fontSize: 14)),
                        onPressed: () => _selectDate(context, isStartDate: false),
                        child: Text(_endDate == null ? 'Hasta' : DateFormat('dd/MM/yy').format(_endDate!)),
                      ),
                    ),
                  ],
                ),
              ),
            // Fila para Dropdown y Botón Aplicar
            Padding(
              padding: const EdgeInsets.only(top: 16.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center, // Centrar verticalmente
                children: [
                  Expanded(
                    flex: 3, // Dropdown ocupa más espacio
                    child: DropdownButtonFormField<String>(
                      value: _selectedAttentionType,
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.category_outlined),
                        hintText: 'Tipo',
                        contentPadding: EdgeInsets.symmetric(vertical: 10.0, horizontal: 12.0), // Menos padding vertical
                        border: OutlineInputBorder(), // Añadir borde estándar
                      ),
                      isExpanded: true,
                      onChanged: (String? newValue) {
                        setState(() { _selectedAttentionType = newValue; });
                      },
                      items: [
                        const DropdownMenuItem<String>(value: null, child: Text('Todos')), // Texto más corto
                        ..._attentionTypes.map<DropdownMenuItem<String>>((String value) {
                          return DropdownMenuItem<String>(value: value, child: Text(value, overflow: TextOverflow.ellipsis)); // Evita overflow
                        }).toList(),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16), // Espacio entre dropdown y botón
                  Expanded(
                     flex: 2, // Botón ocupa menos espacio
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                         padding: const EdgeInsets.symmetric(vertical: 14.5), // Ajustar padding para alinear altura aprox.
                      ),
                      onPressed: _applyFilters,
                      child: const Text('Aplicar'), // Texto cambiado
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }


  Widget _buildResultsList() {
    if (_filteredAttentions.isEmpty) {
      return Container();
    }
    return ListView.builder(
      // Ya no necesita shrinkWrap ni physics porque está dentro de Expanded
      padding: const EdgeInsets.symmetric(horizontal: 8),
      itemCount: _filteredAttentions.length,
      itemBuilder: (context, index) {
        final data = _filteredAttentions[index].data() as Map<String, dynamic>;
        String formattedDate = 'Fecha no disponible';
        if (data['timestamp'] != null) {
          final timestamp = data['timestamp'] as Timestamp;
          formattedDate = DateFormat('dd/MM/yyyy, hh:mm a').format(timestamp.toDate());
        }

        String advisorNotes = data['advisorNotes'] ?? '';
        if (advisorNotes.length > 80) {
          advisorNotes = '${advisorNotes.substring(0, 80)}...';
        }

        return Card(
          elevation: 2,
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          child: ListTile(
            leading: const Icon(Icons.person, color: accentColor, size: 30),
            title: Text(
              '${data['studentName']} ${data['studentLastName']}',
              style: const TextStyle(fontWeight: FontWeight.bold, color: primaryColor),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(data['attentionType'] ?? 'Sin tipo'),
                if (advisorNotes.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4.0),
                    child: Text(
                      advisorNotes,
                      style: TextStyle(color: Colors.grey.shade700, fontStyle: FontStyle.italic, fontSize: 12),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.only(top: 4.0),
                  child: Text(
                    formattedDate,
                    style: const TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                ),
              ],
            ),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => AttentionDetailPage(attentionId: _filteredAttentions[index].id),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Map<String, int> _getAttentionCounts() {
    final Map<String, int> counts = {};
    for (var doc in _filteredAttentions) {
      final data = doc.data() as Map<String, dynamic>;
      final type = data['attentionType'] as String? ?? 'Desconocido';
      counts[type] = (counts[type] ?? 0) + 1;
    }
    return counts;
  }
}