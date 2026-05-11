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
  final ScrollController _mainListController = ScrollController();
  final ScrollController _quickPickController = ScrollController();
  
  bool _loading = true;
  bool _playing = false;
  bool _isShuffle = false;
  int _repeatMode = 0; // 0: no, 1: all, 2: one
  double _volume = 0.7;
  Duration _dur = Duration.zero;
  Duration _pos = Duration.zero;

  late AnimationController _rotationController;
  late AnimationController _spectrumController;
  List<double> _spectrumValues = List.generate(60, (index) => 2.0);

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

    _audioPlayer.onPlayerComplete.listen((event) {
      if (_repeatMode == 2) _play(_activeTrack!);
      else _playNext();
    });
    
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

  void _startSharedAutoScroll() {
    _autoScrollTimer = Timer.periodic(const Duration(milliseconds: 50), (timer) {
      if (_quickPickController.hasClients && !_isHoveringQuick) {
        double max = _quickPickController.position.maxScrollExtent;
        double curr = _quickPickController.offset;
        if (max > 0) {
          if (_quickForward) { if (curr < max) _quickPickController.jumpTo(curr + 0.5); else _quickForward = false; }
          else { if (curr > 0) _quickPickController.jumpTo(curr - 0.5); else _quickForward = true; }
        }
      }
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
    await _audioPlayer.setVolume(_volume);
    await _audioPlayer.play(UrlSource(t['url']!));
  }

  void _playNext() {
    if (_filteredTracks.isEmpty) return;
    int currentIndex = _filteredTracks.indexOf(_activeTrack!);
    int nextIndex;
    if (_isShuffle) {
      nextIndex = math.Random().nextInt(_filteredTracks.length);
    } else {
      nextIndex = (currentIndex + 1);
      if (nextIndex >= _filteredTracks.length) {
        if (_repeatMode == 1) nextIndex = 0; else return;
      }
    }
    _play(_filteredTracks[nextIndex]);
  }

  void _playPrev() {
    if (_filteredTracks.isEmpty) return;
    int index = (_filteredTracks.indexOf(_activeTrack!) - 1);
    if (index < 0) index = _filteredTracks.length - 1;
    _play(_filteredTracks[index]);
  }

  String _formatDuration(Duration d) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    return "${twoDigits(d.inMinutes.remainder(60))}:${twoDigits(d.inSeconds.remainder(60))}";
  }

  // --- UI Складові ---

  Widget _buildTrackCard(Map<String, String> track) {
    bool isActive = _activeTrack == track;
    return GestureDetector(
      onTap: () => _play(track),
      child: Container(
        width: 170, margin: const EdgeInsets.only(right: 25),
        child: Column(children: [
            Container(height: 170, decoration: BoxDecoration(
                color: isActive ? Colors.orangeAccent.withOpacity(0.1) : Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(20),
                border: isActive ? Border.all(color: Colors.orangeAccent, width: 2) : null,
              ),
              child: Center(child: Icon(isActive ? Icons.graphic_eq : Icons.album, color: Colors.orangeAccent, size: 70)),
            ),
            const SizedBox(height: 12),
            Text(track['title']!, style: TextStyle(color: isActive ? Colors.orangeAccent : Colors.white, fontSize: 13), textAlign: TextAlign.center, maxLines: 2),
        ]),
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
            unselectedIconTheme: const IconThemeData(color: Colors.grey),
            selectedIconTheme: const IconThemeData(color: Colors.orangeAccent),
            destinations: const [
              NavigationRailDestination(icon: Icon(Icons.home), label: Text("Головна")),
              NavigationRailDestination(icon: Icon(Icons.library_music), label: Text("Плейлист")),
            ],
            selectedIndex: 0,
          ),
          Expanded(child: _loading 
            ? const Center(child: CircularProgressIndicator(color: Colors.orangeAccent))
            : SingleChildScrollView(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    _buildSearchBar(),
                    _buildSectionHeader("Швидкий вибір"),
                    _buildHorizontalList(_quickPickController, _tracks.take(10).toList(), (h) => _isHoveringQuick = h),
                    const SizedBox(height: 20),
                    _buildSectionHeader("Всі треки"),
                    _buildHorizontalList(_mainListController, _filteredTracks, (h) => _isHoveringMain = h),
                    const SizedBox(height: 150),
                ]),
              )
          ),
        ]),
        bottomNavigationBar: _activeTrack == null ? null : _buildMiniPlayer(),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 10),
      child: Text(title, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildHorizontalList(ScrollController controller, List<Map<String, String>> list, Function(bool) onHover) {
    return MouseRegion(
      onEnter: (_) => onHover(true), onExit: (_) => onHover(false),
      child: SizedBox(height: 240, child: ListView.builder(
          controller: controller, scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 25),
          itemCount: list.length, itemBuilder: (context, i) => _buildTrackCard(list[i]),
      )),
    );
  }

  Widget _buildSearchBar() {
    return Padding(padding: const EdgeInsets.all(25), child: TextField(
        controller: _searchController,
        onChanged: (v) => setState(() => _filteredTracks = _tracks.where((t) => t['title']!.toLowerCase().contains(v.toLowerCase())).toList()),
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          hintText: "Пошук треку...", prefixIcon: const Icon(Icons.search, color: Colors.orangeAccent),
          filled: true, fillColor: Colors.white.withOpacity(0.05),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide.none),
        ),
      ),
    );
  }

  // --- Плеєри ---

  Widget _buildMiniPlayer() {
    return GestureDetector(
      onTap: _openFullPlayer,
      child: Container(
        height: 110, color: const Color(0xFF121212),
        child: Column(children: [
          LinearProgressIndicator(
            value: _pos.inSeconds / (_dur.inSeconds > 0 ? _dur.inSeconds : 1),
            backgroundColor: Colors.white10, valueColor: const AlwaysStoppedAnimation(Colors.orangeAccent), minHeight: 2,
          ),
          Expanded(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 20), child: Row(children: [
                _buildMiniVisualizer(),
                const SizedBox(width: 15),
                Expanded(child: Text(_activeTrack!['title']!, style: const TextStyle(color: Colors.white, fontSize: 13), overflow: TextOverflow.ellipsis)),
                IconButton(icon: Icon(_isShuffle ? Icons.shuffle : Icons.shuffle, color: _isShuffle ? Colors.orangeAccent : Colors.white54, size: 18), onPressed: () => setState(() => _isShuffle = !_isShuffle)),
                IconButton(icon: const Icon(Icons.skip_previous, color: Colors.white), onPressed: _playPrev),
                IconButton(icon: Icon(_playing ? Icons.pause_circle_filled : Icons.play_circle_filled, color: Colors.orangeAccent, size: 40), onPressed: () => _playing ? _audioPlayer.pause() : _audioPlayer.resume()),
                IconButton(icon: const Icon(Icons.skip_next, color: Colors.white), onPressed: _playNext),
                const SizedBox(width: 10),
                const Icon(Icons.volume_up, color: Colors.white54, size: 18),
                SizedBox(width: 80, child: Slider(value: _volume, onChanged: (v) { setState(() => _volume = v); _audioPlayer.setVolume(v); })),
          ]))),
        ]),
      ),
    );
  }

  Widget _buildMiniVisualizer() {
    return Stack(alignment: Alignment.center, children: [
      RotationTransition(turns: _rotationController, child: CustomPaint(size: const Size(55, 55), painter: SpectrumPainter(values: _spectrumValues, isOuter: false))),
      const Icon(Icons.bolt, size: 14, color: Colors.orangeAccent),
    ]);
  }

  void _openFullPlayer() {
    showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setModalState) {
        // Оновлення стану всередині модального вікна
        _audioPlayer.onPositionChanged.listen((p) => setModalState(() {})); 

        return Container(
          height: MediaQuery.of(ctx).size.height,
          width: MediaQuery.of(ctx).size.width,
          decoration: const BoxDecoration(
            gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFF1A1A1A), Colors.black])
          ),
          child: Scaffold(
            backgroundColor: Colors.transparent,
            appBar: AppBar(
              backgroundColor: Colors.transparent, elevation: 0,
              leading: IconButton(icon: const Icon(Icons.keyboard_arrow_down, size: 35), onPressed: () => Navigator.pop(ctx)),
              title: const Text("ЗАРАЗ ГРАЄ", style: TextStyle(fontSize: 12, letterSpacing: 2)), centerTitle: true,
            ),
            body: Column(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
              // Центральна візуалізація
              Center(
                child: Stack(alignment: Alignment.center, children: [
                  RotationTransition(turns: _rotationController, child: CustomPaint(size: const Size(320, 320), painter: SpectrumPainter(values: _spectrumValues, isOuter: true))),
                  Container(
                    width: 180, height: 180,
                    decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.black, border: Border.all(color: Colors.orangeAccent.withOpacity(0.2), width: 5)),
                    child: const Icon(Icons.music_note, size: 80, color: Colors.orangeAccent),
                  ),
                ]),
              ),

              // Назва та опис
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: Column(children: [
                  Text(_activeTrack!['title']!, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
                  const SizedBox(height: 8),
                  Text("Valerii Visual Music Collection", style: TextStyle(color: Colors.orangeAccent.withOpacity(0.7), fontSize: 16)),
                ]),
              ),

              // Таймлайн
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 30),
                child: Column(children: [
                  SliderTheme(
                    data: SliderTheme.of(context).copyWith(trackHeight: 4, thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8)),
                    child: Slider(
                      activeColor: Colors.orangeAccent, inactiveColor: Colors.white10,
                      max: _dur.inSeconds.toDouble() > 0 ? _dur.inSeconds.toDouble() : 1.0,
                      value: _pos.inSeconds.toDouble().clamp(0.0, _dur.inSeconds.toDouble()),
                      onChanged: (v) => _audioPlayer.seek(Duration(seconds: v.toInt())),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                      Text(_formatDuration(_pos), style: const TextStyle(color: Colors.white54)),
                      Text(_formatDuration(_dur), style: const TextStyle(color: Colors.white54)),
                    ]),
                  ),
                ]),
              ),

              // Кнопки керування
              Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
                IconButton(icon: Icon(Icons.shuffle, color: _isShuffle ? Colors.orangeAccent : Colors.white54), onPressed: () { setModalState(() => _isShuffle = !_isShuffle); setState((){}); }),
                IconButton(icon: const Icon(Icons.skip_previous, size: 45, color: Colors.white), onPressed: () { _playPrev(); setModalState(() {}); }),
                IconButton(icon: Icon(_playing ? Icons.pause_circle_filled : Icons.play_circle_filled, size: 85, color: Colors.orangeAccent), onPressed: () { _playing ? _audioPlayer.pause() : _audioPlayer.resume(); setModalState(() {}); }),
                IconButton(icon: const Icon(Icons.skip_next, size: 45, color: Colors.white), onPressed: () { _playNext(); setModalState(() {}); }),
                IconButton(
                  icon: Icon(_repeatMode == 2 ? Icons.repeat_one : Icons.repeat, color: _repeatMode > 0 ? Colors.orangeAccent : Colors.white54), 
                  onPressed: () { setModalState(() => _repeatMode = (_repeatMode + 1) % 3); setState((){}); }
                ),
              ]),

              // Гучність
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 50),
                child: Row(children: [
                  const Icon(Icons.volume_down, color: Colors.white54),
                  Expanded(child: Slider(value: _volume, activeColor: Colors.orangeAccent, onChanged: (v) { setModalState(() => _volume = v); _audioPlayer.setVolume(v); setState((){}); })),
                  const Icon(Icons.volume_up, color: Colors.white54),
                ]),
              ),
              const SizedBox(height: 20),
            ]),
          ),
        );
      }),
    );
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
    final paint = Paint()..color = Colors.orangeAccent.withOpacity(0.8)..strokeWidth = 3..strokeCap = StrokeCap.round;
    final center = Offset(size.width / 2, size.height / 2);
    final radius = isOuter ? size.width / 3 : size.width / 2.5;
    for (int i = 0; i < values.length; i++) {
      double angle = (i * 360 / values.length) * (math.pi / 180);
      Offset start = Offset(center.dx + radius * math.cos(angle), center.dy + radius * math.sin(angle));
      double barHeight = isOuter ? values[i] * 1.2 : -values[i] * 0.5;
      Offset end = Offset(center.dx + (radius + barHeight) * math.cos(angle), center.dy + (radius + barHeight) * math.sin(angle));
      canvas.drawLine(start, end, paint);
    }
  }
  @override
  bool shouldRepaint(SpectrumPainter oldDelegate) => true;
}
