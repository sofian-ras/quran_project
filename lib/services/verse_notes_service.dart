import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class VerseNotesService {
  static const String _kNotes = 'verse_notes';

  static final VerseNotesService _instance = VerseNotesService._internal();
  factory VerseNotesService() => _instance;
  VerseNotesService._internal();
  static VerseNotesService get instance => _instance;

  Map<String, String>? _cached;

  Future<Map<String, String>> getAll() async {
    if (_cached != null) return _cached!;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kNotes);
    if (raw == null) {
      _cached = {};
      return _cached!;
    }
    try {
      final map = json.decode(raw) as Map<String, dynamic>;
      _cached = map.map((k, v) => MapEntry(k, v as String));
      return _cached!;
    } catch (_) {
      _cached = {};
      return _cached!;
    }
  }

  String? getNote(String key) => _cached?[key];

  Future<void> setNote(String key, String text) async {
    await getAll();
    if (text.trim().isEmpty) {
      _cached!.remove(key);
    } else {
      _cached![key] = text.trim();
    }
    await _save();
  }

  Future<void> deleteNote(String key) async {
    await getAll();
    _cached!.remove(key);
    await _save();
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kNotes, json.encode(_cached));
  }

  void clearCache() => _cached = null;
}
