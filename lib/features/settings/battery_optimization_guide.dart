import 'dart:io';
import 'package:flutter/material.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:app_settings/app_settings.dart';

class BatteryOptimizationGuide extends StatefulWidget {
  const BatteryOptimizationGuide({super.key});

  @override
  State<BatteryOptimizationGuide> createState() => _BatteryOptimizationGuideState();
}

class _BatteryOptimizationGuideState extends State<BatteryOptimizationGuide> {
  String? _manufacturer;

  @override
  void initState() {
    super.initState();
    _detectManufacturer();
  }

  Future<void> _detectManufacturer() async {
    if (Platform.isAndroid) {
      final deviceInfo = DeviceInfoPlugin();
      final androidInfo = await deviceInfo.androidInfo;
      if (!mounted) return;
      setState(() {
        _manufacturer = androidInfo.manufacturer.toLowerCase();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Background Performance'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Icon(Icons.battery_saver, size: 64, color: colorScheme.tertiary),
          const SizedBox(height: 24),
          Text(
            'Keep your timer running',
            style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Text(
            'Some phone manufacturers aggressively kill apps to save battery. To ensure your timer works accurately in the background, please follow these steps:',
            style: theme.textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          
          if (_manufacturer != null) ...[
            _BrandSection(
              brand: _manufacturer!,
              isCurrent: true,
              colorScheme: colorScheme,
            ),
            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 24),
          ],

          Text(
            'Other Manufacturers',
            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          
          if (_manufacturer != 'samsung')
            _BrandSection(brand: 'samsung', colorScheme: colorScheme),
          if (_manufacturer != 'xiaomi')
            _BrandSection(brand: 'xiaomi', colorScheme: colorScheme),
          if (_manufacturer != 'huawei')
            _BrandSection(brand: 'huawei', colorScheme: colorScheme),
          if (_manufacturer != 'oneplus')
            _BrandSection(brand: 'oneplus', colorScheme: colorScheme),
          
          const SizedBox(height: 32),
          Center(
            child: FilledButton.icon(
              onPressed: () => AppSettings.openAppSettings(type: AppSettingsType.batteryOptimization),
              icon: const Icon(Icons.settings),
              label: const Text('Open Battery Settings'),
            ),
          ),
          const SizedBox(height: 16),
          Center(
            child: TextButton(
              onPressed: () => AppSettings.openAppSettings(),
              child: const Text('Open App Info'),
            ),
          ),
        ],
      ),
    );
  }
}

class _BrandSection extends StatelessWidget {
  const _BrandSection({
    required this.brand,
    this.isCurrent = false,
    required this.colorScheme,
  });

  final String brand;
  final bool isCurrent;
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    final title = brand.toUpperCase();
    final instructions = _getInstructions(brand);

    return Card(
      elevation: isCurrent ? 4 : 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: isCurrent 
            ? BorderSide(color: colorScheme.primary, width: 2)
            : BorderSide.none,
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: isCurrent ? colorScheme.primary : null,
                  ),
                ),
                if (isCurrent) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'YOUR DEVICE',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: colorScheme.onPrimaryContainer,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 12),
            ...instructions.map((step) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('• ', style: TextStyle(fontWeight: FontWeight.bold)),
                  Expanded(child: Text(step, style: const TextStyle(fontSize: 13))),
                ],
              ),
            )),
          ],
        ),
      ),
    );
  }

  List<String> _getInstructions(String brand) {
    switch (brand.toLowerCase()) {
      case 'samsung':
        return [
          'Settings > Apps > StudyTracker > Battery > Unrestricted',
          'Settings > Device Care > Battery > Background usage limits > Never sleeping apps > Add StudyTracker',
        ];
      case 'xiaomi':
        return [
          'Settings > Apps > Manage apps > StudyTracker > Battery saver > No restrictions',
          'Enable "Autostart" in app settings',
        ];
      case 'huawei':
        return [
          'Settings > Battery > App launch > StudyTracker > Disable "Manage automatically" > Enable "Manual management" (all 3 toggles)',
        ];
      case 'oneplus':
        return [
          'Settings > Battery > Battery optimization > StudyTracker > Don\'t optimize',
        ];
      default:
        return [
          'Settings > Apps > StudyTracker > Battery > Unrestricted or "Don\'t optimize"',
          'Ensure background data is enabled.',
        ];
    }
  }
}
