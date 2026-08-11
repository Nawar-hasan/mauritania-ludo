import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../core/app_controller.dart';
import '../core/app_theme.dart';
import '../core/routes.dart';
import '../core/widgets.dart';
import '../core/localization.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key, this.embedded = false});
  final bool embedded;

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    final profile = (controller.currentUser?['profile'] as Map?)?.cast<String, dynamic>() ?? const <String, dynamic>{};
    final level = _int(profile['level'], 1);
    final xp = _int(profile['xp'], 0);
    final wins = _int(profile['wins'], 0);
    final losses = _int(profile['losses'], 0);
    final matches = _int(profile['matches'], wins + losses);
    final rate = matches == 0 ? 0 : (wins / matches * 100);
    final stage = controller.currentStage(level);
    final stageName = stage == null ? '' : (controller.isArabic ? '${stage['nameAr'] ?? ''}' : '${stage['nameEn'] ?? ''}');
    final stageColor = _hexColor('${stage?['colorHex'] ?? ''}') ?? AppColors.gold;

    final content = RefreshIndicator(
      onRefresh: controller.refreshAll,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 28),
        children: [
          if (embedded) Text(context.tr('Profile'), style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 14),
          GradientPanel(borderColor: AppColors.gold, child: Column(children: [
            PlayerAvatar(name: controller.displayName, avatarUrl: controller.avatarUrl, size: 92, level: level),
            const SizedBox(height: 15),
            Text(controller.displayName, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 22)),
            const SizedBox(height: 4),
            Text('@${controller.username}', style: const TextStyle(color: AppColors.muted)),
            if (stageName.isNotEmpty) ...[
              const SizedBox(height: 9),
              Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), decoration: BoxDecoration(color: stageColor.withValues(alpha: .14), borderRadius: BorderRadius.circular(30), border: Border.all(color: stageColor)), child: Text(stageName, style: TextStyle(color: stageColor, fontWeight: FontWeight.w900, fontSize: 11))),
            ],
            const SizedBox(height: 14),
            ClipRRect(borderRadius: BorderRadius.circular(20), child: LinearProgressIndicator(value: controller.levelProgress(level: level, xp: xp), minHeight: 9, backgroundColor: AppColors.divider, color: AppColors.gold)),
            const SizedBox(height: 6),
            Builder(builder: (context) {
              final nextLevel = controller.nextLevelDefinition(level);
              final target = nextLevel == null ? null : int.tryParse('${nextLevel['xpRequired']}');
              return Text(target == null ? '$xp XP • ${context.tr('Maximum configured level')}' : '$xp / $target XP • ${context.tr('Next level')}: ${nextLevel?['level']}', style: const TextStyle(color: AppColors.muted, fontSize: 10));
            }),
            const SizedBox(height: 16),
            Row(children: [
              Expanded(child: _StatCard(label: 'Matches', value: '$matches')),
              Expanded(child: _StatCard(label: 'Wins', value: '$wins')),
              Expanded(child: _StatCard(label: 'Win rate', value: '${rate.toStringAsFixed(1)}%')),
            ]),
            const SizedBox(height: 14),
            Row(children: [
              Expanded(child: OutlinedButton.icon(onPressed: () => Navigator.pushNamed(context, Routes.editProfile), icon: const Icon(Icons.edit_outlined), label: Text(context.tr('Edit profile')))),
              const SizedBox(width: 8),
              Expanded(child: OutlinedButton.icon(onPressed: () => _changeAvatar(context), icon: const Icon(Icons.photo_camera_outlined), label: Text(context.tr('Change photo')))),
            ]),
          ])),
          const SizedBox(height: 18),
          OptionTile(icon: Icons.analytics_outlined, title: 'Statistics', subtitle: 'Real profile statistics returned by the server', onTap: () => Navigator.pushNamed(context, Routes.stats)),
          OptionTile(icon: Icons.history_rounded, title: 'Match history', subtitle: 'Matches stored in the backend', onTap: () => Navigator.pushNamed(context, Routes.matchHistory)),
          OptionTile(icon: Icons.inventory_2_outlined, title: 'Inventory', subtitle: 'Owned boards, dice, frames, backgrounds and special items', onTap: () => Navigator.pushNamed(context, Routes.inventory)),
          OptionTile(icon: Icons.military_tech_outlined, title: 'Achievements', subtitle: 'Progress, rewards and claimed achievements', onTap: () => Navigator.pushNamed(context, Routes.achievements)),
          OptionTile(icon: Icons.group_add_outlined, title: 'Invite friends', subtitle: 'Share your referral code and track invited players', onTap: () => Navigator.pushNamed(context, Routes.referrals)),
          OptionTile(icon: Icons.settings_outlined, title: 'Account settings', subtitle: 'Language, sound, privacy and account controls', onTap: () => Navigator.pushNamed(context, Routes.accountSettings)),
          OptionTile(icon: Icons.logout_rounded, title: 'Log out', subtitle: 'End the current authenticated session', color: AppColors.red, onTap: () => _logout(context)),
        ],
      ),
    );
    return embedded ? content : Scaffold(backgroundColor: AppColors.background, appBar: AppBar(title: Text(context.tr('Profile'))), body: Container(decoration: const BoxDecoration(gradient: AppGradients.background), child: content));
  }

  Future<void> _changeAvatar(BuildContext context) async {
    final source = await showModalBottomSheet<ImageSource>(context: context, backgroundColor: AppColors.surface, builder: (context) => SafeArea(child: Column(mainAxisSize: MainAxisSize.min, children: [
      ListTile(leading: const Icon(Icons.photo_library_outlined, color: AppColors.gold), title: Text(context.tr('Choose from gallery')), onTap: () => Navigator.pop(context, ImageSource.gallery)),
      ListTile(leading: const Icon(Icons.photo_camera_outlined, color: AppColors.cyan), title: Text(context.tr('Take a photo')), onTap: () => Navigator.pop(context, ImageSource.camera)),
    ])));
    if (source == null || !context.mounted) return;
    final image = await ImagePicker().pickImage(source: source, imageQuality: 82, maxWidth: 1600);
    if (image == null || !context.mounted) return;
    final controller = AppScope.of(context);
    final ok = await controller.uploadAvatarBytes(await image.readAsBytes(), image.name);
    if (!context.mounted) return;
    _message(context, ok ? 'Profile photo updated' : (controller.errorMessage ?? 'Profile photo update failed'));
  }

  Future<void> _logout(BuildContext context) async {
    final confirmed = await showDialog<bool>(context: context, builder: (context) => AlertDialog(title: Text(context.tr('Log out?')), content: Text(context.tr('This ends the current session on this device.')), actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: Text(context.tr('Cancel'))), FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(context.tr('Log out')))]));
    if (confirmed != true || !context.mounted) return;
    await AppScope.of(context).logout();
    if (context.mounted) Navigator.pushNamedAndRemoveUntil(context, Routes.login, (_) => false);
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.label, required this.value});
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => Column(children: [Text(value, style: const TextStyle(color: AppColors.gold, fontWeight: FontWeight.w900, fontSize: 18)), const SizedBox(height: 4), Text(context.tr(label), style: const TextStyle(color: AppColors.muted, fontSize: 10))]);
}

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});
  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final displayName = TextEditingController();
  final country = TextEditingController();
  final bio = TextEditingController();
  bool loaded = false;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (loaded) return;
    final profile = (AppScope.of(context).currentUser?['profile'] as Map?)?.cast<String, dynamic>() ?? const <String, dynamic>{};
    displayName.text = '${profile['displayName'] ?? ''}';
    country.text = '${profile['countryCode'] ?? ''}';
    bio.text = '${profile['bio'] ?? ''}';
    loaded = true;
  }
  @override
  void dispose() { displayName.dispose(); country.dispose(); bio.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    return AppPage(title: 'Edit profile', child: Column(children: [
      AppTextField(label: 'Display name', controller: displayName, icon: Icons.person_outline_rounded),
      const SizedBox(height: 14),
      AppTextField(label: 'Country code', hint: 'Two-letter code', controller: country, icon: Icons.flag_outlined),
      const SizedBox(height: 14),
      AppTextField(label: 'Bio', controller: bio, icon: Icons.notes_rounded, maxLines: 4),
      const SizedBox(height: 22),
      GoldButton(label: 'Save changes', loading: controller.busy, onPressed: controller.busy ? null : () async {
        final normalizedCountry = country.text.trim().toUpperCase();
        if (normalizedCountry.isNotEmpty && normalizedCountry.length != 2) { _message(context, 'Country code must contain two letters'); return; }
        final ok = await controller.updateProfile(displayName: displayName.text.trim(), countryCode: normalizedCountry, bio: bio.text.trim());
        if (!context.mounted) return;
        if (ok) Navigator.pop(context); else _message(context, controller.errorMessage ?? 'Profile update failed');
      }),
    ]));
  }
}

