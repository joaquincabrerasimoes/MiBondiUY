class Subsystem {
  final int code;
  final String name;

  const Subsystem({required this.code, required this.name});

  static const List<Subsystem> subsystems = [Subsystem(code: 1, name: 'Montevideo'), Subsystem(code: 2, name: 'Canelones'), Subsystem(code: 3, name: 'San Jose'), Subsystem(code: 4, name: 'Metropolitano')];

  static Subsystem? getByCode(int code) {
    try {
      return subsystems.firstWhere((subsystem) => subsystem.code == code);
    } catch (e) {
      return null;
    }
  }
}
