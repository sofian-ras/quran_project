import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import '../../theme/app_theme.dart';

const _books = [
  {'id': '1',  'name': 'Sahih Al-Bukhari',       'nameAr': 'صحيح البخاري',       'count': '7563 hadiths'},
  {'id': '2',  'name': 'Sahih Muslim',            'nameAr': 'صحيح مسلم',           'count': '5362 hadiths'},
  {'id': '3',  'name': 'Sunan Abi Dawud',         'nameAr': 'سنن أبي داود',        'count': '5274 hadiths'},
  {'id': '4',  'name': 'Jami\' At-Tirmidhi',      'nameAr': 'جامع الترمذي',        'count': '3956 hadiths'},
  {'id': '5',  'name': 'Sunan An-Nasai',          'nameAr': 'سنن النسائي',         'count': '5758 hadiths'},
  {'id': '6',  'name': 'Sunan Ibn Majah',         'nameAr': 'سنن ابن ماجه',        'count': '4341 hadiths'},
  {'id': '7',  'name': 'Musnad Ahmad',            'nameAr': 'مسند أحمد',           'count': '27647 hadiths'},
  {'id': '8',  'name': 'Al-Muwatta',              'nameAr': 'موطأ مالك',           'count': '1832 hadiths'},
  {'id': '9',  'name': 'Sunan Ad-Darimi',         'nameAr': 'سنن الدارمي',         'count': '3367 hadiths'},
];

const _apiBase = 'https://hadeethenc.com/api/v1';
final _dio = Dio();

class HadithScreen extends StatelessWidget {
  const HadithScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Hadith', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: AppColors.primary,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [AppColors.primary.withValues(alpha: 0.05), Colors.white],
          ),
        ),
        child: ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: _books.length,
          itemBuilder: (context, index) {
            final book = _books[index];
            return _BookCard(book: book);
          },
        ),
      ),
    );
  }
}

class _BookCard extends StatelessWidget {
  final Map<String, String> book;
  const _BookCard({required this.book});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => Navigator.push(context, MaterialPageRoute(
          builder: (_) => _HadithCategoriesScreen(bookId: book['id']!, bookName: book['name']!),
        )),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.menu_book, color: Colors.white, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(book['nameAr']!, style: const TextStyle(
                      fontFamily: 'ScheherazadeNew', fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ), textDirection: TextDirection.rtl),
                    const SizedBox(height: 2),
                    Text(book['name']!, style: TextStyle(color: Colors.grey[600], fontSize: 13)),
                    Text(book['count']!, style: TextStyle(color: AppColors.accent, fontSize: 12)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }
}

class _HadithCategoriesScreen extends StatefulWidget {
  final String bookId;
  final String bookName;
  const _HadithCategoriesScreen({required this.bookId, required this.bookName});

  @override
  State<_HadithCategoriesScreen> createState() => _HadithCategoriesScreenState();
}

class _HadithCategoriesScreenState extends State<_HadithCategoriesScreen> {
  List<dynamic> _categories = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final res = await _dio.get(
        '$_apiBase/categories/roots/',
        queryParameters: {'language': 'ar'},
      );
      final data = res.data is String ? json.decode(res.data as String) : res.data;
      if (mounted) setState(() { _categories = data as List; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.bookName, style: const TextStyle(color: Colors.white)),
        backgroundColor: AppColors.primary,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!, style: const TextStyle(color: Colors.red)))
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: _categories.length,
                  itemBuilder: (context, i) {
                    final cat = _categories[i];
                    return ListTile(
                      leading: Container(
                        width: 40, height: 40,
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Center(child: Text('${cat['hadeeths_count'] ?? ''}',
                          style: TextStyle(color: AppColors.primary, fontSize: 11, fontWeight: FontWeight.bold))),
                      ),
                      title: Text(cat['title'] ?? '', textDirection: TextDirection.rtl,
                        style: const TextStyle(fontFamily: 'ScheherazadeNew', fontSize: 16)),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => Navigator.push(context, MaterialPageRoute(
                        builder: (_) => _HadithListScreen(
                          categoryId: cat['id'].toString(),
                          categoryName: cat['title']?.toString() ?? '',
                        ),
                      )),
                    );
                  },
                ),
    );
  }
}

class _HadithListScreen extends StatefulWidget {
  final String categoryId;
  final String categoryName;
  const _HadithListScreen({required this.categoryId, required this.categoryName});

