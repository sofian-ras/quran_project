import 'package:flutter/material.dart';
import '../models/arabic_models.dart';

// ─── 28 Arabic Letters ────────────────────────────────────────────────────

const List<ArabicLetter> kArabicLetters = [
  ArabicLetter(char: 'ا', nameFr: 'Alif', nameAr: 'أَلِف', phonetic: 'a / â', exampleFr: 'comme "a" dans père', isolated: 'ا', initial: 'ا', medial: 'ـا', final_: 'ـا'),
  ArabicLetter(char: 'ب', nameFr: 'Ba', nameAr: 'بَاء', phonetic: 'b', exampleFr: 'comme "b" dans bateau', isolated: 'ب', initial: 'بـ', medial: 'ـبـ', final_: 'ـب'),
  ArabicLetter(char: 'ت', nameFr: 'Ta', nameAr: 'تَاء', phonetic: 't', exampleFr: 'comme "t" dans table', isolated: 'ت', initial: 'تـ', medial: 'ـتـ', final_: 'ـت'),
  ArabicLetter(char: 'ث', nameFr: 'Tha', nameAr: 'ثَاء', phonetic: 'th', exampleFr: 'comme "th" en anglais (think)', isolated: 'ث', initial: 'ثـ', medial: 'ـثـ', final_: 'ـث'),
  ArabicLetter(char: 'ج', nameFr: 'Jeem', nameAr: 'جِيم', phonetic: 'dj', exampleFr: 'comme "dj" dans djinn', isolated: 'ج', initial: 'جـ', medial: 'ـجـ', final_: 'ـج'),
  ArabicLetter(char: 'ح', nameFr: 'Ha', nameAr: 'حَاء', phonetic: 'ħ', exampleFr: 'h fortement soufflé de la gorge', isolated: 'ح', initial: 'حـ', medial: 'ـحـ', final_: 'ـح'),
  ArabicLetter(char: 'خ', nameFr: 'Kha', nameAr: 'خَاء', phonetic: 'kh', exampleFr: 'comme "jota" espagnol ou "Bach" allemand', isolated: 'خ', initial: 'خـ', medial: 'ـخـ', final_: 'ـخ'),
  ArabicLetter(char: 'د', nameFr: 'Dal', nameAr: 'دَال', phonetic: 'd', exampleFr: 'comme "d" dans dos', isolated: 'د', initial: 'د', medial: 'ـد', final_: 'ـد'),
  ArabicLetter(char: 'ذ', nameFr: 'Dhal', nameAr: 'ذَال', phonetic: 'dh', exampleFr: 'comme "th" dans "the" en anglais', isolated: 'ذ', initial: 'ذ', medial: 'ـذ', final_: 'ـذ'),
  ArabicLetter(char: 'ر', nameFr: 'Ra', nameAr: 'رَاء', phonetic: 'r', exampleFr: 'r roulé comme en espagnol', isolated: 'ر', initial: 'ر', medial: 'ـر', final_: 'ـر'),
  ArabicLetter(char: 'ز', nameFr: 'Zay', nameAr: 'زَاي', phonetic: 'z', exampleFr: 'comme "z" dans zèbre', isolated: 'ز', initial: 'ز', medial: 'ـز', final_: 'ـز'),
  ArabicLetter(char: 'س', nameFr: 'Sin', nameAr: 'سِين', phonetic: 's', exampleFr: 'comme "s" dans soleil', isolated: 'س', initial: 'سـ', medial: 'ـسـ', final_: 'ـس'),
  ArabicLetter(char: 'ش', nameFr: 'Shin', nameAr: 'شِين', phonetic: 'sh', exampleFr: 'comme "ch" dans chat', isolated: 'ش', initial: 'شـ', medial: 'ـشـ', final_: 'ـش'),
  ArabicLetter(char: 'ص', nameFr: 'Sad', nameAr: 'صَاد', phonetic: 'ṣ', exampleFr: 's emphatique (bouche arrondie)', isolated: 'ص', initial: 'صـ', medial: 'ـصـ', final_: 'ـص'),
  ArabicLetter(char: 'ض', nameFr: 'Dad', nameAr: 'ضَاد', phonetic: 'ḍ', exampleFr: 'd emphatique, unique à l\'arabe', isolated: 'ض', initial: 'ضـ', medial: 'ـضـ', final_: 'ـض'),
  ArabicLetter(char: 'ط', nameFr: 'Taa', nameAr: 'طَاء', phonetic: 'ṭ', exampleFr: 't emphatique (gorge)', isolated: 'ط', initial: 'طـ', medial: 'ـطـ', final_: 'ـط'),
  ArabicLetter(char: 'ظ', nameFr: 'Dhaa', nameAr: 'ظَاء', phonetic: 'ẓ', exampleFr: 'dh emphatique (gorge)', isolated: 'ظ', initial: 'ظـ', medial: 'ـظـ', final_: 'ـظ'),
  ArabicLetter(char: 'ع', nameFr: 'Ain', nameAr: 'عَيْن', phonetic: 'ʿ', exampleFr: 'son guttural du fond de la gorge', isolated: 'ع', initial: 'عـ', medial: 'ـعـ', final_: 'ـع'),
  ArabicLetter(char: 'غ', nameFr: 'Ghain', nameAr: 'غَيْن', phonetic: 'gh', exampleFr: 'r grasseyé parisien, du fond de la gorge', isolated: 'غ', initial: 'غـ', medial: 'ـغـ', final_: 'ـغ'),
  ArabicLetter(char: 'ف', nameFr: 'Fa', nameAr: 'فَاء', phonetic: 'f', exampleFr: 'comme "f" dans feu', isolated: 'ف', initial: 'فـ', medial: 'ـفـ', final_: 'ـف'),
  ArabicLetter(char: 'ق', nameFr: 'Qaf', nameAr: 'قَاف', phonetic: 'q', exampleFr: 'k du fond de la gorge', isolated: 'ق', initial: 'قـ', medial: 'ـقـ', final_: 'ـق'),
  ArabicLetter(char: 'ك', nameFr: 'Kaf', nameAr: 'كَاف', phonetic: 'k', exampleFr: 'comme "k" dans kilo', isolated: 'ك', initial: 'كـ', medial: 'ـكـ', final_: 'ـك'),
  ArabicLetter(char: 'ل', nameFr: 'Lam', nameAr: 'لاَم', phonetic: 'l', exampleFr: 'comme "l" dans lune', isolated: 'ل', initial: 'لـ', medial: 'ـلـ', final_: 'ـل'),
  ArabicLetter(char: 'م', nameFr: 'Mim', nameAr: 'مِيم', phonetic: 'm', exampleFr: 'comme "m" dans mer', isolated: 'م', initial: 'مـ', medial: 'ـمـ', final_: 'ـم'),
  ArabicLetter(char: 'ن', nameFr: 'Nun', nameAr: 'نُون', phonetic: 'n', exampleFr: 'comme "n" dans nuit', isolated: 'ن', initial: 'نـ', medial: 'ـنـ', final_: 'ـن'),
  ArabicLetter(char: 'ه', nameFr: 'Ha (doux)', nameAr: 'هَاء', phonetic: 'h', exampleFr: 'h aspiré comme en anglais (hello)', isolated: 'ه', initial: 'هـ', medial: 'ـهـ', final_: 'ـه'),
  ArabicLetter(char: 'و', nameFr: 'Waw', nameAr: 'وَاو', phonetic: 'w / û', exampleFr: 'comme "ou" dans oui', isolated: 'و', initial: 'و', medial: 'ـو', final_: 'ـو'),
  ArabicLetter(char: 'ي', nameFr: 'Ya', nameAr: 'يَاء', phonetic: 'y / î', exampleFr: 'comme "y" dans yaourt', isolated: 'ي', initial: 'يـ', medial: 'ـيـ', final_: 'ـي'),
];

