import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

const _names = [
  {'n': 1,  'ar': 'الله',        'tr': 'Allah',        'fr': 'Dieu'},
  {'n': 2,  'ar': 'الرَّحْمَن',   'tr': 'Ar-Rahman',    'fr': 'Le Tout Miséricordieux'},
  {'n': 3,  'ar': 'الرَّحِيم',    'tr': 'Ar-Rahim',     'fr': 'Le Très Miséricordieux'},
  {'n': 4,  'ar': 'الْمَلِك',     'tr': 'Al-Malik',     'fr': 'Le Souverain'},
  {'n': 5,  'ar': 'الْقُدُّوس',   'tr': 'Al-Quddus',    'fr': 'Le Très Saint'},
  {'n': 6,  'ar': 'السَّلَام',    'tr': 'As-Salam',     'fr': 'La Paix'},
  {'n': 7,  'ar': 'الْمُؤْمِن',   'tr': 'Al-Mu\'min',   'fr': 'Le Gardien de la Foi'},
  {'n': 8,  'ar': 'الْمُهَيْمِن', 'tr': 'Al-Muhaymin',  'fr': 'Le Préservateur'},
  {'n': 9,  'ar': 'الْعَزِيز',    'tr': 'Al-\'Aziz',    'fr': 'Le Puissant'},
  {'n': 10, 'ar': 'الْجَبَّار',   'tr': 'Al-Jabbar',    'fr': 'Le Contraignant'},
  {'n': 11, 'ar': 'الْمُتَكَبِّر','tr': 'Al-Mutakabbir','fr': 'Le Très Grand'},
  {'n': 12, 'ar': 'الْخَالِق',    'tr': 'Al-Khaliq',    'fr': 'Le Créateur'},
  {'n': 13, 'ar': 'الْبَارِئ',    'tr': 'Al-Bari\'',    'fr': 'Le Créateur parfait'},
  {'n': 14, 'ar': 'الْمُصَوِّر',  'tr': 'Al-Musawwir',  'fr': 'Le Modeleur'},
  {'n': 15, 'ar': 'الْغَفَّار',   'tr': 'Al-Ghaffar',   'fr': 'Le Grand Pardonneur'},
  {'n': 16, 'ar': 'الْقَهَّار',   'tr': 'Al-Qahhar',    'fr': 'Le Dominateur'},
  {'n': 17, 'ar': 'الْوَهَّاب',   'tr': 'Al-Wahhab',    'fr': 'Le Grand Donateur'},
  {'n': 18, 'ar': 'الرَّزَّاق',   'tr': 'Ar-Razzaq',    'fr': 'Le Pourvoyeur'},
  {'n': 19, 'ar': 'الْفَتَّاح',   'tr': 'Al-Fattah',    'fr': 'L\'Ouvreur'},
  {'n': 20, 'ar': 'الْعَلِيم',    'tr': 'Al-\'Alim',    'fr': 'L\'Omniscient'},
  {'n': 21, 'ar': 'الْقَابِض',    'tr': 'Al-Qabid',     'fr': 'Celui qui resserre'},
  {'n': 22, 'ar': 'الْبَاسِط',    'tr': 'Al-Basit',     'fr': 'Celui qui étend'},
  {'n': 23, 'ar': 'الْخَافِض',    'tr': 'Al-Khafid',    'fr': 'Celui qui abaisse'},
  {'n': 24, 'ar': 'الرَّافِع',    'tr': 'Ar-Rafi\'',    'fr': 'Celui qui élève'},
  {'n': 25, 'ar': 'الْمُعِز',     'tr': 'Al-Mu\'izz',   'fr': 'Celui qui honore'},
  {'n': 26, 'ar': 'الْمُذِل',     'tr': 'Al-Mudhill',   'fr': 'Celui qui humilie'},
  {'n': 27, 'ar': 'السَّمِيع',    'tr': 'As-Sami\'',    'fr': 'L\'Omnient'},
  {'n': 28, 'ar': 'الْبَصِير',    'tr': 'Al-Basir',     'fr': 'Le Clairvoyant'},
  {'n': 29, 'ar': 'الْحَكَم',     'tr': 'Al-Hakam',     'fr': 'Le Juge'},
  {'n': 30, 'ar': 'الْعَدْل',     'tr': 'Al-\'Adl',     'fr': 'Le Juste'},
  {'n': 31, 'ar': 'اللَّطِيف',    'tr': 'Al-Latif',     'fr': 'Le Subtil'},
  {'n': 32, 'ar': 'الْخَبِير',    'tr': 'Al-Khabir',    'fr': 'Le Bien informé'},
  {'n': 33, 'ar': 'الْحَلِيم',    'tr': 'Al-Halim',     'fr': 'Le Doux'},
  {'n': 34, 'ar': 'الْعَظِيم',    'tr': 'Al-\'Azim',    'fr': 'L\'Immense'},
  {'n': 35, 'ar': 'الْغَفُور',    'tr': 'Al-Ghafur',    'fr': 'Le Très Pardonnant'},
  {'n': 36, 'ar': 'الشَّكُور',    'tr': 'Ash-Shakur',   'fr': 'Le Reconnaissant'},
  {'n': 37, 'ar': 'الْعَلِي',     'tr': 'Al-\'Ali',     'fr': 'Le Très Haut'},
  {'n': 38, 'ar': 'الْكَبِير',    'tr': 'Al-Kabir',     'fr': 'Le Grand'},
  {'n': 39, 'ar': 'الْحَفِيظ',    'tr': 'Al-Hafiz',     'fr': 'Le Gardien'},
  {'n': 40, 'ar': 'الْمُقِيت',    'tr': 'Al-Muqit',     'fr': 'Le Nourricier'},
  {'n': 41, 'ar': 'الْحَسِيب',    'tr': 'Al-Hasib',     'fr': 'Le Comptable'},
  {'n': 42, 'ar': 'الْجَلِيل',    'tr': 'Al-Jalil',     'fr': 'Le Majestueux'},
  {'n': 43, 'ar': 'الْكَرِيم',    'tr': 'Al-Karim',     'fr': 'Le Généreux'},
  {'n': 44, 'ar': 'الرَّقِيب',    'tr': 'Ar-Raqib',     'fr': 'Le Surveillant'},
  {'n': 45, 'ar': 'الْمُجِيب',    'tr': 'Al-Mujib',     'fr': 'Celui qui répond'},
  {'n': 46, 'ar': 'الْوَاسِع',    'tr': 'Al-Wasi\'',    'fr': 'L\'Immensément Vaste'},
  {'n': 47, 'ar': 'الْحَكِيم',    'tr': 'Al-Hakim',     'fr': 'Le Sage'},
  {'n': 48, 'ar': 'الْوَدُود',    'tr': 'Al-Wadud',     'fr': 'Le Très Aimant'},
  {'n': 49, 'ar': 'الْمَجِيد',    'tr': 'Al-Majid',     'fr': 'Le Glorieux'},
  {'n': 50, 'ar': 'الْبَاعِث',    'tr': 'Al-Ba\'ith',   'fr': 'Celui qui ressuscite'},
  {'n': 51, 'ar': 'الشَّهِيد',    'tr': 'Ash-Shahid',   'fr': 'Le Témoin'},
  {'n': 52, 'ar': 'الْحَق',       'tr': 'Al-Haqq',      'fr': 'La Vérité'},
  {'n': 53, 'ar': 'الْوَكِيل',    'tr': 'Al-Wakil',     'fr': 'Le Garant'},
  {'n': 54, 'ar': 'الْقَوِي',     'tr': 'Al-Qawi',      'fr': 'Le Fort'},
  {'n': 55, 'ar': 'الْمَتِين',    'tr': 'Al-Matin',     'fr': 'L\'Inébranlable'},
  {'n': 56, 'ar': 'الْوَلِي',     'tr': 'Al-Wali',      'fr': 'L\'Ami Protecteur'},
  {'n': 57, 'ar': 'الْحَمِيد',    'tr': 'Al-Hamid',     'fr': 'Le Digne de louanges'},
  {'n': 58, 'ar': 'الْمُحْصِي',   'tr': 'Al-Muhsi',     'fr': 'Le Dénombrateur'},
  {'n': 59, 'ar': 'الْمُبْدِئ',   'tr': 'Al-Mubdi\'',   'fr': 'Celui qui commence'},
  {'n': 60, 'ar': 'الْمُعِيد',    'tr': 'Al-Mu\'id',    'fr': 'Celui qui recommence'},
  {'n': 61, 'ar': 'الْمُحْيِي',   'tr': 'Al-Muhyi',     'fr': 'Celui qui vivifie'},
  {'n': 62, 'ar': 'الْمُمِيت',    'tr': 'Al-Mumit',     'fr': 'Celui qui fait mourir'},
  {'n': 63, 'ar': 'الْحَي',       'tr': 'Al-Hayy',      'fr': 'Le Vivant'},
  {'n': 64, 'ar': 'الْقَيُّوم',   'tr': 'Al-Qayyum',    'fr': 'Le Subsistant'},
  {'n': 65, 'ar': 'الْوَاجِد',    'tr': 'Al-Wajid',     'fr': 'Celui qui trouve'},
  {'n': 66, 'ar': 'الْمَاجِد',    'tr': 'Al-Majid',     'fr': 'Le Noble'},
  {'n': 67, 'ar': 'الْوَاحِد',    'tr': 'Al-Wahid',     'fr': 'L\'Unique'},
  {'n': 68, 'ar': 'الْأَحَد',     'tr': 'Al-Ahad',      'fr': 'L\'Un'},
  {'n': 69, 'ar': 'الصَّمَد',     'tr': 'As-Samad',     'fr': 'L\'Éternel Absolu'},
  {'n': 70, 'ar': 'الْقَادِر',    'tr': 'Al-Qadir',     'fr': 'Le Tout Puissant'},
  {'n': 71, 'ar': 'الْمُقْتَدِر', 'tr': 'Al-Muqtadir',  'fr': 'Le Dominateur Puissant'},
  {'n': 72, 'ar': 'الْمُقَدِّم',  'tr': 'Al-Muqaddim',  'fr': 'Celui qui avance'},
  {'n': 73, 'ar': 'الْمُؤَخِّر',  'tr': 'Al-Mu\'akhkhir','fr': 'Celui qui reporte'},
  {'n': 74, 'ar': 'الْأَوَّل',    'tr': 'Al-Awwal',     'fr': 'Le Premier'},
  {'n': 75, 'ar': 'الْآخِر',      'tr': 'Al-Akhir',     'fr': 'Le Dernier'},
  {'n': 76, 'ar': 'الظَّاهِر',    'tr': 'Az-Zahir',     'fr': 'L\'Apparent'},
  {'n': 77, 'ar': 'الْبَاطِن',    'tr': 'Al-Batin',     'fr': 'Le Caché'},
  {'n': 78, 'ar': 'الْوَالِي',    'tr': 'Al-Wali',      'fr': 'Le Gouverneur'},
  {'n': 79, 'ar': 'الْمُتَعَالِ', 'tr': 'Al-Muta\'ali', 'fr': 'L\'Infiniment Élevé'},
  {'n': 80, 'ar': 'الْبَرّ',      'tr': 'Al-Barr',      'fr': 'La Source de Bonté'},
  {'n': 81, 'ar': 'التَّوَّاب',   'tr': 'At-Tawwab',    'fr': 'Celui qui accepte le repentir'},
  {'n': 82, 'ar': 'الْمُنْتَقِم', 'tr': 'Al-Muntaqim',  'fr': 'Le Vengeur'},
  {'n': 83, 'ar': 'الْعَفُو',     'tr': 'Al-\'Afuw',    'fr': 'Le Très Indulgent'},
  {'n': 84, 'ar': 'الرَّؤُوف',    'tr': 'Ar-Ra\'uf',    'fr': 'Le Clément'},
  {'n': 85, 'ar': 'مَالِكُ الْمُلْك','tr': 'Malik Al-Mulk','fr': 'Maître du Royaume'},
  {'n': 86, 'ar': 'ذُو الْجَلَال وَالإِكْرَام','tr': 'Dhu Al-Jalal','fr': 'Seigneur de la Majesté'},
  {'n': 87, 'ar': 'الْمُقْسِط',   'tr': 'Al-Muqsit',    'fr': 'L\'Équitable'},
  {'n': 88, 'ar': 'الْجَامِع',    'tr': 'Al-Jami\'',    'fr': 'Le Rassembleur'},
  {'n': 89, 'ar': 'الْغَنِي',     'tr': 'Al-Ghani',     'fr': 'Le Riche'},
  {'n': 90, 'ar': 'الْمُغْنِي',   'tr': 'Al-Mughni',    'fr': 'Celui qui enrichit'},
  {'n': 91, 'ar': 'الْمَانِع',    'tr': 'Al-Mani\'',    'fr': 'Celui qui empêche'},
  {'n': 92, 'ar': 'الضَّار',      'tr': 'Ad-Darr',      'fr': 'Celui qui afflige'},
  {'n': 93, 'ar': 'النَّافِع',    'tr': 'An-Nafi\'',    'fr': 'Celui qui profite'},
  {'n': 94, 'ar': 'النُّور',       'tr': 'An-Nur',       'fr': 'La Lumière'},
  {'n': 95, 'ar': 'الْهَادِئ',    'tr': 'Al-Hadi',      'fr': 'Le Guide'},
  {'n': 96, 'ar': 'الْبَدِيع',    'tr': 'Al-Badi\'',    'fr': 'L\'Incomparable'},
  {'n': 97, 'ar': 'الْبَاقِي',    'tr': 'Al-Baqi',      'fr': 'L\'Éternel'},
  {'n': 98, 'ar': 'الْوَارِث',    'tr': 'Al-Warith',    'fr': 'L\'Héritier'},
  {'n': 99, 'ar': 'الرَّشِيد',    'tr': 'Ar-Rashid',    'fr': 'Le Guide Droit'},
];

