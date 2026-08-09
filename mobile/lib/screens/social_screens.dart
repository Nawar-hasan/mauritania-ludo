import 'package:flutter/material.dart';
import '../core/app_theme.dart';
import '../core/widgets.dart';
import '../core/localization.dart';

Widget _moduleState(String title, String message, IconData icon) => EmptyState(icon: icon, title: title, message: message);

class RoomsScreen extends StatelessWidget {
  const RoomsScreen({super.key, this.embedded = false});
  final bool embedded;
  @override
  Widget build(BuildContext context) {
    final state = _moduleState('Social rooms are not connected yet', 'Mock rooms and members were removed. Voice rooms will be displayed only after the social backend and live audio provider are connected.', Icons.forum_outlined);
    if (embedded) return ListView(padding: const EdgeInsets.fromLTRB(18, 16, 18, 28), children: [Text(context.tr('Rooms'), style: Theme.of(context).textTheme.headlineSmall), state]);
    return AppPage(title: 'Rooms', child: state);
  }
}

class CreateVoiceRoomScreen extends StatelessWidget {
  const CreateVoiceRoomScreen({super.key});
  @override
  Widget build(BuildContext context) => AppPage(title: 'Create room', child: _moduleState('Voice room creation is disabled', 'A room will not be created locally. This feature requires the social backend and audio service.', Icons.mic_none_rounded));
}

class VoiceRoomScreen extends StatelessWidget {
  const VoiceRoomScreen({super.key});
  @override
  Widget build(BuildContext context) => AppPage(title: 'Rooms', child: _moduleState('No real room selected', 'Open this screen later from a room returned by the backend.', Icons.record_voice_over_outlined));
}

class TournamentsScreen extends StatelessWidget {
  const TournamentsScreen({super.key});
  @override
  Widget build(BuildContext context) => AppPage(title: 'Tournaments', child: _moduleState('Tournaments are not connected yet', 'Mock brackets, prizes and participants were removed. The module will appear after tournament tables and administration tools are implemented.', Icons.emoji_events_outlined));
}

class TournamentDetailsScreen extends StatelessWidget {
  const TournamentDetailsScreen({super.key});
  @override
  Widget build(BuildContext context) => AppPage(title: 'Tournament details', child: _moduleState('No real tournament selected', 'Tournament details must come from the backend.', Icons.emoji_events_outlined));
}

class BracketScreen extends StatelessWidget {
  const BracketScreen({super.key});
  @override
  Widget build(BuildContext context) => AppPage(title: 'Tournament bracket', child: _moduleState('No real bracket available', 'The bracket will be generated from real tournament matches.', Icons.account_tree_outlined));
}

class LeaderboardScreen extends StatelessWidget {
  const LeaderboardScreen({super.key});
  @override
  Widget build(BuildContext context) => AppPage(title: 'Leaderboard', child: _moduleState('Leaderboard is not connected yet', 'Player rankings will be calculated by the backend, not by static application data.', Icons.leaderboard_outlined));
}
