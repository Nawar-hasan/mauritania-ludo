import 'dart:async';
import 'package:flutter/material.dart';
import '../core/app_controller.dart';
import '../core/app_theme.dart';
import '../core/routes.dart';
import '../core/widgets.dart';
import '../core/localization.dart';

class PlayModesScreen extends StatelessWidget {
  const PlayModesScreen({super.key});
  @override
  Widget build(BuildContext context) => AppPage(title: 'Choose Game Mode', child: Column(children: [
    OptionTile(icon: Icons.sports_esports_rounded, title: 'Casual Match', subtitle: 'Real server match without reserving wallet funds', color: AppColors.cyan, onTap: () => Navigator.pushNamed(context, Routes.playerCount, arguments: 'casual')),
    OptionTile(icon: Icons.payments_rounded, title: 'Wager Match', subtitle: 'The server reserves the selected amount from every player', color: AppColors.gold, onTap: () => Navigator.pushNamed(context, Routes.playerCount, arguments: 'wager')),
    OptionTile(icon: Icons.key_rounded, title: 'Private Room', subtitle: 'Create a server room or join with its six-digit code', color: AppColors.purpleLight, onTap: () => Navigator.pushNamed(context, Routes.privateRoom)),
    OptionTile(icon: Icons.offline_bolt_rounded, title: 'Offline / Solo Play', subtitle: 'Play locally against computer players with no internet and no wager', color: AppColors.cyan, onTap: () => Navigator.pushNamed(context, Routes.offlineMode)),
    OptionTile(icon: Icons.emoji_events_outlined, title: 'Tournaments', subtitle: 'Official brackets, entry status and tournament matches', color: AppColors.orange, onTap: () => Navigator.pushNamed(context, Routes.tournaments)),
  ]));
}

class PlayerCountScreen extends StatelessWidget {
  const PlayerCountScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final mode = (ModalRoute.of(context)?.settings.arguments as String?) ?? 'casual';
    return AppPage(title: 'Number of Players', child: Column(children: [
      const ScreenHeader(title: 'Select match size', subtitle: 'Online matches use separate authenticated accounts. Offline solo play is available from the game mode menu.', icon: Icons.groups_rounded),
      const SizedBox(height: 24),
      _CountCard(players: 2, onTap: () => Navigator.pushNamed(context, Routes.rules, arguments: {'mode': mode, 'players': 2})),
      const SizedBox(height: 12),
      _CountCard(players: 4, onTap: () => Navigator.pushNamed(context, Routes.rules, arguments: {'mode': mode, 'players': 4})),
    ]));
  }
}

class _CountCard extends StatelessWidget {
  const _CountCard({required this.players, required this.onTap});
  final int players;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => GradientPanel(onTap: onTap, borderColor: players == 2 ? AppColors.gold : AppColors.cyan, padding: const EdgeInsets.all(24), child: Row(children: [
    CircleAvatar(radius: 40, backgroundColor: (players == 2 ? AppColors.gold : AppColors.cyan).withValues(alpha: .16), child: Icon(players == 2 ? Icons.people_alt_rounded : Icons.groups_2_rounded, size: 42, color: players == 2 ? AppColors.gold : AppColors.cyan)),
    const SizedBox(width: 18),
    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(context.tr(players == 2 ? '2 Players' : '4 Players'), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 20)), const SizedBox(height: 5), Text(context.tr(players == 2 ? 'Head-to-head match' : 'Full four-player match'), style: const TextStyle(color: AppColors.muted))])),
    const Icon(Icons.chevron_right_rounded),
  ]));
}

