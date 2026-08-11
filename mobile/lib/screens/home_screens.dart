import 'package:flutter/material.dart';
import '../core/app_controller.dart';
import '../core/api_config.dart';
import '../core/app_theme.dart';
import '../core/routes.dart';
import '../core/widgets.dart';
import '../core/localization.dart';
import 'profile_screens.dart';
import 'social_screens.dart';
import 'store_screens.dart';
import 'wallet_screens.dart';

class MainShellScreen extends StatefulWidget {
  const MainShellScreen({super.key});
  @override
  State<MainShellScreen> createState() => _MainShellScreenState();
}

class _MainShellScreenState extends State<MainShellScreen> {
  int index = 0;

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      HomeScreen(onTabChange: (value) => setState(() => index = value)),
      const StoreScreen(embedded: true),
      const RoomsScreen(embedded: true),
      const WalletScreen(embedded: true),
      const ProfileScreen(embedded: true),
    ];
    final controller = AppScope.of(context);
    final campaign = controller.activeCampaign('APP_BACKGROUND');
    final equippedBackground = controller.equippedItem('BACKGROUND');
    final imageUrl = ApiConfig.resolveAssetUrl(campaign?['imageUrl'] ?? equippedBackground?['imageUrl']);
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Container(
        decoration: BoxDecoration(
          gradient: AppGradients.background,
          image: imageUrl.isEmpty
              ? null
              : DecorationImage(
                  image: NetworkImage(imageUrl),
                  fit: BoxFit.cover,
                  colorFilter: ColorFilter.mode(Colors.black.withValues(alpha: .38), BlendMode.darken),
                ),
        ),
        child: SafeArea(child: IndexedStack(index: index, children: pages)),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (value) => setState(() => index = value),
        backgroundColor: AppColors.surface,
        indicatorColor: AppColors.gold.withValues(alpha: 0.18),
        destinations: [
          NavigationDestination(icon: const Icon(Icons.home_outlined), selectedIcon: const Icon(Icons.home_rounded, color: AppColors.gold), label: context.tr('Home')),
          NavigationDestination(icon: const Icon(Icons.storefront_outlined), selectedIcon: const Icon(Icons.storefront_rounded, color: AppColors.gold), label: context.tr('Store')),
          NavigationDestination(icon: const Icon(Icons.forum_outlined), selectedIcon: const Icon(Icons.forum_rounded, color: AppColors.gold), label: context.tr('Rooms')),
          NavigationDestination(icon: const Icon(Icons.account_balance_wallet_outlined), selectedIcon: const Icon(Icons.account_balance_wallet_rounded, color: AppColors.gold), label: context.tr('Wallet')),
          NavigationDestination(icon: const Icon(Icons.person_outline_rounded), selectedIcon: const Icon(Icons.person_rounded, color: AppColors.gold), label: context.tr('Profile')),
        ],
      ),
    );
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, required this.onTabChange});
  final ValueChanged<int> onTabChange;

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    final profile = (controller.currentUser?['profile'] as Map?)?.cast<String, dynamic>() ?? const <String, dynamic>{};
    final level = int.tryParse('${profile['level'] ?? 1}') ?? 1;
    final unread = controller.notifications.where((item) => item['readAt'] == null).length;
    final recent = controller.matches.isEmpty ? null : controller.matches.first;
    final homeCampaign = controller.activeCampaign('HOME_BANNER');

    return RefreshIndicator(
      onRefresh: controller.refreshAll,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 28),
        children: [
          Row(children: [
            PlayerAvatar(name: controller.displayName, avatarUrl: controller.avatarUrl, size: 56, level: level),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(context.tr('Welcome back,'), style: const TextStyle(color: AppColors.muted, fontSize: 12)),
              Text(controller.displayName.isEmpty ? controller.username : controller.displayName, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
              const SizedBox(height: 4),
              StatusBadge('${context.tr('Level')} $level', color: AppColors.gold),
            ])),
            Stack(children: [
              IconButton(onPressed: () => Navigator.pushNamed(context, Routes.notifications), icon: const Icon(Icons.notifications_none_rounded)),
              if (unread > 0) Positioned(top: 4, right: 4, child: CircleAvatar(radius: 9, backgroundColor: AppColors.red, child: Text('$unread', style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w900)))),
            ]),
            IconButton(onPressed: () => _showQuickSettings(context), icon: const Icon(Icons.settings_outlined)),
          ]),
          const SizedBox(height: 16),
          Wrap(spacing: 8, runSpacing: 8, children: [
            BalancePill(icon: Icons.account_balance_wallet_rounded, value: '${controller.walletBalance.toStringAsFixed(0)} MRU', color: AppColors.green, label: 'Cash balance'),
            BalancePill(icon: Icons.lock_outline_rounded, value: '${controller.lockedBalance.toStringAsFixed(0)} MRU', color: AppColors.orange, label: 'Locked balance'),
            BalancePill(icon: Icons.monetization_on_outlined, value: '${controller.coins}', color: AppColors.gold, label: 'Coins'),
            BalancePill(icon: Icons.diamond_outlined, value: '${controller.gems}', color: AppColors.cyan, label: 'Gems'),
          ]),
          const SizedBox(height: 18),
          if (homeCampaign != null) ...[
            _HomeCampaignBanner(campaign: homeCampaign, onTabChange: onTabChange),
            const SizedBox(height: 18),
          ],
          GradientPanel(
            borderColor: AppColors.green,
            child: Row(children: [
              Container(width: 54, height: 54, decoration: BoxDecoration(color: AppColors.green.withValues(alpha: .13), borderRadius: BorderRadius.circular(16)), child: const Icon(Icons.cloud_done_rounded, color: AppColors.green, size: 30)),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(context.tr('Online services connected'), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                const SizedBox(height: 5),
                Text(context.tr('Wallet, matches, store and progression are synchronized with the server. Pull down to refresh.'), style: const TextStyle(color: AppColors.muted, height: 1.35, fontSize: 11)),
              ])),
            ]),
          ),
          const SizedBox(height: 20),
          const SectionTitle('Play', subtitle: 'Choose casual, cash wager, private room or offline practice.'),
          Row(children: [
            Expanded(child: _MainGameCard(title: 'Casual Match', subtitle: 'Online • No cash wager', icon: Icons.sports_esports_rounded, gradient: AppGradients.cyan, dark: true, onTap: () => Navigator.pushNamed(context, Routes.playerCount, arguments: 'casual'))),
            const SizedBox(width: 10),
            Expanded(child: _MainGameCard(title: 'Wager Match', subtitle: 'Choose stake • Winner takes prize', icon: Icons.payments_rounded, gradient: AppGradients.gold, dark: true, onTap: () => Navigator.pushNamed(context, Routes.playerCount, arguments: 'wager'))),
          ]),
          const SizedBox(height: 12),
          GradientPanel(borderColor: AppColors.gold, onTap: () => Navigator.pushNamed(context, Routes.playerCount, arguments: 'wager'), child: Row(children: [
            const Icon(Icons.verified_user_rounded, color: AppColors.gold, size: 36), const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(context.tr('Cash wagering'), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)), const SizedBox(height: 4), Text(context.tr('Select 2 or 4 players, choose the rules, then choose your stake. The server locks each player stake before the match and settles the prize after the verified result.'), style: const TextStyle(color: AppColors.muted, height: 1.4, fontSize: 10))])),
            const Icon(Icons.chevron_right_rounded),
          ])),
          const SizedBox(height: 14),
          Row(children: [
            Expanded(child: _QuickAccess(icon: Icons.offline_bolt_rounded, label: 'Offline Play', color: AppColors.cyan, onTap: () => Navigator.pushNamed(context, Routes.offlineMode))),
            Expanded(child: _QuickAccess(icon: Icons.key_rounded, label: 'Private Room', color: AppColors.purpleLight, onTap: () => Navigator.pushNamed(context, Routes.privateRoom))),
            Expanded(child: _QuickAccess(icon: Icons.account_balance_wallet_rounded, label: 'Wallet', color: AppColors.green, onTap: () => onTabChange(3))),
          ]),
          const SizedBox(height: 22),
          SectionTitle('Recent match', trailing: TextButton(onPressed: () => Navigator.pushNamed(context, Routes.matchHistory), child: Text(context.tr('View all')))),
          if (recent == null)
            const EmptyState(icon: Icons.sports_esports_outlined, title: 'No matches yet', message: 'Start a casual or wager match, or use offline practice while you wait for other players.')
          else
            _RecentMatchCard(match: recent),
        ],
      ),
    );
  }

  void _showQuickSettings(BuildContext context) {
    showModalBottomSheet<void>(context: context, backgroundColor: AppColors.surface, shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))), builder: (_) => const QuickSettingsSheet());
  }
}