class StatsScreen extends StatelessWidget {
  const StatsScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final profile = (AppScope.of(context).currentUser?['profile'] as Map?)?.cast<String, dynamic>() ?? const <String, dynamic>{};
    final values = <(String, dynamic, IconData)>[
      ('Level', profile['level'] ?? 1, Icons.stairs_rounded),
      ('Experience', profile['xp'] ?? 0, Icons.auto_graph_rounded),
      ('Matches', profile['matches'] ?? 0, Icons.sports_esports_rounded),
      ('Wins', profile['wins'] ?? 0, Icons.emoji_events_outlined),
      ('Losses', profile['losses'] ?? 0, Icons.close_rounded),
    ];
    return AppPage(
      title: 'Statistics',
      child: Column(
        children: values.map((item) => GradientPanel(
          margin: const EdgeInsets.only(bottom: 10),
          child: Row(children: [
            Icon(item.$3, color: AppColors.gold),
            const SizedBox(width: 12),
            Expanded(child: Text(context.tr(item.$1), style: const TextStyle(fontWeight: FontWeight.w800))),
            Text('${item.$2}', style: const TextStyle(color: AppColors.gold, fontWeight: FontWeight.w900, fontSize: 18)),
          ]),
        )).toList(),
      ),
    );
  }
}

