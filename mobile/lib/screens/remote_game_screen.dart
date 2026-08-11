import 'dart:async';
import 'package:flutter/material.dart';
import '../core/app_controller.dart';
import '../core/api_config.dart';
import '../core/app_theme.dart';
import '../core/routes.dart';
import '../core/widgets.dart';
import '../core/localization.dart';

class RemoteLudoGameScreen extends StatefulWidget {
  const RemoteLudoGameScreen({super.key});
  @override
  State<RemoteLudoGameScreen> createState() => _RemoteLudoGameScreenState();
}

class _RemoteLudoGameScreenState extends State<RemoteLudoGameScreen> {
  Timer? poller;
  Timer? clock;
  Map<String, dynamic>? match;
  int seconds = 0;
  bool loaded = false;

  String get matchId => '${((ModalRoute.of(context)?.settings.arguments as Map?)?['matchId'] ?? '')}';

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (loaded) return;
    loaded = true;
    _refresh();
    poller = Timer.periodic(const Duration(seconds: 1), (_) => _refresh(silent: true));
    clock = Timer.periodic(const Duration(seconds: 1), (_) => _updateClock());
  }

  @override
  void dispose() {
    poller?.cancel();
    clock?.cancel();
    super.dispose();
  }

  Future<void> _refresh({bool silent = false}) async {
    if (matchId.isEmpty) return;
    final result = await AppScope.of(context).getMatch(matchId);
    if (!mounted || result == null) return;
    setState(() => match = result);
    _updateClock();
  }

  void _updateClock() {
    if (!mounted || match == null) return;
    final state = _state;
    final raw = state['phase'] == 'MOVE' ? state['moveDeadline'] : state['turnDeadline'];
    final deadline = DateTime.tryParse('$raw');
    final next = deadline == null ? 0 : deadline.difference(DateTime.now().toUtc()).inSeconds.clamp(0, 999);
    if (seconds != next) setState(() => seconds = next);
  }

  Map<String, dynamic> get _state => (match?['currentState'] as Map?)?.cast<String, dynamic>() ?? const <String, dynamic>{};
  List<Map<String, dynamic>> get _statePlayers => (( _state['players'] as List?) ?? const []).whereType<Map>().map((e) => e.cast<String, dynamic>()).toList();
  List<Map<String, dynamic>> get _records => ((match?['players'] as List?) ?? const []).whereType<Map>().map((e) => e.cast<String, dynamic>()).toList();

  String _nameFor(String userId) {
    Map<String, dynamic>? record;
    for (final item in _records) {
      if ('${item['userId']}' == userId) { record = item; break; }
    }
    final user = (record?['user'] as Map?)?.cast<String, dynamic>() ?? const <String, dynamic>{};
    final profile = (user['profile'] as Map?)?.cast<String, dynamic>() ?? const <String, dynamic>{};
    final fallback = userId.length > 6 ? userId.substring(0, 6) : userId;
    return '${profile['displayName'] ?? user['username'] ?? fallback}';
  }

  Future<void> _roll() async {
    final controller = AppScope.of(context);
    final result = await controller.rollMatch(matchId);
    if (!mounted) return;
    if (result == null) _snack(controller.errorMessage ?? 'Dice roll failed'); else setState(() => match = result);
  }

  Future<void> _move(int pieceId) async {
    final controller = AppScope.of(context);
    final version = int.tryParse('${_state['version'] ?? match?['stateVersion'] ?? 0}') ?? 0;
    final result = await controller.moveMatch(matchId, pieceId, version);
    if (!mounted) return;
    if (result == null) _snack(controller.errorMessage ?? 'Move failed'); else setState(() => match = result);
  }

  Future<void> _forfeit() async {
    final confirmed = await showDialog<bool>(context: context, builder: (context) => AlertDialog(title: Text(context.tr('Leave match?')), content: Text(context.tr('Forfeiting is recorded by the backend and may settle the wager as a loss.')), actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: Text(context.tr('Continue playing'))), FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(context.tr('Forfeit')))]));
    if (confirmed != true || !mounted) return;
    final controller = AppScope.of(context);
    final result = await controller.forfeitMatch(matchId);
    if (!mounted) return;
    if (result == null) _snack(controller.errorMessage ?? 'Forfeit failed'); else Navigator.pushNamedAndRemoveUntil(context, Routes.shell, (_) => false);
  }

  void _snack(String value) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.tr(value))));

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    if (matchId.isEmpty) return const AppPage(title: 'Game', child: EmptyState(icon: Icons.error_outline_rounded, title: 'No match selected', message: 'Open a real match from matchmaking, a private room or match history.'));
    if (match == null) return const AppPage(title: 'Game', child: Center(child: Padding(padding: EdgeInsets.all(70), child: CircularProgressIndicator(color: AppColors.gold))));

    final state = _state;
    final players = _statePlayers;
    final turnIndex = int.tryParse('${state['turnIndex'] ?? 0}') ?? 0;
    final active = turnIndex >= 0 && turnIndex < players.length ? players[turnIndex] : const <String, dynamic>{};
    final currentUserId = '${controller.currentUser?['id'] ?? ''}';
    final isMyTurn = '${active['userId'] ?? ''}' == currentUserId;
    final phase = '${state['phase'] ?? ''}';
    final legal = ((state['legalPieceIds'] as List?) ?? const []).map((e) => int.tryParse('$e') ?? -1).where((e) => e >= 0).toList();
    final status = '${match!['status'] ?? ''}';
    final winner = '${match!['winnerUserId'] ?? ''}';
    final stake = double.tryParse('${match!['stakeAmount'] ?? 0}') ?? 0;
    final isWager = '${match!['mode'] ?? ''}' == 'WAGER' || stake > 0;
    final boardItem = controller.equippedItem('BOARD');
    final diceItem = controller.equippedItem('DICE');
    final frameItem = controller.equippedItem('DICE_FRAME');
    final boardStyle = ((boardItem?['metadata'] as Map?) ?? const <String,dynamic>{}).cast<String,dynamic>();
    final diceStyle = ((diceItem?['metadata'] as Map?) ?? const <String,dynamic>{}).cast<String,dynamic>();
    final frameStyle = ((frameItem?['metadata'] as Map?) ?? const <String,dynamic>{}).cast<String,dynamic>();
    final boardImage = ApiConfig.resolveAssetUrl(boardItem?['imageUrl']);
    final lobbyCampaign = controller.activeCampaign('GAME_LOBBY');
    final lobbyImage = ApiConfig.resolveAssetUrl(lobbyCampaign?['imageUrl']);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Container(
        decoration: BoxDecoration(gradient: AppGradients.background, image: lobbyImage.isEmpty ? null : DecorationImage(image: NetworkImage(lobbyImage), fit: BoxFit.cover, colorFilter: ColorFilter.mode(Colors.black.withValues(alpha: .42), BlendMode.darken))),
        child: SafeArea(child: Column(children: [
          Padding(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6), child: Row(children: [
            IconButton(onPressed: _forfeit, icon: const Icon(Icons.arrow_back_rounded)),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('${context.tr('Match')} #${match!['publicCode'] ?? ''}', style: const TextStyle(fontWeight: FontWeight.w900)), Text('${match!['mode']} • ${(match!['ruleSet'] as Map?)?['code'] ?? ''}', style: const TextStyle(color: AppColors.muted, fontSize: 10))])),
            if (isWager) StatusBadge('${stake.toStringAsFixed(0)} MRU', color: AppColors.gold),
            if (isWager) const SizedBox(width: 6),
            StatusBadge(status, color: status == 'ACTIVE' ? AppColors.green : status == 'COMPLETED' ? AppColors.gold : AppColors.orange),
          ])),
          SizedBox(height: 82, child: ListView.separated(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 10), itemCount: players.length, separatorBuilder: (_, __) => const SizedBox(width: 8), itemBuilder: (context, index) {
            final player = players[index];
            final color = _color('${player['color']}');
            final name = _nameFor('${player['userId']}');
            return Container(width: 150, padding: const EdgeInsets.all(9), decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(17), border: Border.all(color: index == turnIndex ? color : AppColors.divider, width: index == turnIndex ? 2 : 1)), child: Row(children: [PlayerAvatar(name: name, size: 45, color: color), const SizedBox(width: 9), Expanded(child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [Text(name, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 11)), const SizedBox(height: 4), Text(context.tr('${player['color']}'), style: TextStyle(color: color, fontSize: 9)), if (index == turnIndex) Text('$seconds ${context.tr('seconds remaining')}', style: const TextStyle(color: AppColors.muted, fontSize: 8))]))]));
          })),
          const SizedBox(height: 6),
          Expanded(child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 7),
            child: AspectRatio(
              aspectRatio: 1,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  image: boardImage.isEmpty ? null : DecorationImage(image: NetworkImage(boardImage), fit: BoxFit.cover),
                  boxShadow: [BoxShadow(color: _styleColor(boardStyle, 'glowColor', AppColors.gold).withValues(alpha: .22), blurRadius: 22)],
                ),
                child: CustomPaint(
                  painter: _ServerBoardPainter(
                    players: players,
                    activeUserId: '${active['userId'] ?? ''}',
                    legalPieces: legal,
                    myUserId: currentUserId,
                    style: boardStyle,
                    transparentBoard: boardImage.isNotEmpty && '${boardStyle['renderMode'] ?? ''}'.toUpperCase() == 'IMAGE',
                  ),
                ),
              ),
            ),
          )),
          Padding(padding: const EdgeInsets.fromLTRB(14, 8, 14, 14), child: GradientPanel(borderColor: isMyTurn ? AppColors.gold : AppColors.divider, padding: const EdgeInsets.all(12), child: Column(children: [
            Row(children: [
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 320),
                transitionBuilder: (child, animation) => RotationTransition(
                  turns: Tween<double>(begin: -.12, end: 0).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutBack)),
                  child: ScaleTransition(scale: Tween<double>(begin: .72, end: 1).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutBack)), child: child),
                ),
                child: _DiceFace(key: ValueKey('${state['version'] ?? ''}:${state['dice'] ?? 0}'), value: int.tryParse('${state['dice'] ?? 0}') ?? 0, style: diceStyle, frameStyle: frameStyle),
              ),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(status == 'COMPLETED' ? (winner == currentUserId ? context.tr('You won') : context.tr('Match completed')) : isMyTurn ? context.tr('Your turn') : '${context.tr('Waiting for')} ${_nameFor('${active['userId'] ?? ''}')}', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15)),
                const SizedBox(height: 4),
                Text(context.tr(status == 'COMPLETED' ? 'The backend has stored the final result and wallet settlement.' : phase == 'ROLL' ? 'Roll the dice' : 'Select a legal token'), style: const TextStyle(color: AppColors.muted, fontSize: 10)),
              ])),
              if (status == 'ACTIVE' && isMyTurn && phase == 'ROLL') GoldButton(label: 'Roll', expanded: false, loading: controller.busy, onPressed: controller.busy ? null : _roll),
            ]),
            if (status == 'ACTIVE' && isMyTurn && phase == 'MOVE' && legal.isNotEmpty) ...[
              const SizedBox(height: 10),
              Wrap(spacing: 8, runSpacing: 8, children: legal.map((id) => FilledButton(onPressed: controller.busy ? null : () => _move(id), child: Text('${context.tr('Token')} ${id + 1}'))).toList()),
            ],
            if (status == 'COMPLETED') ...[
              const SizedBox(height: 10),
              GoldButton(label: 'Back to Home', onPressed: () async { await controller.refreshAll(); if (context.mounted) Navigator.pushNamedAndRemoveUntil(context, Routes.shell, (_) => false); }),
            ],
          ]))),
        ])),
      ),
    );
  }
}