class AsmaScreen extends StatefulWidget {
  const AsmaScreen({super.key});

  @override
  State<AsmaScreen> createState() => _AsmaScreenState();
}

class _AsmaScreenState extends State<AsmaScreen> {
  bool _detailMode = false;
  late final PageController _pageCtrl;

  @override
  void initState() {
    super.initState();
    _pageCtrl = PageController();
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }

  void _openDetail(int index) {
    setState(() => _detailMode = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _pageCtrl.jumpToPage(index);
    });
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_detailMode,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _detailMode) setState(() => _detailMode = false);
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            _detailMode ? 'الأسماء الحسنى' : '99 Noms d\'Allah',
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          backgroundColor: AppColors.primary,
          iconTheme: const IconThemeData(color: Colors.white),
          leading: _detailMode
              ? IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () => setState(() => _detailMode = false),
                )
              : null,
        ),
        body: _detailMode ? _buildDetail() : _buildGrid(),
      ),
    );
  }

  Widget _buildGrid() {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 0.85,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: _names.length,
      itemBuilder: (context, i) {
        final n = _names[i];
        return GestureDetector(
          onTap: () => _openDetail(i),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [AppColors.primary, AppColors.primaryLight],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '${n['n']}',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.7),
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  n['ar'] as String,
                  style: const TextStyle(
                    fontFamily: 'ScheherazadeNew',
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 4),
                Text(
                  n['tr'] as String,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.85),
                    fontSize: 10,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDetail() {
    return PageView.builder(
      controller: _pageCtrl,
      onPageChanged: (_) {},
      itemCount: _names.length,
      itemBuilder: (context, i) {
        final n = _names[i];
        return SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: Column(
            children: [
              const SizedBox(height: 32),
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text('${n['n']}',
                    style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 32),
              Text(
                n['ar'] as String,
                style: TextStyle(
                  fontFamily: 'ScheherazadeNew',
                  fontSize: 48,
                  color: AppColors.primary,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                n['tr'] as String,
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w600, letterSpacing: 1),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Container(
                width: 60, height: 2,
                decoration: BoxDecoration(
                  color: AppColors.accent,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                n['fr'] as String,
                style: TextStyle(fontSize: 18, color: Colors.grey[700], height: 1.5),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 48),
              Text(
                '${i + 1} / ${_names.length}',
                style: TextStyle(color: Colors.grey[400], fontSize: 13),
              ),
            ],
          ),
        );
      },
    );
  }
}
