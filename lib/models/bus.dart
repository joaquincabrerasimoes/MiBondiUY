class Bus {
  final String id;
  final int codigoEmpresa;
  final int frecuencia;
  final int codigoBus;
  final int variante;
  final String linea;
  final String sublinea;
  final int tipoLinea;
  final String tipoLineaDesc;
  final int destino;
  final String destinoDesc;
  final int subsistema;
  final String subsistemaDesc;
  final int version;
  final int velocidad;
  final double latitude;
  final double longitude;

  Bus({
    required this.id,
    required this.codigoEmpresa,
    required this.frecuencia,
    required this.codigoBus,
    required this.variante,
    required this.linea,
    required this.sublinea,
    required this.tipoLinea,
    required this.tipoLineaDesc,
    required this.destino,
    required this.destinoDesc,
    required this.subsistema,
    required this.subsistemaDesc,
    required this.version,
    required this.velocidad,
    required this.latitude,
    required this.longitude,
  });

  factory Bus.fromJson(Map<String, dynamic> json) {
    final properties = json['properties'] as Map<String, dynamic>;
    final coordinates = json['geometry']['coordinates'] as List<dynamic>;

    return Bus(
      id: properties['id'] ?? '',
      codigoEmpresa: properties['codigoEmpresa'] ?? 0,
      frecuencia: properties['frecuencia'] ?? 0,
      codigoBus: properties['codigoBus'] ?? 0,
      variante: properties['variante'] ?? 0,
      linea: properties['linea'] ?? '',
      sublinea: properties['sublinea'] ?? '',
      tipoLinea: properties['tipoLinea'] ?? 0,
      tipoLineaDesc: properties['tipoLineaDesc'] ?? '',
      destino: properties['destino'] ?? 0,
      destinoDesc: properties['destinoDesc'] ?? '',
      subsistema: properties['subsistema'] ?? 0,
      subsistemaDesc: properties['subsistemaDesc'] ?? '',
      version: properties['version'] ?? 0,
      velocidad: properties['velocidad'] ?? 0,
      longitude: coordinates[0].toDouble(),
      latitude: coordinates[1].toDouble(),
    );
  }
}