class MatchHistoryScreen extends StatelessWidget {
  const MatchHistoryScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    return AppPage(title: 'Match history', actions: [IconButton(onPressed: controller.refreshAll, icon: const Icon(Icons.refresh_rounded))], child: controller.matches.isEmpty
      ? const EmptyState(icon: Icons.history_rounded, title: 'No matches yet', message: 'Real matches created or joined by this account will appear here.')
      : Column(children: controller.matches.map((match) {
          final status = '${match['status'] ?? ''}';
          return GradientPanel(margin: const EdgeInsets.only(bottom: 10), onTap: () { final id = '${match['id'] ?? ''}'; if (id.isNotEmpty) Navigator.pushNamed(context, Routes.game, arguments: {'matchId': id}); }, child: Row(children: [
            const CircleAvatar(backgroundColor: AppColors.surface, child: Icon(Icons.casino_rounded, color: AppColors.gold)),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('${context.tr('Match')} #${match['publicCode'] ?? ''}', style: const TextStyle(fontWeight: FontWeight.w900)), const SizedBox(height: 4), Text('${match['mode'] ?? ''} • ${match['maxPlayers'] ?? ''} ${context.tr('Players')}', style: const TextStyle(color: AppColors.muted, fontSize: 10))])),
            StatusBadge(status, color: status == 'COMPLETED' ? AppColors.green : AppColors.orange),
          ]));
        }).toList()));
  }
}

class InventoryScreen extends StatelessWidget {
  const InventoryScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    return AppPage(
      title: 'Inventory',
      actions: [IconButton(onPressed: controller.refreshAll, icon: const Icon(Icons.refresh_rounded))],
      child: controller.inventory.isEmpty
        ? const EmptyState(icon: Icons.inventory_2_outlined, title: 'Inventory is empty', message: 'Purchased and rewarded boards, dice, frames and other items will appear here.')
        : Column(children: controller.inventory.map((entry) {
            final item = (entry['item'] as Map?)?.cast<String,dynamic>() ?? const <String,dynamic>{};
            final name = controller.isArabic ? '${item['nameAr'] ?? ''}' : '${item['nameEn'] ?? ''}';
            final equipped = entry['equipped'] == true;
            return GradientPanel(margin: const EdgeInsets.only(bottom: 10), child: Row(children: [
              CircleAvatar(backgroundColor: AppColors.surface, child: const Icon(Icons.auto_awesome_rounded, color: AppColors.gold)),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(name, style: const TextStyle(fontWeight: FontWeight.w900)), Text('${item['type'] ?? ''} • x${entry['quantity'] ?? 1}', style: const TextStyle(color: AppColors.muted, fontSize: 10))])),
              if (equipped) const StatusBadge('EQUIPPED', color: AppColors.green) else TextButton(onPressed: controller.busy ? null : () => controller.equipCatalogItem('${item['id']}'), child: Text(context.tr('Equip'))),
            ]));
          }).toList()),
    );
  }
}