// Helper: get letter by char
ArabicLetter? letterByChar(String char) {
  try {
    return kArabicLetters.firstWhere((l) => l.char == char);
  } catch (_) {
    return null;
  }
}

// ─── Diacritics / Vowels data ─────────────────────────────────────────────

class ArabicVowel {
  final String symbol;
  final String nameFr;
  final String nameAr;
  final String sound;
  final String example;
  final String exampleTranslation;

  const ArabicVowel({
    required this.symbol,
    required this.nameFr,
    required this.nameAr,
    required this.sound,
    required this.example,
    required this.exampleTranslation,
  });
}

const List<ArabicVowel> kArabicVowels = [
  ArabicVowel(symbol: 'بَ', nameFr: 'Fatha', nameAr: 'فَتْحَة', sound: 'a bref', example: 'كَتَبَ', exampleTranslation: 'il a écrit'),
  ArabicVowel(symbol: 'بِ', nameFr: 'Kasra', nameAr: 'كَسْرَة', sound: 'i bref', example: 'بِسْمِ', exampleTranslation: 'au nom de'),
  ArabicVowel(symbol: 'بُ', nameFr: 'Damma', nameAr: 'ضَمَّة', sound: 'u bref', example: 'كُتُب', exampleTranslation: 'livres'),
  ArabicVowel(symbol: 'بْ', nameFr: 'Sukun', nameAr: 'سُكُون', sound: 'pas de voyelle', example: 'مَكْتَب', exampleTranslation: 'bureau'),
  ArabicVowel(symbol: 'بّ', nameFr: 'Shadda', nameAr: 'شَدَّة', sound: 'consonne doublée', example: 'مُحَمَّد', exampleTranslation: 'Mohammed'),
  ArabicVowel(symbol: 'بً', nameFr: 'Tanwin (Fath)', nameAr: 'تَنْوِين', sound: 'an / in / un', example: 'كِتَابًا', exampleTranslation: 'un livre (accusatif)'),
];

