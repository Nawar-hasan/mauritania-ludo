import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import '../core/app_theme.dart';
import '../core/routes.dart';
import '../core/widgets.dart';
import '../core/localization.dart';

class OfflineModeScreen extends StatelessWidget {
  const OfflineModeScreen({super.key});
  @override
  Widget build(BuildContext context) => AppPage(
    title: 'Offline Play',
    child: Column(children: [
      const ScreenHeader(title: 'Play without internet', subtitle: 'Practice locally against computer players. Offline matches never use or change your wallet.', icon: Icons.offline_bolt_rounded),
      const SizedBox(height: 20),
      OptionTile(icon: Icons.person_rounded, title: 'Solo vs Computer', subtitle: 'You against one computer player • Classic rules', color: AppColors.gold, onTap: () => Navigator.pushNamed(context, Routes.localGame, arguments: {'players': 2})),
      OptionTile(icon: Icons.groups_rounded, title: 'Four-player Practice', subtitle: 'You against three computer players • No server required', color: AppColors.cyan, onTap: () => Navigator.pushNamed(context, Routes.localGame, arguments: {'players': 4})),
      const SizedBox(height: 12),
      const GradientPanel(child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Icon(Icons.info_outline_rounded, color: AppColors.green), SizedBox(width: 10), Expanded(child: Text('Offline results are for practice only. They do not affect cash balance, wagers, XP, levels, stages or online statistics.', style: TextStyle(color: AppColors.muted, height: 1.45)))])),
    ]),
  );
}

class LocalLudoGameScreen extends StatefulWidget {
  const LocalLudoGameScreen({super.key});
  @override
  State<LocalLudoGameScreen> createState() => _LocalLudoGameScreenState();
}

