import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  JustAudioBackground.init(
    androidNotificationChannelId: 'com.example.focus_player.focus_tmp.music',
    androidNotificationOngoing: true,
  );
  runApp(const FocusPlayer());
}

const Color rose = Color(0xFFFF4081);
const Color violet = Color(0xFF9C27B0);
const Color carte = Color(0xFF1A1A24);
const String auteur = 'NAMBININTSOA Tsiky Fanantenana';

const List<Color> palette = [
  Color(0xFFFF4081),
  Color(0xFF9C27B0),
  Color(0xFF2979FF),
  Color(0xFFFF6D00),
  Color(0xFF00C853),
  Color(0xFF00BCD4),
];

class FocusPlayer extends StatefulWidget {
  const FocusPlayer({super.key});
  @override
  State<FocusPlayer> createState() => _FocusPlayerState();
}

class _FocusPlayerState extends State<FocusPlayer> {
  Color _accent = rose;

  @override
  void initState() {
    super.initState();
    _loadAccent();
  }

  Future<void> _loadAccent() async {
    final p = await SharedPreferences.getInstance();
    if (mounted) setState(() => _accent = Color(p.getInt('accent') ?? rose.value));
  }

  void changerAccent(Color c) {
    setState(() => _accent = c);
    SharedPreferences.getInstance().then((p) => p.setInt('accent', c.value));
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Focus Player',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorSchemeSeed: _accent,
        scaffoldBackgroundColor: const Color(0xFF101018),
      ),
      home: HomePage(accent: _accent, onAccent: changerAccent),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key, required this.accent, required this.onAccent});
  final Color accent;
  final ValueChanged<Color> onAccent;
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final OnAudioQuery _audioQuery = OnAudioQuery();
  final AudioPlayer _player = AudioPlayer();
  SharedPreferences? _prefs;
  List<SongModel> _all = [];
  Set<String> _favoris = {};
  Map<String, int> _compteur = {};
  SongModel? _enCours;
  bool _chargement = true;
  bool _autoSuivant = true;
  bool _melanger = false;
  bool _notifActive = true;
  String _repeat = 'off';
  Duration _pos = Duration.zero;
  Duration _dur = Duration.zero;
  StreamSubscription? _sPos;
  StreamSubscription? _sDur;
  StreamSubscription? _sDone;

  @override
  void initState() {
    super.initState();
    _sPos = _player.positionStream.listen((d) {
      if (mounted) setState(() => _pos = d);
    });
    _sDur = _player.durationStream.listen((d) {
      if (mounted) setState(() => _dur = d ?? Duration.zero);
    });
    _sDone = _player.processingStateStream.listen((st) {
      if (st == ProcessingState.completed) _aLaFin();
    });
    _initialiser();
  }

  @override
  void dispose() {
    _sPos?.cancel();
    _sDur?.cancel();
    _sDone?.cancel();
    _player.dispose();
    super.dispose();
  }

  Future<void> _initialiser() async {
    await [Permission.audio, Permission.storage].request();
    await Permission.notification.request();
    final p = await SharedPreferences.getInstance();
    _prefs = p;
    _favoris = (p.getStringList('favoris') ?? []).toSet();
    _compteur = Map<String, int>.from(jsonDecode(p.getString('compteur') ?? '{}'));
    _autoSuivant = p.getBool('autoSuivant') ?? true;
    _melanger = p.getBool('melanger') ?? false;
    _notifActive = p.getBool('notif') ?? true;
    _repeat = p.getString('repeat') ?? 'off';
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

  int get _idx {
    if (_enCours == null) return -1;
    return _all.indexWhere((s) => s.id == _enCours!.id);
  }

  Future<void> _jouer(SongModel s) async {
    setState(() => _enCours = s);
    try {
      await _player.setFilePath(s.data);
      _player.play();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Text('Impossible de lire ce fichier'),
          backgroundColor: widget.accent,
          behavior: SnackBarBehavior.floating,
        ));
      }
      return;
    }
    _compteur[s.id.toString()] = (_compteur[s.id.toString()] ?? 0) + 1;
    await _prefs?.setString('compteur', jsonEncode(_compteur));
    if (mounted) setState(() {});
  }

  void _suivant() {
    if (_all.isEmpty) return;
    int n;
    if (_melanger && _all.length > 1) {
      n = Random().nextInt(_all.length);
      if (n == _idx) n = (n + 1) % _all.length;
    } else {
      n = (_idx + 1) % _all.length;
    }
    _jouer(_all[n]);
  }

  void _precedent() {
    if (_all.isEmpty) return;
    int n = _idx - 1;
    if (n < 0) n = _all.length - 1;
    _jouer(_all[n]);
  }

  void _aLaFin() {
    if (_repeat == 'one') {
      _player.seek(Duration.zero);
      _player.play();
      return;
    }
    if (!_autoSuivant) return;
    _suivant();
  }

  Future<void> _basculerFavori(SongModel s) async {
    final id = s.id.toString();
    _favoris.contains(id) ? _favoris.remove(id) : _favoris.add(id);
    await _prefs?.setStringList('favoris', _favoris.toList());
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

  void _setAuto(bool v) {
    setState(() => _autoSuivant = v);
    _prefs?.setBool('autoSuivant', v);
  }

  void _setMelanger(bool v) {
    setState(() => _melanger = v);
    _prefs?.setBool('melanger', v);
  }

  void _setNotif(bool v) {
    setState(() => _notifActive = v);
    _prefs?.setBool('notif', v);
    if (v) Permission.notification.request();
  }

  void _setRepeat(String v) {
    setState(() => _repeat = v);
    _prefs?.setString('repeat', v);
  }

  Future<void> _effacerFavoris() async {
    setState(() => _favoris = {});
    await _prefs?.setStringList('favoris', []);
  }

  Future<void> _effacerCompteurs() async {
    setState(() => _compteur = {});
    await _prefs?.remove('compteur');
  }

  Future<void> _partager(SongModel s) async {
    await SharePlus.instance.share(ShareParams(
      files: [XFile(s.data)],
      text: '${s.title} — ${s.artist ?? "Inconnue"} · écouté sur Focus Player',
    ));
  }

  String _fmt(Duration d) {
    final m = d.inMinutes;
    final s = d.inSeconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  // ----------------------------------------------------------------- couverture
  Widget _pochette(SongModel s, double taille) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: SizedBox(
        width: taille,
        height: taille,
        child: QueryArtworkWidget(
          controller: _audioQuery,
          id: s.id,
          type: ArtworkType.AUDIO,
          artworkBorder: BorderRadius.circular(14),
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

  // ------------------------------------------------------------------- liste
  Widget _ligne(SongModel s) {
    final id = s.id.toString();
    final enCours = _enCours?.id == s.id;
    final ecoutes = _compteur[id] ?? 0;
    final favori = _favoris.contains(id);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Material(
        color: enCours ? const Color(0xFF2E1524) : carte,
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
                          color: enCours ? widget.accent : Colors.white,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${s.artist ?? "Inconnue"}  ·  $ecoutes écoute${ecoutes > 1 ? "s" : ""}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white54, fontSize: 12.5),
                      ),
                    ],
                  ),
                ),
                if (enCours)
                  Padding(
                    padding: const EdgeInsets.only(right: 2),
                    child: Icon(Icons.graphic_eq, color: widget.accent, size: 22),
                  ),
                Container(
                  decoration: favori
                      ? BoxDecoration(
                          color: widget.accent.withOpacity(.18),
                          shape: BoxShape.circle,
                        )
                      : null,
                  child: IconButton(
                    tooltip: favori ? 'Retirer des favoris' : 'Ajouter aux favoris',
                    icon: Icon(
                      favori ? Icons.favorite : Icons.favorite_border,
                      color: favori ? widget.accent : Colors.white54,
                      size: favori ? 26 : 24,
                    ),
                    onPressed: () => _basculerFavori(s),
                  ),
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
          Icon(Icons.verified, color: rose, size: 20),
          SizedBox(height: 6),
          Text('Créé par NAMBININTSOA Tsiky Fanantenana',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white70, fontSize: 13)),
          SizedBox(height: 2),
          Text('Tsikynambs · © 2026 — Tous droits réservés',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white38, fontSize: 11.5)),
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
            CircularProgressIndicator(color: rose),
            SizedBox(height: 16),
            Text('Lecture de ta musique…', style: TextStyle(color: Colors.white54)),
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

  // -------------------------------------------------------------- mini barre
  Widget? _barre() {
    if (_enCours == null) return null;
    final s = _enCours!;
    return GestureDetector(
      onVerticalDragEnd: (d) {
        if ((d.primaryVelocity ?? 0) < -300) _ouvrirLecteur();
      },
      child: Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => Navigator.push(
            context, MaterialPageRoute(builder: (_) => LecteurPage(h: this))),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [widget.accent, violet]),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: const EdgeInsets.fromLTRB(14, 8, 14, 10),
          child: SafeArea(
            top: false,
            child: Row(
              children: [
                _pochette(s, 44),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(s.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14)),
                      Text(s.artist ?? 'Inconnue',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              color: Colors.white70, fontSize: 12)),
                    ],
                  ),
                ),
                StreamBuilder<PlayerState>(
                  stream: _player.playerStateStream,
                  builder: (c, st) {
                    final enLecture = st.data?.playing ?? false;
                    return IconButton(
                      iconSize: 36,
                      icon: Icon(enLecture ? Icons.pause : Icons.play_arrow,
                          color: Colors.white),
                      onPressed: enLecture ? _player.pause : _player.play,
                    );
                  },
                ),
                const Icon(Icons.keyboard_arrow_up, color: Colors.white70),
                const SizedBox(width: 4),
              ],
            ),
          ),
        ),
      ),
      ),
    );
  }

  // ----------------------------------------------------------- plein écran
  void _ouvrirLecteur() {
    if (_enCours == null) return;
    Navigator.push(
        context, MaterialPageRoute(builder: (_) => LecteurPage(h: this)));
  }

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
          elevation: 0,
          backgroundColor: Colors.transparent,
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Focus Player',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
              Text('Créé par Tsiky · v1.2',
                  style: TextStyle(fontSize: 12, color: widget.accent.withOpacity(.9))),
            ],
          ),
          actions: [
            IconButton(
              tooltip: 'Paramètres',
              icon: const Icon(Icons.settings_outlined),
              onPressed: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => ParametresPage(h: this))),
            ),
            IconButton(
              tooltip: 'À propos du créateur',
              icon: const Icon(Icons.info_outline),
              onPressed: _aPropos,
            ),
          ],
          flexibleSpace: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [widget.accent, violet],
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
        bottomNavigationBar: _barre(),
      ),
    );
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
            const Text('version 1.2.0',
                style: TextStyle(color: Colors.white54, fontSize: 12)),
            const SizedBox(height: 16),
            Container(height: 1, color: Colors.white12),
            const SizedBox(height: 16),
            const Text('Créé et développé par',
                style: TextStyle(color: Colors.white54, fontSize: 13)),
            const SizedBox(height: 6),
            const Text(auteur,
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 15, color: Colors.white)),
            const SizedBox(height: 3),
            const Text('« Tsiky »', style: TextStyle(color: rose, fontSize: 13)),
            const SizedBox(height: 14),
            const Text('tsikynambs@gmail.com',
                style: TextStyle(color: Colors.white70, fontSize: 13)),
            const SizedBox(height: 3),
            const Text('038 97 91 195 · 033 07 71 835',
                style: TextStyle(color: Colors.white70, fontSize: 13)),
            const SizedBox(height: 16),
            const Text('© 2026 Tsiky — Tous droits réservés',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white38, fontSize: 12)),
          ],
        ),
        actions: [
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: widget.accent,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
            ),
            onPressed: () => Navigator.pop(c),
            child: const Text('Fermer'),
          ),
        ],
      ),
    );
  }
}