class RulesScreen extends StatefulWidget {
  const RulesScreen({super.key});
  @override
  State<RulesScreen> createState() => _RulesScreenState();
}
class _RulesScreenState extends State<RulesScreen> {
  String? selected;
  @override
  Widget build(BuildContext context) {
    final args = _mapArgs(context);
    final controller = AppScope.of(context);
    final rules = controller.gameRules.where((x) => x['enabled'] != false).toList()
      ..sort((a,b) => (int.tryParse('${a['sortOrder'] ?? 0}') ?? 0).compareTo(int.tryParse('${b['sortOrder'] ?? 0}') ?? 0));
    if (rules.isNotEmpty && (selected == null || !rules.any((x) => '${x['code']}' == selected))) selected = '${rules.first['code']}';
    return AppPage(title: 'Match Rules', child: Column(children: [
      const SectionTitle('Choose a rule set', subtitle: 'The server applies the selected rule set and validates every roll and move.'),
      if (rules.isEmpty)
        const EmptyState(icon: Icons.rule_folder_outlined, title: 'No game modes are enabled', message: 'Enable or create a game mode from the administration panel.')
      else
        ...rules.map((rule) {
          final code = '${rule['code'] ?? ''}';
          final name = '${rule['name'] ?? code}';
          final description = controller.isArabic
              ? '${rule['descriptionAr'] ?? _ruleDescriptionAr(rule)}'
              : '${rule['descriptionEn'] ?? _ruleDescriptionEn(rule)}';
          final color = _ruleColor(code);
          return GradientPanel(
            margin: const EdgeInsets.only(bottom: 11),
            borderColor: selected == code ? color : AppColors.divider,
            onTap: () => setState(() => selected = code),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(_ruleIcon(code), color: color, size: 34),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(context.tr(name), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17)),
                const SizedBox(height: 5),
                Text(description, style: const TextStyle(color: AppColors.muted, height: 1.4, fontSize: 11)),
                const SizedBox(height: 7),
                Wrap(spacing: 7, runSpacing: 5, children: [
                  StatusBadge('${rule['piecesPerPlayer'] ?? 4} ${context.tr('pieces')}', color: color),
                  StatusBadge('${rule['rollSeconds'] ?? 12}s ${context.tr('roll')}', color: AppColors.cyan),
                  StatusBadge('${rule['moveSeconds'] ?? 15}s ${context.tr('move')}', color: AppColors.orange),
                ]),
              ])),
              Icon(selected == code ? Icons.check_circle_rounded : Icons.circle_outlined, color: selected == code ? color : AppColors.muted),
            ]),
          );
        }),
      const SizedBox(height: 10),
      GoldButton(label: 'Continue', onPressed: selected == null ? null : () {
        final merged = {...args, 'rules': selected};
        Navigator.pushNamed(context, args['mode'] == 'wager' ? Routes.wager : Routes.matchmaking, arguments: merged);
      }),
    ]));
  }

  String _ruleDescriptionAr(Map<String,dynamic> rule) => 'عدد القطع ${rule['piecesPerPlayer'] ?? 4}، وقت الرمي ${rule['rollSeconds'] ?? 12} ثانية، ووقت الحركة ${rule['moveSeconds'] ?? 15} ثانية.';
  String _ruleDescriptionEn(Map<String,dynamic> rule) => '${rule['piecesPerPlayer'] ?? 4} pieces, ${rule['rollSeconds'] ?? 12}s to roll and ${rule['moveSeconds'] ?? 15}s to move.';
  IconData _ruleIcon(String code) => code.contains('QUICK') ? Icons.bolt_rounded : code.contains('MASTER') ? Icons.workspace_premium_rounded : Icons.casino_rounded;
  Color _ruleColor(String code) => code.contains('QUICK') ? AppColors.cyan : code.contains('MASTER') ? AppColors.orange : AppColors.gold;
}

