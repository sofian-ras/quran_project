import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocationService {
  static const String _prefCity = 'prayer_city';
  static const String _prefCountry = 'prayer_country';
  static const String _prefLat = 'prayer_lat';
  static const String _prefLng = 'prayer_lng';
  static const String _prefManual = 'prayer_manual'; // true = saisie manuelle

  /// Vérifie et demande les permissions de localisation
  static Future<bool> handlePermission() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      await Geolocator.openLocationSettings();
      return false;
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return false;
    }

    if (permission == LocationPermission.deniedForever) {
      await Geolocator.openAppSettings();
      return false;
    }

    return true;
  }

  static Future<bool> validateCityCountry(String city, String country) async {
    try {
      final query = '${city.trim()}, ${country.trim()}';
      final results = await locationFromAddress(query);
      return results.isNotEmpty;
    } catch (_) {
      return false;
    }
  }



  /// Récupère la position GPS actuelle
  static Future<Position?> getCurrentPosition() async {
    final hasPermission = await handlePermission();
    if (!hasPermission) return null;

    try {
      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );
    } catch (e) {
      return null;
    }
  }


  /// Convertit les coordonnées en nom de ville
  static Future<LocationData?> getCityFromCoordinates(double lat, double lng) async {
    try {
      final placemarks = await placemarkFromCoordinates(lat, lng);
      if (placemarks.isEmpty) return null;

      final place = placemarks.first;
      
      // Priorité pour obtenir le nom de la ville
      String city = place.locality ?? 
                    place.subAdministrativeArea ?? 
                    place.administrativeArea ?? 
                    'Inconnu';
      
      // Nettoie le nom de la ville (enlève les codes postaux, etc.)
      city = city.replaceAll(RegExp(r'\d+'), '').trim();

      return LocationData(
        city: city,
        country: place.country ?? 'France',
        latitude: lat,
        longitude: lng,
        isManual: false,
      );
    } catch (e) {
      return null;
    }
  }

  /// Récupère la localisation complète (GPS + ville)
  static Future<LocationData?> getCurrentLocation() async {
    final position = await getCurrentPosition();
    if (position == null) return null;

    return await getCityFromCoordinates(position.latitude, position.longitude);
  }

  /// Sauvegarde la localisation dans les prefs
  static Future<void> saveLocation(LocationData location) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefCity, location.city);
    await prefs.setString(_prefCountry, location.country);
    await prefs.setDouble(_prefLat, location.latitude);
    await prefs.setDouble(_prefLng, location.longitude);
    await prefs.setBool(_prefManual, location.isManual);
  }

  /// Sauvegarde une ville manuelle (sans coordonnées GPS)
  static Future<void> saveManualLocation(String city, String country) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefCity, city);
    await prefs.setString(_prefCountry, country);
    await prefs.setBool(_prefManual, true);
    // Supprime les anciennes coordonnées
    await prefs.remove(_prefLat);
    await prefs.remove(_prefLng);
  }

  /// Récupère la ville sauvegardée ou demande la localisation
  static Future<LocationData> getSavedOrCurrentLocation() async {
    final prefs = await SharedPreferences.getInstance();
    
    final savedCity = prefs.getString(_prefCity);
    final savedCountry = prefs.getString(_prefCountry);
    final isManual = prefs.getBool(_prefManual) ?? false;

    // Si on a déjà une ville sauvegardée, on l'utilise
    if (savedCity != null && savedCity.isNotEmpty) {
      return LocationData(
        city: savedCity,
        country: savedCountry ?? 'France',
        latitude: prefs.getDouble(_prefLat) ?? 0,
        longitude: prefs.getDouble(_prefLng) ?? 0,
        isManual: isManual,
      );
    }

    // Sinon, on tente le GPS
    final current = await getCurrentLocation();
    if (current != null) {
      await saveLocation(current);
      return current;
    }

    // Fallback sur Paris
    return const LocationData(
      city: 'Paris',
      country: 'France',
      latitude: 48.8566,
      longitude: 2.3522,
      isManual: false,
    );
  }

  /// Force la mise à jour avec la position GPS actuelle
  static Future<LocationData?> refreshLocation() async {
    final location = await getCurrentLocation();
    if (location != null) {
      await saveLocation(location);
    }
    return location;
  }

  /// Vérifie si c'est la première fois (pas de ville sauvegardée)
  static Future<bool> isFirstTime() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_prefCity) == null;
  }
}

class LocationData {
  final String city;
  final String country;
  final double latitude;
  final double longitude;
  final bool isManual;

  const LocationData({
    required this.city,
    required this.country,
    required this.latitude,
    required this.longitude,
    this.isManual = false,
  });

  /// Affichage utilisateur : uniquement "Ville, Pays"
  String get displayLocation => '$city, $country';
}