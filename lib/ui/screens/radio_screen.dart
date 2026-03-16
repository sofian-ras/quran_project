import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:dio/dio.dart';
import '../../theme/app_theme.dart';

const _radioApiUrl = 'http://mp3quran.net/api/v3/radios';
final _dio = Dio();

class RadioScreen extends StatefulWidget {
  const RadioScreen({super.key});

  @override
  State<RadioScreen> createState() => _RadioScreenState();
}

class _RadioScreenState extends State<RadioScreen> {
  final AudioPlayer _player = AudioPlayer();
  List<dynamic> _stations = [];
  List<dynamic> _filtered = [];
  bool _loading = true;
  String? _error;
  int? _playingIndex;
  bool _isPlaying = false;
  final TextEditingController _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
    _player.playerStateStream.listen((state) {
      if (mounted) setState(() => _isPlaying = state.playing);
    });
  }

  @override
  void dispose() {
    _player.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final res = await _dio.get(_radioApiUrl);
      final data = res.data is String ? json.decode(res.data as String) : res.data;
      final stations = (data['radios'] as List?) ?? [];
      if (mounted) {
        setState(() {
          _stations = stations;
          _filtered = stations;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  void _onSearch(String q) {
    final lower = q.trim().toLowerCase();
    setState(() {
      _filtered = lower.isEmpty
          ? _stations
          : _stations.where((s) =>
              s['name']?.toString().toLowerCase().contains(lower) == true).toList();
    });
  }

  Future<void> _play(int index) async {
    final station = _filtered[index];
    final url = station['url']?.toString() ?? '';
    if (url.isEmpty) return;

    if (_playingIndex == index && _isPlaying) {
      await _player.pause();
    } else {
      setState(() => _playingIndex = index);
      try {
        await _player.setUrl(url);
        await _player.play();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erreur: $e'), behavior: SnackBarBehavior.floating),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Radio Islamique', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: AppColors.primary,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            child: TextField(
              controller: _searchCtrl,
              onChanged: _onSearch,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Rechercher une station...',
                hintStyle: const TextStyle(color: Colors.white60),
                prefixIcon: const Icon(Icons.search, color: Colors.white60),
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.15),
                contentPadding: const EdgeInsets.symmetric(vertical: 8),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.wifi_off, size: 48, color: Colors.grey),
                      const SizedBox(height: 16),
                      Text(_error!, style: const TextStyle(color: Colors.grey)),
                      const SizedBox(height: 16),
                      ElevatedButton(onPressed: _load, child: const Text('Réessayer')),
                    ],
                  ),
                )
              : _filtered.isEmpty
                  ? const Center(child: Text('Aucune station trouvée'))
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: _filtered.length,
                      itemBuilder: (context, i) {
                        final s = _filtered[i];
                        final isActive = _playingIndex == i;
                        return ListTile(
                          leading: Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: isActive ? AppColors.primary : AppColors.primary.withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              isActive && _isPlaying ? Icons.radio : Icons.radio_outlined,
                              color: isActive ? Colors.white : AppColors.primary,
                              size: 22,
                            ),
                          ),
                          title: Text(
                            s['name']?.toString() ?? 'Station ${i + 1}',
                            style: TextStyle(
                              fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                              color: isActive ? AppColors.primary : null,
                            ),
                          ),
                          subtitle: isActive
                              ? Text(
                                  _isPlaying ? '● En cours de lecture' : '❙❙ En pause',
                                  style: TextStyle(
                                    color: isActive ? AppColors.accent : Colors.grey,
                                    fontSize: 12,
                                  ),
                                )
                              : null,
                          trailing: IconButton(
                            icon: Icon(
                              isActive && _isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled,
                              size: 36,
                              color: AppColors.primary,
                            ),
                            onPressed: () => _play(i),
                          ),
                          onTap: () => _play(i),
                        );
                      },
                    ),
    );
  }
}