class WagerSelectionScreen extends StatefulWidget {
  const WagerSelectionScreen({super.key});
  @override
  State<WagerSelectionScreen> createState() => _WagerSelectionScreenState();
}
class _WagerSelectionScreenState extends State<WagerSelectionScreen> {
  double amount = 50;
  @override
  Widget build(BuildContext context) {
    final args = _mapArgs(context);
    final controller = AppScope.of(context);
    final min = _setting(controller, 'minimum_wager', 50);
    final max = _setting(controller, 'maximum_wager', 100000);
    final values = <double>[min, min * 2, min * 3, min * 5, min * 10].where((v) => v <= max).toSet().toList();
    if (!values.contains(amount)) amount = values.first;
    return AppPage(title: 'Choose Wager', child: Column(children: [
      GradientPanel(gradient: AppGradients.purple, child: Row(children: [const Icon(Icons.account_balance_wallet_rounded, color: AppColors.gold, size: 42), const SizedBox(width: 13), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(context.tr('Cash balance'), style: const TextStyle(color: Colors.white70)), const SizedBox(height: 4), Text('${controller.walletBalance.toStringAsFixed(2)} MRU', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 25))]))])),
      const SizedBox(height: 18),
      Wrap(spacing: 9, runSpacing: 9, children: values.map((value) => ChoiceChip(label: Text('${value.toStringAsFixed(0)} MRU'), selected: amount == value, onSelected: (_) => setState(() => amount = value))).toList()),
      const SizedBox(height: 18),
      GradientPanel(child: Column(children: [
        _InfoRow('Entry amount', '${amount.toStringAsFixed(2)} MRU'),
        _InfoRow('Players', '${args['players'] ?? 2}'),
        _InfoRow('Total pool before fee', '${(amount * ((args['players'] as int?) ?? 2)).toStringAsFixed(2)} MRU', strong: true),
      ])),
      const SizedBox(height: 20),
      GoldButton(label: 'Review match', onPressed: amount > controller.walletBalance ? null : () => Navigator.pushNamed(context, Routes.wagerConfirm, arguments: {...args, 'wager': amount})),
      if (amount > controller.walletBalance) Padding(padding: const EdgeInsets.only(top: 12), child: Text(context.tr('Insufficient wallet balance'), style: const TextStyle(color: AppColors.red, fontWeight: FontWeight.w800))),
    ]));
  }
}

class WagerConfirmScreen extends StatelessWidget {
  const WagerConfirmScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final args = _mapArgs(context);
    final controller = AppScope.of(context);
    final players = (args['players'] as int?) ?? 2;
    final stake = _double(args['wager']);
    final feeRate = _setting(controller, 'platform_fee_rate', .05);
    final pool = stake * players;
    final prize = pool - (pool * feeRate);
    return AppPage(title: 'Confirm Match', child: Column(children: [
      const ScreenHeader(title: 'Server-side wager reservation', subtitle: 'The stake is reserved only when a match is created. The backend settles the result atomically.', icon: Icons.verified_user_outlined),
      const SizedBox(height: 20),
      GradientPanel(borderColor: AppColors.gold, child: Column(children: [
        _InfoRow('Rules', '${args['rules'] ?? 'CLASSIC'}'),
        _InfoRow('Players', '$players'),
        _InfoRow('Your entry', '${stake.toStringAsFixed(2)} MRU'),
        _InfoRow('Estimated platform fee', '${(pool * feeRate).toStringAsFixed(2)} MRU'),
        _InfoRow('Estimated winner prize', '${prize.toStringAsFixed(2)} MRU', strong: true),
      ])),
      const SizedBox(height: 20),
      GoldButton(label: 'Start matchmaking', onPressed: () => Navigator.pushReplacementNamed(context, Routes.matchmaking, arguments: args)),
    ]));
  }
}

class MatchmakingScreen extends StatefulWidget {
  const MatchmakingScreen({super.key});
  @override
  State<MatchmakingScreen> createState() => _MatchmakingScreenState();
}
class _MatchmakingScreenState extends State<MatchmakingScreen> {
  Timer? timer;
  String? ticketId;
  bool started = false;
  @override
  void didChangeDependencies() { super.didChangeDependencies(); if (!started) { started = true; _begin(); } }
  @override
  void dispose() { timer?.cancel(); super.dispose(); }

  Future<void> _begin() async {
    final controller = AppScope.of(context);
    final args = _mapArgs(context);
    final result = await controller.matchmake(mode: args['mode'] == 'wager' ? 'WAGER' : 'CASUAL', maxPlayers: (args['players'] as int?) ?? 2, ruleCode: '${args['rules'] ?? 'CLASSIC'}', stakeAmount: _double(args['wager']));
    if (!mounted) return;
    if (result == null) { setState(() {}); return; }
    final matchId = '${result['matchId'] ?? ''}';
    if (matchId.isNotEmpty) { _openMatch(matchId); return; }
    ticketId = '${result['id'] ?? result['ticketId'] ?? ''}';
    if (ticketId!.isEmpty) { setState(() {}); return; }
    timer = Timer.periodic(const Duration(seconds: 2), (_) => _poll());
    setState(() {});
  }

