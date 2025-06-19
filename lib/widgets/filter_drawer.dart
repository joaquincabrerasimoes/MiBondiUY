import 'package:flutter/material.dart';
import 'package:mibondiuy/models/company.dart';
import 'package:mibondiuy/models/subsystem.dart';

class FilterDrawer extends StatefulWidget {
  final int selectedSubsystem;
  final int selectedCompany;
  final Set<int> selectedCompanies;
  final List<String> selectedLines;
  final Function(
      {int? subsystem,
      int? company,
      Set<int>? companies,
      List<String>? lines}) onFiltersChanged;

  const FilterDrawer({
    super.key,
    required this.selectedSubsystem,
    required this.selectedCompany,
    required this.selectedCompanies,
    required this.selectedLines,
    required this.onFiltersChanged,
  });

  @override
  State<FilterDrawer> createState() => _FilterDrawerState();
}

class _FilterDrawerState extends State<FilterDrawer> {
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
    _tempCompanies = widget.selectedCompanies.isNotEmpty
        ? Set.from(widget.selectedCompanies)
        : Company.companies.map((c) => c.code).toSet();
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
    return Drawer(
      child: Column(
        children: [
          DrawerHeader(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  'MiBondiUY',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onPrimary,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'Filter Options',
                  style: TextStyle(
                    color: Theme.of(context)
                        .colorScheme
                        .onPrimary
                        .withValues(alpha: 0.7),
                    fontSize: 16,
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
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: DropdownButtonFormField<int>(
                    value: _tempSubsystem,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
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
                const SizedBox(height: 16),
                const Divider(),
                const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text(
                    'Bus Lines',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
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
                    ),
                    onChanged: (value) {
                      _tempLines = value
                          .split(',')
                          .map((s) => s.trim())
                          .where((s) => s.isNotEmpty)
                          .toList();
                    },
                  ),
                ),
                const SizedBox(height: 16),
                const Divider(),
                const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text(
                    'Companies',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
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
                        _tempCompanies
                            .addAll(Company.companies.map((c) => c.code));
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
                          width: 16,
                          height: 16,
                          decoration: BoxDecoration(
                            color: company.color,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(child: Text(company.name)),
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
                        _tempCompanies =
                            Company.companies.map((c) => c.code).toSet();
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
                      _linesController.text =
                          _linesController.text.toUpperCase();
                      widget.onFiltersChanged(
                        subsystem: _tempSubsystem,
                        company: _tempCompany,
                        companies: _tempCompanies,
                        lines: _tempLines,
                      );
                      Navigator.pop(context);
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
