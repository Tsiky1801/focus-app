import 'dart:async';
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
        useMaterial3: true,
        brightness: Brightness.dark,
        colorSchemeSeed: Color(0xFFFF4081),
        scaffoldBackgroundColor: Color(0xFF101018),
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
  static const Color rose = Color(0xFFFF4081);
  static const Color violet = Color(0xFF9C27B0);
  static const Color carte = Color(0xFF1A1A24);
  static const Color roseSombre = Color(0xFF2E1524);
  static const String auteur = 'NAMBININTSOA Tsiky Fanantenana';

  final OnAudioQuery _audioQuery = OnAudioQuery();
  final AudioPlayer _player = AudioPlayer();
  List<SongModel> _all = [];
  Set<String> _favoris = {};
  Map<String, int> _compteur = {};
  SongModel? _enCours;
  bool _chargement = true;
  Duration _pos = Duration.zero;
  Duration _dur = Duration.zero;
  StreamSubscription? _sPos;
  StreamSubscription? _sDur;

  @override
  void initState() {
    super.initState();
    _sPos = _player.positionStream.listen((d) {
      if (mounted) setState(() => _pos = d);
    });
    _sDur = _player.durationStream.listen((d) {
      if (mounted) setState(() => _dur = d ?? Duration.zero);
    });
    _initialiser();
  }

  @override
  void dispose() {
    _sPos?.cancel();
    _sDur?.cancel();
    _player.dispose();
    super.dispose();
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
    if (mounted) setState(() => _chargement = false);
  }

  Future<void> _jouer(SongModel s) async {
    setState(() => _enCours = s);
    try {
      await _player.setFilePath(s.data);
      _player.play();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Impossible de lire ce fichier'),
            backgroundColor: rose,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    _compteur[s.id.toString()] = (_compteur[s.id.toString()] ?? 0) + 1;
    await prefs.setString('compteur', jsonEncode(_compteur));
    if (mounted) setState(() {});
  }

  Future<void> _basculerFavori(SongModel s) async {
    final id = s.id.toString();
    _favoris.contains(id) ? _favoris.remove(id) : _favoris.add(id);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('favoris', _favoris.toList());
    if (mounted) setState(() {});
  }

  void _arreter() {
    _player.stop();
    setState(() {
      _enCours = null;
      _pos = Duration.zero;
      _dur = Duration.zero;
    });
  }

  void _aPropos() {
    showDialog<void>(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: carte,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: const BoxDecoration(
                gradient: LinearGradient(colors: [rose, violet]),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.music_note, color: Colors.white, size: 34),
            ),
            const SizedBox(height: 14),
            const Text('Focus Player',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 2),
            Text('version 1.1.1',
                style: TextStyle(color: Colors.white54, fontSize: 12)),
            const SizedBox(height: 16),
            Container(height: 1, color: Colors.white12),
            const SizedBox(height: 16),
            const Text('Créé et développé par',
                style: TextStyle(color: Colors.white54, fontSize: 13)),
            const SizedBox(height: 6),
            Text(
              auteur,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontWeight: FontWeight.bold, fontSize: 15, color: Colors.white),
            ),
            const SizedBox(height: 3),
            const Text('« Tsiky »',
                style: TextStyle(color: rose, fontSize: 13)),
            const SizedBox(height: 14),
            const Text('tsikynambs@gmail.com',
                style: TextStyle(color: Colors.white70, fontSize: 13)),
            const SizedBox(height: 3),
            const Text('038 97 91 195 · 033 07 71 835',
                style: TextStyle(color: Colors.white70, fontSize: 13)),
            const SizedBox(height: 16),
            const Text(
              '© 2026 Tsiky — Tous droits réservés',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white38, fontSize: 12),
            ),
          ],
        ),
        actions: [
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: rose,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30)),
            ),
            onPressed: () => Navigator.pop(c),
            child: const Text('Fermer'),
          ),
        ],
      ),
    );
  }

  Widget _pochette(SongModel s, double taille) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        width: taille,
        height: taille,
        child: QueryArtworkWidget(
          controller: _audioQuery,
          id: s.id,
          type: ArtworkType.AUDIO,
          artworkBorder: BorderRadius.circular(12),
          artworkWidth: taille,
          artworkHeight: taille,
          nullArtworkWidget: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(colors: [rose, violet]),
            ),
            child: Icon(Icons.music_note, color: Colors.white, size: taille / 2),
          ),
        ),
      ),
    );
  }

  Widget _ligne(SongModel s) {
    final id = s.id.toString();
    final enCours = _enCours?.id == s.id;
    final ecoutes = _compteur[id] ?? 0;
    final favori = _favoris.contains(id);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Material(
        color: enCours ? roseSombre : carte,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _jouer(s),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Row(
              children: [
                _pochette(s, 52),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        s.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                          color: enCours ? rose : Colors.white,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${s.artist ?? "Inconnue"}  ·  $ecoutes écoute${ecoutes > 1 ? "s" : ""}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: Colors.white54, fontSize: 12.5),
                      ),
                    ],
                  ),
                ),
                if (enCours)
                  const Padding(
                    padding: EdgeInsets.only(right: 4),
                    child: Icon(Icons.graphic_eq, color: rose, size: 22),
                  ),
                IconButton(
                  tooltip: favori ? 'Retirer des favoris' : 'Ajouter aux favoris',
                  icon: Icon(
                    favori ? Icons.favorite : Icons.favorite_border,
                    color: favori ? rose : Colors.white38,
                  ),
                  onPressed: () => _basculerFavori(s),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _signature() {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 20),
      child: Column(
        children: [
          Icon(Icons.verified, color: Color(0xFFFF4081), size: 20),
          SizedBox(height: 6),
          Text(
            'Créé par NAMBININTSOA Tsiky Fanantenana',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white70, fontSize: 13),
          ),
          SizedBox(height: 2),
          Text(
            'Tsikynambs · © 2026 — Tous droits réservés',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white38, fontSize: 11.5),
          ),
        ],
      ),
    );
  }

  Widget _liste(List<SongModel> morceaux, String msgVide, IconData iconeVide) {
    if (_chargement) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: Color(0xFFFF4081)),
            SizedBox(height: 16),
            Text('Lecture de ta musique…',
                style: TextStyle(color: Colors.white54)),
          ],
        ),
      );
    }
    if (morceaux.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(iconeVide, size: 64, color: Colors.white24),
            const SizedBox(height: 14),
            Text(msgVide,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white54, fontSize: 15)),
          ],
        ),
      );
    }
    return ListView(
      children: [
        const SizedBox(height: 4),
        ...morceaux.map(_ligne),
        _signature(),
        const SizedBox(height: 96),
      ],
    );
  }

  Widget? _lecteur() {
    if (_enCours == null) return null;
    final s = _enCours!;
    final ms = _dur.inMilliseconds;
    final ps = _pos.inMilliseconds;
    final maxMs = ms > 0 ? ms : (ps > 0 ? ps + 1000 : 1);
    final val = ps.clamp(0, maxMs).toDouble();
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFAD1457), Color(0xFF6A1B9A)],
        ),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(color: Color(0x66000000), blurRadius: 18, offset: Offset(0, -4)),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 12),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                _pochette(s, 46),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        s.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14),
                      ),
                      Text(
                        s.artist ?? 'Inconnue',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Arrêter',
                  icon: const Icon(Icons.stop_circle_outlined,
                      color: Colors.white70, size: 26),
                  onPressed: _arreter,
                ),
                StreamBuilder<PlayerState>(
                  stream: _player.playerStateStream,
                  builder: (c, st) {
                    final enLecture = st.data?.playing ?? false;
                    return Material(
                      color: Colors.white,
                      shape: const CircleBorder(),
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: enLecture ? _player.pause : _player.play,
                        child: Padding(
                          padding: const EdgeInsets.all(8),
                          child: Icon(
                            enLecture ? Icons.pause : Icons.play_arrow,
                            color: const Color(0xFFAD1457),
                            size: 30,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
            SliderTheme(
              data: SliderThemeData(
                trackHeight: 4,
                thumbShape:
                    const RoundSliderThumbShape(enabledThumbRadius: 7),
                overlayShape:
                    const RoundSliderOverlayShape(overlayRadius: 14),
                activeTrackColor: Colors.white,
                inactiveTrackColor: Colors.white24,
                thumbColor: Colors.white,
                overlayColor: Colors.white24,
              ),
              child: Slider(
                value: val,
                min: 0,
                max: maxMs.toDouble(),
                onChanged: (v) =>
                    _player.seek(Duration(milliseconds: v.round())),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final populaires = [..._all]
      ..sort((a, b) => (_compteur[b.id.toString()] ?? 0)
          .compareTo(_compteur[a.id.toString()] ?? 0));
    final fav =
        _all.where((s) => _favoris.contains(s.id.toString())).toList();

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          elevation: 0,
          backgroundColor: Colors.transparent,
          title: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Focus Player',
                  style: TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 20)),
              Text('Créé par Tsiky · v1.1',
                  style: TextStyle(
                      fontSize: 12, color: Color(0xFFFFC1DD))),
            ],
          ),
          actions: [
            IconButton(
              tooltip: 'À propos du créateur',
              icon: const Icon(Icons.info_outline),
              onPressed: _aPropos,
            ),
          ],
          flexibleSpace: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFFD81B60), Color(0xFF6A1B9A)],
              ),
            ),
          ),
          bottom: const TabBar(
            indicatorColor: Colors.white,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            tabs: [
              Tab(icon: Icon(Icons.library_music_outlined), text: 'Toutes'),
              Tab(icon: Icon(Icons.favorite), text: 'Favoris'),
              Tab(icon: Icon(Icons.trending_up), text: 'Plus jouées'),
            ],
          ),
        ),
        body: TabBarView(children: [
          _liste(_all, 'Aucune musique trouvée\nsur ton téléphone',
              Icons.library_music_outlined),
          _liste(fav, 'Aucun favori pour l\'instant\nTouche ❤️ sur une chanson',
              Icons.favorite_border),
          _liste(populaires.take(20).toList(),
              'Les chansons les plus écoutées\napparaîtront ici',
              Icons.trending_up),
        ]),
        bottomNavigationBar: _lecteur(),
      ),
    );
  }
}