  Future<void> _poll() async {
    if (ticketId == null || !mounted) return;
    final result = await AppScope.of(context).getTicket(ticketId!);
    if (!mounted || result == null) return;
    final matchId = '${result['matchId'] ?? ''}';
    final status = '${result['status'] ?? ''}';
    if (matchId.isNotEmpty && status == 'MATCHED') _openMatch(matchId);
    if (status == 'CANCELLED' || status == 'EXPIRED') { timer?.cancel(); setState(() {}); }
  }

  void _openMatch(String matchId) {
    timer?.cancel();
    Navigator.pushReplacementNamed(context, Routes.waitingRoom, arguments: {'matchId': matchId});
  }

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    return AppPage(title: 'Matchmaking', child: Column(children: [
      const SizedBox(height: 35),
      const SizedBox(width: 90, height: 90, child: CircularProgressIndicator(strokeWidth: 8, color: AppColors.gold)),
      const SizedBox(height: 28),
      Text(context.tr(controller.errorMessage == null ? 'Finding players...' : 'Matchmaking failed'), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 21)),
      const SizedBox(height: 10),
      Text(context.tr(controller.errorMessage ?? 'Open the application with another account and choose the same mode, player count, rule set and wager.'), textAlign: TextAlign.center, style: const TextStyle(color: AppColors.muted, height: 1.5)),
      const SizedBox(height: 28),
      OutlinedButton.icon(onPressed: () async { if (ticketId != null) await controller.cancelTicket(ticketId!); if (context.mounted) Navigator.pop(context); }, icon: const Icon(Icons.close_rounded), label: Text(context.tr('Cancel Search'))),
    ]));
  }
}

class OpponentFoundScreen extends StatelessWidget {
  const OpponentFoundScreen({super.key});
  @override
  Widget build(BuildContext context) => const AppPage(title: 'Opponent found', child: EmptyState(icon: Icons.people_alt_rounded, title: 'Match created', message: 'The connected flow now opens the real waiting room directly.'));
}

class PrivateRoomScreen extends StatefulWidget {
  const PrivateRoomScreen({super.key});
  @override
  State<PrivateRoomScreen> createState() => _PrivateRoomScreenState();
}
class _PrivateRoomScreenState extends State<PrivateRoomScreen> {
  int players = 2;
  String rules = 'CLASSIC';
  final stake = TextEditingController(text: '0');
  @override
  void dispose() { stake.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    return AppPage(title: 'Private Room', child: Column(children: [
      const ScreenHeader(title: 'Create a private server room', subtitle: 'Share the generated six-digit code with authenticated players.', icon: Icons.key_rounded),
      const SizedBox(height: 18),
      SegmentedButton<int>(segments: [ButtonSegment(value: 2, label: Text(context.tr('2 Players'))), ButtonSegment(value: 4, label: Text(context.tr('4 Players')))], selected: {players}, onSelectionChanged: (v) => setState(() => players = v.first)),
      const SizedBox(height: 16),
      DropdownButtonFormField<String>(initialValue: rules, decoration: InputDecoration(labelText: context.tr('Rules')), items: const ['CLASSIC', 'QUICK', 'MASTER'].map((value) => DropdownMenuItem(value: value, child: Text(value))).toList(), onChanged: (value) => setState(() => rules = value ?? rules)),
      const SizedBox(height: 16),
      AppTextField(label: 'Entry amount', hint: '0 for a no-wager room', controller: stake, keyboardType: const TextInputType.numberWithOptions(decimal: true), icon: Icons.payments_outlined),
      const SizedBox(height: 22),
      GoldButton(label: 'Create room', loading: controller.busy, onPressed: controller.busy ? null : () async {
        final amount = double.tryParse(stake.text.trim()) ?? 0;
        if (amount > controller.walletBalance) { _snack(context, 'Insufficient wallet balance'); return; }
        final match = await controller.createMatch(mode: 'PRIVATE', maxPlayers: players, ruleCode: rules, stakeAmount: amount);
        if (!context.mounted) return;
        if (match == null) _snack(context, controller.errorMessage ?? 'Room creation failed');
        else Navigator.pushReplacementNamed(context, Routes.waitingRoom, arguments: {'matchId': '${match['id']}'});
      }),
      const SizedBox(height: 12),
      PurpleButton(label: 'Join with code', icon: Icons.login_rounded, onPressed: () => Navigator.pushNamed(context, Routes.joinRoom)),
    ]));
  }
}

