import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DuaFavoritesService {
  static const String _key = 'dua_favorites';
  static final DuaFavoritesService instance = DuaFavoritesService._();
  DuaFavoritesService._();

  final ValueNotifier<Set<String>> notifier = ValueNotifier(const {});
  Future<void>? _loadFuture;

  Future<void> _ensureLoaded() =>
      _loadFuture ??= SharedPreferences.getInstance().then((prefs) {
        notifier.value = (prefs.getStringList(_key) ?? []).toSet();
      });

  Future<Set<String>> getAll() async {
    await _ensureLoaded();
    return notifier.value;
  }

  Future<bool> isFavorite(String id) async {
    await _ensureLoaded();
    return notifier.value.contains(id);
  }

  Future<bool> toggle(String id) async {
    await _ensureLoaded();
    final wasPresent = notifier.value.contains(id);
    final next = Set<String>.from(notifier.value);
    if (wasPresent) { next.remove(id); } else { next.add(id); }
    notifier.value = next;
    _persist(next);
    return !wasPresent;
  }

  Future<void> remove(String id) async {
    await _ensureLoaded();
    final next = Set<String>.from(notifier.value);
    next.remove(id);
    notifier.value = next;
    _persist(next);
  }

  Future<void> add(String id) async {
    await _ensureLoaded();
    final next = Set<String>.from(notifier.value);
    next.add(id);
    notifier.value = next;
    _persist(next);
  }

  void _persist(Set<String> snapshot) {
    SharedPreferences.getInstance().then((prefs) {
      prefs.setStringList(_key, snapshot.toList());
    });
  }
}