class _DiceFace extends StatelessWidget {
  const _DiceFace({super.key, required this.value, required this.style, required this.frameStyle});
  final int value;
  final Map<String,dynamic> style;
  final Map<String,dynamic> frameStyle;
  @override
  Widget build(BuildContext context) {
    final face = _styleColor(style, 'faceColor', Colors.white);
    final pip = _styleColor(style, 'pipColor', AppColors.background2);
    final border = _styleColor(frameStyle, 'frameColor', _styleColor(style, 'borderColor', AppColors.gold));
    final glow = _styleColor(frameStyle, 'glowColor', border);
    final radius = double.tryParse('${style['radius'] ?? 15}')?.clamp(4, 28).toDouble() ?? 15;
    final width = double.tryParse('${frameStyle['borderWidth'] ?? 3}')?.clamp(1, 8).toDouble() ?? 3;
    return Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(color: face, borderRadius: BorderRadius.circular(radius), border: Border.all(color: border, width: width), boxShadow: [BoxShadow(color: glow.withValues(alpha: .45), blurRadius: 14)]),
      child: value <= 0 ? Center(child: Text('—', style: TextStyle(color: pip, fontSize: 29, fontWeight: FontWeight.w900))) : CustomPaint(painter: _DicePipPainter(value: value, color: pip)),
    );
  }
}