class JoinRoomScreen extends StatefulWidget {
  const JoinRoomScreen({super.key});
  @override
  State<JoinRoomScreen> createState() => _JoinRoomScreenState();
}
class _JoinRoomScreenState extends State<JoinRoomScreen> {
  final code = TextEditingController();
  @override
  void dispose() { code.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    return AppPage(title: 'Join Private Room', child: Column(children: [
      const ScreenHeader(title: 'Enter room code', subtitle: 'Use the six-digit code generated by the host backend.', icon: Icons.key_rounded),
      const SizedBox(height: 28),
      AppTextField(label: 'Room code', controller: code, keyboardType: TextInputType.number, icon: Icons.numbers_rounded),
      const SizedBox(height: 22),
      GoldButton(label: 'Find Room', loading: controller.busy, onPressed: controller.busy ? null : () async {
        final value = code.text.trim();
        if (value.length != 6) { _snack(context, 'Enter the six-digit room code'); return; }
        final room = await controller.previewRoom(value);
        if (!context.mounted) return;
        if (room == null) _snack(context, controller.errorMessage ?? 'Room not found');
        else Navigator.pushNamed(context, Routes.roomPreview, arguments: room);
      }),
    ]));
  }
}

class RoomPreviewScreen extends StatelessWidget {
  const RoomPreviewScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final room = _mapArgs(context);
    final players = (room['players'] as List?) ?? const [];
    final controller = AppScope.of(context);
    return AppPage(title: 'Room Found', child: Column(children: [
      ScreenHeader(title: '${context.tr('Room')} #${room['publicCode'] ?? ''}', subtitle: 'Review the actual server room before joining.', icon: Icons.meeting_room_rounded),
      const SizedBox(height: 20),
      GradientPanel(borderColor: AppColors.gold, child: Column(children: [
        _InfoRow('Mode', '${room['mode'] ?? ''}'),
        _InfoRow('Status', '${room['status'] ?? ''}'),
        _InfoRow('Players', '${players.length}/${room['maxPlayers'] ?? 0}'),
        _InfoRow('Rules', '${(room['ruleSet'] as Map?)?['code'] ?? ''}'),
        _InfoRow('Entry amount', '${_double(room['stakeAmount']).toStringAsFixed(2)} ${room['currency'] ?? 'MRU'}', strong: true),
      ])),
      const SizedBox(height: 20),
      GoldButton(label: room['alreadyJoined'] == true ? 'Open waiting room' : 'Join room', loading: controller.busy, onPressed: controller.busy ? null : () async {
        Map<String, dynamic>? match = room;
        if (room['alreadyJoined'] != true) match = await controller.joinRoomByCode('${room['publicCode']}');
        if (!context.mounted) return;
        if (match == null) _snack(context, controller.errorMessage ?? 'Could not join room');
        else Navigator.pushReplacementNamed(context, Routes.waitingRoom, arguments: {'matchId': '${match['id'] ?? room['id']}'});
      }),
    ]));
  }
}