// ============================================================ PLEIN ÉCRAN
class LecteurPage extends StatefulWidget {
  const LecteurPage({super.key, required this.h});
  final _HomePageState h;
  @override
  State<LecteurPage> createState() => _LecteurPageState();
}

class _LecteurPageState extends State<LecteurPage> {
  _HomePageState get h => widget.h;
  final ScrollController _sc = ScrollController();
  double _dy = 0;
  bool _drag = false;
  bool _decided = false;
  bool _vert = false;

  @override
  void dispose() {
    _sc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = h._enCours;
    if (s == null) return const SizedBox.shrink();
    final accent = h.widget.accent;
    final favori = h._favoris.contains(s.id.toString());
    final ms = h._dur.inMilliseconds;
    final ps = h._pos.inMilliseconds;
    final maxMs = ms > 0 ? ms : (ps > 0 ? ps + 1000 : 1);
    final val = ps.clamp(0, maxMs).toDouble();

    return Scaffold(
      body: Listener(
        onPointerDown: (_) {
          _drag = true;
          _decided = false;
          _vert = false;
        },
        onPointerMove: (e) {
          if (!_drag) return;
          if (!_decided) {
            if (e.delta.dx.abs() + e.delta.dy.abs() < 2) return;
            _decided = true;
            _vert = e.delta.dy.abs() > e.delta.dx.abs() * 1.5;
          }
          if (!_vert) return;
          final enHaut = _dy > 0 || !_sc.hasClients || _sc.offset <= 0.5;
          if (!enHaut) return;
          final nd = _dy + e.delta.dy;
          setState(() => _dy = nd < 0 ? 0 : nd);
        },
        onPointerUp: (_) {
          _drag = false;
          _decided = false;
          if (!mounted) return;
          if (_dy > 140) {
            Navigator.pop(context);
          } else if (_dy > 0) {
            setState(() => _dy = 0);
          }
        },
        onPointerCancel: (_) {
          _drag = false;
          _decided = false;
          if (_dy > 0 && mounted) setState(() => _dy = 0);
        },
        child: Transform.translate(
          offset: Offset(0, _dy),
          child: Opacity(
            opacity: (1 - _dy / 600).clamp(0.0, 1.0).toDouble(),
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFF3A1226), Color(0xFF101018)],
                ),
              ),
              child: SafeArea(
          child: SingleChildScrollView(
            controller: _sc,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Column(
              children: [
                Row(
                  children: [
                    _rectBtn(
                      icon: Icons.keyboard_arrow_down,
                      label: 'Réduire',
                      onTap: () => Navigator.pop(context),
                      accent: accent,
                    ),
                    const Spacer(),
                    const Text('Lecture',
                        style: TextStyle(color: Colors.white54, fontSize: 13)),
                    const Spacer(),
                    const SizedBox(width: 96),
                  ],
                ),
                const SizedBox(height: 18),
                Center(
                  child: Stack(
                    children: [
                      SizedBox(
                        width: 280,
                        height: 280,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(28),
                          child: QueryArtworkWidget(
                            controller: h._audioQuery,
                            id: s.id,
                            type: ArtworkType.AUDIO,
                            artworkBorder: BorderRadius.circular(28),
                            artworkWidth: 280,
                            artworkHeight: 280,
                            nullArtworkWidget: Container(
                              decoration: const BoxDecoration(
                                gradient: LinearGradient(colors: [rose, violet]),
                              ),
                              child: const Icon(Icons.music_note,
                                  color: Colors.white, size: 110),
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        right: 14,
                        bottom: 14,
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.black54,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white24),
                          ),
                          child: const Icon(Icons.music_note,
                              color: Colors.white, size: 22),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 22),
                Text(s.title,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 21)),
                const SizedBox(height: 4),
                Text(s.artist ?? 'Inconnue',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white70, fontSize: 15)),
                const SizedBox(height: 10),
                IconButton(
                  tooltip: favori ? 'Retirer des favoris' : 'Ajouter aux favoris',
                  iconSize: 40,
                  icon: Icon(
                    favori ? Icons.favorite : Icons.favorite_border,
                    color: favori ? accent : Colors.white54,
                  ),
                  onPressed: () => h._basculerFavori(s),
                ),
                const SizedBox(height: 6),
                SliderTheme(
                  data: SliderThemeData(
                    trackHeight: 4,
                    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
                    overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
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
                        h._player.seek(Duration(milliseconds: v.round())),
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(h._fmt(h._pos),
                        style: const TextStyle(
                            color: Colors.white54, fontSize: 12)),
                    Text(h._fmt(h._dur),
                        style: const TextStyle(
                            color: Colors.white54, fontSize: 12)),
                  ],
                ),
                const SizedBox(height: 16),
                StreamBuilder<PlayerState>(
                  stream: h._player.playerStateStream,
                  builder: (c, st) {
                    final enLecture = st.data?.playing ?? false;
                    return Row(
                      children: [
                        Expanded(
                          child: _rectBtn(
                            icon: Icons.skip_previous,
                            label: 'Précédent',
                            onTap: h._precedent,
                            accent: accent,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          flex: 2,
                          child: _rectBtn(
                            icon: enLecture ? Icons.pause : Icons.play_arrow,
                            label: enLecture ? 'Pause' : 'Lecture',
                            onTap: enLecture ? h._player.pause : h._player.play,
                            accent: accent,
                            filled: true,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _rectBtn(
                            icon: Icons.skip_next,
                            label: 'Suivant',
                            onTap: h._suivant,
                            accent: accent,
                          ),
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _rectBtn(
                        icon: Icons.stop,
                        label: 'Quitter',
                        onTap: () {
                          h._arreter();
                          Navigator.pop(context);
                        },
                        accent: accent,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _rectBtn(
                        icon: h._melanger ? Icons.shuffle : Icons.shuffle,
                        label: 'Mélanger',
                        onTap: () => h._setMelanger(!h._melanger),
                        accent: accent,
                        actif: h._melanger,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _rectBtn(
                        icon: h._repeat == 'one'
                            ? Icons.repeat_one
                            : Icons.repeat,
                        label: h._repeat == 'off'
                            ? 'Répéter'
                            : (h._repeat == 'all' ? 'Tout' : 'Une'),
                        onTap: () => h._setRepeat(h._repeat == 'off'
                            ? 'all'
                            : (h._repeat == 'all' ? 'one' : 'off')),
                        accent: accent,
                        actif: h._repeat != 'off',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _rectBtn(
                        icon: Icons.share,
                        label: 'Partager le son',
                        onTap: () => h._partager(s),
                        accent: accent,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'Créé par $auteur',
                  style: const TextStyle(color: Colors.white38, fontSize: 11.5),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _rectBtn({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required Color accent,
    bool filled = false,
    bool actif = false,
  }) {
    return Material(
      color: filled
          ? accent
          : (actif ? accent.withOpacity(.2) : Colors.white10),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          height: 58,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
                color: filled
                    ? Colors.transparent
                    : (actif ? accent : Colors.white24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon,
                  size: 24,
                  color: filled
                      ? Colors.white
                      : (actif ? accent : Colors.white70)),
              const SizedBox(height: 2),
              Text(label,
                  style: TextStyle(
                      fontSize: 11,
                      color: filled
                          ? Colors.white
                          : (actif ? accent : Colors.white54))),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================== PARAMÈTRES
class ParametresPage extends StatefulWidget {
  const ParametresPage({super.key, required this.h});
  final _HomePageState h;
  @override
  State<ParametresPage> createState() => _ParametresPageState();
}

class _ParametresPageState extends State<ParametresPage> {
  _HomePageState get h => widget.h;

  @override
  Widget build(BuildContext context) {
    final accent = h.widget.accent;
    final ecoutesTotal =
        h._compteur.values.fold<int>(0, (a, b) => a + b);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Text('Paramètres',
            style: TextStyle(fontWeight: FontWeight.bold)),
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [accent, violet]),
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(14),
        children: [
          _section('Lecture', Icons.play_circle_outline, [
            SwitchListTile(
              value: h._autoSuivant,
              onChanged: h._setAuto,
              title: const Text('Lecture automatique suivante'),
              subtitle: const Text('Passer au morceau suivant à la fin'),
            ),
            SwitchListTile(
              value: h._melanger,
              onChanged: h._setMelanger,
              title: const Text('Mélanger les morceaux'),
              subtitle: const Text('Ordre aléatoire'),
            ),
            ListTile(
              leading: const Icon(Icons.repeat),
              title: const Text('Répétition'),
              trailing: Text(
                h._repeat == 'off'
                    ? 'Désactivée'
                    : (h._repeat == 'all' ? 'Toutes' : 'Un morceau'),
                style: TextStyle(color: accent),
              ),
              onTap: () => h._setRepeat(h._repeat == 'off'
                  ? 'all'
                  : (h._repeat == 'all' ? 'one' : 'off')),
            ),
            SwitchListTile(
              value: h._notifActive,
              onChanged: h._setNotif,
              title: const Text('Notification de lecture'),
              subtitle: const Text('Afficher la musique en cours dans la barre de notification'),
            ),
          ]),
          _section('Apparence', Icons.palette_outlined, [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Wrap(
                spacing: 14,
                runSpacing: 14,
                children: palette.map((c) {
                  final sel = c.value == accent.value;
                  return GestureDetector(
                    onTap: () {
                      h.widget.onAccent(c);
                      setState(() {});
                    },
                    child: Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: c,
                        shape: BoxShape.circle,
                        border: Border.all(
                            color: sel ? Colors.white : Colors.transparent,
                            width: 3),
                      ),
                      child: sel
                          ? const Icon(Icons.check, color: Colors.white, size: 24)
                          : null,
                    ),
                  );
                }).toList(),
              ),
            ),
          ]),
          _section('Statistiques', Icons.bar_chart, [
            ListTile(
              leading: const Icon(Icons.music_note),
              title: Text('${h._all.length} chansons sur le téléphone'),
            ),
            ListTile(
              leading: const Icon(Icons.favorite),
              title: Text('${h._favoris.length} favoris'),
            ),
            ListTile(
              leading: const Icon(Icons.play_arrow),
              title: Text('$ecoutesTotal écoutes cumulées'),
            ),
          ]),
          _section('Données', Icons.delete_outline, [
            ListTile(
              leading: const Icon(Icons.favorite_border),
              title: const Text('Effacer tous les favoris'),
              onTap: () => _confirmer(
                'Effacer les favoris ?',
                'Toutes tes chansons favorites seront retirées.',
                h._effacerFavoris,
              ),
            ),
            ListTile(
              leading: const Icon(Icons.refresh),
              title: const Text('Réinitialiser les compteurs d\'écoutes'),
              onTap: () => _confirmer(
                'Réinitialiser les écoutes ?',
                'Le classement « Plus jouées » repartira à zéro.',
                h._effacerCompteurs,
              ),
            ),
          ]),
          _section('À propos', Icons.verified, [
            const ListTile(
              leading: Icon(Icons.music_note),
              title: Text('Focus Player — version 1.2.0'),
              subtitle: Text('Lecteur de musique de concentration'),
            ),
            const ListTile(
              leading: Icon(Icons.person),
              title: Text(auteur),
              subtitle: Text('« Tsiky »\ntsikynambs@gmail.com\n038 97 91 195 · 033 07 71 835'),
            ),
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                '© 2026 Tsiky — Tous droits réservés',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white38, fontSize: 12),
              ),
            ),
          ]),
          const SizedBox(height: 30),
        ],
      ),
    );
  }

  Widget _section(String titre, IconData icone, List<Widget> enfants) {
    return Card(
      color: carte,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
            child: Row(children: [
              Icon(icone, size: 20, color: h.widget.accent),
              const SizedBox(width: 10),
              Text(titre,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 15)),
            ]),
          ),
          ...enfants,
        ],
      ),
    );
  }

  Future<void> _confirmer(String titre, String msg, Future<void> Function() action) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: carte,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(titre),
        content: Text(msg),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('Annuler')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: h.widget.accent),
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Confirmer'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await action();
      if (mounted) setState(() {});
    }
  }
}
