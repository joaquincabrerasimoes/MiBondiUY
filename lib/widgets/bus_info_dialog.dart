import 'package:flutter/material.dart';
import 'package:mibondiuy/models/bus.dart';
import 'package:mibondiuy/models/company.dart';

class BusInfoDialog extends StatelessWidget {
  final Bus bus;

  const BusInfoDialog({super.key, required this.bus});

  @override
  Widget build(BuildContext context) {
    final company = Company.getByCode(bus.codigoEmpresa);

    return AlertDialog(
      title: Row(
        children: [
          Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(color: company?.color ?? Colors.grey, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Text('Line ${bus.linea}'),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildInfoRow('Route', bus.sublinea),
            _buildInfoRow('Destination', bus.destinoDesc),
            _buildInfoRow('Company', company?.name ?? 'Unknown'),
            _buildInfoRow('Subsystem', bus.subsistemaDesc),
            _buildInfoRow('Type', bus.tipoLineaDesc),
            _buildInfoRow('Bus Number', bus.codigoBus.toString()),
            _buildInfoRow('Speed', '${bus.velocidad} km/h'),
            _buildInfoRow('Coordinates', '${bus.latitude.toStringAsFixed(6)}, ${bus.longitude.toStringAsFixed(6)}'),
          ],
        ),
      ),
      actions: [TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Close'))],
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text('$label:', style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}