class WaitingRoomScreen extends StatefulWidget {
  const WaitingRoomScreen({super.key});
  @override
  State<WaitingRoomScreen> createState() => _WaitingRoomScreenState();
}
class _WaitingRoomScreenState extends State<WaitingRoomScreen> {
  Timer? timer;
  Map<String, dynamic>? match;
  bool loaded = false;
  bool navigating = false;
  @override
  void didChangeDependencies() { super.didChangeDependencies(); if (!loaded) { loaded = true; _refresh(); timer = Timer.periodic(const Duration(seconds: 2), (_) => _refresh()); } }
  @override
  void dispose() { timer?.cancel(); super.dispose(); }
  String get id => '${_mapArgs(context)['matchId'] ?? ''}';

  Future<void> _refresh() async {
    if (id.isEmpty || navigating) return;
    final result = await AppScope.of(context).getMatch(id);
    if (!mounted || result == null) return;
    setState(() => match = result);
    final status = '${result['status']}';
    if (status == 'ACTIVE' || status == 'COMPLETED') {
      navigating = true;
      timer?.cancel();
      Navigator.pushReplacementNamed(context, Routes.game, arguments: {'matchId': id});
    } else if (status == 'CANCELLED' || status == 'REFUNDED') {
      navigating = true;
      timer?.cancel();
      _snack(context, status == 'REFUNDED' ? 'Room cancelled and wager refunded' : 'Room cancelled');
      Navigator.pushNamedAndRemoveUntil(context, Routes.shell, (_) => false);
    }
  }

  Future<void> _leave() async {
    if (navigating) return;
    final controller = AppScope.of(context);
    final players = (match?['players'] as List?) ?? const [];
    final currentId = '${controller.currentUser?['id'] ?? ''}';
    final hostId = players.isEmpty ? '' : '${(players.first as Map)['userId'] ?? ''}';
    final isHost = currentId == hostId;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.tr(isHost ? 'Cancel room?' : 'Leave room?')),
        content: Text(context.tr(isHost
            ? 'Cancelling the room returns every reserved wager before the match starts.'
            : 'Leaving before the match starts returns your reserved wager.')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: Text(context.tr('Continue waiting'))),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: Text(context.tr(isHost ? 'Cancel room' : 'Leave room'))),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final ok = isHost ? await controller.cancelMatch(id) : await controller.leaveWaitingRoom(id);
    if (!mounted) return;
    if (!ok) {
      _snack(context, controller.errorMessage ?? 'Could not leave the room');
      return;
    }
    navigating = true;
    timer?.cancel();
    Navigator.pushNamedAndRemoveUntil(context, Routes.shell, (_) => false);
  }

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    final players = (match?['players'] as List?) ?? const [];
    final maxPlayers = int.tryParse('${match?['maxPlayers'] ?? 0}') ?? 0;
    final currentId = '${controller.currentUser?['id'] ?? ''}';
    final hostId = players.isEmpty ? '' : '${(players.first as Map)['userId'] ?? ''}';
    final canStart = players.length == maxPlayers && currentId == hostId && '${match?['status']}' != 'ACTIVE';
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) { if (!didPop) _leave(); },
      child: AppPage(title: 'Waiting Room', showBack: false, actions: [
        IconButton(onPressed: _refresh, icon: const Icon(Icons.refresh_rounded)),
        IconButton(onPressed: _leave, icon: const Icon(Icons.close_rounded)),
      ], child: match == null
      ? const Center(child: Padding(padding: EdgeInsets.all(50), child: CircularProgressIndicator(color: AppColors.gold)))
      : Column(children: [
          GradientPanel(borderColor: AppColors.gold, child: Column(children: [Text(context.tr('ROOM CODE'), style: const TextStyle(color: AppColors.muted)), const SizedBox(height: 7), Text('${match!['publicCode'] ?? ''}', style: const TextStyle(color: AppColors.gold, fontWeight: FontWeight.w900, fontSize: 29, letterSpacing: 3)), const SizedBox(height: 8), Text('${match!['mode']} • ${(match!['ruleSet'] as Map?)?['code'] ?? ''} • ${_double(match!['stakeAmount']).toStringAsFixed(2)} MRU', style: const TextStyle(color: AppColors.muted, fontSize: 10))])),
          const SizedBox(height: 16),
          SectionTitle('Players (${players.length}/$maxPlayers)'),
          ...players.map((raw) { final player = (raw as Map).cast<String, dynamic>(); final user = (player['user'] as Map?)?.cast<String, dynamic>() ?? const <String, dynamic>{}; final profile = (user['profile'] as Map?)?.cast<String, dynamic>() ?? const <String, dynamic>{}; final name = '${profile['displayName'] ?? user['username'] ?? ''}'; return GradientPanel(margin: const EdgeInsets.only(bottom: 9), child: Row(children: [PlayerAvatar(name: name, avatarUrl: profile['avatarUrl']?.toString(), level: int.tryParse('${profile['level'] ?? 1}') ?? 1), const SizedBox(width: 12), Expanded(child: Text(name, style: const TextStyle(fontWeight: FontWeight.w900))), StatusBadge('${player['color'] ?? 'WAITING'}', color: AppColors.green)])); }),
          if (players.length < maxPlayers) const EmptyState(icon: Icons.hourglass_top_rounded, title: 'Waiting for players', message: 'Open the application on another device or emulator with another account and join the same room code.'),
          if (canStart) GoldButton(label: 'Start Match', loading: controller.busy, onPressed: controller.busy ? null : () async { final result = await controller.startMatch(id); if (!context.mounted) return; if (result == null) _snack(context, controller.errorMessage ?? 'Match start failed'); else Navigator.pushReplacementNamed(context, Routes.game, arguments: {'matchId': id}); }),
          if (players.length == maxPlayers && !canStart) const EmptyState(icon: Icons.hourglass_bottom_rounded, title: 'Waiting for host', message: 'The host account must start the match.'),
          const SizedBox(height: 12),
          PurpleButton(label: currentId == hostId ? 'Cancel room' : 'Leave room', icon: Icons.exit_to_app_rounded, onPressed: controller.busy ? null : _leave),
        ])),
    );
  }
}