class _LocalLudoGameScreenState extends State<LocalLudoGameScreen> {
  final _random = Random();
  final _colors = const ['GREEN', 'YELLOW', 'BLUE', 'RED'];
  Timer? _botTimer;
  int _playerCount = 2;
  int _turn = 0;
  int? _dice;
  int _sixCount = 0;
  List<int> _legal = const [];
  List<_LocalPlayer> _players = const [];
  bool _ready = false;
  bool _finished = false;
  String? _winner;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_ready) return;
    final args = ((ModalRoute.of(context)?.settings.arguments as Map?) ?? const {}).cast<String, dynamic>();
    _playerCount = args['players'] == 4 ? 4 : 2;
    final selected = _playerCount == 2 ? ['GREEN', 'RED'] : _colors;
    _players = List.generate(_playerCount, (i) => _LocalPlayer(
      name: i == 0 ? 'You' : 'Computer $i',
      color: selected[i],
      human: i == 0,
      pieces: List.generate(4, (id) => _LocalPiece(id, -1)),
    ));
    _ready = true;
  }

  @override
  void dispose() { _botTimer?.cancel(); super.dispose(); }

  _LocalPlayer get _current => _players[_turn];

  void _roll() {
    if (_finished || _dice != null || !_current.human) return;
    _rollForCurrent();
  }

  void _rollForCurrent() {
    final value = _random.nextInt(6) + 1;
    setState(() {
      _dice = value;
      _sixCount = value == 6 ? _sixCount + 1 : 0;
      if (_sixCount >= 3) {
        _dice = null;
        _legal = const [];
        _advance();
        return;
      }
      _legal = _legalMoves(_current, value);
      if (_legal.isEmpty) {
        _dice = null;
        if (value != 6) _advance();
      }
    });
    _scheduleBot();
  }

  List<int> _legalMoves(_LocalPlayer player, int dice) {
    return player.pieces.where((piece) {
      if (piece.progress == 58) return false;
      if (piece.progress == -1) return dice == 6;
      return piece.progress + dice <= 58;
    }).map((p) => p.id).toList();
  }

  void _move(int pieceId) {
    if (_finished || _dice == null || !_legal.contains(pieceId)) return;
    final movingPlayer = _current;
    final piece = movingPlayer.pieces.firstWhere((p) => p.id == pieceId);
    final rolled = _dice!;
    final before = piece.progress;
    piece.progress = before == -1 ? 0 : before + rolled;
    final capture = _capture(movingPlayer, piece);
    final finishedPiece = piece.progress == 58;
    final allDone = movingPlayer.pieces.every((p) => p.progress == 58);
    setState(() {
      _dice = null;
      _legal = const [];
      if (allDone) {
        _finished = true;
        _winner = movingPlayer.name;
      } else {
        final extra = rolled == 6 || capture || finishedPiece;
        if (!extra) _advance();
      }
    });
    if (_finished) _showResult(); else _scheduleBot();
  }

  bool _capture(_LocalPlayer mover, _LocalPiece piece) {
    if (piece.progress < 0 || piece.progress > 51) return false;
    const safe = {0, 8, 13, 21, 26, 34, 39, 47};
    final global = _globalIndex(mover.color, piece.progress);
    if (safe.contains(global)) return false;
    var captured = false;
    for (final opponent in _players.where((p) => p != mover)) {
      for (final other in opponent.pieces) {
        if (other.progress >= 0 && other.progress <= 51 && _globalIndex(opponent.color, other.progress) == global) {
          other.progress = -1;
          captured = true;
        }
      }
    }
    return captured;
  }

  int _globalIndex(String color, int progress) {
    final start = switch (color) { 'GREEN' => 0, 'YELLOW' => 13, 'BLUE' => 26, _ => 39 };
    return (start + progress) % 52;
  }

  void _advance() {
    _sixCount = 0;
    _turn = (_turn + 1) % _players.length;
  }

  void _scheduleBot() {
    _botTimer?.cancel();
    if (_finished || _current.human) return;
    _botTimer = Timer(const Duration(milliseconds: 650), () {
      if (!mounted || _finished || _current.human) return;
      if (_dice == null) {
        _rollForCurrent();
      } else if (_legal.isNotEmpty) {
        _move(_bestBotPiece());
      }
    });
  }

  int _bestBotPiece() {
    final dice = _dice!;
    int best = _legal.first;
    int score = -999;
    for (final id in _legal) {
      final piece = _current.pieces.firstWhere((p) => p.id == id);
      final target = piece.progress == -1 ? 0 : piece.progress + dice;
      var s = target;
      if (target == 58) s += 1000;
      if (piece.progress == -1) s += 80;
      if (target <= 51) {
        final global = _globalIndex(_current.color, target);
        for (final opponent in _players.where((p) => p != _current)) {
          if (opponent.pieces.any((p) => p.progress >= 0 && p.progress <= 51 && _globalIndex(opponent.color, p.progress) == global)) s += 400;
        }
      }
      if (s > score) { score = s; best = id; }
    }
    return best;
  }

  void _showResult() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      showDialog<void>(context: context, barrierDismissible: false, builder: (context) => AlertDialog(
        title: Text(context.tr(_winner == 'You' ? 'Practice victory!' : 'Practice completed')),
        content: Text(context.tr(_winner == 'You' ? 'You won the offline match. No wallet or online statistics were changed.' : 'The computer won this practice match. Try again whenever you want.')),
        actions: [
          TextButton(onPressed: () { Navigator.pop(context); Navigator.pushReplacementNamed(context, Routes.localGame, arguments: {'players': _playerCount}); }, child: Text(context.tr('Play again'))),
          FilledButton(onPressed: () { Navigator.pop(context); Navigator.pop(context); }, child: Text(context.tr('Done'))),
        ],
      ));
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) return const SizedBox.shrink();
    final current = _current;
    final humanTurn = current.human;
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Container(
        decoration: const BoxDecoration(gradient: AppGradients.background),
        child: SafeArea(child: Column(children: [
          Padding(padding: const EdgeInsets.fromLTRB(8, 6, 8, 4), child: Row(children: [
            IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.arrow_back_rounded)),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(context.tr('Offline Practice'), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18)), Text(context.tr('No internet • No wager • Classic local rules'), style: const TextStyle(color: AppColors.muted, fontSize: 10))])),
            const StatusBadge('OFFLINE', color: AppColors.cyan),
          ])),
          SizedBox(height: 74, child: ListView.separated(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6), scrollDirection: Axis.horizontal, itemCount: _players.length, separatorBuilder: (_, __) => const SizedBox(width: 8), itemBuilder: (_, i) {
            final p = _players[i];
            return Container(width: 106, padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: AppColors.surface2, borderRadius: BorderRadius.circular(15), border: Border.all(color: i == _turn ? _pieceColor(p.color) : AppColors.divider, width: i == _turn ? 2 : 1)), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Text(context.tr(p.name), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 11)), const SizedBox(height: 4), Text('${p.pieces.where((x) => x.progress == 58).length}/4 ${context.tr('home')}', style: const TextStyle(color: AppColors.muted, fontSize: 9))]));
          })),
          Expanded(child: Padding(padding: const EdgeInsets.all(8), child: Center(child: AspectRatio(aspectRatio: 1, child: GestureDetector(onTapDown: humanTurn && _dice != null ? _handleBoardTap : null, child: CustomPaint(painter: _LocalBoardPainter(players: _players, active: _turn, legal: _legal), child: const SizedBox.expand()))))),),
          Padding(padding: const EdgeInsets.fromLTRB(14, 6, 14, 14), child: Column(children: [
            Text(context.tr(_finished ? 'Practice completed' : humanTurn ? (_dice == null ? 'Your turn — roll the dice' : 'Choose a highlighted piece') : "Computer's turn"), style: const TextStyle(fontWeight: FontWeight.w900, color: AppColors.gold)),
            const SizedBox(height: 8),
            GestureDetector(onTap: humanTurn && _dice == null ? _roll : null, child: AnimatedContainer(duration: const Duration(milliseconds: 180), width: 82, height: 82, decoration: BoxDecoration(gradient: humanTurn ? AppGradients.gold : AppGradients.purple, borderRadius: BorderRadius.circular(24)), child: Center(child: _dice == null ? Icon(humanTurn ? Icons.casino_rounded : Icons.smart_toy_rounded, color: AppColors.background2, size: 42) : Text('$_dice', style: const TextStyle(color: AppColors.background2, fontSize: 34, fontWeight: FontWeight.w900))))),
            const SizedBox(height: 7),
            Text(context.tr(_dice == null ? (humanTurn ? 'Tap the dice' : 'Computer is thinking...') : 'Tap a highlighted piece on the board'), style: const TextStyle(color: AppColors.muted, fontSize: 10)),
          ])),
        ])),
      ),
    );
  }

  void _handleBoardTap(TapDownDetails details) {
    if (_legal.isEmpty) return;
    final boardWidth = context.size?.width ?? 0;
    if (boardWidth <= 0) {
      _move(_legal.first);
      return;
    }
    final cell = boardWidth / 15;
    int? nearestId;
    var nearestDistance = double.infinity;
    for (final id in _legal) {
      final piece = _current.pieces.firstWhere((p) => p.id == id);
      final pos = _localPiecePosition(_current.color, piece.progress, piece.id, cell);
      final distance = (pos - details.localPosition).distance;
      if (distance < nearestDistance) {
        nearestDistance = distance;
        nearestId = id;
      }
    }
    if (nearestId != null && nearestDistance <= cell * 1.15) {
      _move(nearestId);
    }
  }
}