class _DicePipPainter extends CustomPainter {
  const _DicePipPainter({required this.value, required this.color});
  final int value;
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final r = size.width * .065;
    final points = <Offset>[
      Offset(size.width*.27,size.height*.27), Offset(size.width*.73,size.height*.27),
      Offset(size.width*.27,size.height*.5), Offset(size.width*.5,size.height*.5), Offset(size.width*.73,size.height*.5),
      Offset(size.width*.27,size.height*.73), Offset(size.width*.73,size.height*.73),
    ];
    final indexes = switch(value) {1=>[3],2=>[0,6],3=>[0,3,6],4=>[0,1,5,6],5=>[0,1,3,5,6],_=>[0,1,2,4,5,6]};
    for(final i in indexes) canvas.drawCircle(points[i], r, paint);
  }
  @override
  bool shouldRepaint(covariant _DicePipPainter oldDelegate) => oldDelegate.value != value || oldDelegate.color != color;
}

class _ServerBoardPainter extends CustomPainter {
  const _ServerBoardPainter({required this.players, required this.activeUserId, required this.legalPieces, required this.myUserId, required this.style, required this.transparentBoard});
  final List<Map<String, dynamic>> players;
  final String activeUserId;
  final List<int> legalPieces;
  final String myUserId;
  final Map<String,dynamic> style;
  final bool transparentBoard;

