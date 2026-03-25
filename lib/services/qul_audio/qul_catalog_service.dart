// lib/services/qul_audio/qul_catalog_service.dart
//
// Catalogue des récitateurs verset-par-verset.
//
// Trois types de récitateurs :
//
//   1. CDN QUL (quranComId connu)
//      → URL résolue via api.quran.com/v4/recitations/{id}/by_chapter/{surah}
//
//   2. everyayah.com direct (everyayahSlug)
//      → URL directe : https://everyayah.com/data/{slug}/{S:3}{A:3}.mp3
//
//   3. Seek-based / timedSource (ReciterAudioSource)
//      → MP3 sourate complète téléchargé localement + timings API mp3quran
//      → Délégué à TimedSurahPlayer
//      → Utiliser quand le récitateur n'a pas de fichiers audio par verset
//
// Pour ajouter un récitateur seek-based :
//   1. Trouver serverBaseUrl  → lien "Download" sur la page mp3quran.net
//   2. Trouver mp3quranReadId → appeler Mp3QuranTimingCache.instance.logAvailableReads()
//   3. Choisir un localCacheId stable (nom de dossier pour le stockage local)

import '../../models/reciter_audio_source.dart';
import 'models/qul_reciter.dart';

// ── Configurations seek-based ─────────────────────────────────────────────────
//
// mp3quranReadId : à remplir après avoir appelé :
//   await Mp3QuranTimingCache.instance.logAvailableReads();
// Chercher dans les logs la ligne "soufi" + "hafs" et noter l'id.

const _soufiHafs = ReciterAudioSource(
  localCacheId  : 'soufi_hafs',
  serverBaseUrl : 'https://server16.mp3quran.net/download/soufi/Rewayat-Hafs-A-n-Assem',
  mp3quranReadId: 258, // عبدالرشيد صوفي / حفص عن عاصم
);

// Pour ajouter un autre récitateur seek-based, déclarer ici :
// const _autreRecitateur = ReciterAudioSource(
//   localCacheId  : 'nom_unique',
//   serverBaseUrl : 'https://...',
//   mp3quranReadId: 456,
// );

// ─────────────────────────────────────────────────────────────────────────────

class QulCatalogService {
  QulCatalogService._();
  static final QulCatalogService instance = QulCatalogService._();

  static const List<QulReciter> reciters = [
    // ── Seek-based : MP3 complet + timings mp3quran ──────────────────────────
    QulReciter(
      qulId      : 9001,
      name       : 'Soufi',
      style      : 'Hafs',
      timedSource: _soufiHafs,
    ),
    // Modèle pour en ajouter d'autres :
    // QulReciter(qulId: 9002, name: '...', style: '...', timedSource: _autreRecitateur),

    // ── CDN QUL (quranComId connu) ───────────────────────────────────────────
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
    // ── Non indexés (quranComId: null = indisponible pour l'instant) ─────────
    QulReciter(qulId: 562, quranComId: null, name: 'Maher al-Muaiqly'),
    QulReciter(qulId: 119, quranComId: null, name: 'Saad al-Ghamdi'),
    QulReciter(qulId: 415, quranComId: null, name: 'Abdullah Awad al-Juhani'),
    QulReciter(qulId: 416, quranComId: null, name: 'Abdullah Basfar'),
    QulReciter(qulId: 422, quranComId: null, name: 'Yasser ad-Dussary'),
    QulReciter(qulId: 419, quranComId: null, name: 'Muhammad Jibreel'),
    QulReciter(qulId: 418, quranComId: null, name: 'Ali Abdur-Rahman al-Huthaify'),
    QulReciter(qulId: 356, quranComId: null, name: 'Nasser al-Qatami'),
    QulReciter(qulId: 388, quranComId: null, name: 'Bandar Baleela'),
    QulReciter(qulId: 404, quranComId: null, name: 'Abdullah Ali Jabir'),
    QulReciter(qulId: 421, quranComId: null, name: 'Hady Toure'),
  ];

  QulReciter? findByQulId(int qulId) {
    try { return reciters.firstWhere((r) => r.qulId == qulId); }
    catch (_) { return null; }
  }

  QulReciter? findByQuranComId(int quranComId) {
    try { return reciters.firstWhere((r) => r.quranComId == quranComId); }
    catch (_) { return null; }
  }

  List<QulReciter> get available =>
      reciters.where((r) => r.isAvailable).toList();
}
