// lib/services/qul_audio/qul_catalog_service.dart
//
// Catalogue des récitateurs disponibles sur QUL (qul.tarteel.ai).
//
// Source de la liste : https://qul.tarteel.ai/resources/recitation (132 récitations).
//
// quranComId : ID sur api.quran.com/v4 (résolution des URLs audio).
//   - null → audio indisponible sur le CDN QUL public.
//   - Les IDs 1-12 proviennent de api.quran.com/v4/resources/recitations.
//
// Pour ajouter un récitateur :
//   1. Trouver son ID sur qul.tarteel.ai (qulId)
//   2. Trouver son ID sur api.quran.com (quranComId) en testant
//      api.quran.com/api/v4/recitations/{id}/by_chapter/1
//   3. Ajouter l'entrée à la liste ci-dessous.

import 'models/qul_reciter.dart';

class QulCatalogService {
  QulCatalogService._();
  static final QulCatalogService instance = QulCatalogService._();

  /// Liste complète des récitateurs QUL.
  /// Triée : disponibles d'abord, puis indisponibles.
  static const List<QulReciter> reciters = [
    // ── Disponibles sur le CDN QUL (quranComId connu) ──────────────────────
    QulReciter(qulId: 118, quranComId: 7,  name: 'Mishary Alafasy'),
    QulReciter(qulId: 102, quranComId: 3,  name: 'Abdur-Rahman as-Sudais'),
    QulReciter(qulId: 107, quranComId: 10, name: "Sa'ud ash-Shuraym"),
    QulReciter(qulId: 104, quranComId: 5,  name: 'Hani ar-Rifai'),
    QulReciter(qulId: 117, quranComId: 4,  name: 'Abu Bakr al-Shatri'),
    QulReciter(qulId: 114, quranComId: 1,  name: 'AbdulBaset AbdulSamad', style: 'Mujawwad'),
    QulReciter(qulId: 115, quranComId: 2,  name: 'AbdulBaset AbdulSamad', style: 'Murattal'),
    QulReciter(qulId: 108, quranComId: 9,  name: 'Mohamed al-Minshawi',   style: 'Murattal'),
    QulReciter(qulId: 314, quranComId: 8,  name: 'Mohamed al-Minshawi',   style: 'Mujawwad'),
    QulReciter(qulId: 112, quranComId: 6,  name: 'Mahmoud Khalil Al-Husary'),
    // ── Non indexés publiquement (quranComId: null = indisponible) ──────────
    // Ces récitateurs apparaissent sur qul.tarteel.ai mais leurs URLs audio
    // ne sont pas accessibles via l'API publique de quran.com.
    // Pour les activer : trouver leur quranComId et mettre à jour.
    QulReciter(qulId: 562, quranComId: null, name: 'Maher al-Muaiqly'),
    QulReciter(qulId: 119, quranComId: null, name: 'Saad al-Ghamdi'),
    QulReciter(qulId: 415, quranComId: null, name: 'Abdullah Awad al-Juhani'),
    QulReciter(qulId: 416, quranComId: null, name: 'Abdullah Basfar'),
    QulReciter(qulId: 422, quranComId: null, name: 'Yasser ad-Dussary'),
    QulReciter(qulId: 419, quranComId: null, name: 'Muhammad Jibreel'),
    QulReciter(qulId: 418, quranComId: null, name: 'Ali Abdur-Rahman al-Huthaify'),
    QulReciter(qulId: 356, quranComId: null, name: 'Nasser al-Qatami'),
    QulReciter(qulId: 388, quranComId: null, name: 'Bandar Baleela'),
    QulReciter(qulId: 328, quranComId: 60,   name: 'Abdur-Rashid Sufi', style: 'Soosi'),
    QulReciter(qulId: 360, quranComId: 110,  name: 'Abdur-Rashid Sufi', style: "Kasaa'ee"),
    QulReciter(qulId: 363, quranComId: 111,  name: 'Abdur-Rashid Sufi', style: 'Ad-Doori'),
    QulReciter(qulId: 364, quranComId: 112,  name: 'Abdur-Rashid Sufi', style: "Shu'bah"),
    QulReciter(qulId: 378, quranComId: 137,  name: 'Abdur-Rashid Sufi', style: 'Soosi (2020)'),
    QulReciter(qulId: 404, quranComId: null, name: 'Abdullah Ali Jabir'),
    QulReciter(qulId: 421, quranComId: null, name: 'Hady Toure'),
  ];

  /// Récupère un récitateur par son QUL ID. Retourne null si inconnu.
  QulReciter? findByQulId(int qulId) {
    try {
      return reciters.firstWhere((r) => r.qulId == qulId);
    } catch (_) {
      return null;
    }
  }

  /// Récupère un récitateur par son quranComId. Retourne null si inconnu.
  QulReciter? findByQuranComId(int quranComId) {
    try {
      return reciters.firstWhere((r) => r.quranComId == quranComId);
    } catch (_) {
      return null;
    }
  }

  /// Récitateurs avec audio disponible.
  List<QulReciter> get available =>
      reciters.where((r) => r.isAvailable).toList();
}
