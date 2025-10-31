import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'statistics_page.dart';
import 'stats_card_widget.dart';
import 'add_attention_page.dart';
import 'user_management_page.dart'; // Importa la página de gestión

import 'advisor_dashboard_app.dart';
import 'attention_detail_page.dart';
import 'pdf_service.dart';

class DashboardPage extends StatelessWidget {
  final String userRole; // Recibe el rol del usuario logueado

  DashboardPage({super.key, required this.userRole});

  final String webAppUrl = "https://upt-tutoria-app.web.app/";

  @override
  Widget build(BuildContext context) {
    final PdfService pdfService = PdfService();
    final bool isSuperAdmin = (userRole == 'superadmin'); // Verifica si es superadmin

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard de Atenciones'),
        // elevation: 0, // Puedes mantenerlo si te gusta
        actions: [
          // Botón de Información
          IconButton(
            icon: const Icon(Icons.info_outline),
            tooltip: 'Info Página Web',
            onPressed: () {
                showDialog(
                context: context,
                builder: (BuildContext context) {
                  return AlertDialog(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                    title: const Row(
                      children: [
                        Icon(Icons.link, color: primaryColor),
                        SizedBox(width: 8),
                        Text('Página de Registro Web'),
                      ],
                    ),
                    content: SingleChildScrollView(
                      child: ListBody(
                        children: <Widget>[
                          const Text('URL para el registro de asistencias:'),
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: SelectableText(
                              webAppUrl,
                              style: const TextStyle(fontWeight: FontWeight.bold, color: accentColor),
                              textAlign: TextAlign.center,
                            ),
                          ),
                          const SizedBox(height: 15),
                          Center(
                            child: ElevatedButton.icon(
                               icon: const Icon(Icons.copy, size: 16),
                               label: const Text('Copiar Enlace'),
                               style: ElevatedButton.styleFrom(
                                  backgroundColor: accentColor,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  )
                               ),
                               onPressed: () {
                                 Clipboard.setData(ClipboardData(text: webAppUrl));
                                 Navigator.of(context).pop();
                                 ScaffoldMessenger.of(context).showSnackBar(
                                   const SnackBar(content: Text('Enlace copiado al portapapeles'), backgroundColor: accentColor)
                                 );
                               },
                             ),
                          )
                        ],
                      ),
                    ),
                    actions: <Widget>[
                      TextButton(
                        child: const Text('Cerrar', style: TextStyle(color: primaryColor)),
                        onPressed: () {
                          Navigator.of(context).pop();
                        },
                      ),
                    ],
                  );
                },
              );
            },
          ),
          const SizedBox(width: 8.0),

          // --- Botón Gestionar Usuarios (SOLO para SuperAdmin) ---
          if (isSuperAdmin)
            IconButton(
              icon: const Icon(Icons.manage_accounts_outlined),
              tooltip: 'Gestionar Usuarios',
              onPressed: () {
                 Navigator.push(
                   context,
                   MaterialPageRoute(builder: (context) => const UserManagementPage()),
                 );
              },
            ),
          if (isSuperAdmin) const SizedBox(width: 8.0), // Espacio si el botón se muestra

          // Botón de Cerrar Sesión
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Cerrar Sesión',
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              if (context.mounted) {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (context) => const LoginPage()),
                  (Route<dynamic> route) => false,
                );
              }
            },
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('attentions')
            .orderBy('timestamp', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: primaryColor));
          }
          if (snapshot.hasError) {
             print("Error en StreamBuilder: ${snapshot.error}");
             return const Center(child: Text('Ocurrió un error al cargar los datos.'));
          }
           if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            // Mostrar la tarjeta de estadísticas incluso si no hay datos
            final Map<String, int> emptyCounts = {};
            return Column(
              children: [
                StatsCard(
                  attentionCounts: emptyCounts,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const StatisticsPage()),
                    );
                  },
                ),
                const Expanded(
                  child: Center(
                    child: Text(
                      'Aún no hay atenciones registradas.',
                      style: TextStyle(fontSize: 18, color: Colors.grey),
                    ),
                  ),
                ),
              ],
            );
          }


          final attentions = snapshot.data!.docs;
          final Map<String, int> attentionCounts = {};
          for (var doc in attentions) {
            final data = doc.data() as Map<String, dynamic>;
            final type = data['attentionType'] as String? ?? 'Desconocido';
            attentionCounts[type] = (attentionCounts[type] ?? 0) + 1;
          }

          return Column(
            children: [
              StatsCard(
                attentionCounts: attentionCounts,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const StatisticsPage()),
                  );
                },
              ),
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Atenciones Recientes',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: primaryColor),
                  ),
                ),
              ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(8, 0, 8, 80), // Padding inferior para no solapar con FABs
                  itemCount: attentions.length,
                  itemBuilder: (context, index) {
                    final attentionData = attentions[index].data() as Map<String, dynamic>;
                    String formattedDate = 'Fecha no disponible';
                    if (attentionData['timestamp'] != null) {
                      final timestamp = attentionData['timestamp'] as Timestamp;
                      formattedDate = DateFormat('dd/MM/yyyy, hh:mm a').format(timestamp.toDate());
                    }
                    String advisorNotes = attentionData['advisorNotes'] ?? '';
                    if (advisorNotes.length > 80) {
                      advisorNotes = '${advisorNotes.substring(0, 80)}...';
                    }

                    return Card( // Usa el tema por defecto
                      // margin y shape vienen del tema
                      child: ListTile(
                        leading: const Icon(Icons.person, color: accentColor, size: 30),
                        title: Text(
                          '${attentionData['studentName']} ${attentionData['studentLastName']}',
                          style: const TextStyle(fontWeight: FontWeight.bold, color: primaryColor),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(attentionData['attentionType'] ?? 'Sin tipo'),
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
                          String docId = attentions[index].id;
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => AttentionDetailPage(attentionId: docId),
                            ),
                          );
                        },
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: Padding(
         padding: const EdgeInsets.only(left: 32.0, right: 16.0, bottom: 16.0), // Ajusta padding
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            FloatingActionButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const AddAttentionPage()),
                );
              },
              heroTag: 'addAttentionBtn',
              // backgroundColor: accentColor, // Usa el tema por defecto
              tooltip: 'Añadir Nueva Atención',
              child: const Icon(Icons.add),
            ),
            FloatingActionButton(
              onPressed: () async {
                final data = await FirebaseFirestore.instance
                    .collection('attentions')
                    .orderBy('timestamp', descending: true)
                    .get();

                 if (!context.mounted) return;

                if (data.docs.isNotEmpty) {
                  await pdfService.generateAndPrintPdf(
                    data.docs,
                    dateFilter: 'all',
                    attentionType: null,
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('No hay datos para generar un reporte.')),
                  );
                }
              },
              heroTag: 'generatePdfBtn',
              backgroundColor: primaryColor, // Mantiene el color primario para PDF
              tooltip: 'Generar Reporte PDF General',
              child: const Icon(Icons.picture_as_pdf),
            ),
          ],
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat, // Posición ajustada
    );
  }
}