class _HomeCampaignBanner extends StatelessWidget {
  const _HomeCampaignBanner({required this.campaign, required this.onTabChange});
  final Map<String, dynamic> campaign;
  final ValueChanged<int> onTabChange;

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    final imageUrl = ApiConfig.resolveAssetUrl(campaign['imageUrl']);
    final title = controller.isArabic
        ? '${campaign['nameAr'] ?? campaign['nameEn'] ?? ''}'
        : '${campaign['nameEn'] ?? campaign['nameAr'] ?? ''}';
    final actionType = '${campaign['actionType'] ?? ''}'.toUpperCase();
    final actionValue = '${campaign['actionValue'] ?? ''}';
    return InkWell(
      onTap: actionType.isEmpty ? null : () => _openAction(context, actionType, actionValue),
      borderRadius: BorderRadius.circular(24),
      child: Container(
        height: 160,
        padding: const EdgeInsets.all(18),
        alignment: controller.isArabic ? Alignment.bottomRight : Alignment.bottomLeft,
        decoration: BoxDecoration(
          color: _campaignHex('${campaign['backgroundColor'] ?? ''}') ?? AppColors.surface2,
          image: imageUrl.isEmpty
              ? null
              : DecorationImage(
                  image: NetworkImage(imageUrl),
                  fit: BoxFit.cover,
                  colorFilter: ColorFilter.mode(Colors.black.withValues(alpha: .28), BlendMode.darken),
                ),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppColors.gold.withValues(alpha: .58)),
          boxShadow: [BoxShadow(color: AppColors.gold.withValues(alpha: .12), blurRadius: 20, offset: const Offset(0, 8))],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 20, shadows: [Shadow(color: Colors.black, blurRadius: 8)]))),
            if (actionType.isNotEmpty) const Icon(Icons.arrow_forward_rounded, color: AppColors.gold),
          ],
        ),
      ),
    );
  }

  void _openAction(BuildContext context, String type, String value) {
    switch (type) {
      case 'STORE': onTabChange(1); break;
      case 'WALLET': onTabChange(3); break;
      case 'PROFILE': onTabChange(4); break;
      case 'PRIVATE_ROOM': Navigator.pushNamed(context, Routes.privateRoom); break;
      case 'RULES': Navigator.pushNamed(context, Routes.rules, arguments: {'mode': value.isEmpty ? 'casual' : value, 'players': 2}); break;
      case 'ROUTE': if (value.isNotEmpty) Navigator.pushNamed(context, value); break;
    }
  }
}

