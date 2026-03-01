import 'package:flutter/material.dart';
import '../../services/location_service.dart';

const _kTeal  = Color(0xFF0E6B63);
const _kTeal2 = Color(0xFF0B4F4A);

class LocationPickerDialog extends StatefulWidget {
  const LocationPickerDialog({super.key});

  @override
  State<LocationPickerDialog> createState() => _LocationPickerDialogState();
}

class _LocationPickerDialogState extends State<LocationPickerDialog> {
  final _cityCtrl    = TextEditingController();
  final _countryCtrl = TextEditingController(text: 'France');
  bool   _isLoading  = false;
  String? _error;

  @override
  void dispose() {
    _cityCtrl.dispose();
    _countryCtrl.dispose();
    super.dispose();
  }

  Future<void> _useGps() async {
    setState(() { _isLoading = true; _error = null; });
    final location = await LocationService.refreshLocation();
    if (!mounted) return;
    setState(() => _isLoading = false);
    if (location != null) {
      Navigator.pop(context, location);
    } else {
      setState(() => _error =
          "Impossible d'obtenir la position.\n"
          "Active le GPS et autorise la localisation.");
    }
  }

  Future<void> _saveManual() async {
    final city    = _cityCtrl.text.trim();
    final country = _countryCtrl.text.trim();
    if (city.isEmpty) {
      setState(() => _error = 'Veuillez entrer une ville.');
      return;
    }
    setState(() { _isLoading = true; _error = null; });
    final ok = await LocationService.validateCityCountry(
        city, country.isEmpty ? 'France' : country);
    if (!mounted) return;
    if (!ok) {
      setState(() { _isLoading = false; _error = "Ville introuvable. Vérifie l'orthographe."; });
      return;
    }
    final loc = LocationData(
      city: city,
      country: country.isEmpty ? 'France' : country,
      latitude: 0, longitude: 0, isManual: true,
    );
    await LocationService.saveManualLocation(loc.city, loc.country);
    if (!mounted) return;
    setState(() => _isLoading = false);
    Navigator.pop(context, loc);
  }

  @override
  Widget build(BuildContext context) {
    final isDark   = Theme.of(context).brightness == Brightness.dark;
    final bgCard   = isDark ? const Color(0xFF111827) : Colors.white;
    final txtP     = isDark ? Colors.white             : const Color(0xFF0F172A);
    final txtS     = isDark ? Colors.white54           : Colors.black45;
    final fieldBg  = isDark ? const Color(0xFF1E2A3A)  : const Color(0xFFF1F5F9);
    final border   = isDark ? Colors.white12           : Colors.black12;

    InputDecoration field({
      required String label,
      required String hint,
      required IconData icon,
    }) =>
        InputDecoration(
          labelText:  label,
          hintText:   hint,
          labelStyle: TextStyle(color: isDark ? Colors.white54 : Colors.black45, fontSize: 13),
          hintStyle:  TextStyle(color: isDark ? Colors.white24 : Colors.black26, fontSize: 13),
          prefixIcon: Icon(icon, color: isDark ? Colors.white38 : Colors.black38, size: 20),
          filled:     true,
          fillColor:  fieldBg,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: _kTeal, width: 1.8),
          ),
        );

    return Container(
      decoration: BoxDecoration(
        color: bgCard,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      // padding bottom = keyboard height (géré automatiquement par isScrollControlled)
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [

              // ── Drag handle ──────────────────────────────────────────────
              Center(
                child: Container(
                  width: 36, height: 4,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white24 : Colors.black12,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // ── En-tête ──────────────────────────────────────────────────
              Row(
                children: [
                  Container(
                    width: 40, height: 40,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [_kTeal, _kTeal2],
                        begin: Alignment.topLeft, end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.location_on_rounded,
                        color: Colors.white, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Localisation',
                            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: txtP)),
                        Text('Pour les horaires de prière',
                            style: TextStyle(fontSize: 12, color: txtS)),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close_rounded, color: txtS, size: 20),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // ── Bouton GPS ───────────────────────────────────────────────
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _isLoading ? null : _useGps,
                  icon: _isLoading
                      ? const SizedBox(
                          width: 18, height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.my_location_rounded, size: 18),
                  label: Text(
                    _isLoading ? 'Localisation…' : 'Utiliser ma position GPS',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: _kTeal,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // ── Séparateur ───────────────────────────────────────────────
              Row(
                children: [
                  Expanded(child: Divider(color: isDark ? Colors.white12 : Colors.black12)),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text('ou saisir manuellement',
                        style: TextStyle(fontSize: 11, color: txtS, fontWeight: FontWeight.w500)),
                  ),
                  Expanded(child: Divider(color: isDark ? Colors.white12 : Colors.black12)),
                ],
              ),

              const SizedBox(height: 14),

              // ── Champs ───────────────────────────────────────────────────
              TextField(
                controller: _cityCtrl,
                style: TextStyle(color: txtP, fontSize: 14),
                textCapitalization: TextCapitalization.words,
                decoration: field(
                  label: 'Ville',
                  hint: 'Ex: Lyon, Marseille…',
                  icon: Icons.location_city_rounded,
                ),
                onSubmitted: (_) => FocusScope.of(context).nextFocus(),
              ),

              const SizedBox(height: 10),

              TextField(
                controller: _countryCtrl,
                style: TextStyle(color: txtP, fontSize: 14),
                textCapitalization: TextCapitalization.words,
                decoration: field(
                  label: 'Pays',
                  hint: 'Ex: France, Maroc…',
                  icon: Icons.public_rounded,
                ),
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _isLoading ? null : _saveManual(),
              ),

              // ── Erreur ───────────────────────────────────────────────────
              if (_error != null) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.red.withValues(alpha: 0.25)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline_rounded,
                          color: Colors.redAccent, size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(_error!,
                            style: const TextStyle(color: Colors.redAccent, fontSize: 12)),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 20),

              // ── Boutons ──────────────────────────────────────────────────
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: txtS,
                        side: BorderSide(color: isDark ? Colors.white12 : Colors.black12),
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: const Text('Annuler',
                          style: TextStyle(fontWeight: FontWeight.w600)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: FilledButton(
                      onPressed: _isLoading ? null : _saveManual,
                      style: FilledButton.styleFrom(
                        backgroundColor: _kTeal,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              width: 18, height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Text('Valider',
                              style: TextStyle(fontWeight: FontWeight.w700)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
