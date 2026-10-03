import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_state.dart';
import 'screens/cut_screen.dart';
import 'screens/gallery_screen.dart';
import 'screens/home_screen.dart';
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

enum Screen { home, cut, reveal, gallery }

/// Router + game state, mirrors ui_kits/app/App.jsx.
class GameShell extends StatefulWidget {
  const GameShell({super.key});

  @override
  State<GameShell> createState() => _GameShellState();
}

class _GameShellState extends State<GameShell> {
  final _game = GameState();
  Screen _screen = Screen.home;
  int _runKey = 0;
  var _session = CutSession();
  List<Cut> _cuts = const [];
  int _folds = 6;
  Paper _paper = const Paper();

  /// The revealed flake as saved to the collection, while it is there.
  SavedFlake? _savedFlake;

  void _go(Screen s) => setState(() => _screen = s);

  /// Opens the cut board with a fresh flake, folded like the last one.
  void _newFlake() => setState(() {
        _runKey++;
        _session = CutSession()..folds = _session.folds;
        _screen = Screen.cut;
      });

  void _back() {
    switch (_screen) {
      case Screen.home:
        SystemNavigator.pop();
      case Screen.reveal:
        _go(Screen.cut);
      case Screen.cut:
      case Screen.gallery:
        _go(Screen.home);
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
        return HomeScreen(
          game: _game,
          // Picks up the unfinished flake, if any: leaving for the home screen keeps it.
          onPlay: () => _go(Screen.cut),
          onGallery: () => _go(Screen.gallery),
        );
      case Screen.cut:
        return CutScreen(
          game: _game,
          session: _session,
          onHome: () => _go(Screen.home),
          onUnfold: (shape, folds, paper) => setState(() {
            _cuts = shape;
            _folds = folds;
            _paper = paper;
            _savedFlake = null;
            _screen = Screen.reveal;
          }),
        );
      case Screen.reveal:
        return RevealScreen(
          cuts: _cuts,
          folds: _folds,
          paper: _paper,
          saved: _savedFlake != null,
          onDone: _newFlake,
          onBack: () => _go(Screen.cut),
          // Stays on the card: the player may still go back and change the flake.
          onSave: () {
            final f = _savedFlake;
            if (f != null) {
              _game.remove(f);
              _savedFlake = null;
            } else {
              final n = _game.saved.where((f) => f.own).length + 1;
              _game.save(_savedFlake = SavedFlake(name: 'Снежинка $n', cuts: _cuts, folds: _folds, color: _paper.color, pattern: _paper.pattern, fav: true));
            }
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