Color? _campaignHex(String raw) {
  final value = raw.replaceAll('#', '').trim();
  if (value.length != 6 && value.length != 8) return null;
  return Color(int.parse(value.length == 6 ? 'FF$value' : value, radix: 16));
}

class _RecentMatchCard extends StatelessWidget {
  const _RecentMatchCard({required this.match});
  final Map<String, dynamic> match;
  @override
  Widget build(BuildContext context) {
    final status = '${match['status'] ?? ''}';
    final players = (match['players'] as List?) ?? const [];
    final code = '${match['publicCode'] ?? ''}';
    return GradientPanel(
      onTap: () {
        final id = '${match['id'] ?? ''}';
        if (id.isNotEmpty) Navigator.pushNamed(context, Routes.game, arguments: {'matchId': id});
      },
      child: Row(children: [
        CircleAvatar(backgroundColor: AppColors.gold.withValues(alpha: .14), child: const Icon(Icons.casino_rounded, color: AppColors.gold)),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('${context.tr('Match')} #$code', style: const TextStyle(fontWeight: FontWeight.w900)),
          const SizedBox(height: 4),
          Text('${context.tr('Players')}: ${players.length}/${match['maxPlayers'] ?? 0}', style: const TextStyle(color: AppColors.muted, fontSize: 11)),
        ])),
        StatusBadge(status, color: status == 'COMPLETED' ? AppColors.green : AppColors.orange),
      ]),
    );
  }
}

