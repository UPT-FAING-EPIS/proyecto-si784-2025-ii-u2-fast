class NotasResponse {
  final bool success;
  final String? url;
  final double tiempoTotal;
  final String? captcha;
  final String? error;
  final List<Curso> notas;
  final int totalCursos;

  NotasResponse({
    required this.success,
    this.url,
    required this.tiempoTotal,
    this.captcha,
    this.error,
    required this.notas,
    required this.totalCursos,
  });

  factory NotasResponse.fromJson(Map<String, dynamic> json) {
    return NotasResponse(
      success: json['success'] ?? false,
      url: json['url'],
      tiempoTotal: (json['tiempo_total'] ?? 0.0).toDouble(),
      captcha: json['captcha'],
      error: json['error'],
      notas: (json['notas'] as List<dynamic>?)
          ?.map((curso) => Curso.fromJson(curso))
          .toList() ?? [],
      totalCursos: json['total_cursos'] ?? 0,
    );
  }
}

class Curso {
  final String nombreCurso;
  final List<Unidad> unidades;
  final String promedioFinal;
  final bool tieneNotas;

  Curso({
    required this.nombreCurso,
    required this.unidades,
    required this.promedioFinal,
    required this.tieneNotas,
  });

  factory Curso.fromJson(Map<String, dynamic> json) {
    return Curso(
      nombreCurso: json['nombre_curso'] ?? '',
      unidades: (json['unidades'] as List<dynamic>?)
          ?.map((unidad) => Unidad.fromJson(unidad))
          .toList() ?? [],
      promedioFinal: json['promedio_final']?.toString() ?? '0',
      tieneNotas: json['tiene_notas'] ?? false,
    );
  }

  // Método para calcular el promedio numérico del curso
  double get promedioNumerico {
    try {
      return double.parse(promedioFinal);
    } catch (e) {
      return 0.0;
    }
  }
}

class Unidad {
  final String nombre;
  final String pesoUnidad;
  final List<Evaluacion> evaluaciones;
  final String? promedioUnidad;

  Unidad({
    required this.nombre,
    required this.pesoUnidad,
    required this.evaluaciones,
    this.promedioUnidad,
  });

  factory Unidad.fromJson(Map<String, dynamic> json) {
    return Unidad(
      nombre: json['nombre'] ?? '',
      pesoUnidad: json['peso_unidad'] ?? '',
      evaluaciones: (json['evaluaciones'] as List<dynamic>?)
          ?.map((eval) => Evaluacion.fromJson(eval))
          .toList() ?? [],
      promedioUnidad: json['promedio_unidad'],
    );
  }
}

class Evaluacion {
  final String criterio;
  final String pesoCriterio;
  final String nota;
  final String fecha;
  final String descripcion;

  Evaluacion({
    required this.criterio,
    required this.pesoCriterio,
    required this.nota,
    required this.fecha,
    required this.descripcion,
  });

  factory Evaluacion.fromJson(Map<String, dynamic> json) {
    return Evaluacion(
      criterio: json['criterio'] ?? '',
      pesoCriterio: json['peso_criterio'] ?? '',
      nota: json['nota']?.toString() ?? '',
      fecha: json['fecha'] ?? '',
      descripcion: json['descripcion'] ?? '',
    );
  }

  // Método para obtener la nota como número
  double get notaNumerica {
    try {
      if (nota.isEmpty) return 0.0;
      return double.parse(nota);
    } catch (e) {
      return 0.0;
    }
  }
}