  @override
  State<_HadithListScreen> createState() => _HadithListScreenState();
}

class _HadithListScreenState extends State<_HadithListScreen> {
  List<dynamic> _items = [];
  bool _loading = true;
  String? _error;
  int _page = 1;
  bool _hasMore = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final res = await _dio.get(
        '$_apiBase/hadeeths/list/',
        queryParameters: {
          'language': 'ar',
          'category_id': widget.categoryId,
          'page': _page,
          'per_page': 20,
        },
      );
      final data = res.data is String ? json.decode(res.data as String) : res.data;
      final List items = (data['data'] as List?) ?? [];
      if (mounted) {
        setState(() {
          _items.addAll(items);
          _loading = false;
          _hasMore = items.length == 20;
        });
      }
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.categoryName, style: const TextStyle(color: Colors.white, fontSize: 15)),
        backgroundColor: AppColors.primary,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : ListView.separated(
                  padding: const EdgeInsets.all(12),
                  itemCount: _items.length + (_hasMore ? 1 : 0),
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, i) {
                    if (i == _items.length) {
                      return TextButton(
                        onPressed: () { setState(() { _page++; _load(); }); },
                        child: const Text('Voir plus'),
                      );
                    }
                    final h = _items[i];
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      title: Text(
                        h['hadeeth']?.toString() ?? h['title']?.toString() ?? '',
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        textDirection: TextDirection.rtl,
                        style: const TextStyle(fontFamily: 'ScheherazadeNew', fontSize: 15, height: 1.6),
                      ),
                      subtitle: h['attribution'] != null
                          ? Text(h['attribution'].toString(), maxLines: 1, overflow: TextOverflow.ellipsis,
                              style: TextStyle(color: Colors.grey[600], fontSize: 12))
                          : null,
                      onTap: () => Navigator.push(context, MaterialPageRoute(
                        builder: (_) => _HadithDetailScreen(hadithId: h['id'].toString()),
                      )),
                    );
                  },
                ),
    );
  }
}

class _HadithDetailScreen extends StatefulWidget {
  final String hadithId;
  const _HadithDetailScreen({required this.hadithId});

  @override
  State<_HadithDetailScreen> createState() => _HadithDetailScreenState();
}

class _HadithDetailScreenState extends State<_HadithDetailScreen> {
  Map<String, dynamic>? _hadith;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final res = await _dio.get(
        '$_apiBase/hadeeths/one/',
        queryParameters: {'language': 'ar', 'id': widget.hadithId},
      );
      final data = res.data is String ? json.decode(res.data as String) : res.data;
      if (mounted) setState(() { _hadith = data as Map<String, dynamic>; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Hadith', style: TextStyle(color: Colors.white)),
        backgroundColor: AppColors.primary,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _hadith == null
              ? const Center(child: Text('Erreur de chargement'))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
                        ),
                        child: Text(
                          _hadith!['hadeeth']?.toString() ?? '',
                          textDirection: TextDirection.rtl,
                          textAlign: TextAlign.right,
                          style: const TextStyle(
                            fontFamily: 'ScheherazadeNew',
                            fontSize: 20,
                            height: 1.8,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      if (_hadith!['attribution'] != null) ...[
                        _InfoRow(label: 'Attribution', value: _hadith!['attribution'].toString(), rtl: true),
                        const SizedBox(height: 8),
                      ],
                      if (_hadith!['grade'] != null) ...[
                        _InfoRow(label: 'Grade', value: _hadith!['grade'].toString(), rtl: true),
                        const SizedBox(height: 8),
                      ],
                      if (_hadith!['explanation'] != null && _hadith!['explanation'].toString().isNotEmpty) ...[
                        const SizedBox(height: 8),
                        const Text('Explication', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        Text(
                          _hadith!['explanation'].toString(),
                          textDirection: TextDirection.rtl,
                          textAlign: TextAlign.right,
                          style: const TextStyle(fontFamily: 'ScheherazadeNew', fontSize: 16, height: 1.7),
                        ),
                      ],
                    ],
                  ),
                ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final bool rtl;
  const _InfoRow({required this.label, required this.value, this.rtl = false});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('$label: ', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
        Expanded(
          child: Text(value,
            textDirection: rtl ? TextDirection.rtl : TextDirection.ltr,
            style: const TextStyle(fontSize: 13)),
        ),
      ],
    );
  }
}
