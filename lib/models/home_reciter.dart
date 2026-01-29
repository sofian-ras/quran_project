class HomeReciter {
  final String name;
  final String asset;
  final String server;

  const HomeReciter({required this.name, required this.asset, required this.server});

  factory HomeReciter.fromJson(Map<String, dynamic> json) {
    return HomeReciter(
      name: (json['name'] ?? '').toString(),
      asset: (json['asset'] ?? '').toString(),
      server: (json['server'] ?? '').toString(),
    );
  }
}