class MatchResultScreen extends StatelessWidget {
  const MatchResultScreen({super.key, required this.type});
  final String type;
  @override
  Widget build(BuildContext context) => AppPage(title: 'Match result', child: Column(children: [
    EmptyState(icon: type == 'win' ? Icons.emoji_events_rounded : Icons.sports_esports_rounded, title: 'Match completed', message: 'The final result, wallet settlement and profile statistics are loaded from the backend after refresh.'),
    GoldButton(label: 'Back to Home', onPressed: () => Navigator.pushNamedAndRemoveUntil(context, Routes.shell, (_) => false)),
  ]));
}

class MatchDetailsScreen extends StatelessWidget {
  const MatchDetailsScreen({super.key});
  @override
  Widget build(BuildContext context) => const AppPage(title: 'Match details', child: EmptyState(icon: Icons.receipt_long_outlined, title: 'Open a real match from history', message: 'The connected game screen includes the current server state and event information.'));
}

class LudoGameScreen extends StatelessWidget {
  const LudoGameScreen({super.key, this.fourPlayers = false});
  final bool fourPlayers;
  @override
  Widget build(BuildContext context) => const AppPage(title: 'Game', child: EmptyState(icon: Icons.cloud_off_outlined, title: 'Local game removed', message: 'The local random game was removed. Open a match created by the backend.'));
}

class _InfoRow extends StatelessWidget {
  const _InfoRow(this.label, this.value, {this.strong = false});
  final String label;
  final String value;
  final bool strong;
  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.symmetric(vertical: 9), child: Row(children: [Expanded(child: Text(context.tr(label), style: const TextStyle(color: AppColors.muted))), Text(context.tr(value), style: TextStyle(color: strong ? AppColors.gold : Colors.white, fontWeight: strong ? FontWeight.w900 : FontWeight.w700))]));
}

Map<String, dynamic> _mapArgs(BuildContext context) => ((ModalRoute.of(context)?.settings.arguments as Map?) ?? const <String, dynamic>{}).cast<String, dynamic>();
double _double(dynamic value) => double.tryParse('$value') ?? 0;
double _setting(AppController controller, String key, double fallback) => double.tryParse('${controller.publicSettings?[key] ?? fallback}') ?? fallback;
void _snack(BuildContext context, String value) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.tr(value))));
