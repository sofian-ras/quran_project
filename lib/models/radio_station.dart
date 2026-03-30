import 'dart:convert';

class RadioStation {
  final int id;
  final String name;
  final String url;

  const RadioStation({required this.id, required this.name, required this.url});

  String get displayName =>
      name.startsWith('Radio ') ? name.substring(6) : name;

  String get domain {
    try {
      return Uri.parse(url).host;
    } catch (_) {
      return url;
    }
  }

  factory RadioStation.fromJson(Map<String, dynamic> j) => RadioStation(
        id: j['id'] as int,
        name: j['name'] as String,
        url: j['url'] as String,
      );

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'url': url};

  static List<RadioStation> listFromJson(String source) {
    final list = jsonDecode(source) as List<dynamic>;
    return list.map((e) => RadioStation.fromJson(e as Map<String, dynamic>)).toList();
  }

  static String listToJson(List<RadioStation> stations) =>
      jsonEncode(stations.map((s) => s.toJson()).toList());
}
