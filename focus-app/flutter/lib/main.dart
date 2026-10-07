import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:just_audio/just_audio.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() => runApp(const FocusPlayer());

class FocusPlayer extends StatelessWidget {
  const FocusPlayer({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Focus Player',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        colorSchemeSeed: Colors.pinkAccent,
        useMaterial3: true,
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final OnAudioQuery _audioQuery = OnAudioQuery();
  final AudioPlayer _player = AudioPlayer();
  List<SongModel> _all = [];
  Set<String> _favoris = {};
  Map<String, int> _compteur = {};
  SongModel? _enCours;

  @override
  void initState() {
    super.initState();
    _initialiser();
  }

  Future<void> _initialiser() async {
    await [Permission.audio, Permission.storage].request();
    final prefs = await SharedPreferences.getInstance();
    _favoris = (prefs.getStringList('favoris') ?? []).toSet();
    _compteur = Map<String, int>.from(
      jsonDecode(prefs.getString('compteur') ?? '{}'),
    );
    await _charger();
  }

  Future<void> _charger() async {
    try {
      _all = await _audioQuery.querySongs(
        sortType: SongSortType.DATE_ADDED,
        orderType: OrderType.DESC_OR_GREATER,
      );
    } catch (_) {
      _all = [];
    }
    setState(() {});
  }

  Future<void> _jouer(SongModel s) async {
    setState(() => _enCours = s);
    await _player.setFilePath(s.data);
    _player.play();
    final prefs = await SharedPreferences.getInstance();
    _compteur[s.id.toString()] = (_compteur[s.id.toString()] ?? 0) + 1;
    await prefs.setString('compteur', jsonEncode(_compteur));
    setState(() {});
  }

  Future<void> _basculerFavori(SongModel s) async {
    final id = s.id.toString();
    _favoris.contains(id) ? _favoris.remove(id) : _favoris.add(id);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('favoris', _favoris.toList());
    setState(() {});
  }

  Widget _ligne(SongModel s) => ListTile(
        leading: CircleAvatar(
          child: const Icon(Icons.music_note),
          onBackgroundImageError: (_, __) {},
        ),
        title: Text(s.title, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text(s.artist ?? "Inconnu"),
        trailing: IconButton(
          icon: Icon(
            _favoris.contains(s.id.toString()) ? Icons.favorite : Icons.favorite_border,
            color: Colors.pinkAccent,
          ),
          onPressed: () => _basculerFavori(s),
        ),
        onTap: () => _jouer(s),
      );

  @override
  Widget build(BuildContext context) {
    final populaires = [..._all]
      ..sort((a, b) => (_compteur[b.id.toString()] ?? 0)
          .compareTo(_compteur[a.id.toString()] ?? 0));
    final fav = _all.where((s) => _favoris.contains(s.id.toString())).toList();

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('🎵 Focus Player'),
          bottom: const TabBar(tabs: [
            Tab(text: 'Toutes'),
            Tab(text: '❤️ Favoris'),
            Tab(text: '🔥 Plus jouées'),
          ]),
        ),
        body: TabBarView(children: [
          ListView(children: _all.map(_ligne).toList()),
          ListView(children: fav.map(_ligne).toList()),
          ListView(children: populaires.take(20).map(_ligne).toList()),
        ]),
        bottomNavigationBar: _enCours == null
            ? null
            : Container(
                color: Colors.grey[900],
                padding: const EdgeInsets.all(12),
                child: Row(children: [
                  const Icon(Icons.music_note, color: Colors.pinkAccent),
                  Expanded(child: Text(_enCours!.title)),
                  IconButton(
                      icon: const Icon(Icons.pause),
                      onPressed: () => _player.pause()),
                  IconButton(
                      icon: const Icon(Icons.play_arrow),
                      onPressed: () => _player.play()),
                ]),
              ),
      ),
    );
  }
}
