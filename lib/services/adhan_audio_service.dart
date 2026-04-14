import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ── Muezzins normaux ──────────────────────────────────────────────────────────
const kMuezzins = <String, String>{
  // AlAdhan CDN — noms vérifiés
  'aladhan_alafasy1': 'Mishary Rashid Alafasy (Yet Another)',
  'aladhan_nafees':   'Ahmad al-Nafees',
  'aladhan_ozcan':    'Hafiz Mustafa Özcan (Turquie)',
  'aladhan_jenkins':  'Karl Jenkins',
  'aladhan_alafasy4': 'Mishary Rashid Alafasy (Dubai One TV)',
  'aladhan_alafasy7': 'Mishary Rashid Alafasy (v2)',
  'aladhan_zahrani':  'Mansour Al-Zahrani',
  // PrayTimes Sunni — nom dans l'URL
  'pt_Abdul-Basit':   'Abdul Basit',
  'pt_Abdul-Ghaffar': 'Abdul Ghaffar',
  'pt_Abdul-Hakam':   'Abdul Hakam',
  'pt_Adhan-Alaqsa':  'Adhan Al-Aqsa',
  'pt_Adhan-Egypt':   'Adhan Égypte',
  'pt_Adhan-Halab':   'Adhan Halab',
  'pt_Adhan-Madinah': 'Adhan Madinah',
  'pt_Adhan-Makkah':  'Adhan Mecca',
  'pt_Al-Hussaini':   'Al-Hussaini',
  'pt_Bakir-Bash':    'Bakir Bash',
  'pt_Hafez':         'Hafez',
  'pt_Hafiz-Murad':   'Hafiz Murad',
  'pt_Minshawi':      'Minshawi',
  'pt_Naghshbandi':   'Naghshbandi',
  'pt_Saber':         'Saber',
  'pt_Sharif-Doman':  'Sharif Doman',
  'pt_Yusuf-Islam':   'Yusuf Islam',
};

const kAdhanUrls = <String, String>{
  'aladhan_alafasy1': 'https://cdn.aladhan.com/audio/adhans/a9.mp3',
  'aladhan_nafees':   'https://cdn.aladhan.com/audio/adhans/a1.mp3',
  'aladhan_ozcan':    'https://cdn.aladhan.com/audio/adhans/a2.mp3',
  'aladhan_jenkins':  'https://cdn.aladhan.com/audio/adhans/a3.mp3',
  'aladhan_alafasy4': 'https://cdn.aladhan.com/audio/adhans/a4.mp3',
  'aladhan_alafasy7': 'https://cdn.aladhan.com/audio/adhans/a7.mp3',
  'aladhan_zahrani':  'https://cdn.aladhan.com/audio/adhans/a11-mansour-al-zahrani.mp3',
  'pt_Abdul-Basit':   'https://praytimes.org/audio/sunni/Abdul-Basit.mp3',
  'pt_Abdul-Ghaffar': 'https://praytimes.org/audio/sunni/Abdul-Ghaffar.mp3',
  'pt_Abdul-Hakam':   'https://praytimes.org/audio/sunni/Abdul-Hakam.mp3',
  'pt_Adhan-Alaqsa':  'https://praytimes.org/audio/sunni/Adhan-Alaqsa.mp3',
  'pt_Adhan-Egypt':   'https://praytimes.org/audio/sunni/Adhan-Egypt.mp3',
  'pt_Adhan-Halab':   'https://praytimes.org/audio/sunni/Adhan-Halab.mp3',
  'pt_Adhan-Madinah': 'https://praytimes.org/audio/sunni/Adhan-Madinah.mp3',
  'pt_Adhan-Makkah':  'https://praytimes.org/audio/sunni/Adhan-Makkah.mp3',
  'pt_Al-Hussaini':   'https://praytimes.org/audio/sunni/Al-Hussaini.mp3',
  'pt_Bakir-Bash':    'https://praytimes.org/audio/sunni/Bakir-Bash.mp3',
  'pt_Hafez':         'https://praytimes.org/audio/sunni/Hafez.mp3',
  'pt_Hafiz-Murad':   'https://praytimes.org/audio/sunni/Hafiz-Murad.mp3',
  'pt_Minshawi':      'https://praytimes.org/audio/sunni/Minshawi.mp3',
  'pt_Naghshbandi':   'https://praytimes.org/audio/sunni/Naghshbandi.mp3',
  'pt_Saber':         'https://praytimes.org/audio/sunni/Saber.mp3',
  'pt_Sharif-Doman':  'https://praytimes.org/audio/sunni/Sharif-Doman.mp3',
  'pt_Yusuf-Islam':   'https://praytimes.org/audio/sunni/Yusuf-Islam.mp3',
};

