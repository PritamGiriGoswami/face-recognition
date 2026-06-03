import 'package:flutter/material.dart';
import '../services/gps_service.dart';

class GpsWidget extends StatefulWidget {
  const GpsWidget({super.key});

  @override
  State<GpsWidget> createState() => _GpsWidgetState();
}

class _GpsWidgetState extends State<GpsWidget> {
  final GpsService _gps = GpsService();
  final TextEditingController _latitudeController = TextEditingController();
  final TextEditingController _longitudeController = TextEditingController();

  String _status = 'Press the button to get location';
  double? _manualLatitude;
  double? _manualLongitude;

  @override
  void dispose() {
    _latitudeController.dispose();
    _longitudeController.dispose();
    super.dispose();
  }

  Future<void> _fetchLocation() async {
    setState(() => _status = 'Fetching…');
    final pos = await _gps.getCurrentPosition();
    if (pos == null) {
      setState(() => _status = 'Permission denied or GPS disabled');
    } else {
      setState(() {
        _manualLatitude = null;
        _manualLongitude = null;
        _status =
            'Lat: ${pos.latitude.toStringAsFixed(5)}, Lon: ${pos.longitude.toStringAsFixed(5)}';
      });
    }
  }

  void _applyManualLocation() {
    final latitude = double.tryParse(_latitudeController.text.trim());
    final longitude = double.tryParse(_longitudeController.text.trim());

    if (latitude == null ||
        longitude == null ||
        latitude < -90 ||
        latitude > 90 ||
        longitude < -180 ||
        longitude > 180) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Enter valid latitude (-90 to 90) and longitude (-180 to 180).'),
        ),
      );
      return;
    }

    setState(() {
      _manualLatitude = latitude;
      _manualLongitude = longitude;
      _status =
          'Manual Lat: ${latitude.toStringAsFixed(5)}, Lon: ${longitude.toStringAsFixed(5)}';
    });
    Navigator.pop(context);
  }

  void _clearManualLocation() {
    setState(() {
      _manualLatitude = null;
      _manualLongitude = null;
      _latitudeController.clear();
      _longitudeController.clear();
      _status = 'Manual location cleared. Press the button to get location';
    });
  }

  void _openManualLocationDialog() {
    if (_manualLatitude != null && _manualLongitude != null) {
      _latitudeController.text = _manualLatitude!.toString();
      _longitudeController.text = _manualLongitude!.toString();
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Set Manual GPS'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _latitudeController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
                signed: true,
              ),
              decoration: const InputDecoration(
                labelText: 'Latitude',
                hintText: '22.57260',
                prefixIcon: Icon(Icons.north),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _longitudeController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
                signed: true,
              ),
              decoration: const InputDecoration(
                labelText: 'Longitude',
                hintText: '88.36390',
                prefixIcon: Icon(Icons.east),
              ),
            ),
          ],
        ),
        actions: [
          if (_manualLatitude != null && _manualLongitude != null)
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _clearManualLocation();
              },
              child: const Text('Clear'),
            ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: _applyManualLocation,
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(12),
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_status, style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: _fetchLocation,
              icon: const Icon(Icons.my_location),
              label: const Text('Get Current Location'),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _openManualLocationDialog,
              icon: const Icon(Icons.edit_location_alt_outlined),
              label: Text(
                _manualLatitude == null
                    ? 'Set Manual Location'
                    : 'Change Manual Location',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
