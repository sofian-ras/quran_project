import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../models/reciter.dart';

class RecitersRepository {
  RecitersRepository._();
  static final RecitersRepository instance = RecitersRepository._();

  List<Reciter>? _cache;

  Future<List<Reciter>> loadReciters() async {
    if (_cache != null) return _cache!;
    final jsonStr = await rootBundle.loadString('assets/data/reciters_full.json');
    _cache = await compute(_parseReciters, jsonStr);
    return _cache!;
  }

  static List<Reciter> _parseReciters(String jsonStr) {
    final data = json.decode(jsonStr) as List<dynamic>;
    return data.map((e) => Reciter.fromJson(e as Map<String, dynamic>)).toList();
  }
}
