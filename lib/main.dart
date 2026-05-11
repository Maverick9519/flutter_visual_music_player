import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:math' as math;
import 'dart:async';
import 'package:flutter/gestures.dart';

void main() => runApp(const MaterialApp(
  debugShowCheckedModeBanner: false, 
  home: ValeriiVisualMusic()
));

class MyCustomScrollBehavior extends MaterialScrollBehavior {
  @override
  Set<PointerDeviceKind> get dragDevices => {
    PointerDeviceKind.touch,
    PointerDeviceKind.mouse,
  };
}

class ValeriiVisualMusic extends StatefulWidget {
  const ValeriiVisualMusic({super.key});
  @override
  State<ValeriiVisualMusic> createState() => _ValeriiVisualMusicState();
}

class _ValeriiVisualMusicState extends State<ValeriiVisualMusic> with TickerProviderStateMixin {
  final AudioPlayer _audioPlayer = AudioPlayer();
  final String _id = "valerii_music_collection_2026";
  
  List<Map<String, String>> _tracks = [];
  List<Map<String, String>> _filteredTracks = [];
  Map<String, String>? _activeTrack;
  
  final TextEditingController _searchController = TextEditingController();
  
  // Контролери для обох стрічок
  final ScrollController _mainListController = ScrollController();
  final ScrollController _quickPickController = ScrollController();
  
  bool _loading = true;
  bool _playing = false;
  bool _isShuffle = false;
  int _repeatMode = 0; 
  double _volume = 0.7;
  Duration _dur = Duration.zero;
  Duration _pos = Duration.zero;

  late AnimationController _rotationController;
  late AnimationController _spectrumController;
  List<double> _spectrumValues = List.generate(60, (index) => 2.0);

  // Параметри автопрокрутки
  Timer? _autoScrollTimer;
  bool _mainForward = true;
  bool _quickForward = true;
  bool _isHoveringMain = false;
  bool _isHoveringQuick = false;

  @override
  void initState() {
    super.initState();
    _load();
    _rotationController = AnimationController(vsync: this, duration: const Duration(seconds: 12));
    
    _spectrumController = AnimationController(vsync: this, duration: const Duration(milliseconds: 50))..addListener(() {
      if (_playing) {
        setState(() {
          _spectrumValues = List.generate(60, (i) => 2 + math.Random().nextDouble() * 35);
        });
      }
    });

    _audioPlayer.onDurationChanged.listen((d) => setState(() => _dur = d));
    _audioPlayer.onPositionChanged.listen((p) => setState(() => _pos = p));
    _audioPlayer.onPlayerStateChanged.listen((s) {
      if (mounted) {
        setState(() => _playing = s == PlayerState.playing);
        _playing ? _rotationController.repeat() : _rotationController.stop();
        _playing ? _spectrumController.repeat() : _spectrumController.stop();
      }
    });
    _audioPlayer.onPlayerComplete.listen((event) => _playNext());
    
    _startSharedAutoScroll();
  }

  Future<void> _load() async {
    try {
      final res = await http.get(Uri.parse('https://archive.org/metadata/$_id'));
      final data = json.decode(res.body);
      final List files = data['files'];
      List<Map<String, String>> temp = [];
      for (var f in files) {
        if (f['name'].toString().endsWith('.mp3')) {
          temp.add({
            "title": f['title'] ?? f['name'].toString().replaceAll('.mp3', ''),
            "url": "https://archive.org/download/$_id/${f['name']}"
          });
        }
      }
      setState(() { _tracks = temp; _filteredTracks = temp; _loading = false; });
    } catch (e) { setState(() => _loading = false); }
  }

  // Логіка плавного руху для обох стрічок
  void _startSharedAutoScroll() {
    _autoScrollTimer = Timer.periodic(const Duration(milliseconds: 50), (timer) {
      // Рух для швидкого вибору
      if (_quickPickController.hasClients && !_isHoveringQuick) {
        double max = _quickPickController.position.maxScrollExtent;
        double curr = _quickPickController.offset;
        if (max > 0) {
          if (_quickForward) { if (curr < max) _quickPickController.jumpTo(curr + 0.5); else _quickForward = false; }
          else { if (curr > 0) _quickPickController.jumpTo(curr - 0.5); else _quickForward = true; }
        }
      }
      // Рух для основного списку
      if (_mainListController.hasClients && !_isHoveringMain) {
        double max = _mainListController.position.maxScrollExtent;
        double curr = _mainListController.offset;
        if (max > 0) {
          if (_mainForward) { if (curr < max) _mainListController.jumpTo(curr + 0.5); else _mainForward = false; }
          else { if (curr > 0) _mainListController.jumpTo(curr - 0.5); else _mainForward = true; }
        }
      }
    });
  }

