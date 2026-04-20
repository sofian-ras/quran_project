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
      arabic: (map['arabic'] as String?) ?? '',
      translation: (map['translation'] as String?) ?? '',
      title: (map['title'] as String?) ?? '',
      explanation: (map['explanation'] as String?) ?? '',
      categoryId: (map['category_id'] as String?) ?? '',
      categoryName: (map['category_name'] as String?) ?? '',
    );
  }
}
