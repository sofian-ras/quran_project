import 'dart:convert';

enum AnnouncementType { newFeature, info, tip, streak, warning }

class Announcement {
  final String id;
  final DateTime date;
  final String title;
  final String body;
  final AnnouncementType type;
  final bool isRemote;

  const Announcement({
    required this.id,
    required this.date,
    required this.title,
    required this.body,
    required this.type,
    required this.isRemote,
  });

  factory Announcement.fromJson(Map<String, dynamic> json) {
    return Announcement(
      id: json['id'] as String,
      date: DateTime.tryParse(json['date'] as String? ?? '') ?? DateTime.now(),
      title: json['title'] as String,
      body: json['body'] as String,
      type: _parseType(json['type'] as String? ?? 'info'),
      isRemote: true,
    );
  }

  static AnnouncementType _parseType(String raw) {
    switch (raw) {
      case 'new_feature': return AnnouncementType.newFeature;
      case 'tip':         return AnnouncementType.tip;
      case 'streak':      return AnnouncementType.streak;
      case 'warning':     return AnnouncementType.warning;
      default:            return AnnouncementType.info;
    }
  }

  static List<Announcement> listFromJson(String jsonStr) {
    final list = jsonDecode(jsonStr) as List<dynamic>;
    return list
        .map((e) => Announcement.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
