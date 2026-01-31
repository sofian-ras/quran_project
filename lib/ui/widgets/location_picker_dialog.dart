import 'package:flutter/material.dart';
import '../../services/location_service.dart';

class LocationPickerDialog extends StatefulWidget {
  const LocationPickerDialog({super.key});

  @override
  State<LocationPickerDialog> createState() => _LocationPickerDialogState();
}

class _LocationPickerDialogState extends State<LocationPickerDialog> {
  final _cityController = TextEditingController();
  final _countryController = TextEditingController(text: 'France');
  bool _isLoading = false;
  String? _error;

  @override
  void dispose() {
    _cityController.dispose();
    _countryController.dispose();
    super.dispose();
  }

  Future<void> _useGps() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    final location = await LocationService.refreshLocation();
    
    setState(() => _isLoading = false);

    if (location != null && mounted) {
      Navigator.pop(context, location);
    } else {
      setState(() => _error =
          "Impossible d'obtenir la localisation.\n"
          "• Active le GPS\n"
          "• Autorise la localisation pour l’app (Réglages)\n"
          "• Réessaie.");
    }

  }

  Future<void> _saveManual() async {
    final city = _cityController.text.trim();
    final country = _countryController.text.trim();

    if (city.isEmpty) {
      setState(() => _error = 'Veuillez entrer une ville');
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    final ok = await LocationService.validateCityCountry(
      city,
      country.isEmpty ? 'France' : country,
    );

    if (!mounted) return;

    if (!ok) {
      setState(() {
        _isLoading = false;
        _error = "Ville/Pays introuvable. Vérifie l’orthographe.";
      });
      return;
    }

    final location = LocationData(
      city: city,
      country: country.isEmpty ? 'France' : country,
      latitude: 0,
      longitude: 0,
      isManual: true,
    );

    await LocationService.saveManualLocation(location.city, location.country);

    if (!mounted) return;
    setState(() => _isLoading = false);
    Navigator.pop(context, location);
  }


  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF0F1734) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF111827);

    return Dialog(
      backgroundColor: bg,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Localisation',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: textColor,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Choisissez comment définir votre localisation pour les horaires de prière',
              style: TextStyle(
                fontSize: 13,
                color: textColor.withOpacity(0.7),
              ),
            ),
            const SizedBox(height: 20),

            // Bouton GPS
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _isLoading ? null : _useGps,
                icon: _isLoading 
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.my_location_rounded),
                label: Text(_isLoading ? 'Localisation...' : 'Utiliser ma position'),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF2C6CB5),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),

            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(child: Divider(color: textColor.withOpacity(0.2))),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text(
                    'OU',
                    style: TextStyle(
                      fontSize: 12,
                      color: textColor.withOpacity(0.5),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Expanded(child: Divider(color: textColor.withOpacity(0.2))),
              ],
            ),
            const SizedBox(height: 16),

            // Saisie manuelle
            TextField(
              controller: _cityController,
              decoration: InputDecoration(
                labelText: 'Ville',
                hintText: 'Ex: Lyon',
                prefixIcon: const Icon(Icons.location_city_rounded),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _countryController,
              decoration: InputDecoration(
                labelText: 'Pays',
                hintText: 'Ex: France',
                prefixIcon: const Icon(Icons.public_rounded),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),

            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(
                _error!,
                style: const TextStyle(
                  color: Colors.red,
                  fontSize: 12,
                ),
              ),
            ],

            const SizedBox(height: 20),

            // Boutons d'action
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: textColor,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: const Text('Annuler'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: _isLoading ? null : _saveManual,
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF2C6CB5),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: const Text('Valider'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}