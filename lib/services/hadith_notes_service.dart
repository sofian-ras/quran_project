import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class HadithNotesService {
  static final instance = HadithNotesService._();
  HadithNotesService._();

  static const _key = 'hadith_notes';
  Map<int, String>? _cache;

  Future<Map<int, String>> _load() async {
    if (_cache != null) return _cache!;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key) ?? '{}';
    final map = jsonDecode(raw) as Map<String, dynamic>;
    _cache = map.map((k, v) => MapEntry(int.parse(k), v as String));
    return _cache!;
  }

  Future<String> getNote(int id) async {
    final notes = await _load();
    return notes[id] ?? '';
  }

  Future<void> saveNote(int id, String note) async {
    final notes = await _load();
    if (note.trim().isEmpty) {
      notes.remove(id);
    } else {
      notes[id] = note.trim();
    }
    _cache = notes;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _key,
      jsonEncode(notes.map((k, v) => MapEntry(k.toString(), v))),
    );
  }

  Future<bool> hasNote(int id) async {
    final notes = await _load();
    return notes.containsKey(id) && notes[id]!.isNotEmpty;
  }
}
