import 'package:flutter/material.dart';
import 'package:mibondiuy/models/company.dart';
import 'package:mibondiuy/models/subsystem.dart';

class AdaptiveFilterPanel extends StatefulWidget {
  final int selectedSubsystem;
  final int selectedCompany;
  final Set<int> selectedCompanies;
  final List<String> selectedLines;
  final Map<int, Color> customCompanyColors;
  final Function({int? subsystem, int? company, Set<int>? companies, List<String>? lines}) onFiltersChanged;

  const AdaptiveFilterPanel({
    super.key,
    required this.selectedSubsystem,
    required this.selectedCompany,
    required this.selectedCompanies,
    required this.selectedLines,
    this.customCompanyColors = const {},
    required this.onFiltersChanged,
  });

  @override
  State<AdaptiveFilterPanel> createState() => _AdaptiveFilterPanelState();
}

class _AdaptiveFilterPanelState extends State<AdaptiveFilterPanel> {
  late int _tempSubsystem;
  late int _tempCompany;
  late Set<int> _tempCompanies;
  late List<String> _tempLines;
  late TextEditingController _linesController;

  @override
  void initState() {
    super.initState();
    _tempSubsystem = widget.selectedSubsystem;
    _tempCompany = widget.selectedCompany;
    _tempCompanies = widget.selectedCompanies.isNotEmpty ? Set.from(widget.selectedCompanies) : Company.companies.map((c) => c.code).toSet();
    _tempLines = List.from(widget.selectedLines);
    _linesController = TextEditingController(text: _tempLines.join(', '));
  }

  @override
  void dispose() {
    _linesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 300,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).shadowColor.withValues(alpha: 0.2),
            blurRadius: 8,
            offset: const Offset(2, 0),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16.0),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.filter_list, color: Theme.of(context).colorScheme.onPrimary),
                const SizedBox(width: 8),
                Text(
                  'Filters',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text(
                    'Subsystem',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: DropdownButtonFormField<int>(
                    value: _tempSubsystem,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    items: [
                      const DropdownMenuItem(
                        value: -1,
                        child: Text('All Subsystems'),
                      ),
                      ...Subsystem.subsystems.map(
                        (subsystem) => DropdownMenuItem(
                          value: subsystem.code,
                          child: Text(subsystem.name),
                        ),
                      ),
                    ],
                    onChanged: (value) {
                      setState(() {
                        _tempSubsystem = value!;
                      });
                    },
                  ),
                ),
                const SizedBox(height: 8),
                const Divider(),
                const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text(
                    'Bus Lines',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: TextField(
                    controller: _linesController,
                    decoration: const InputDecoration(
                      hintText: 'Enter line codes (e.g., 130, 60, 151)',
                      labelText: 'Lines (comma separated)',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    onChanged: (value) {
                      _tempLines = value.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
                    },
                  ),
                ),
                const SizedBox(height: 8),
                const Divider(),
                const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text(
                    'Companies',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
                CheckboxListTile(
                  title: const Text('Select All Companies'),
                  value: _tempCompanies.length == Company.companies.length,
                  tristate: true,
                  onChanged: (value) {
                    setState(() {
                      if (value == true) {
                        // Select all companies
                        _tempCompanies.addAll(Company.companies.map((c) => c.code));
                      } else {
                        // Unselect all companies
                        _tempCompanies.clear();
                      }
                    });
                  },
                ),
                ...Company.companies.map(
                  (company) => CheckboxListTile(
                    title: Row(
                      children: [
                        Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: widget.customCompanyColors[company.code] ?? company.color,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            company.name,
                            style: const TextStyle(fontSize: 12),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    value: _tempCompanies.contains(company.code),
                    onChanged: (value) {
                      setState(() {
                        if (value == true) {
                          _tempCompanies.add(company.code);
                        } else {
                          _tempCompanies.remove(company.code);
                        }
                      });
                    },
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _tempSubsystem = -1;
                        _tempCompany = -1;
                        _tempCompanies = Company.companies.map((c) => c.code).toSet();
                        _tempLines.clear();
                        _linesController.clear();
                      });
                    },
                    child: const Text('Reset'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      _linesController.text = _linesController.text.toUpperCase();
                      widget.onFiltersChanged(
                        subsystem: _tempSubsystem,
                        company: _tempCompany,
                        companies: _tempCompanies,
                        lines: _tempLines,
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: Theme.of(context).colorScheme.onPrimary,
                    ),
                    child: const Text('Apply'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