  void _play(Map<String, String> t) async {
    setState(() => _activeTrack = t);
    await _audioPlayer.stop();
    await _audioPlayer.play(UrlSource(t['url']!));
  }

  void _playNext() {
    if (_filteredTracks.isEmpty) return;
    int index = _isShuffle ? math.Random().nextInt(_filteredTracks.length) : (_filteredTracks.indexOf(_activeTrack!) + 1) % _filteredTracks.length;
    _play(_filteredTracks[index]);
  }

  void _playPrev() {
    if (_filteredTracks.isEmpty) return;
    int index = (_filteredTracks.indexOf(_activeTrack!) - 1);
    if (index < 0) index = _filteredTracks.length - 1;
    _play(_filteredTracks[index]);
  }

  Widget _buildTrackCard(Map<String, String> track) {
    bool isActive = _activeTrack == track;
    return GestureDetector(
      onTap: () => _play(track),
      child: Container(
        width: 170, 
        margin: const EdgeInsets.only(right: 25),
        child: Column(
          children: [
            Container(
              height: 170, 
              decoration: BoxDecoration(
                color: isActive ? Colors.orangeAccent.withOpacity(0.1) : Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(20),
                border: isActive ? Border.all(color: Colors.orangeAccent, width: 2) : null,
              ),
              child: Center(
                child: Icon(isActive ? Icons.graphic_eq : Icons.album, color: Colors.orangeAccent, size: 70)
              ),
            ),
            const SizedBox(height: 12),
            Text(track['title']!, style: TextStyle(color: isActive ? Colors.orangeAccent : Colors.white, fontSize: 13, fontWeight: isActive ? FontWeight.bold : FontWeight.normal), textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ScrollConfiguration(
      behavior: MyCustomScrollBehavior(),
      child: Scaffold(
        backgroundColor: const Color(0xFF0A0A0A),
        body: Row(children: [
          NavigationRail(
            backgroundColor: const Color(0xFF121212),
            destinations: const [
              NavigationRailDestination(icon: Icon(Icons.home), label: Text("Головна")),
              NavigationRailDestination(icon: Icon(Icons.library_music), label: Text("Плейлист")),
            ],
            selectedIndex: 0,
          ),
          Expanded(child: _loading 
            ? const Center(child: CircularProgressIndicator(color: Colors.orangeAccent))
            : SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSearchBar(),
                    
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 25, vertical: 10),
                      child: Text("Швидкий вибір", style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                    ),
                    MouseRegion(
                      onEnter: (_) => _isHoveringQuick = true,
                      onExit: (_) => _isHoveringQuick = false,
                      child: SizedBox(
                        height: 240,
                        child: ListView.builder(
                          controller: _quickPickController,
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 25),
                          itemCount: _tracks.length > 10 ? 10 : _tracks.length,
                          itemBuilder: (context, i) => _buildTrackCard(_tracks[i]),
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 25, vertical: 10),
                      child: Text("Всі треки", style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                    ),
                    MouseRegion(
                      onEnter: (_) => _isHoveringMain = true,
                      onExit: (_) => _isHoveringMain = false,
                      child: SizedBox(
                        height: 240,
                        child: ListView.builder(
                          controller: _mainListController,
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 25),
                          itemCount: _filteredTracks.length,
                          itemBuilder: (context, i) => _buildTrackCard(_filteredTracks[i]),
                        ),
                      ),
                    ),
                    const SizedBox(height: 120),
                  ],
                ),
              )
          ),
        ]),
        bottomNavigationBar: _activeTrack == null ? null : _buildMiniPlayer(),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.all(25),
      child: TextField(
        controller: _searchController,
        onChanged: (v) => setState(() => _filteredTracks = _tracks.where((t) => t['title']!.toLowerCase().contains(v.toLowerCase())).toList()),
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          hintText: "Пошук треку...",
          prefixIcon: const Icon(Icons.search, color: Colors.orangeAccent),
          filled: true, fillColor: Colors.white.withOpacity(0.05),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide.none),
        ),
      ),
    );
  }