// ── Muezzins Fajr (avec "As-salatu khayrun min an-nawm") ──────────────────────
const kFajrMuezzins = <String, String>{
  'fajr_zahrani':  'Mansour Al-Zahrani (Fajr)',
  'fajr_basit':    'Abdul Basit (Fajr)',
  'fajr_mecca':    'Mecca — Mosquée (Fajr)',
};

const kFajrAdhanUrls = <String, String>{
  'fajr_zahrani': 'https://archive.org/download/adhan_fajr_mansour_zahrani/adhan_fajr_mansour_zahrani.mp3',
  'fajr_basit':   'https://archive.org/download/Adhan/Abdul-Basit.mp3',
  'fajr_mecca':   'https://archive.org/download/AzanFajrPrayerFromTheHolyMosqueInMecca/wma.mp3',
};

// ── Clés SharedPreferences ────────────────────────────────────────────────────
const kPrefMuezzin     = 'prayer_muezzin';
const kPrefFajrMuezzin = 'prayer_muezzin_fajr';
const kDefaultMuezzin  = 'aladhan_alafasy1';

// ── Service ───────────────────────────────────────────────────────────────────
class AdhanAudioService {
  AdhanAudioService._();

  /// Retourne le chemin local du fichier adhan, le télécharge si absent.
  static Future<String> getOrDownload(String key, String url) async {
    final dir  = await getApplicationCacheDirectory();
    final file = File('${dir.path}/adhan_$key.mp3');
    if (!await file.exists()) {
      final res = await http.get(Uri.parse(url));
      if (res.statusCode != 200) throw Exception('HTTP ${res.statusCode}');
      await file.writeAsBytes(res.bodyBytes);
    }
    return file.path;
  }

  /// Télécharge en tâche de fond sans bloquer l'UI (fire-and-forget).
  static void preDownload(String key, String url) {
    // ignore: discarded_futures
    getOrDownload(key, url);
  }

  /// Sauvegarde le muezzin normal et déclenche le pré-téléchargement.
  static Future<void> setMuezzin(String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(kPrefMuezzin, key);
    final url = kAdhanUrls[key];
    if (url != null) preDownload(key, url);
  }

  /// Sauvegarde le muezzin Fajr et déclenche le pré-téléchargement.
  /// Passe [null] pour revenir au muezzin normal pour le Fajr aussi.
  static Future<void> setFajrMuezzin(String? key) async {
    final prefs = await SharedPreferences.getInstance();
    if (key == null) {
      await prefs.remove(kPrefFajrMuezzin);
    } else {
      await prefs.setString(kPrefFajrMuezzin, key);
      final url = kFajrAdhanUrls[key];
      if (url != null) preDownload(key, url);
    }
  }

  /// Charge les préférences muezzin depuis SharedPreferences.
  static Future<({String muezzin, String? muezzinFajr})> loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    return (
      muezzin:     prefs.getString(kPrefMuezzin)     ?? kDefaultMuezzin,
      muezzinFajr: prefs.getString(kPrefFajrMuezzin),
    );
  }

  /// Lookup combiné : cherche dans les deux maps.
  static String displayName(String key) =>
      kMuezzins[key] ?? kFajrMuezzins[key] ?? key;

  /// URL combinée : cherche dans les deux maps.
  static String? url(String key) => kAdhanUrls[key] ?? kFajrAdhanUrls[key];
}