class _LocalPlayer {
  _LocalPlayer({required this.name, required this.color, required this.human, required this.pieces});
  final String name;
  final String color;
  final bool human;
  final List<_LocalPiece> pieces;
}
class _LocalPiece { _LocalPiece(this.id, this.progress); final int id; int progress; }

class _LocalBoardPainter extends CustomPainter {
  _LocalBoardPainter({required this.players, required this.active, required this.legal});
  final List<_LocalPlayer> players;
  final int active;
  final List<int> legal;
  @override
  void paint(Canvas canvas, Size size) {
    final cell = size.width / 15;
    canvas.drawRRect(RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(12)), Paint()..color = const Color(0xFFF2F0E8));
    _home(canvas, cell, 0, 0, const Color(0xFF087B43));
    _home(canvas, cell, 9, 0, const Color(0xFFD0B900));
    _home(canvas, cell, 9, 9, const Color(0xFF1499C9));
    _home(canvas, cell, 0, 9, const Color(0xFFC1272D));
    final grid = Paint()..color = const Color(0xFF616161)..style = PaintingStyle.stroke..strokeWidth = .55;
    for (var i=0;i<=15;i++) { canvas.drawLine(Offset(i*cell,0),Offset(i*cell,size.height),grid); canvas.drawLine(Offset(0,i*cell),Offset(size.width,i*cell),grid); }
    final path = _path();
    for (var i=0;i<path.length;i++) { final p=path[i]; final r=Rect.fromLTWH(p.$2*cell,p.$1*cell,cell,cell); canvas.drawRect(r.deflate(1),Paint()..color=const Color(0xFFF6F6F6)); canvas.drawRect(r.deflate(1),grid); }
    for (var pi=0;pi<players.length;pi++) {
      final player=players[pi];
      for (final piece in player.pieces) {
        final pos=_piecePosition(player.color,piece.progress,piece.id,cell);
        if (pi==active && legal.contains(piece.id)) canvas.drawCircle(pos,cell*.35,Paint()..color=AppColors.gold.withValues(alpha:.55));
        canvas.drawCircle(pos,cell*.24,Paint()..color=_pieceColor(player.color));
        canvas.drawCircle(pos,cell*.24,Paint()..style=PaintingStyle.stroke..strokeWidth=pi==active?3:1.4..color=pi==active?Colors.white:Colors.black54);
      }
    }
  }
  void _home(Canvas canvas,double c,int col,int row,Color color){canvas.drawRect(Rect.fromLTWH(col*c,row*c,6*c,6*c),Paint()..color=color);canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH((col+1)*c,(row+1)*c,4*c,4*c),Radius.circular(c*.3)),Paint()..color=const Color(0xFFE8E8E8));}
  Offset _piecePosition(String color,int progress,int id,double c)=>_localPiecePosition(color,progress,id,c);
  List<(int,int)> _path()=>_localPath;
  @override bool shouldRepaint(covariant _LocalBoardPainter oldDelegate)=>true;
}
Color _pieceColor(String c)=>switch(c){'GREEN'=>const Color(0xFF087B43),'YELLOW'=>const Color(0xFFD0B900),'BLUE'=>const Color(0xFF1499C9),_=>const Color(0xFFC1272D)};