  // Методи плеєра та візуалізації залишаються такими ж, як у попередній стабільній версії
  Widget _buildMiniVisualizer() {
    return Stack(alignment: Alignment.center, children: [
      RotationTransition(turns: _rotationController, child: CustomPaint(size: const Size(65, 65), painter: SpectrumPainter(values: _spectrumValues, isOuter: false))),
      const Icon(Icons.bolt, size: 18, color: Colors.orangeAccent),
    ]);
  }

  Widget _buildMiniPlayer() {
    return Container(
      height: 130, color: const Color(0xFF121212),
      child: Column(children: [
        Slider(activeColor: Colors.orangeAccent, max: _dur.inSeconds.toDouble() > 0 ? _dur.inSeconds.toDouble() : 1.0, value: _pos.inSeconds.toDouble().clamp(0.0, _dur.inSeconds.toDouble() > 0 ? _dur.inSeconds.toDouble() : 1.0), onChanged: (v) => _audioPlayer.seek(Duration(seconds: v.toInt()))),
        Expanded(child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 15),
          child: Row(children: [
            GestureDetector(onTap: _openFullPlayer, child: _buildMiniVisualizer()),
            const SizedBox(width: 15),
            Expanded(child: Text(_activeTrack!['title']!, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13), overflow: TextOverflow.ellipsis)),
            IconButton(icon: const Icon(Icons.skip_previous, color: Colors.white), onPressed: _playPrev),
            IconButton(icon: Icon(_playing ? Icons.pause_circle_filled : Icons.play_circle_filled, color: Colors.orangeAccent, size: 45), onPressed: () => _playing ? _audioPlayer.pause() : _audioPlayer.resume()),
            IconButton(icon: const Icon(Icons.skip_next, color: Colors.white), onPressed: _playNext),
          ]),
        )),
      ]),
    );
  }

  void _openFullPlayer() {
    showModalBottomSheet(context: context, isScrollControlled: true, backgroundColor: Colors.transparent, builder: (ctx) => StatefulBuilder(builder: (ctx, setST) {
      return Container(
        height: MediaQuery.of(ctx).size.height,
        decoration: const BoxDecoration(color: Colors.black),
        child: Column(children: [
          const SizedBox(height: 50),
          IconButton(icon: const Icon(Icons.keyboard_arrow_down, color: Colors.white, size: 40), onPressed: () => Navigator.pop(ctx)),
          const Spacer(), 
          Stack(alignment: Alignment.center, children: [
            RotationTransition(turns: _rotationController, child: CustomPaint(size: const Size(300, 300), painter: SpectrumPainter(values: _spectrumValues, isOuter: true))),
            const Icon(Icons.music_note, size: 80, color: Colors.orangeAccent),
          ]),
          const Spacer(),
          Padding(padding: const EdgeInsets.symmetric(horizontal: 40), child: Text(_activeTrack!['title']!, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold), textAlign: TextAlign.center)),
          const SizedBox(height: 60),
        ]),
      );
    }));
  }

  @override
  void dispose() { _autoScrollTimer?.cancel(); _rotationController.dispose(); _spectrumController.dispose(); _audioPlayer.dispose(); super.dispose(); }
}

class SpectrumPainter extends CustomPainter {
  final List<double> values;
  final bool isOuter;
  SpectrumPainter({required this.values, required this.isOuter});
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.orangeAccent.withOpacity(0.8)..strokeWidth = 2.5..strokeCap = StrokeCap.round;
    final center = Offset(size.width / 2, size.height / 2);
    final radius = isOuter ? size.width / 4 : size.width / 2.5;
    for (int i = 0; i < values.length; i++) {
      double angle = (i * 360 / values.length) * (math.pi / 180);
      Offset start = Offset(center.dx + radius * math.cos(angle), center.dy + radius * math.sin(angle));
      double barHeight = isOuter ? values[i] : -values[i] * 0.5;
      Offset end = Offset(center.dx + (radius + barHeight) * math.cos(angle), center.dy + (radius + barHeight) * math.sin(angle));
      canvas.drawLine(start, end, paint);
    }
  }
  @override
  bool shouldRepaint(SpectrumPainter oldDelegate) => true;
}