// ─── Common Quran words ───────────────────────────────────────────────────

class QuranWord {
  final String arabic;
  final String translationFr;
  final String phonetic;
  final String occurrences; // number of occurrences in Quran

  const QuranWord({
    required this.arabic,
    required this.translationFr,
    required this.phonetic,
    required this.occurrences,
  });
}

const List<QuranWord> kQuranWords = [
  QuranWord(arabic: 'اللَّهِ', translationFr: 'Allah (de Dieu)', phonetic: 'Allâhi', occurrences: '2698'),
  QuranWord(arabic: 'رَبِّ', translationFr: 'Seigneur', phonetic: 'Rabbi', occurrences: '960'),
  QuranWord(arabic: 'إِنَّ', translationFr: 'Certes / En vérité', phonetic: 'Inna', occurrences: '834'),
  QuranWord(arabic: 'قَالَ', translationFr: 'Il dit / Il a dit', phonetic: 'Qâla', occurrences: '529'),
  QuranWord(arabic: 'فِي', translationFr: 'dans / en', phonetic: 'Fî', occurrences: '1703'),
  QuranWord(arabic: 'مِن', translationFr: 'de / parmi', phonetic: 'Min', occurrences: '2761'),
  QuranWord(arabic: 'عَلَى', translationFr: 'sur / envers', phonetic: 'ʿAlâ', occurrences: '1375'),
  QuranWord(arabic: 'وَ', translationFr: 'et / or', phonetic: 'Wa', occurrences: '>10000'),
  QuranWord(arabic: 'الَّذِينَ', translationFr: 'ceux qui / les gens qui', phonetic: 'Alladhîna', occurrences: '983'),
  QuranWord(arabic: 'كَانَ', translationFr: 'il était / c\'était', phonetic: 'Kâna', occurrences: '1358'),
  QuranWord(arabic: 'بِسْمِ اللَّهِ', translationFr: 'Au nom d\'Allah', phonetic: 'Bismillâh', occurrences: '114'),
  QuranWord(arabic: 'الرَّحْمَٰنِ', translationFr: 'Le Tout Miséricordieux', phonetic: 'Ar-Rahmân', occurrences: '57'),
  QuranWord(arabic: 'الرَّحِيمِ', translationFr: 'Le Très Miséricordieux', phonetic: 'Ar-Rahîm', occurrences: '114'),
  QuranWord(arabic: 'الْحَمْدُ', translationFr: 'La louange / Gloire', phonetic: 'Al-Hamdu', occurrences: '43'),
  QuranWord(arabic: 'نَعْبُدُ', translationFr: 'nous adorons', phonetic: 'Naʿbudu', occurrences: '6'),
  QuranWord(arabic: 'نَسْتَعِينُ', translationFr: 'nous demandons aide', phonetic: 'Nastaʿîn', occurrences: '2'),
  QuranWord(arabic: 'الصِّرَاطَ', translationFr: 'le chemin / la voie', phonetic: 'Aṣ-Ṣirâṭa', occurrences: '45'),
  QuranWord(arabic: 'الْمُسْتَقِيمَ', translationFr: 'le droit / le rectiligne', phonetic: 'Al-Mustaqîm', occurrences: '34'),
];

