import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';

class PdfService {
  Future<void> generateAndPrintPdf(
    List<QueryDocumentSnapshot> attentions, {
    required String dateFilter,
    DateTime? startDate,
    DateTime? endDate,
    String? attentionType,
  }) async {
    await initializeDateFormatting('es_PE', null);

    final pdf = pw.Document();
    final fontData = await rootBundle.load("assets/fonts/OpenSans-Regular.ttf");
    final ttf = pw.Font.ttf(fontData);

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        header: (pw.Context context) {
          return pw.Column(
            children: [
              pw.Text('Universidad Privada de Tacna',
                  style: pw.TextStyle(font: ttf, fontSize: 16, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 5),
              pw.Text('Reporte de Atenciones de Tutoría', style: pw.TextStyle(font: ttf, fontSize: 12)),
              pw.Padding(
                padding: const pw.EdgeInsets.only(top: 10, bottom: 20),
                child: pw.Divider(thickness: 1),
              ),
            ]
          );
        },
        footer: (pw.Context context) {
          return pw.Container(
            alignment: pw.Alignment.centerRight,
            margin: const pw.EdgeInsets.only(top: 10.0),
            child: pw.Text(
              'Página ${context.pageNumber} de ${context.pagesCount}',
              style: pw.TextStyle(font: ttf, fontSize: 10),
            ),
          );
        },
        build: (pw.Context context) {
          return [
            _buildFilterSummary(
              ttf,
              dateFilter: dateFilter,
              startDate: startDate,
              endDate: endDate,
              attentionType: attentionType,
            ),
            pw.SizedBox(height: 20),
            pw.Container(
              alignment: pw.Alignment.centerLeft,
              child: pw.Text(
                'Total de Atenciones Encontradas: ${attentions.length}',
                style: pw.TextStyle(font: ttf, fontSize: 12, fontWeight: pw.FontWeight.bold),
              ),
            ),
            pw.SizedBox(height: 10),
            _buildPdfTable(attentions, ttf), // Llama a la función de tabla actualizada
          ];
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
    );
  }

  pw.Widget _buildFilterSummary(
    pw.Font ttf, {
    required String dateFilter,
    DateTime? startDate,
    DateTime? endDate,
    String? attentionType,
  }) {
    String dateText;
    if (dateFilter == 'month') {
      dateText = "Periodo: Mes actual (${DateFormat.yMMMM('es_PE').format(DateTime.now())})";
    } else if (dateFilter == 'custom' && startDate != null && endDate != null) {
      dateText = "Periodo: Del ${DateFormat('dd/MM/yyyy').format(startDate)} al ${DateFormat('dd/MM/yyyy').format(endDate)}";
    } else {
      dateText = "Periodo: Todas las fechas";
    }
    final typeText = "Tipo de Atención: ${attentionType ?? 'Todos'}";

    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey, width: 1),
        borderRadius: pw.BorderRadius.circular(5),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text("Filtros Aplicados:", style: pw.TextStyle(font: ttf, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 5),
          pw.Text(dateText, style: pw.TextStyle(font: ttf)),
          pw.Text(typeText, style: pw.TextStyle(font: ttf)),
        ],
      ),
    );
  }

  // --- FUNCIÓN DE TABLA ACTUALIZADA ---
  pw.Widget _buildPdfTable(List<QueryDocumentSnapshot> attentions, pw.Font ttf) {
    // 1. Cambiar el encabezado de la columna
    final headers = ['N°', 'Nombres y Apellidos', 'Código/DNI', 'Tipo de Atención', 'Fecha'];

    final data = attentions.asMap().entries.map((entry) {
      final index = entry.key + 1;
      final doc = entry.value.data() as Map<String, dynamic>;

      String studentName = '${doc['studentName']} ${doc['studentLastName']}';
      String attentionType = doc['attentionType'] ?? 'N/A';

      // 2. Determinar qué identificador mostrar
      String identifier;
      if (doc['userType'] == 'Estudiante') {
        identifier = doc['studentCode']?.toString() ?? 'N/R';
      } else if (doc['userType'] == 'Externo') {
        identifier = doc['dni']?.toString() ?? 'N/R';
      } else {
        // Fallback si userType no está o es inesperado
        identifier = (doc['studentCode']?.toString() ?? doc['dni']?.toString()) ?? 'N/R';
      }


      String formattedDate = 'N/A';
      if (doc['timestamp'] != null) {
        final timestamp = doc['timestamp'] as Timestamp;
        formattedDate = DateFormat('dd/MM/yyyy').format(timestamp.toDate());
      }

      // 3. Devolver la fila con el identificador combinado
      return [index.toString(), studentName, identifier, attentionType, formattedDate];
    }).toList();

    return pw.Table.fromTextArray(
      headers: headers,
      data: data,
      headerStyle: pw.TextStyle(font: ttf, fontWeight: pw.FontWeight.bold, fontSize: 10),
      cellStyle: pw.TextStyle(font: ttf, fontSize: 9),
      headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
      cellHeight: 30,
      // 4. Ajustar alineaciones si es necesario (la columna 2 ahora es Código/DNI)
      cellAlignments: {
        0: pw.Alignment.center,
        1: pw.Alignment.centerLeft,
        2: pw.Alignment.center, // Código/DNI centrado
        3: pw.Alignment.centerLeft,
        4: pw.Alignment.center,
      },
    );
  }
}