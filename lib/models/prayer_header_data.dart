class PrayerHeaderData {
  final String city;
  final String country;
  final String hijriLine;
  final Map<String, String> times;
  final String methodLabel;

  const PrayerHeaderData({
    required this.city,
    required this.country,
    required this.hijriLine,
    required this.times,
    required this.methodLabel,
  });

  factory PrayerHeaderData.error({required String city, required String country}) {
    return PrayerHeaderData(
      city: city,
      country: country,
      hijriLine: '',
      times: const {},
      methodLabel: '',
    );
  }
}