// ─── Build exercises helpers ──────────────────────────────────────────────

List<Exercise> _buildLetterGroupLesson(List<ArabicLetter> letters) {
  final exercises = <Exercise>[];

  // 1. Intro card for each letter
  for (final letter in letters) {
    exercises.add(Exercise(
      type: ExerciseType.letterIntro,
      data: {'letter': letter},
      xpReward: 5,
    ));
  }

  // 2. Recognition MCQ for each letter (which name for this letter?)
  for (int i = 0; i < letters.length; i++) {
    final correct = letters[i];
    // 3 distractors from the full alphabet
    final distractors = kArabicLetters
        .where((l) => l.char != correct.char)
        .toList()
      ..shuffle();
    final options = [correct, ...distractors.take(3)]..shuffle();

    exercises.add(Exercise(
      type: ExerciseType.letterRecognition,
      data: {
        'letter': correct,
        'options': options,
        'correctIndex': options.indexOf(correct),
      },
      xpReward: 10,
    ));
  }

  // 3. Name-to-letter MCQ for each letter
  for (int i = 0; i < letters.length; i++) {
    final correct = letters[i];
    final distractors = kArabicLetters
        .where((l) => l.char != correct.char)
        .toList()
      ..shuffle();
    final options = [correct, ...distractors.take(3)]..shuffle();

    exercises.add(Exercise(
      type: ExerciseType.nameToLetter,
      data: {
        'letter': correct,
        'options': options,
        'correctIndex': options.indexOf(correct),
      },
      xpReward: 10,
    ));
  }

  // 4. Writing exercise for first 2 letters in group (keep lesson length reasonable)
  for (final letter in letters.take(2)) {
    exercises.add(Exercise(
      type: ExerciseType.letterWriting,
      data: {'letter': letter},
      xpReward: 15,
    ));
  }

  return exercises;
}

List<Exercise> _buildLetterFormsLesson(List<ArabicLetter> letters) {
  return letters.map((letter) => Exercise(
    type: ExerciseType.letterForms,
    data: {
      'letter': letter,
      'options': [
        {'form': letter.isolated, 'label': 'Isolée'},
        {'form': letter.initial, 'label': 'Initiale'},
        {'form': letter.medial, 'label': 'Médiane'},
        {'form': letter.final_, 'label': 'Finale'},
      ],
    },
    xpReward: 10,
  )).toList();
}

List<Exercise> _buildVowelLesson(ArabicVowel vowel) {
  return [
    Exercise(
      type: ExerciseType.letterIntro,
      data: {'vowel': vowel, 'isVowel': true},
      xpReward: 5,
    ),
    Exercise(
      type: ExerciseType.letterRecognition,
      data: {
        'isVowelRecog': true,
        'vowel': vowel,
        'options': kArabicVowels.toList()..shuffle(),
        'correct': vowel,
      },
      xpReward: 10,
    ),
  ];
}

List<Exercise> _buildWordAssociationLesson(List<QuranWord> words) {
  return [
    Exercise(
      type: ExerciseType.wordAssociation,
      data: {'words': words},
      xpReward: 20,
    ),
  ];
}

List<Exercise> _buildQuizLesson(List<ArabicLetter> letters) {
  final exercises = <Exercise>[];
  final shuffled = [...letters]..shuffle();

  for (final letter in shuffled) {
    final distractors = kArabicLetters
        .where((l) => l.char != letter.char)
        .toList()
      ..shuffle();
    final options = [letter, ...distractors.take(3)]..shuffle();

    // Alternate between recognition and name-to-letter
    exercises.add(Exercise(
      type: exercises.length.isEven
          ? ExerciseType.letterRecognition
          : ExerciseType.nameToLetter,
      data: {
        'letter': letter,
        'options': options,
        'correctIndex': options.indexOf(letter),
      },
      xpReward: 10,
    ));
  }

  return exercises;
}

// ─── Full Curriculum ──────────────────────────────────────────────────────

