import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mibondiuy/models/company.dart';
import 'package:mibondiuy/services/theme_service.dart' as theme_service;
import 'package:mibondiuy/screens/bus_stop_data_screen.dart';

class SettingsScreen extends StatefulWidget {
  final theme_service.ThemeService? themeService;
  final VoidCallback? onRefreshBusStops;
  final bool isRefreshingBusStops;
  final bool alwaysShowAllBusStops;
  final bool alwaysShowAllBuses;
  final Function(bool) onAlwaysShowAllBusStopsChanged;
  final Function(bool) onAlwaysShowAllBusesChanged;
  final Map<int, Color> customCompanyColors;
  final Function(int, Color) onCompanyColorChanged;

  const SettingsScreen({
    super.key,
    this.themeService,
    this.onRefreshBusStops,
    this.isRefreshingBusStops = false,
    this.alwaysShowAllBusStops = true,
    this.alwaysShowAllBuses = true,
    required this.onAlwaysShowAllBusStopsChanged,
    required this.onAlwaysShowAllBusesChanged,
    required this.customCompanyColors,
    required this.onCompanyColorChanged,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _alwaysShowAllBusStops = true;
  bool _alwaysShowAllBuses = true;

  @override
  void initState() {
    super.initState();
    _alwaysShowAllBusStops = widget.alwaysShowAllBusStops;
    _alwaysShowAllBuses = widget.alwaysShowAllBuses;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          // Theme Section
          _buildSectionHeader('Appearance'),
          Card(
            child: Column(
              children: [
                if (widget.themeService != null)
                  ListTile(
                    leading: Icon(widget.themeService!.themeIcon),
                    title: const Text('Theme'),
                    subtitle: Text(widget.themeService!.themeTooltip),
                    trailing: Switch(
                      value: widget.themeService!.isDarkMode,
                      onChanged: (value) {
                        widget.themeService!.toggleTheme();
                        setState(() {});
                      },
                    ),
                  ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Map Behavior Section
          _buildSectionHeader('Map Behavior'),
          Card(
            child: Column(
              children: [
                SwitchListTile(
                  title: const Text('Always Show All Bus Stops'),
                  subtitle: const Text('When disabled, only selected bus stop shows when one is selected'),
                  value: _alwaysShowAllBusStops,
                  onChanged: (value) {
                    _alwaysShowAllBusStops = value;
                    widget.onAlwaysShowAllBusStopsChanged(value);
                    setState(() {});
                  },
                ),
                const Divider(height: 1),
                SwitchListTile(
                  title: const Text('Always Show All Buses'),
                  subtitle: const Text('When disabled, only buses through selected stop show when one is selected'),
                  value: _alwaysShowAllBuses,
                  onChanged: (value) {
                    _alwaysShowAllBuses = value;
                    widget.onAlwaysShowAllBusesChanged(value);
                    setState(() {});
                  },
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Data Section
          _buildSectionHeader('Data'),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.storage),
                  title: const Text('Bus Stop Data'),
                  subtitle: const Text('Manage bus stop data and cache'),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () => _navigateToBusStopData(),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Company Colors Section
          _buildSectionHeader('Company Colors'),
          Card(
            child: Column(
              children: [
                for (int i = 0; i < Company.companies.length; i++) ...[
                  if (i > 0) const Divider(height: 1),
                  _buildCompanyColorTile(Company.companies[i]),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.primary,
            ),
      ),
    );
  }

  Widget _buildCompanyColorTile(Company company) {
    final currentColor = widget.customCompanyColors[company.code] ?? company.color;

    return ListTile(
      leading: Container(
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          color: currentColor,
          shape: BoxShape.circle,
          border: Border.all(
            color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
          ),
        ),
      ),
      title: Text(company.name),
      subtitle: Text('Code: ${company.code}'),
      trailing: const Icon(Icons.palette, size: 20),
      onTap: () => _showColorPicker(company, currentColor),
    );
  }

  void _showColorPicker(Company company, Color currentColor) {
    showDialog(
      context: context,
      builder: (context) => _ColorPickerDialog(
        company: company,
        initialColor: currentColor,
        onColorChanged: (color) {
          widget.onCompanyColorChanged(company.code, color);
          setState(() {});
        },
      ),
    );
  }

  void _navigateToBusStopData() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => BusStopDataScreen(
          onRefreshBusStops: widget.onRefreshBusStops,
          isRefreshingBusStops: widget.isRefreshingBusStops,
        ),
      ),
    );
  }
}

class _ColorPickerDialog extends StatefulWidget {
  final Company company;
  final Color initialColor;
  final Function(Color) onColorChanged;

  const _ColorPickerDialog({
    required this.company,
    required this.initialColor,
    required this.onColorChanged,
  });

  @override
  State<_ColorPickerDialog> createState() => _ColorPickerDialogState();
}

class _ColorPickerDialogState extends State<_ColorPickerDialog> {
  late Color _selectedColor;
  late TextEditingController _redController;
  late TextEditingController _greenController;
  late TextEditingController _blueController;
  double _hue = 0;
  double _saturation = 1;
  double _lightness = 0.5;

  @override
  void initState() {
    super.initState();
    _selectedColor = widget.initialColor;
    _redController = TextEditingController(text: ((_selectedColor.r * 255.0).round() & 0xff).toString());
    _greenController = TextEditingController(text: ((_selectedColor.g * 255.0).round() & 0xff).toString());
    _blueController = TextEditingController(text: ((_selectedColor.b * 255.0).round() & 0xff).toString());

    // Convert RGB to HSL
    final hsl = _rgbToHsl((_selectedColor.r * 255.0).round() & 0xff, (_selectedColor.g * 255.0).round() & 0xff, (_selectedColor.b * 255.0).round() & 0xff);
    _hue = hsl[0];
    _saturation = hsl[1];
    _lightness = hsl[2];
  }

  @override
  void dispose() {
    _redController.dispose();
    _greenController.dispose();
    _blueController.dispose();
    super.dispose();
  }

  List<double> _rgbToHsl(int r, int g, int b) {
    double rNorm = r / 255.0;
    double gNorm = g / 255.0;
    double bNorm = b / 255.0;

    double max = [rNorm, gNorm, bNorm].reduce((a, b) => a > b ? a : b);
    double min = [rNorm, gNorm, bNorm].reduce((a, b) => a < b ? a : b);

    double h = 0, s = 0, l = (max + min) / 2;

    if (max == min) {
      h = s = 0; // achromatic
    } else {
      double d = max - min;
      s = l > 0.5 ? d / (2 - max - min) : d / (max + min);

      if (max == rNorm) {
        h = (gNorm - bNorm) / d + (gNorm < bNorm ? 6 : 0);
      } else if (max == gNorm) {
        h = (bNorm - rNorm) / d + 2;
      } else if (max == bNorm) {
        h = (rNorm - gNorm) / d + 4;
      }
      h /= 6;
    }

    return [h * 360, s, l];
  }

  Color _hslToRgb(double h, double s, double l) {
    h = h / 360;

    double r, g, b;

    if (s == 0) {
      r = g = b = l; // achromatic
    } else {
      double hue2rgb(double p, double q, double t) {
        if (t < 0) t += 1;
        if (t > 1) t -= 1;
        if (t < 1 / 6) return p + (q - p) * 6 * t;
        if (t < 1 / 2) return q;
        if (t < 2 / 3) return p + (q - p) * (2 / 3 - t) * 6;
        return p;
      }

      double q = l < 0.5 ? l * (1 + s) : l + s - l * s;
      double p = 2 * l - q;
      r = hue2rgb(p, q, h + 1 / 3);
      g = hue2rgb(p, q, h);
      b = hue2rgb(p, q, h - 1 / 3);
    }

    return Color.fromRGBO(
      (r * 255).round(),
      (g * 255).round(),
      (b * 255).round(),
      1.0,
    );
  }

  void _updateColorFromHsl() {
    final color = _hslToRgb(_hue, _saturation, _lightness);
    setState(() {
      _selectedColor = color;
      _redController.text = ((color.r * 255.0).round() & 0xff).toString();
      _greenController.text = ((color.g * 255.0).round() & 0xff).toString();
      _blueController.text = ((color.b * 255.0).round() & 0xff).toString();
    });
  }

  void _updateColorFromRgb() {
    final r = int.tryParse(_redController.text) ?? 0;
    final g = int.tryParse(_greenController.text) ?? 0;
    final b = int.tryParse(_blueController.text) ?? 0;

    final color = Color.fromRGBO(
      r.clamp(0, 255),
      g.clamp(0, 255),
      b.clamp(0, 255),
      1.0,
    );

    final hsl = _rgbToHsl((color.r * 255.0).round() & 0xff, (color.g * 255.0).round() & 0xff, (color.b * 255.0).round() & 0xff);

    setState(() {
      _selectedColor = color;
      _hue = hsl[0];
      _saturation = hsl[1];
      _lightness = hsl[2];
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('${widget.company.name} Color'),
      content: SizedBox(
        width: 300,
        height: 400,
        child: Column(
          children: [
            // Color preview
            Container(
              width: double.infinity,
              height: 60,
              decoration: BoxDecoration(
                color: _selectedColor,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Hue slider
            Text('Hue', style: Theme.of(context).textTheme.labelMedium),
            Slider(
              value: _hue,
              min: 0,
              max: 360,
              divisions: 360,
              onChanged: (value) {
                setState(() {
                  _hue = value;
                });
                _updateColorFromHsl();
              },
            ),

            // Saturation slider
            Text('Saturation', style: Theme.of(context).textTheme.labelMedium),
            Slider(
              value: _saturation,
              min: 0,
              max: 1,
              divisions: 100,
              onChanged: (value) {
                setState(() {
                  _saturation = value;
                });
                _updateColorFromHsl();
              },
            ),

            // Lightness slider
            Text('Lightness', style: Theme.of(context).textTheme.labelMedium),
            Slider(
              value: _lightness,
              min: 0,
              max: 1,
              divisions: 100,
              onChanged: (value) {
                setState(() {
                  _lightness = value;
                });
                _updateColorFromHsl();
              },
            ),

            const SizedBox(height: 20),

            // RGB input fields
            Text('RGB Values', style: Theme.of(context).textTheme.labelMedium),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _redController,
                    decoration: const InputDecoration(
                      labelText: 'R',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      FilteringTextInputFormatter.allow(RegExp(r'^([0-9]|[1-9][0-9]|1[0-9][0-9]|2[0-4][0-9]|25[0-5])$')),
                    ],
                    onChanged: (_) => _updateColorFromRgb(),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _greenController,
                    decoration: const InputDecoration(
                      labelText: 'G',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      FilteringTextInputFormatter.allow(RegExp(r'^([0-9]|[1-9][0-9]|1[0-9][0-9]|2[0-4][0-9]|25[0-5])$')),
                    ],
                    onChanged: (_) => _updateColorFromRgb(),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _blueController,
                    decoration: const InputDecoration(
                      labelText: 'B',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      FilteringTextInputFormatter.allow(RegExp(r'^([0-9]|[1-9][0-9]|1[0-9][0-9]|2[0-4][0-9]|25[0-5])$')),
                    ],
                    onChanged: (_) => _updateColorFromRgb(),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            // Reset to default
            final defaultColor = Company.companies.firstWhere((c) => c.code == widget.company.code).color;
            widget.onColorChanged(defaultColor);
            Navigator.of(context).pop();
          },
          child: const Text('Reset'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            widget.onColorChanged(_selectedColor);
            Navigator.of(context).pop();
          },
          child: const Text('Apply'),
        ),
      ],
    );
  }
}
