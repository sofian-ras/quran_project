// Mapping des photos des récitants
const Map<String, String> reciterPhotos = {
  'Mishari Alafasy': 'https://example.com/photos/mishari_alafasy.jpg',
  'Abdul Rahman Al-Sudais': 'https://example.com/photos/sudais.jpg',
  'Saad Al-Ghamdi': 'https://example.com/photos/ghamdi.jpg',
  'Abdul Rashid Sofy': 'https://example.com/photos/sofy.jpg',
  // Ajouter d'autres récitants...
};

String? getReciterPhoto(String reciterName) {
  return reciterPhotos[reciterName];
}
