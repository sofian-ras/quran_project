// lib/services/qul_audio/qul_catalog_service.dart
//
// 98 récitateurs Hafs (حفص عن عاصم) — tous seek-based via mp3quran.net.
//
// Généré depuis les logs de Mp3QuranTimingCache.instance.logAvailableReads().
// Pour mettre à jour : relancer logAvailableReads() et reconstruire ce fichier.

import '../../models/reciter_audio_source.dart';
import 'models/qul_reciter.dart';

ReciterAudioSource _src(String id, String server, int readId) =>
    ReciterAudioSource(
      localCacheId  : id,
      serverBaseUrl : server,
      mp3quranReadId: readId,
    );

class QulCatalogService {
  QulCatalogService._();
  static final QulCatalogService instance = QulCatalogService._();

  // qulId == mp3quranReadId pour éviter tout conflit d'identifiant.
  static final List<QulReciter> reciters = [
    QulReciter(qulId:   1, name: 'Ibrahim Al-Akdar',               timedSource: _src('akdr',          'https://server6.mp3quran.net/akdr',                                       1)),
    QulReciter(qulId:   3, name: 'Ibrahim Al-Asiri',               timedSource: _src('3siri',         'https://server6.mp3quran.net/3siri',                                      3)),
    QulReciter(qulId:   4, name: 'Abu Bakr Al-Shatri',             timedSource: _src('shatri',        'https://server11.mp3quran.net/shatri',                                    4)),
    QulReciter(qulId:   5, name: 'Ahmad Al-Ajmy',                  timedSource: _src('ajm',           'https://server10.mp3quran.net/ajm',                                       5)),
    QulReciter(qulId:   6, name: 'Ahmad Al-Hawashi',               timedSource: _src('hawashi',       'https://server11.mp3quran.net/hawashi',                                   6)),
    QulReciter(qulId:   8, name: 'Ahmad Saber',                    timedSource: _src('saber',         'https://server8.mp3quran.net/saber',                                      8)),
    QulReciter(qulId:   9, name: 'Ahmad Nauina',                   timedSource: _src('ahmad_nu',      'https://server11.mp3quran.net/ahmad_nu',                                  9)),
    QulReciter(qulId:  10, name: 'Akram Alalaqmi',                 timedSource: _src('akrm',          'https://server9.mp3quran.net/akrm',                                      10)),
    QulReciter(qulId:  12, name: 'Idrees Abkr',                    timedSource: _src('abkr',          'https://server6.mp3quran.net/abkr',                                      12)),
    QulReciter(qulId:  13, name: 'Alzain Mohammad Ahmad',          timedSource: _src('alzain',        'https://server9.mp3quran.net/alzain',                                    13)),
    QulReciter(qulId:  17, name: 'Tawfeeq As-Sayegh',             timedSource: _src('twfeeq',        'https://server6.mp3quran.net/twfeeq',                                    17)),
    QulReciter(qulId:  20, name: 'Khalid Al-Jileel',               timedSource: _src('jleel',         'https://server10.mp3quran.net/jleel',                                    20)),
    QulReciter(qulId:  21, name: 'Khaled Al-Qahtani',              timedSource: _src('qht',           'https://server10.mp3quran.net/qht',                                      21)),
    QulReciter(qulId:  22, name: 'Khalid Abdulkafi',               timedSource: _src('kafi',          'https://server11.mp3quran.net/kafi',                                     22)),
    QulReciter(qulId:  24, name: 'Khalifa Altunaiji',              timedSource: _src('tnjy',          'https://server12.mp3quran.net/tnjy',                                     24)),
    QulReciter(qulId:  25, name: 'Dawood Hamza',                   timedSource: _src('hamza',         'https://server9.mp3quran.net/hamza',                                     25)),
    QulReciter(qulId:  30, name: 'Saad Al-Ghamdi',                 timedSource: _src('s_gmd',         'https://server7.mp3quran.net/s_gmd',                                     30)),
    QulReciter(qulId:  31, name: 'Saud Al-Shuraim',                timedSource: _src('shur',          'https://server7.mp3quran.net/shur',                                      31)),
    QulReciter(qulId:  32, name: 'Sahl Yassin',                    timedSource: _src('shl',           'https://server6.mp3quran.net/shl',                                       32)),
    QulReciter(qulId:  33, name: 'Zaki Daghistani',                timedSource: _src('zaki',          'https://server9.mp3quran.net/zaki',                                      33)),
    QulReciter(qulId:  38, name: 'Shirazad Taher',                 timedSource: _src('taher',         'https://server12.mp3quran.net/taher',                                    38)),
    QulReciter(qulId:  39, name: 'Saber Abdulhakm',                timedSource: _src('hkm',           'https://server12.mp3quran.net/hkm',                                      39)),
    QulReciter(qulId:  40, name: 'Saleh Alsahood',                 timedSource: _src('sahood',        'https://server8.mp3quran.net/sahood',                                    40)),
    QulReciter(qulId:  42, name: 'Saleh Al-Habdan',                timedSource: _src('habdan',        'https://server6.mp3quran.net/habdan',                                    42)),
    QulReciter(qulId:  43, name: 'Salah Albudair',                 timedSource: _src('s_bud',         'https://server6.mp3quran.net/s_bud',                                     43)),
    QulReciter(qulId:  44, name: 'Salah Alhashim',                 timedSource: _src('salah_hashim_m','https://server12.mp3quran.net/salah_hashim_m',                           44)),
    QulReciter(qulId:  46, name: 'Salah Bukhatir',                 timedSource: _src('bu_khtr',       'https://server8.mp3quran.net/bu_khtr',                                   46)),
    QulReciter(qulId:  48, name: 'Adel Ryyan',                     timedSource: _src('ryan',          'https://server8.mp3quran.net/ryan',                                      48)),
    QulReciter(qulId:  49, name: 'Abdelbari Al-Toubayti',          timedSource: _src('thubti',        'https://server6.mp3quran.net/thubti',                                    49)),
    QulReciter(qulId:  50, name: 'Abdulbari Mohammad',             timedSource: _src('bari',          'https://server12.mp3quran.net/bari',                                     50)),
    QulReciter(qulId:  53, name: 'Abdulbasit Abdulsamad',          timedSource: _src('basit',         'https://server7.mp3quran.net/basit',                                     53)),
    QulReciter(qulId:  54, name: 'Abdulrahman Al-Sudaes',          timedSource: _src('sds',           'https://server11.mp3quran.net/sds',                                      54)),
    QulReciter(qulId:  55, name: 'Abdul Aziz Al-Ahmad',            timedSource: _src('a_ahmed',       'https://server11.mp3quran.net/a_ahmed',                                  55)),
    QulReciter(qulId:  56, name: 'Abdulaziz Az-Zahrani',           timedSource: _src('zahrani',       'https://server9.mp3quran.net/zahrani',                                   56)),
    QulReciter(qulId:  58, name: 'Abdullah Albuajan',              timedSource: _src('buajan',        'https://server8.mp3quran.net/buajan',                                    58)),
    QulReciter(qulId:  59, name: 'Abdullah Al-Mattrod',            timedSource: _src('mtrod',         'https://server8.mp3quran.net/mtrod',                                     59)),
    QulReciter(qulId:  60, name: 'Abdullah Basfer',                timedSource: _src('bsfr',          'https://server6.mp3quran.net/bsfr',                                      60)),
    QulReciter(qulId:  61, name: 'Abdullah Khayyat',               timedSource: _src('kyat',          'https://server12.mp3quran.net/kyat',                                     61)),
    QulReciter(qulId:  62, name: 'Abdullah Al-Johany',             timedSource: _src('jhn',           'https://server13.mp3quran.net/jhn',                                      62)),
    QulReciter(qulId:  66, name: 'Abdulmohsin Al-Harthy',          timedSource: _src('mohsin_harthi', 'https://server6.mp3quran.net/mohsin_harthi',                             66)),
    QulReciter(qulId:  67, name: 'Abdulmohsen Al-Qasim',           timedSource: _src('qasm',          'https://server8.mp3quran.net/qasm',                                      67)),
    QulReciter(qulId:  69, name: 'Abdulmohsin Al-Obaikan',         timedSource: _src('obk',           'https://server12.mp3quran.net/obk',                                      69)),
    QulReciter(qulId:  70, name: 'Abdulhadi Kanakeri',             timedSource: _src('kanakeri',      'https://server6.mp3quran.net/kanakeri',                                  70)),
    QulReciter(qulId:  71, name: 'Abdulwadood Haneef',             timedSource: _src('wdod',          'https://server8.mp3quran.net/wdod',                                      71)),
    QulReciter(qulId:  72, name: 'Abdulwali Al-Arkani',            timedSource: _src('arkani',        'https://server6.mp3quran.net/arkani',                                    72)),
    QulReciter(qulId:  74, name: 'Ali Alhuthaifi',                 timedSource: _src('hthfi',         'https://server9.mp3quran.net/hthfi',                                     74)),
    QulReciter(qulId:  76, name: 'Ali Jaber',                      timedSource: _src('a_jbr',         'https://server11.mp3quran.net/a_jbr',                                    76)),
    QulReciter(qulId:  77, name: 'Ali Hajjaj Alsouasi',            timedSource: _src('hajjaj',        'https://server9.mp3quran.net/hajjaj',                                    77)),
    QulReciter(qulId:  78, name: 'Emad Hafez',                     timedSource: _src('hafz',          'https://server6.mp3quran.net/hafz',                                      78)),
    QulReciter(qulId:  81, name: 'Fares Abbad',                    timedSource: _src('frs_a',         'https://server8.mp3quran.net/frs_a',                                     81)),
    QulReciter(qulId:  86, name: 'Nasser Alqatami',                timedSource: _src('qtm',           'https://server6.mp3quran.net/qtm',                                       86)),
    QulReciter(qulId:  87, name: 'Nabil Al Rifay',                 timedSource: _src('nabil',         'https://server9.mp3quran.net/nabil',                                     87)),
    QulReciter(qulId:  88, name: 'Neamah Al-Hassan',               timedSource: _src('namh',          'https://server8.mp3quran.net/namh',                                      88)),
    QulReciter(qulId:  89, name: 'Hani Arrifai',                   timedSource: _src('hani',          'https://server8.mp3quran.net/hani',                                      89)),
    QulReciter(qulId:  92, name: 'Yasser Al-Dosari',               timedSource: _src('yasser',        'https://server11.mp3quran.net/yasser',                                   92)),
    QulReciter(qulId: 106, name: 'Mohammad Al-Tablaway',           timedSource: _src('tblawi',        'https://server12.mp3quran.net/tblawi',                                  106)),
    QulReciter(qulId: 109, name: 'Mohammed Ayyub',                 timedSource: _src('ayyub',         'https://server8.mp3quran.net/ayyub',                                    109)),
    QulReciter(qulId: 110, name: 'Mohammad Saleh Alim Shah',       timedSource: _src('shah',          'https://server12.mp3quran.net/shah',                                    110)),
    QulReciter(qulId: 112, name: 'Mohammed Siddiq Al-Minshawi',    timedSource: _src('minsh',         'https://server10.mp3quran.net/minsh',                                   112)),
    QulReciter(qulId: 115, name: 'Mohammad Abdullkarem',           timedSource: _src('m_krm',         'https://server12.mp3quran.net/m_krm',                                   115)),
    QulReciter(qulId: 118, name: 'Mahmoud Khalil Al-Hussary',      timedSource: _src('husr',          'https://server13.mp3quran.net/husr',                                    118)),
    QulReciter(qulId: 123, name: 'Mishary Alafasi',                timedSource: _src('afs',           'https://server8.mp3quran.net/afs',                                      123)),
    QulReciter(qulId: 135, name: 'Abdulrahman Alsuwayid',          timedSource: _src('a_swaiyd',      'https://server16.mp3quran.net/a_swaiyd/Rewayat-Hafs-A-n-Assem',         135)),
    QulReciter(qulId: 137, name: 'Ahmad Talib bin Humaid',         timedSource: _src('a_binhameed',   'https://server16.mp3quran.net/a_binhameed/Rewayat-Hafs-A-n-Assem',      137)),
    QulReciter(qulId: 139, name: 'Majed Al-Zamil',                 timedSource: _src('zaml',          'https://server9.mp3quran.net/zaml',                                     139)),
    QulReciter(qulId: 159, name: 'Khalid Almohana',                timedSource: _src('mohna',         'https://server11.mp3quran.net/mohna',                                   159)),
    QulReciter(qulId: 181, name: 'Jamaan Alosaimi',                timedSource: _src('jaman',         'https://server6.mp3quran.net/jaman',                                    181)),
    QulReciter(qulId: 193, name: 'Yousef Bin Noah Ahmad',          timedSource: _src('noah',          'https://server8.mp3quran.net/noah',                                     193)),
    QulReciter(qulId: 198, name: 'Mohammad Rashad Alshareef',      timedSource: _src('rashad',        'https://server10.mp3quran.net/rashad',                                  198)),
    QulReciter(qulId: 201, name: 'Ahmed Al-Trabulsi',              timedSource: _src('trabulsi',      'https://server10.mp3quran.net/trabulsi',                                201)),
    QulReciter(qulId: 203, name: 'Ahmed Amer',                     timedSource: _src('aamer',         'https://server10.mp3quran.net/Aamer',                                   203)),
    QulReciter(qulId: 217, name: 'Bandar Balilah',                 timedSource: _src('balilah',       'https://server6.mp3quran.net/balilah',                                  217)),
    QulReciter(qulId: 219, name: 'Wadeea Al-Yamani',               timedSource: _src('wdee3',         'https://server6.mp3quran.net/wdee3',                                    219)),
    QulReciter(qulId: 221, name: 'Raad Al Kurdi',                  timedSource: _src('kurdi',         'https://server6.mp3quran.net/kurdi',                                    221)),
    QulReciter(qulId: 225, name: 'Abdulrahman Aloosi',             timedSource: _src('aloosi',        'https://server6.mp3quran.net/aloosi',                                   225)),
    QulReciter(qulId: 229, name: 'Mohammad Khalil Al-Qari',        timedSource: _src('m_qari',        'https://server8.mp3quran.net/m_qari',                                   229)),
    QulReciter(qulId: 232, name: 'Ibrahim Aldosari',               timedSource: _src('ibrahim_dosri', 'https://server10.mp3quran.net/ibrahim_dosri/Rewayat-Hafs-A-n-Assem',    232)),
    QulReciter(qulId: 236, name: 'Abdulrahman Al-Majed',           timedSource: _src('a_majed',       'https://server10.mp3quran.net/a_majed',                                 236)),
    QulReciter(qulId: 243, name: 'Abdullah Al-Mousa',              timedSource: _src('mousa',         'https://server14.mp3quran.net/mousa/Rewayat-Hafs-A-n-Assem',            243)),
    QulReciter(qulId: 244, name: 'Abdullah Al-Khalaf',             timedSource: _src('khalf',         'https://server14.mp3quran.net/khalf',                                   244)),
    QulReciter(qulId: 245, name: 'Mansour Al-Salemi',              timedSource: _src('mansor',        'https://server14.mp3quran.net/mansor',                                  245)),
    QulReciter(qulId: 250, name: 'Mohammad Albukheet',             timedSource: _src('bukheet',       'https://server14.mp3quran.net/bukheet',                                 250)),
    QulReciter(qulId: 256, name: 'Ahmad Shaheen',                  timedSource: _src('shaheen',       'https://server16.mp3quran.net/shaheen/Rewayat-Hafs-A-n-Assem',          256)),
    QulReciter(qulId: 258, name: 'Abdulrasheed Soufi',             timedSource: _src('soufi',         'https://server16.mp3quran.net/soufi/Rewayat-Hafs-A-n-Assem',            258)),
    QulReciter(qulId: 259, name: 'Ahmad Al Nufais',                timedSource: _src('nufais',        'https://server16.mp3quran.net/nufais/Rewayat-Hafs-A-n-Assem',           259)),
    QulReciter(qulId: 265, name: 'Ahmad Deban',                    timedSource: _src('deban',         'https://server16.mp3quran.net/deban/Rewayat-Hafs-A-n-Assem',            265)),
    QulReciter(qulId: 268, name: 'Peshawa Qadr Al-Kurdi',          timedSource: _src('peshawa',       'https://server16.mp3quran.net/peshawa/Rewayat-Hafs-A-n-Assem',          268)),
    QulReciter(qulId: 273, name: 'Haitham Aldukhain',              timedSource: _src('h_dukhain',     'https://server16.mp3quran.net/h_dukhain/Rewayat-Hafs-A-n-Assem',        273)),
    QulReciter(qulId: 282, name: 'Abdulaziz Alturki',              timedSource: _src('a_turki',       'https://server16.mp3quran.net/a_turki/Rewayat-Hafs-A-n-Assem',          282)),
    QulReciter(qulId: 289, name: 'Ahmad Issa Al Maasaraawi',       timedSource: _src('a_maasaraawi',  'https://server16.mp3quran.net/a_maasaraawi/Rewayat-Hafs-A-n-Assem',     289)),
    QulReciter(qulId: 294, name: 'Sayed Ahmad Hashemi',            timedSource: _src('s_hashemi',     'https://server16.mp3quran.net/s_hashemi/Rewayat-Hafs-A-n-Assem',        294)),
    QulReciter(qulId: 295, name: 'Khalid Mohammadi',               timedSource: _src('kh_mohammadi',  'https://server16.mp3quran.net/kh_mohammadi/Rewayat-Hafs-A-n-Assem',     295)),
    QulReciter(qulId: 299, name: 'Hasan Saleh',                    timedSource: _src('h_saleh',       'https://server16.mp3quran.net/h_saleh/Rewayat-Hafs-A-n-Assem',          299)),
    QulReciter(qulId: 300, name: 'Saleh Alshamrani',               timedSource: _src('shamrani',      'https://server16.mp3quran.net/shamrani/Rewayat-Hafs-A-n-Assem',         300)),
    QulReciter(qulId: 303, name: 'Issa Omar Sanankoua',            timedSource: _src('i_sanankoua',   'https://server16.mp3quran.net/i_sanankoua/Rewayat-Hafs-A-n-Assem',      303)),
    QulReciter(qulId: 314, name: 'Anas Alemadi',                   timedSource: _src('a_alemadi',     'https://server16.mp3quran.net/a_alemadi/Rewayat-Hafs-A-n-Assem',        314)),
    QulReciter(qulId: 340, name: 'Muhammad Burhaji',               timedSource: _src('m_burhaji',     'https://server16.mp3quran.net/M_Burhaji/Rewayat-Hafs-A-n-Assem',        340)),
    QulReciter(qulId: 10905, name: 'Hassan Aldaghriri',            timedSource: _src('h_aldaghriri',  'https://server16.mp3quran.net/H-Aldaghriri/Rewayat-Hafs-A-n-Assem',   10905)),
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