const List<(int,int)> _localPath = [(6,1),(6,2),(6,3),(6,4),(6,5),(5,6),(4,6),(3,6),(2,6),(1,6),(0,6),(0,7),(0,8),(1,8),(2,8),(3,8),(4,8),(5,8),(6,9),(6,10),(6,11),(6,12),(6,13),(6,14),(7,14),(8,14),(8,13),(8,12),(8,11),(8,10),(8,9),(9,8),(10,8),(11,8),(12,8),(13,8),(14,8),(14,7),(14,6),(13,6),(12,6),(11,6),(10,6),(9,6),(8,5),(8,4),(8,3),(8,2),(8,1),(8,0),(7,0),(6,0)];

Offset _localPiecePosition(String color,int progress,int id,double c){
  if(progress<0){
    final base=switch(color){'GREEN'=>(0,0),'YELLOW'=>(9,0),'BLUE'=>(9,9),_=>(0,9)};
    final spots=[(2,2),(2,4),(4,2),(4,4)];
    final p=spots[id%4];
    return Offset((base.$1+p.$2+.5)*c,(base.$2+p.$1+.5)*c);
  }
  if(progress<=51){
    final offset=switch(color){'GREEN'=>0,'YELLOW'=>13,'BLUE'=>26,_=>39};
    final p=_localPath[(offset+progress)%52];
    return Offset((p.$2+.5)*c+((id%2)-.5)*c*.11,(p.$1+.5)*c+((id~/2)-.5)*c*.11);
  }
  if(progress<=57){
    final i=progress-52;
    final lane=switch(color){
      'GREEN'=>[(7,1),(7,2),(7,3),(7,4),(7,5),(7,6)],
      'YELLOW'=>[(1,7),(2,7),(3,7),(4,7),(5,7),(6,7)],
      'RED'=>[(13,7),(12,7),(11,7),(10,7),(9,7),(8,7)],
      _=>[(7,13),(7,12),(7,11),(7,10),(7,9),(7,8)]
    };
    final p=lane[i.clamp(0,5)];
    return Offset((p.$2+.5)*c,(p.$1+.5)*c);
  }
  return Offset(7.5*c+((id%2)-.5)*c*.18,7.5*c+((id~/2)-.5)*c*.18);
}