class _MainGameCard extends StatelessWidget {
  const _MainGameCard({required this.title, required this.subtitle, required this.icon, required this.gradient, required this.onTap, this.dark = false});
  final String title;
  final String subtitle;
  final IconData icon;
  final Gradient gradient;
  final VoidCallback onTap;
  final bool dark;
  @override
  Widget build(BuildContext context) => GradientPanel(onTap: onTap, gradient: gradient, borderColor: AppColors.gold, padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 20), child: Column(children: [
    Icon(icon, size: 46, color: dark ? AppColors.background2 : Colors.white),
    const SizedBox(height: 12),
    Text(context.tr(title), textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.w900, color: dark ? AppColors.background2 : Colors.white, fontSize: 16)),
    const SizedBox(height: 4),
    Text(context.tr(subtitle), textAlign: TextAlign.center, style: TextStyle(color: dark ? const Color(0xFF61421C) : Colors.white70, fontSize: 10)),
  ]));
}

class _QuickAccess extends StatelessWidget {
  const _QuickAccess({required this.icon, required this.label, required this.color, required this.onTap});
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => InkWell(onTap: onTap, borderRadius: BorderRadius.circular(18), child: Column(children: [
    Container(width: 58, height: 58, decoration: BoxDecoration(color: color.withValues(alpha: .15), borderRadius: BorderRadius.circular(18), border: Border.all(color: color.withValues(alpha: .6))), child: Icon(icon, color: color, size: 29)),
    const SizedBox(height: 7),
    Text(context.tr(label), textAlign: TextAlign.center, style: const TextStyle(fontSize: 10, color: AppColors.muted, fontWeight: FontWeight.w700)),
  ]));
}

class QuickSettingsSheet extends StatefulWidget {
  const QuickSettingsSheet({super.key});
  @override
  State<QuickSettingsSheet> createState() => _QuickSettingsSheetState();
}

