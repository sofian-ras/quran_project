import 'dart:convert';
import 'package:flutter/services.dart';
import '../models/reciter.dart';

class RecitersRepository {
  RecitersRepository._();
  static final RecitersRepository instance = RecitersRepository._();

  List<Reciter>? _cache;

  Future<List<Reciter>> loadReciters() async {
    if (_cache != null) return _cache!;

    // IMPORTANT:
    // Mets ici EXACTEMENT la même source que ReciterSelectorSheet utilise déjà.
    //
    // Si ReciterSelectorSheet charge depuis un JSON local => mets ce chemin.
    // Si ReciterSelectorSheet charge depuis une API => on déplacera ce code ici.

    final jsonStr = await rootBundle.loadString('assets/data/reciters_full.json');
    final List<dynamic> data = json.decode(jsonStr) as List<dynamic>;
    final list = data.map((e) => Reciter.fromJson(e as Map<String, dynamic>)).toList();

    _cache = list;
    return list;
  }
}
