import 'package:flutter/material.dart';

class Company {
  final int code;
  final String name;
  final Color color;

  const Company({required this.code, required this.name, required this.color});

  static const List<Company> companies = [
    Company(code: 10, name: 'COETC', color: Colors.red),
    Company(code: 13, name: 'EMPRESA CASANOVA LIMITADA', color: Colors.purple),
    Company(code: 18, name: 'COPSA', color: Colors.red),
    Company(code: 20, name: 'COME/COMESA', color: Colors.green),
    Company(code: 29, name: 'CITA', color: Colors.amber),
    Company(code: 32, name: 'SAN ANTONIO TRANSPORTE Y TURISMO', color: Colors.pink),
    Company(code: 33, name: 'C.O. DEL ESTE', color: Colors.deepOrange),
    Company(code: 35, name: 'TALA-PANDO-MONTEVIDEO', color: Colors.brown),
    Company(code: 36, name: 'SOLFY SA', color: Colors.cyan),
    Company(code: 37, name: 'TURIL', color: Colors.amber),
    Company(code: 39, name: 'ZEBALLOS HERMANOS', color: Colors.lime),
    Company(code: 41, name: 'RUTAS DEL NORTE', color: Colors.deepOrange),
    Company(code: 50, name: 'CUTCSA', color: Colors.blue),
    Company(code: 70, name: 'UCOT', color: Colors.amber),
    Company(code: 80, name: 'COIT', color: Colors.blueGrey),
  ];

  static Company? getByCode(int code) {
    try {
      return companies.firstWhere((company) => company.code == code);
    } catch (e) {
      return null;
    }
  }

  static Color getColorByCode(int code, {Map<int, Color>? customColors}) {
    if (customColors != null && customColors.containsKey(code)) {
      return customColors[code]!;
    }
    final company = getByCode(code);
    return company?.color ?? Colors.grey;
  }
}