  @override
  void paint(Canvas canvas, Size size) {
    final cell = size.width / 15;
    final rect = Offset.zero & size;
    if (!transparentBoard) canvas.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(10)), Paint()..color = _styleColor(style, 'backgroundColor', const Color(0xFFF2F0E8)));
    _home(canvas, cell, 0, 0, const Color(0xFF087B43));
    _home(canvas, cell, 9, 0, const Color(0xFFD0B900));
    _home(canvas, cell, 0, 9, const Color(0xFFC1272D));
    _home(canvas, cell, 9, 9, const Color(0xFF1499C9));

    final grid = Paint()..color = _styleColor(style, 'gridColor', const Color(0xFF616161))..style = PaintingStyle.stroke..strokeWidth = .55;
    for (var i = 0; i <= 15; i++) {
      canvas.drawLine(Offset(i * cell, 0), Offset(i * cell, size.height), grid);
      canvas.drawLine(Offset(0, i * cell), Offset(size.width, i * cell), grid);
    }

    final track = _path();
    for (var i = 0; i < track.length; i++) {
      final p = track[i];
      final r = Rect.fromLTWH(p.$2 * cell, p.$1 * cell, cell, cell);
      if (!transparentBoard) canvas.drawRect(r.deflate(1), Paint()..color = _styleColor(style, 'trackColor', const Color(0xFFF6F6F6)));
      canvas.drawRect(r.deflate(1), grid);
      if ({0, 8, 13, 21, 26, 34, 39, 47}.contains(i)) {
        final star = TextPainter(text: TextSpan(text: '★', style: TextStyle(color: _styleColor(style, 'safeColor', const Color(0xFF777777)), fontSize: 14)), textDirection: TextDirection.ltr)..layout();
        star.paint(canvas, Offset(r.center.dx - star.width / 2, r.center.dy - star.height / 2));
      }
    }
    _lane(canvas, cell, 'GREEN', const Color(0xFF087B43));
    _lane(canvas, cell, 'YELLOW', const Color(0xFFD0B900));
    _lane(canvas, cell, 'RED', const Color(0xFFC1272D));
    _lane(canvas, cell, 'BLUE', const Color(0xFF1499C9));

    for (final player in players) {
      final colorName = '${player['color']}';
      final userId = '${player['userId']}';
      final pieces = ((player['pieces'] as List?) ?? const []).whereType<Map>().map((e) => e.cast<String, dynamic>()).toList();
      for (final piece in pieces) {
        final id = int.tryParse('${piece['id']}') ?? 0;
        final progress = int.tryParse('${piece['progress']}') ?? -1;
        final pos = _piecePosition(colorName, progress, id, cell);
        final color = _color(colorName);
        final legal = userId == myUserId && legalPieces.contains(id);
        if (legal) canvas.drawCircle(pos, cell * .34, Paint()..color = AppColors.gold.withValues(alpha: .55));
        canvas.drawCircle(pos, cell * .24, Paint()..color = color);
        final borderPaint = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = userId == activeUserId ? 3 : 1.5
          ..color = userId == activeUserId ? Colors.white : Colors.black54;
        canvas.drawCircle(pos, cell * .24, borderPaint);
        final text = TextPainter(text: TextSpan(text: '${id + 1}', style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.w900)), textDirection: TextDirection.ltr)..layout();
        text.paint(canvas, Offset(pos.dx - text.width / 2, pos.dy - text.height / 2));
      }
    }
  }

  void _home(Canvas canvas, double c, int col, int row, Color color) {
    canvas.drawRect(Rect.fromLTWH(col * c, row * c, 6 * c, 6 * c), Paint()..color = color);
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH((col + 1) * c, (row + 1) * c, 4 * c, 4 * c), Radius.circular(c * .3)), Paint()..color = const Color(0xFFE8E8E8));
  }

  void _lane(Canvas canvas, double c, String color, Color paintColor) {
    final coords = switch (color) {
      'GREEN' => [(7, 1), (7, 2), (7, 3), (7, 4), (7, 5), (7, 6)],
      'YELLOW' => [(1, 7), (2, 7), (3, 7), (4, 7), (5, 7), (6, 7)],
      'RED' => [(13, 7), (12, 7), (11, 7), (10, 7), (9, 7), (8, 7)],
      _ => [(7, 13), (7, 12), (7, 11), (7, 10), (7, 9), (7, 8)],
    };
    for (final p in coords) canvas.drawRect(Rect.fromLTWH(p.$2 * c + 1, p.$1 * c + 1, c - 2, c - 2), Paint()..color = paintColor.withValues(alpha: .82));
  }

  Offset _piecePosition(String color, int progress, int id, double c) {
    if (progress < 0) {
      final base = switch (color) { 'GREEN' => (0, 0), 'YELLOW' => (9, 0), 'RED' => (0, 9), _ => (9, 9) };
      final positions = [(2, 2), (2, 4), (4, 2), (4, 4)];
      final p = positions[id % positions.length];
      return Offset((base.$1 + p.$2 + .5) * c, (base.$2 + p.$1 + .5) * c);
    }
    if (progress <= 51) {
      final offset = switch (color) { 'GREEN' => 0, 'YELLOW' => 13, 'BLUE' => 26, _ => 39 };
      final p = _path()[(offset + progress) % 52];
      return Offset((p.$2 + .5) * c + ((id % 2) - .5) * c * .11, (p.$1 + .5) * c + ((id ~/ 2) - .5) * c * .11);
    }
    if (progress <= 57) {
      final index = progress - 52;
      final coords = switch (color) {
        'GREEN' => [(7, 1), (7, 2), (7, 3), (7, 4), (7, 5), (7, 6)],
        'YELLOW' => [(1, 7), (2, 7), (3, 7), (4, 7), (5, 7), (6, 7)],
        'RED' => [(13, 7), (12, 7), (11, 7), (10, 7), (9, 7), (8, 7)],
        _ => [(7, 13), (7, 12), (7, 11), (7, 10), (7, 9), (7, 8)],
      };
      final p = coords[index.clamp(0, 5)];
      return Offset((p.$2 + .5) * c, (p.$1 + .5) * c);
    }
    return Offset(7.5 * c + ((id % 2) - .5) * c * .18, 7.5 * c + ((id ~/ 2) - .5) * c * .18);
  }

  List<(int, int)> _path() => const [
    (6,1),(6,2),(6,3),(6,4),(6,5),(5,6),(4,6),(3,6),(2,6),(1,6),(0,6),(0,7),(0,8),
    (1,8),(2,8),(3,8),(4,8),(5,8),(6,9),(6,10),(6,11),(6,12),(6,13),(6,14),(7,14),(8,14),
    (8,13),(8,12),(8,11),(8,10),(8,9),(9,8),(10,8),(11,8),(12,8),(13,8),(14,8),(14,7),(14,6),
    (13,6),(12,6),(11,6),(10,6),(9,6),(8,5),(8,4),(8,3),(8,2),(8,1),(8,0),(7,0),(6,0),
  ];

  @override
  bool shouldRepaint(covariant _ServerBoardPainter oldDelegate) => oldDelegate.players != players || oldDelegate.activeUserId != activeUserId || oldDelegate.legalPieces != legalPieces || oldDelegate.style != style || oldDelegate.transparentBoard != transparentBoard;
}

Color _color(String value) => switch (value) {
  'GREEN' => const Color(0xFF087B43),
  'YELLOW' => const Color(0xFFD0B900),
  'RED' => const Color(0xFFC1272D),
  'BLUE' => const Color(0xFF1499C9),
  _ => AppColors.muted,
};


Color _styleColor(Map<String,dynamic> metadata, String key, Color fallback) {
  final raw = '${metadata[key] ?? ''}'.replaceAll('#', '');
  if (raw.length != 6 && raw.length != 8) return fallback;
  final value = int.tryParse(raw.length == 6 ? 'FF$raw' : raw, radix: 16);
  return value == null ? fallback : Color(value);
}
