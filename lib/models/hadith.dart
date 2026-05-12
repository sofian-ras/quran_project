class Hadith {
  final int id;
  final String arabic;
  final String translation;
  final String title;
  final String explanation;
  final String categoryId;
  final String categoryName;

  const Hadith({
    required this.id,
    required this.arabic,
    required this.translation,
    required this.title,
    required this.explanation,
    this.categoryId = '',
    this.categoryName = '',
  });

  factory Hadith.fromMap(Map<String, Object?> map, {String lang = 'fr'}) {
    return Hadith(
      id: (map['hadith_id'] ?? map['id']) as int,
      arabic: _normalize((map['arabic'] as String?) ?? ''),
      translation: _normalize((map['translation'] as String?) ?? ''),
      title: _normalize((map['title'] as String?) ?? ''),
      explanation: _normalize((map['explanation'] as String?) ?? ''),
      categoryId: (map['category_id'] as String?) ?? '',
      categoryName: (map['category_name'] as String?) ?? '',
    );
  }

  // Replaces all forms of the salawat formula with the Unicode ligature ﷺ
  static String _normalize(String text) {
    if (text.isEmpty) return text;
    return text
        .replaceAll('صلى الله عليه وسلم', 'ﷺ')
        .replaceAll('صلى الله عليه و سلم', 'ﷺ')
        .replaceAll('صلى الله عليه وآله وسلم', 'ﷺ')
        .replaceAll('صلي الله عليه وسلم', 'ﷺ');
  }
}