final List<ArabicUnit> kArabicCurriculum = [
  // ── UNIT 1 ── L'Alphabet ────────────────────────────────────────────────
  ArabicUnit(
    id: 'u1',
    titleFr: "L'Alphabet",
    titleAr: 'حروف الهجاء',
    emoji: '📖',
    description: 'Apprends les 28 lettres de l\'alphabet arabe',
    accentColor: const Color(0xFF52B788),
    lessons: [
      ArabicLesson(
        id: 'u1_l1',
        titleFr: 'ا ب ت ث — Les 4 premières',
        exercises: _buildLetterGroupLesson([
          kArabicLetters[0], // ا Alif
          kArabicLetters[1], // ب Ba
          kArabicLetters[2], // ت Ta
          kArabicLetters[3], // ث Tha
        ]),
      ),
      ArabicLesson(
        id: 'u1_l2',
        titleFr: 'ج ح خ — Les gutturales',
        exercises: _buildLetterGroupLesson([
          kArabicLetters[4], // ج Jeem
          kArabicLetters[5], // ح Ha
          kArabicLetters[6], // خ Kha
        ]),
      ),
      ArabicLesson(
        id: 'u1_l3',
        titleFr: 'د ذ ر ز — Nouvelles formes',
        exercises: _buildLetterGroupLesson([
          kArabicLetters[7],  // د Dal
          kArabicLetters[8],  // ذ Dhal
          kArabicLetters[9],  // ر Ra
          kArabicLetters[10], // ز Zay
        ]),
      ),
      ArabicLesson(
        id: 'u1_l4',
        titleFr: 'س ش ص ض — Les sifflantes',
        exercises: _buildLetterGroupLesson([
          kArabicLetters[11], // س Sin
          kArabicLetters[12], // ش Shin
          kArabicLetters[13], // ص Sad
          kArabicLetters[14], // ض Dad
        ]),
      ),
      ArabicLesson(
        id: 'u1_l5',
        titleFr: 'ط ظ ع غ — Les emphatiques',
        exercises: _buildLetterGroupLesson([
          kArabicLetters[15], // ط Taa
          kArabicLetters[16], // ظ Dhaa
          kArabicLetters[17], // ع Ain
          kArabicLetters[18], // غ Ghain
        ]),
      ),
      ArabicLesson(
        id: 'u1_l6',
        titleFr: 'ف ق ك ل — Suite',
        exercises: _buildLetterGroupLesson([
          kArabicLetters[19], // ف Fa
          kArabicLetters[20], // ق Qaf
          kArabicLetters[21], // ك Kaf
          kArabicLetters[22], // ل Lam
        ]),
      ),
      ArabicLesson(
        id: 'u1_l7',
        titleFr: 'م ن ه و ي — Fin de l\'alphabet',
        exercises: _buildLetterGroupLesson([
          kArabicLetters[23], // م Mim
          kArabicLetters[24], // ن Nun
          kArabicLetters[25], // ه Ha
          kArabicLetters[26], // و Waw
          kArabicLetters[27], // ي Ya
        ]),
      ),
      ArabicLesson(
        id: 'u1_l8',
        titleFr: 'Formes des lettres',
        exercises: _buildLetterFormsLesson([
          kArabicLetters[1],  // ب Ba — bonne illustration
          kArabicLetters[4],  // ج Jeem
          kArabicLetters[11], // س Sin
          kArabicLetters[17], // ع Ain
          kArabicLetters[22], // ل Lam
          kArabicLetters[23], // م Mim
        ]),
      ),
      ArabicLesson(
        id: 'u1_l9',
        titleFr: 'Grand Quiz — 28 lettres',
        isQuiz: true,
        exercises: _buildQuizLesson(kArabicLetters),
      ),
    ],
  ),

  // ── UNIT 2 ── Les Voyelles ───────────────────────────────────────────────
  ArabicUnit(
    id: 'u2',
    titleFr: 'Les Voyelles',
    titleAr: 'الحركات',
    emoji: '🔤',
    description: 'Maîtrise les voyelles courtes et les diacritiques',
    accentColor: const Color(0xFF9C6FDE),
    lessons: [
      ArabicLesson(
        id: 'u2_l1',
        titleFr: 'La Fatha — le "a" bref',
        exercises: _buildVowelLesson(kArabicVowels[0]),
      ),
      ArabicLesson(
        id: 'u2_l2',
        titleFr: 'La Kasra — le "i" bref',
        exercises: _buildVowelLesson(kArabicVowels[1]),
      ),
      ArabicLesson(
        id: 'u2_l3',
        titleFr: 'La Damma — le "u" bref',
        exercises: _buildVowelLesson(kArabicVowels[2]),
      ),
      ArabicLesson(
        id: 'u2_l4',
        titleFr: 'Le Sukun — sans voyelle',
        exercises: _buildVowelLesson(kArabicVowels[3]),
      ),
      ArabicLesson(
        id: 'u2_l5',
        titleFr: 'La Shadda — consonne doublée',
        exercises: _buildVowelLesson(kArabicVowels[4]),
      ),
      ArabicLesson(
        id: 'u2_l6',
        titleFr: 'Le Tanwin — Quiz des voyelles',
        isQuiz: true,
        exercises: [
          ..._buildVowelLesson(kArabicVowels[5]),
          ...kArabicVowels.map((v) => Exercise(
            type: ExerciseType.letterRecognition,
            data: {
              'isVowelRecog': true,
              'vowel': v,
              'options': kArabicVowels.toList()..shuffle(),
              'correct': v,
            },
            xpReward: 10,
          )),
        ],
      ),
    ],
  ),

  // ── UNIT 3 ── Lecture de Syllabes ───────────────────────────────────────
  ArabicUnit(
    id: 'u3',
    titleFr: 'Lecture de Syllabes',
    titleAr: 'قراءة المقاطع',
    emoji: '✍️',
    description: 'Combine lettres et voyelles pour lire tes premières syllabes',
    accentColor: const Color(0xFFE07B39),
    lessons: [
      ArabicLesson(
        id: 'u3_l1',
        titleFr: 'Ba + voyelles : بَ بِ بُ',
        exercises: [
          Exercise(type: ExerciseType.letterIntro, data: {
            'syllable': true,
            'items': [
              {'text': 'بَ', 'sound': 'ba', 'desc': 'Ba + Fatha'},
              {'text': 'بِ', 'sound': 'bi', 'desc': 'Ba + Kasra'},
              {'text': 'بُ', 'sound': 'bu', 'desc': 'Ba + Damma'},
            ],
          }, xpReward: 10),
          Exercise(type: ExerciseType.letterRecognition, data: {
            'isSyllable': true,
            'question': 'بَ',
            'questionLabel': 'Comment prononce-t-on cette syllabe ?',
            'options': ['ba', 'bi', 'bu', 'ab'],
            'correctIndex': 0,
          }, xpReward: 10),
          Exercise(type: ExerciseType.letterRecognition, data: {
            'isSyllable': true,
            'question': 'بِ',
            'questionLabel': 'Comment prononce-t-on cette syllabe ?',
            'options': ['ba', 'bi', 'bu', 'ib'],
            'correctIndex': 1,
          }, xpReward: 10),
        ],
      ),
      ArabicLesson(
        id: 'u3_l2',
        titleFr: 'Mots simples : كِتَاب، بَيْت',
        exercises: [
          Exercise(type: ExerciseType.wordAssociation, data: {
            'words': [
              const QuranWord(arabic: 'كِتَاب', translationFr: 'livre', phonetic: 'kitâb', occurrences: '–'),
              const QuranWord(arabic: 'بَيْت', translationFr: 'maison', phonetic: 'bayt', occurrences: '–'),
              const QuranWord(arabic: 'مَاء', translationFr: 'eau', phonetic: 'mâ\'', occurrences: '–'),
              const QuranWord(arabic: 'نُور', translationFr: 'lumière', phonetic: 'nûr', occurrences: '–'),
            ],
          }, xpReward: 20),
        ],
      ),
      ArabicLesson(
        id: 'u3_l3',
        titleFr: 'La Basmala : بِسْمِ اللَّهِ',
        exercises: [
          Exercise(type: ExerciseType.letterIntro, data: {
            'syllable': true,
            'items': [
              {'text': 'بِسْمِ اللَّهِ الرَّحْمَٰنِ الرَّحِيمِ', 'sound': 'Bismillâhir rahmânir rahîm', 'desc': 'Au nom d\'Allah le Tout Miséricordieux le Très Miséricordieux'},
            ],
          }, xpReward: 15),
          Exercise(type: ExerciseType.wordAssociation, data: {
            'words': [
              const QuranWord(arabic: 'بِسْمِ', translationFr: 'au nom de', phonetic: 'bismi', occurrences: '–'),
              const QuranWord(arabic: 'اللَّهِ', translationFr: 'Allah', phonetic: 'Allâhi', occurrences: '–'),
              const QuranWord(arabic: 'الرَّحْمَٰنِ', translationFr: 'Le Miséricordieux', phonetic: 'ar-Rahmân', occurrences: '–'),
              const QuranWord(arabic: 'الرَّحِيمِ', translationFr: 'Le Très Miséricordieux', phonetic: 'ar-Rahîm', occurrences: '–'),
            ],
          }, xpReward: 20),
        ],
      ),
      ArabicLesson(
        id: 'u3_l4',
        titleFr: 'Al-Fatiha : سورة الفاتحة',
        exercises: [
          Exercise(type: ExerciseType.letterIntro, data: {
            'syllable': true,
            'items': [
              {'text': 'الْحَمْدُ لِلَّهِ رَبِّ الْعَالَمِينَ', 'sound': 'Al-hamdu lillâhi rabbil-ʿâlamîn', 'desc': 'Louange à Allah, Seigneur des mondes'},
              {'text': 'إِيَّاكَ نَعْبُدُ وَإِيَّاكَ نَسْتَعِينُ', 'sound': 'Iyyâka naʿbudu wa iyyâka nastaʿîn', 'desc': 'C\'est Toi que nous adorons et c\'est Toi dont nous implorons le secours'},
            ],
          }, xpReward: 15),
          Exercise(type: ExerciseType.wordAssociation, data: {
            'words': [
              const QuranWord(arabic: 'الْحَمْدُ', translationFr: 'La louange', phonetic: 'al-hamdu', occurrences: '–'),
              const QuranWord(arabic: 'رَبِّ', translationFr: 'Seigneur', phonetic: 'rabbi', occurrences: '–'),
              const QuranWord(arabic: 'نَعْبُدُ', translationFr: 'nous adorons', phonetic: 'naʿbudu', occurrences: '–'),
              const QuranWord(arabic: 'الصِّرَاطَ', translationFr: 'le chemin', phonetic: 'aṣ-ṣirâṭa', occurrences: '–'),
            ],
          }, xpReward: 20),
        ],
      ),
      ArabicLesson(
        id: 'u3_l5',
        titleFr: 'Quiz — Lecture de syllabes',
        isQuiz: true,
        exercises: [
          Exercise(type: ExerciseType.letterRecognition, data: {
            'isSyllable': true,
            'question': 'كِتَاب',
            'questionLabel': 'Que signifie ce mot ?',
            'options': ['livre', 'maison', 'eau', 'lumière'],
            'correctIndex': 0,
          }, xpReward: 10),
          Exercise(type: ExerciseType.letterRecognition, data: {
            'isSyllable': true,
            'question': 'بَيْت',
            'questionLabel': 'Que signifie ce mot ?',
            'options': ['livre', 'maison', 'eau', 'lumière'],
            'correctIndex': 1,
          }, xpReward: 10),
          Exercise(type: ExerciseType.wordAssociation, data: {
            'words': kQuranWords.take(4).toList(),
          }, xpReward: 20),
        ],
      ),
    ],
  ),

  // ── UNIT 4 ── Mots du Coran ──────────────────────────────────────────────
  ArabicUnit(
    id: 'u4',
    titleFr: 'Mots du Coran',
    titleAr: 'كلمات قرآنية',
    emoji: '🕌',
    description: 'Apprends les mots les plus fréquents du Coran',
    accentColor: const Color(0xFFD4AF77),
    lessons: [
      ArabicLesson(
        id: 'u4_l1',
        titleFr: 'Allah & ses attributs',
        exercises: _buildWordAssociationLesson(kQuranWords.sublist(0, 3)) + [
          Exercise(type: ExerciseType.letterRecognition, data: {
            'isSyllable': true,
            'question': 'اللَّهِ',
            'questionLabel': 'Que signifie ce mot ?',
            'options': ['Allah', 'Seigneur', 'Miséricordieux', 'Lumière'],
            'correctIndex': 0,
          }, xpReward: 10),
        ],
      ),
      ArabicLesson(
        id: 'u4_l2',
        titleFr: 'Prépositions courantes',
        exercises: _buildWordAssociationLesson([
          kQuranWords[4], // في
          kQuranWords[5], // من
          kQuranWords[6], // على
          kQuranWords[7], // و
        ]),
      ),
      ArabicLesson(
        id: 'u4_l3',
        titleFr: 'Verbes fréquents',
        exercises: _buildWordAssociationLesson([
          kQuranWords[3],  // قال
          kQuranWords[9],  // كان
          kQuranWords[14], // نعبد
          kQuranWords[15], // نستعين
        ]),
      ),
      ArabicLesson(
        id: 'u4_l4',
        titleFr: 'La Basmala mot par mot',
        exercises: _buildWordAssociationLesson(kQuranWords.sublist(10, 14)),
      ),
      ArabicLesson(
        id: 'u4_l5',
        titleFr: 'Al-Fatiha — mots clés',
        exercises: _buildWordAssociationLesson([
          kQuranWords[13], // الحمد
          kQuranWords[1],  // رب
          kQuranWords[16], // الصراط
          kQuranWords[17], // المستقيم
        ]),
      ),
      ArabicLesson(
        id: 'u4_l6',
        titleFr: 'Les 10 mots les + fréquents',
        exercises: _buildWordAssociationLesson(kQuranWords.sublist(0, 4)) +
            _buildWordAssociationLesson(kQuranWords.sublist(4, 8)),
      ),
      ArabicLesson(
        id: 'u4_l7',
        titleFr: 'Révision — 18 mots essentiels',
        exercises: [
          Exercise(type: ExerciseType.wordAssociation, data: {
            'words': kQuranWords.sublist(0, 6),
          }, xpReward: 25),
          Exercise(type: ExerciseType.wordAssociation, data: {
            'words': kQuranWords.sublist(6, 12),
          }, xpReward: 25),
        ],
      ),
      ArabicLesson(
        id: 'u4_l8',
        titleFr: 'Grand Quiz Final',
        isQuiz: true,
        exercises: [
          ...kQuranWords.sublist(0, 8).map((w) => Exercise(
            type: ExerciseType.letterRecognition,
            data: {
              'isSyllable': true,
              'question': w.arabic,
              'questionLabel': 'Que signifie ce mot ?',
              'options': [
                w.translationFr,
                ...kQuranWords.where((q) => q.arabic != w.arabic).map((q) => q.translationFr).take(3).toList(),
              ]..shuffle(),
              'correctIndex': 0,
            },
            xpReward: 10,
          )),
        ],
      ),
    ],
  ),
];

