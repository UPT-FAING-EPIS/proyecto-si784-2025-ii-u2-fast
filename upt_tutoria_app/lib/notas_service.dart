import 'dart:convert';
import 'package:http/http.dart' as http;
import 'notas_response.dart';

class NotasService {
  static const String baseUrl = 'https://upt-api.graystone-b1bd0bb9.eastus.azurecontainerapps.io';
  static const String endpoint = '/api/v1/notas/obtener';

  static Future<NotasResponse?> obtenerNotas({
    required String codigo,
    required String contrasena,
  }) async {
    try {
      final url = Uri.parse('$baseUrl$endpoint');
      
      final requestBody = {
        'codigo': codigo,
        'contrasena': contrasena,
        'headless': true,
        'timeout': 6,
      };

      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode(requestBody),
      );

      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body);
        return NotasResponse.fromJson(jsonData);
      } else {
        print('Error en la petición: ${response.statusCode}');
        print('Respuesta: ${response.body}');
        return null;
      }
    } catch (e) {
      print('Error al obtener notas: $e');
      return null;
    }
  }

  // Método para sugerir motivos de atención basados en las notas
  static List<String> sugerirMotivosAtencion(NotasResponse notasResponse) {
    List<String> motivosSugeridos = [];
    
    if (!notasResponse.success || notasResponse.notas.isEmpty) {
      motivosSugeridos.add('Otros');
      return motivosSugeridos;
    }

    // Analizar promedios de cursos
    List<double> promedios = notasResponse.notas
        .map((curso) => curso.promedioNumerico)
        .where((promedio) => promedio > 0)
        .toList();

    if (promedios.isNotEmpty) {
      double promedioGeneral = promedios.reduce((a, b) => a + b) / promedios.length;
      
      // Contar cursos con notas bajas
      int cursosConNotasBajas = promedios.where((p) => p < 11).length;
      
      // Sugerir motivos basados en el rendimiento
      if (promedioGeneral < 11) {
        motivosSugeridos.add('Bajas calificaciones');
      }
      
      if (cursosConNotasBajas >= 2) {
        motivosSugeridos.add('Reforzamiento');
      }
      
      // Verificar si hay evaluaciones perdidas o con nota 0
      bool tieneEvaluacionesPerdidas = false;
      for (var curso in notasResponse.notas) {
        for (var unidad in curso.unidades) {
          for (var evaluacion in unidad.evaluaciones) {
            if (evaluacion.nota.isEmpty || evaluacion.notaNumerica == 0) {
              tieneEvaluacionesPerdidas = true;
              break;
            }
          }
          if (tieneEvaluacionesPerdidas) break;
        }
        if (tieneEvaluacionesPerdidas) break;
      }
      
      if (tieneEvaluacionesPerdidas) {
        motivosSugeridos.add('Llamado del asesor');
      }
    }

    // Siempre incluir opciones generales
    if (!motivosSugeridos.contains('Reforzamiento')) {
      motivosSugeridos.add('Reforzamiento');
    }
    motivosSugeridos.add('Motivo personal');
    motivosSugeridos.add('Otros');

    return motivosSugeridos;
  }
}