class _QuickSettingsSheetState extends State<QuickSettingsSheet> {
  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    return Padding(padding: EdgeInsets.fromLTRB(20, 16, 20, 20 + MediaQuery.paddingOf(context).bottom), child: Column(mainAxisSize: MainAxisSize.min, children: [
      Container(width: 48, height: 5, decoration: BoxDecoration(color: AppColors.divider, borderRadius: BorderRadius.circular(20))),
      const SizedBox(height: 18),
      const SectionTitle('Quick Settings'),
      SwitchListTile(value: controller.musicEnabled, activeThumbColor: AppColors.gold, onChanged: (value) { controller.toggleMusic(value); setState(() {}); }, title: Text(context.tr('Music')), secondary: const Icon(Icons.music_note_rounded, color: AppColors.gold)),
      SwitchListTile(value: controller.effectsEnabled, activeThumbColor: AppColors.gold, onChanged: (value) { controller.toggleEffects(value); setState(() {}); }, title: Text(context.tr('Sound effects')), secondary: const Icon(Icons.volume_up_rounded, color: AppColors.cyan)),
      SwitchListTile(value: controller.vibrationEnabled, activeThumbColor: AppColors.gold, onChanged: (value) { controller.toggleVibration(value); setState(() {}); }, title: Text(context.tr('Vibration')), secondary: const Icon(Icons.vibration_rounded, color: AppColors.orange)),
      const Divider(color: AppColors.divider),
      ListTile(leading: const Icon(Icons.language_rounded, color: AppColors.green), title: Text(context.tr('Language')), subtitle: Text(controller.isArabic ? 'العربية' : 'English'), trailing: const Icon(Icons.chevron_right_rounded), onTap: () => _showLanguagePicker(context)),
      ListTile(leading: const Icon(Icons.settings_outlined, color: AppColors.muted), title: Text(context.tr('Full settings')), trailing: const Icon(Icons.chevron_right_rounded), onTap: () { Navigator.pop(context); Navigator.pushNamed(context, Routes.accountSettings); }),
    ]));
  }

  void _showLanguagePicker(BuildContext context) {
    final controller = AppScope.of(context);
    showModalBottomSheet<void>(context: context, backgroundColor: AppColors.surface, shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))), builder: (context) => Padding(padding: EdgeInsets.fromLTRB(20, 16, 20, 20 + MediaQuery.paddingOf(context).bottom), child: Column(mainAxisSize: MainAxisSize.min, children: [
      const SectionTitle('Choose Language'),
      ListTile(leading: const Text('🇺🇸', style: TextStyle(fontSize: 27)), title: const Text('English'), trailing: !controller.isArabic ? const Icon(Icons.check_circle, color: AppColors.gold) : null, onTap: () async { await controller.setArabic(false); if (context.mounted) Navigator.pop(context); }),
      ListTile(leading: const Text('🇸🇦', style: TextStyle(fontSize: 27)), title: const Text('العربية'), trailing: controller.isArabic ? const Icon(Icons.check_circle, color: AppColors.gold) : null, onTap: () async { await controller.setArabic(true); if (context.mounted) Navigator.pop(context); }),
    ])));
  }
}

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    return AppPage(
      title: 'Notifications',
      actions: [TextButton(onPressed: controller.notifications.isEmpty ? null : controller.markNotificationsRead, child: Text(context.tr('Mark all read')))],
      child: controller.notifications.isEmpty
          ? const EmptyState(icon: Icons.notifications_none_rounded, title: 'No notifications', message: 'Wallet and match notifications from the server will appear here.')
          : Column(children: controller.notifications.map((item) {
              final read = item['readAt'] != null;
              return GradientPanel(margin: const EdgeInsets.only(bottom: 11), onTap: () { final id = '${item['id'] ?? ''}'; if (!read && id.isNotEmpty) controller.markNotificationRead(id); }, child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                CircleAvatar(backgroundColor: AppColors.gold.withValues(alpha: .14), child: const Icon(Icons.notifications_active_outlined, color: AppColors.gold)),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(context.tr('${item['title'] ?? item['type'] ?? 'Notification'}'), style: const TextStyle(fontWeight: FontWeight.w900)),
                  const SizedBox(height: 5),
                  Text(context.tr('${item['body'] ?? item['message'] ?? ''}'), style: const TextStyle(color: AppColors.muted, height: 1.35, fontSize: 11)),
                ])),
                if (!read) Container(width: 8, height: 8, decoration: const BoxDecoration(shape: BoxShape.circle, color: AppColors.gold)),
              ]));
            }).toList()),
    );
  }
}

class ScreenCatalogScreen extends StatelessWidget {
  const ScreenCatalogScreen({super.key});
  @override
  Widget build(BuildContext context) => const AppPage(title: 'Developer tools', child: EmptyState(icon: Icons.developer_mode_rounded, title: 'Catalog disabled', message: 'The production test build no longer exposes screens backed by mock data.'));
}