// ─── Badge definitions ─────────────────────────────────────────────────────

const List<ArabicBadge> kArabicBadges = [
  ArabicBadge(
    id: 'first_lesson',
    titleFr: 'Premier Pas',
    emoji: '🌟',
    description: 'Tu as complété ta première leçon !',
    condition: 'Compléter la leçon 1.1',
  ),
  ArabicBadge(
    id: 'alphabet_complete',
    titleFr: 'Alphabète',
    emoji: '📖',
    description: 'Tu connais les 28 lettres de l\'alphabet arabe !',
    condition: 'Compléter toutes les leçons de l\'Unité 1',
  ),
  ArabicBadge(
    id: 'vowels_complete',
    titleFr: 'Maître des Voyelles',
    emoji: '💧',
    description: 'Les voyelles n\'ont plus de secrets pour toi !',
    condition: 'Compléter toutes les leçons de l\'Unité 2',
  ),
  ArabicBadge(
    id: 'streak_7',
    titleFr: '7 Jours d\'Arabe',
    emoji: '🔥',
    description: 'Tu as pratiqué 7 jours de suite — mâshâ\'Allah !',
    condition: 'Atteindre un streak de 7 jours',
  ),
  ArabicBadge(
    id: 'perfect_5',
    titleFr: 'Perfectionniste',
    emoji: '⭐',
    description: 'Tu as obtenu un score parfait 5 fois !',
    condition: '5 leçons avec score parfait (100%)',
  ),
  ArabicBadge(
    id: 'quran_reader',
    titleFr: 'Lecteur Coranique',
    emoji: '🕌',
    description: 'Tu peux lire des mots du Coran — barakallahu fik !',
    condition: 'Compléter toutes les leçons de l\'Unité 4',
  ),
  ArabicBadge(
    id: 'xp_1000',
    titleFr: '1000 XP',
    emoji: '💎',
    description: 'Tu as accumulé 1000 points d\'expérience !',
    condition: 'Atteindre 1000 XP total',
  ),
  ArabicBadge(
    id: 'streak_30',
    titleFr: 'Mois de Dévotion',
    emoji: '🌙',
    description: '30 jours de pratique quotidienne — exceptionnel !',
    condition: 'Atteindre un streak de 30 jours',
  ),
];
