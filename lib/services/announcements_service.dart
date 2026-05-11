import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/announcement.dart';

// ── URL du Gist GitHub (mettre à jour avec l'URL raw du Gist) ─────────────────
// Format : https://gist.githubusercontent.com/<user>/<gist_id>/raw/announcements.json
const _kGistUrl = 'https://gist.githubusercontent.com/sofian-ras/9f95dfe884dd687fb6178e15f89bfae6/raw/gistfile1.txt';

// ── Clés SharedPreferences ────────────────────────────────────────────────────
const _kRemoteCache = 'announcements_remote_cache';
const _kLastFetch   = 'announcements_last_fetch';
const _kReadIds     = 'announcements_read_ids';

// ── Clés streak (partagées avec StreakService) ────────────────────────────────
const _kStreakCount = 'streak_count';

const _kCacheDuration = Duration(hours: 1);

class AnnouncementsService {
  AnnouncementsService._();
  static final AnnouncementsService instance = AnnouncementsService._();

  final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 8),
    receiveTimeout: const Duration(seconds: 8),
  ));

  // ── API publique ─────────────────────────────────────────────────────────────

  Future<List<Announcement>> getAll() async {
    final remote = await _getRemote();
    final local  = await _generateLocal();
    final all    = [...remote, ...local];
    all.sort((a, b) => b.date.compareTo(a.date));
    return all;
  }

  Future<int> getUnreadCount() async {
    final all     = await getAll();
    final readIds = await _loadReadIds();
    return all.where((a) => !readIds.contains(a.id)).length;
  }

  Future<void> markRead(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final ids   = await _loadReadIds();
    if (!ids.contains(id)) {
      ids.add(id);
      await prefs.setString(_kReadIds, jsonEncode(ids));
    }
  }

  Future<void> markAllRead() async {
    final prefs = await SharedPreferences.getInstance();
    final all   = await getAll();
    final ids   = all.map((a) => a.id).toList();
    await prefs.setString(_kReadIds, jsonEncode(ids));
  }

  Future<bool> isRead(String id) async {
    final ids = await _loadReadIds();
    return ids.contains(id);
  }

  // ── Remote (GitHub Gist) ─────────────────────────────────────────────────────

  Future<List<Announcement>> _getRemote() async {
    if (_kGistUrl.isEmpty) return [];
    final prefs     = await SharedPreferences.getInstance();
    final lastFetch = prefs.getInt(_kLastFetch) ?? 0;
    final now       = DateTime.now().millisecondsSinceEpoch;
    final cached    = prefs.getString(_kRemoteCache);

    // Retourne le cache si encore frais
    if (cached != null && (now - lastFetch) < _kCacheDuration.inMilliseconds) {
      return _parseCache(cached);
    }

    // Sinon tente un refresh
    try {
      final resp = await _dio.get<String>(_kGistUrl);
      if (resp.statusCode == 200 && resp.data != null) {
        await prefs.setString(_kRemoteCache, resp.data!);
        await prefs.setInt(_kLastFetch, now);
        return _parseCache(resp.data!);
      }
    } catch (e) {
      debugPrint('[AnnouncementsService] fetch error: $e');
    }

    // Fallback sur le cache même périmé
    if (cached != null) return _parseCache(cached);
    return [];
  }

  List<Announcement> _parseCache(String json) {
    try {
      return Announcement.listFromJson(json);
    } catch (_) {
      return [];
    }
  }

  // ── Events locaux ────────────────────────────────────────────────────────────

  Future<List<Announcement>> _generateLocal() async {
    final prefs  = await SharedPreferences.getInstance();
    final streak = prefs.getInt(_kStreakCount) ?? 0;
    final events = <Announcement>[];

    // Message de bienvenue (toujours présent)
    events.add(Announcement(
      id:       'local-welcome',
      date:     DateTime(2025, 5, 11),
      title:    'Bienvenue sur القرآن الكريم',
      body:     'Explorez la lecture, les duas, la radio islamique et bien plus encore. Bonne lecture !',
      type:     AnnouncementType.info,
      isRemote: false,
    ));

    if (streak >= 30) {
      events.add(Announcement(
        id:       'local-streak-30',
        date:     DateTime.now(),
        title:    'Mashallah — 30 jours de suite !',
        body:     'Tu lis le Coran depuis 30 jours consécutifs. Que Allah bénisse ta régularité.',
        type:     AnnouncementType.streak,
        isRemote: false,
      ));
    } else if (streak >= 7) {
      events.add(Announcement(
        id:       'local-streak-7',
        date:     DateTime.now(),
        title:    '🔥 Streak 7 jours !',
        body:     'Une semaine complète de lecture quotidienne. Continue ainsi !',
        type:     AnnouncementType.streak,
        isRemote: false,
      ));
    }

    return events;
  }

  // ── Helpers ──────────────────────────────────────────────────────────────────

  Future<List<String>> _loadReadIds() async {
    final prefs = await SharedPreferences.getInstance();
    final raw   = prefs.getString(_kReadIds);
    if (raw == null) return [];
    try {
      return (jsonDecode(raw) as List<dynamic>).cast<String>();
    } catch (_) {
      return [];
    }
  }
}
