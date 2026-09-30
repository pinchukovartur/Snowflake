import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_state.dart';
import 'screens/cut_screen.dart';
import 'screens/gallery_screen.dart';
import 'screens/home_screen.dart';
import 'screens/levels_screen.dart';
import 'screens/reveal_screen.dart';
import 'snowflake/geometry.dart';
import 'theme/tokens.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: Colors.transparent,
    systemNavigationBarIconBrightness: Brightness.light,
  ));
  runApp(const SnowflakeApp());
}

class SnowflakeApp extends StatelessWidget {
  const SnowflakeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Снежинки',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: C.night800, brightness: Brightness.dark),
        scaffoldBackgroundColor: C.night800,
      ),
      home: const GameShell(),
    );
  }
}

enum Screen { home, levels, cut, reveal, gallery }

/// Router + game state, mirrors ui_kits/app/App.jsx.
class GameShell extends StatefulWidget {
  const GameShell({super.key});

  @override
  State<GameShell> createState() => _GameShellState();
}

class _GameShellState extends State<GameShell> {
  final _game = GameState();
  final _cutKey = GlobalKey<CutScreenState>();
  Screen _screen = Screen.home;
  int _level = 4;
  int _runKey = 0;
  List<Cut> _cuts = const [];
  Paper _paper = const Paper();

  void _go(Screen s) => setState(() => _screen = s);

  void _play(int n) => setState(() {
        _level = n;
        _runKey++;
        _screen = Screen.cut;
      });

  void _back() {
    switch (_screen) {
      case Screen.home:
        SystemNavigator.pop();
      case Screen.cut:
        _cutKey.currentState?.pause();
      case Screen.reveal:
      case Screen.levels:
      case Screen.gallery:
        _go(_screen == Screen.reveal ? Screen.levels : Screen.home);
    }
  }

  @override
  void dispose() {
    _game.dispose();
    super.dispose();
  }

  Widget _view() {
    switch (_screen) {
      case Screen.home:
        return HomeScreen(game: _game, onPlay: () => _go(Screen.levels), onGallery: () => _go(Screen.gallery));
      case Screen.levels:
        return LevelsScreen(game: _game, onBack: () => _go(Screen.home), onPlay: _play);
      case Screen.cut:
        return CutScreen(
          key: _cutKey,
          game: _game,
          level: _level,
          onLevels: () => _go(Screen.levels),
          onUnfold: (cuts, paper) => setState(() {
            _cuts = cuts;
            _paper = paper;
            _game.complete(_level, RevealScreen.starsFor(cuts.length));
            _screen = Screen.reveal;
          }),
        );
      case Screen.reveal:
        return RevealScreen(
          level: _level,
          cuts: _cuts,
          paper: _paper,
          onNext: () => _go(Screen.levels),
          onReplay: () => _play(_level),
          onSave: () {
            _game.save(SavedFlake(name: 'Уровень $_level', cuts: _cuts, color: _paper.color, pattern: _paper.pattern, fav: true));
            _go(Screen.gallery);
          },
        );
      case Screen.gallery:
        return GalleryScreen(game: _game, onBack: () => _go(Screen.home));
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _back();
      },
      child: Scaffold(
        body: ListenableBuilder(
          listenable: _game,
          builder: (_, _) => AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            child: KeyedSubtree(key: ValueKey('$_screen-$_runKey'), child: _view()),
          ),
        ),
      ),
    );
  }
}