class AccountSettingsScreen extends StatelessWidget {
  const AccountSettingsScreen({super.key});
  @override
  Widget build(BuildContext context) => AppPage(title: 'Account settings', child: Column(children: [
    OptionTile(icon: Icons.language_rounded, title: 'Language', subtitle: 'Switch the whole application between Arabic and English', onTap: () => _language(context)),
    OptionTile(icon: Icons.volume_up_outlined, title: 'Sound', subtitle: 'Interface sound and vibration feedback', onTap: () => Navigator.pushNamed(context, Routes.soundSettings)),
    OptionTile(icon: Icons.privacy_tip_outlined, title: 'Privacy', subtitle: 'Server-stored privacy preferences for social features', onTap: () => Navigator.pushNamed(context, Routes.privacySettings)),
    OptionTile(icon: Icons.verified_user_outlined, title: 'Identity & age verification', subtitle: 'Verification status for protected money features', onTap: () => Navigator.pushNamed(context, Routes.identityVerification)),
    OptionTile(icon: Icons.support_agent_rounded, title: 'Support', subtitle: 'Create tickets and follow support replies', onTap: () => Navigator.pushNamed(context, Routes.support)),
    OptionTile(icon: Icons.info_outline_rounded, title: 'About', subtitle: 'Application and environment information', onTap: () => Navigator.pushNamed(context, Routes.about)),
  ]));

  void _language(BuildContext context) {
    final controller = AppScope.of(context);
    showModalBottomSheet<void>(context: context, backgroundColor: AppColors.surface, builder: (context) => SafeArea(child: Column(mainAxisSize: MainAxisSize.min, children: [
      ListTile(title: const Text('العربية'), trailing: controller.isArabic ? const Icon(Icons.check_circle, color: AppColors.gold) : null, onTap: () async { await controller.setArabic(true); if (context.mounted) Navigator.pop(context); }),
      ListTile(title: const Text('English'), trailing: !controller.isArabic ? const Icon(Icons.check_circle, color: AppColors.gold) : null, onTap: () async { await controller.setArabic(false); if (context.mounted) Navigator.pop(context); }),
    ])));
  }
}

class SoundSettingsScreen extends StatefulWidget {
  const SoundSettingsScreen({super.key});
  @override
  State<SoundSettingsScreen> createState() => _SoundSettingsScreenState();
}
class _SoundSettingsScreenState extends State<SoundSettingsScreen> {
  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    return AppPage(title: 'Sound', child: Column(children: [
      GradientPanel(child: Column(children: [
        SwitchListTile(
          value: controller.effectsEnabled,
          activeThumbColor: AppColors.gold,
          onChanged: (v) async { await controller.toggleEffects(v); if (mounted) setState(() {}); },
          title: Text(context.tr('Interface sound')),
          subtitle: Text(context.tr('Use the system click sound on primary interactions.')),
        ),
        SwitchListTile(
          value: controller.vibrationEnabled,
          activeThumbColor: AppColors.gold,
          onChanged: (v) async { await controller.toggleVibration(v); if (mounted) setState(() {}); },
          title: Text(context.tr('Vibration')),
          subtitle: Text(context.tr('Use haptic feedback on primary interactions.')),
        ),
      ])),
    ]));
  }
}

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});
  @override
  Widget build(BuildContext context) => AppPage(title: 'About', child: Column(children: [
    const ScreenHeader(title: 'MAURITANIA LUDO', subtitle: 'Connected staging build', icon: Icons.casino_rounded),
    const SizedBox(height: 18),
    GradientPanel(child: Text(context.tr('This release connects authentication and recovery, profile, wallet, payments, store, inventory, appearance, levels, stages, transactions, authoritative online matches, wager reservation and settlement, offline practice, social rooms, tournaments, leaderboard, referrals, achievements, privacy, identity review and support tickets. Live voice audio and automatic payment processing activate through their selected provider APIs.'), textAlign: TextAlign.center, style: const TextStyle(color: AppColors.muted, height: 1.5))),
  ]));
}

int _int(dynamic value, int fallback) => int.tryParse('$value') ?? fallback;
void _message(BuildContext context, String value) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.tr(value))));

Color? _hexColor(String value) {
  final normalized = value.replaceAll('#', '');
  if (normalized.length != 6) return null;
  final parsed = int.tryParse('FF$normalized', radix: 16);
  return parsed == null ? null : Color(parsed);
}
