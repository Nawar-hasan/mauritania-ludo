import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import '../core/app_controller.dart';
import '../core/app_theme.dart';
import '../core/localization.dart';
import '../core/motion.dart';
import '../core/routes.dart';
import '../core/widgets.dart';

String _text(dynamic value) => value?.toString() ?? '';
int _intValue(dynamic value) => int.tryParse(_text(value)) ?? 0;
double _doubleValue(dynamic value) => double.tryParse(_text(value)) ?? 0;

void _snack(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.tr(message))));
}

Color _statusColor(String status) {
  switch (status) {
    case 'COMPLETED':
    case 'RESOLVED':
    case 'WINNER':
    case 'VERIFIED':
      return AppColors.green;
    case 'ACTIVE':
    case 'OPEN':
    case 'READY':
    case 'IN_PROGRESS':
      return AppColors.gold;
    case 'CANCELLED':
    case 'CLOSED':
    case 'REJECTED':
    case 'ELIMINATED':
      return AppColors.red;
    default:
      return AppColors.cyan;
  }
}

class FinalForgotPasswordScreen extends StatefulWidget {
  const FinalForgotPasswordScreen({super.key});
  @override
  State<FinalForgotPasswordScreen> createState() => _FinalForgotPasswordScreenState();
}

class _FinalForgotPasswordScreenState extends State<FinalForgotPasswordScreen> {
  final identifier = TextEditingController();
  @override
  void dispose() { identifier.dispose(); super.dispose(); }

  Future<void> submit() async {
    final value = identifier.text.trim();
    if (value.length < 3) { _snack(context, 'Enter your email, phone or username'); return; }
    final c = AppScope.of(context);
    final result = await c.requestPasswordReset(value);
    if (!mounted) return;
    if (result == null) { _snack(context, c.errorMessage ?? 'Password reset request failed'); return; }
    if (result['deliveryConfigured'] != true) {
      _snack(context, 'Recovery email provider is not configured yet');
      return;
    }
    Navigator.pushNamed(context, Routes.otp, arguments: {
      'requestId': _text(result['requestId']),
      'destination': _text(result['destination']),
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = AppScope.of(context);
    return AppPage(
      title: 'Forgot Password',
      child: Column(children: [
        const AppReveal(child: ScreenHeader(title: 'Recover account', subtitle: 'We will send a secure 6-digit verification code to your registered email.', icon: Icons.lock_reset_rounded)),
        const SizedBox(height: 24),
        AppReveal(delay: const Duration(milliseconds: 90), child: AppTextField(controller: identifier, label: 'Email, phone or username', icon: Icons.alternate_email_rounded, textDirection: TextDirection.ltr)),
        const SizedBox(height: 18),
        AppReveal(delay: const Duration(milliseconds: 160), child: GoldButton(label: 'Send verification code', loading: c.busy, onPressed: c.busy ? null : submit, icon: Icons.mark_email_read_outlined)),
        const SizedBox(height: 12),
        Text(context.tr('For security, the same response is shown whether or not the account exists.'), textAlign: TextAlign.center, style: const TextStyle(color: AppColors.muted, fontSize: 11)),
      ]),
    );
  }
}

class FinalOtpScreen extends StatefulWidget {
  const FinalOtpScreen({super.key, required this.requestId, this.destination = ''});
  final String requestId;
  final String destination;
  @override
  State<FinalOtpScreen> createState() => _FinalOtpScreenState();
}

class _FinalOtpScreenState extends State<FinalOtpScreen> {
  final code = TextEditingController();
  @override void dispose() { code.dispose(); super.dispose(); }
  Future<void> verify() async {
    final value = code.text.replaceAll(RegExp(r'\D'), '');
    if (value.length != 6) { _snack(context, 'Enter the 6-digit code'); return; }
    final c = AppScope.of(context);
    final result = await c.verifyPasswordReset(widget.requestId, value);
    if (!mounted) return;
    if (result == null) { _snack(context, c.errorMessage ?? 'Verification failed'); return; }
    Navigator.pushReplacementNamed(context, Routes.resetPassword, arguments: {
      'requestId': _text(result['requestId']),
      'resetToken': _text(result['resetToken']),
    });
  }
  @override
  Widget build(BuildContext context) {
    final c = AppScope.of(context);
    return AppPage(title: 'Verification Code', child: Column(children: [
      AppReveal(child: ScreenHeader(title: 'Check your email', subtitle: widget.destination.isEmpty ? 'Enter the 6-digit verification code.' : '${context.tr('Code sent to')} ${widget.destination}', icon: Icons.verified_user_rounded)),
      const SizedBox(height: 24),
      AppTextField(controller: code, label: 'Verification code', keyboardType: TextInputType.number, textDirection: TextDirection.ltr, textAlign: TextAlign.center, icon: Icons.pin_outlined),
      const SizedBox(height: 18),
      GoldButton(label: 'Verify code', loading: c.busy, onPressed: c.busy ? null : verify, icon: Icons.verified_rounded),
    ]));
  }
}

class FinalResetPasswordScreen extends StatefulWidget {
  const FinalResetPasswordScreen({super.key, required this.requestId, required this.resetToken});
  final String requestId;
  final String resetToken;
  @override State<FinalResetPasswordScreen> createState() => _FinalResetPasswordScreenState();
}

class _FinalResetPasswordScreenState extends State<FinalResetPasswordScreen> {
  final password = TextEditingController();
  final confirm = TextEditingController();
  @override void dispose() { password.dispose(); confirm.dispose(); super.dispose(); }
  Future<void> submit() async {
    if (password.text.length < 10) { _snack(context, 'Password must be at least 10 characters'); return; }
    if (password.text != confirm.text) { _snack(context, 'Passwords do not match'); return; }
    final c = AppScope.of(context);
    final ok = await c.completePasswordReset(widget.requestId, widget.resetToken, password.text);
    if (!mounted) return;
    if (!ok) { _snack(context, c.errorMessage ?? 'Password reset failed'); return; }
    Navigator.pushNamedAndRemoveUntil(context, Routes.resetSuccess, (_) => false);
  }
  @override Widget build(BuildContext context) {
    final c = AppScope.of(context);
    return AppPage(title: 'New Password', child: Column(children: [
      const AppReveal(child: ScreenHeader(title: 'Create a new password', subtitle: 'Use at least 10 characters and do not reuse an old password.', icon: Icons.password_rounded)),
      const SizedBox(height: 24),
      AppTextField(controller: password, label: 'New password', obscureText: true, textDirection: TextDirection.ltr, icon: Icons.lock_outline_rounded),
      const SizedBox(height: 12),
      AppTextField(controller: confirm, label: 'Confirm new password', obscureText: true, textDirection: TextDirection.ltr, icon: Icons.lock_reset_rounded),
      const SizedBox(height: 18),
      GoldButton(label: 'Change password', loading: c.busy, onPressed: c.busy ? null : submit, icon: Icons.security_update_good_rounded),
    ]));
  }
}

class FinalResetSuccessScreen extends StatelessWidget {
  const FinalResetSuccessScreen({super.key});
  @override Widget build(BuildContext context) => AppPage(showBack: false, child: Center(child: AppReveal(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
    const BreathingGlow(child: Icon(Icons.verified_rounded, color: AppColors.green, size: 96)),
    const SizedBox(height: 22),
    Text(context.tr('Password changed successfully'), style: Theme.of(context).textTheme.headlineMedium, textAlign: TextAlign.center),
    const SizedBox(height: 10),
    Text(context.tr('All previous login sessions were revoked for your security.'), style: const TextStyle(color: AppColors.muted), textAlign: TextAlign.center),
    const SizedBox(height: 26),
    GoldButton(label: 'Back to login', onPressed: () => Navigator.pushNamedAndRemoveUntil(context, Routes.login, (_) => false)),
  ]))));
}

class FinalTournamentsScreen extends StatefulWidget {
  const FinalTournamentsScreen({super.key});
  @override State<FinalTournamentsScreen> createState() => _FinalTournamentsScreenState();
}

class _FinalTournamentsScreenState extends State<FinalTournamentsScreen> {
  bool loaded = false;
  @override void didChangeDependencies() { super.didChangeDependencies(); if (!loaded) { loaded = true; Future.microtask(() => AppScope.of(context).loadTournaments()); } }
  @override Widget build(BuildContext context) {
    final c = AppScope.of(context);
    final list = c.tournaments;
    return AppPage(title: 'Tournaments', actions: [IconButton(onPressed: c.busy ? null : c.loadTournaments, icon: const Icon(Icons.refresh_rounded))], child: Column(children: [
      AppReveal(child: GradientPanel(gradient: AppGradients.purple, child: Row(children: [
        const Icon(Icons.emoji_events_rounded, color: AppColors.gold, size: 42), const SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(context.tr('Official tournaments'), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 19)), const SizedBox(height: 5), Text(context.tr('Join scheduled brackets, follow your round and open your tournament match when it is ready.'), style: const TextStyle(color: AppColors.muted, height: 1.35))])),
      ]))),
      const SizedBox(height: 14),
      if (c.busy && list.isEmpty) const Padding(padding: EdgeInsets.all(50), child: CircularProgressIndicator(color: AppColors.gold))
      else if (list.isEmpty) const EmptyState(icon: Icons.emoji_events_outlined, title: 'No tournaments available', message: 'New tournaments will appear here when administration opens registration.')
      else ...list.asMap().entries.map((entry) {
        final t = entry.value; final status = _text(t['status']); final fee = _doubleValue(t['entryFee']); final joined = t['joined'] == true;
        final name = c.isArabic ? _text(t['nameAr']) : _text(t['nameEn']);
        return AppReveal(delay: Duration(milliseconds: 55 * entry.key.clamp(0, 6).toInt()), child: GradientPanel(margin: const EdgeInsets.only(bottom: 12), onTap: () => Navigator.pushNamed(context, Routes.tournamentDetails, arguments: {'id': _text(t['id'])}), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [Expanded(child: Text(name, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900))), StatusBadge(status, color: _statusColor(status))]),
          const SizedBox(height: 10),
          Wrap(spacing: 8, runSpacing: 8, children: [StatusBadge('${t['entrants'] ?? 0}/${t['maxPlayers'] ?? 0} ${context.tr('players')}', color: AppColors.cyan), StatusBadge(fee > 0 ? '${fee.toStringAsFixed(0)} ${t['currency'] ?? 'MRU'}' : context.tr('Free entry'), color: fee > 0 ? AppColors.gold : AppColors.green), if (joined) const StatusBadge('JOINED', color: AppColors.green)]),
          if (_text(t['startsAt']).isNotEmpty) ...[const SizedBox(height: 9), Text('${context.tr('Starts')}: ${_text(t['startsAt']).replaceFirst('T', ' ').split('.').first}', style: const TextStyle(color: AppColors.muted, fontSize: 11))],
        ])));
      }),
      const SizedBox(height: 6),
      PurpleButton(label: 'Leaderboard', icon: Icons.leaderboard_rounded, onPressed: () => Navigator.pushNamed(context, Routes.leaderboard)),
    ]));
  }
}

class FinalTournamentDetailsScreen extends StatefulWidget {
  const FinalTournamentDetailsScreen({super.key, required this.id});
  final String id;
  @override State<FinalTournamentDetailsScreen> createState() => _FinalTournamentDetailsScreenState();
}

class _FinalTournamentDetailsScreenState extends State<FinalTournamentDetailsScreen> {
  Map<String, dynamic>? data; bool loading = true;
  @override void initState() { super.initState(); Future.microtask(load); }
  Future<void> load() async { if (widget.id.isEmpty) { if (mounted) setState(() => loading = false); return; } final result = await AppScope.of(context).tournamentDetails(widget.id); if (mounted) setState(() { data = result; loading = false; }); }
  Future<void> toggleJoin() async {
    if (data == null) return; final c = AppScope.of(context); final joined = data!['joined'] == true;
    final ok = joined ? await c.withdrawTournament(widget.id) : await c.joinTournament(widget.id);
    if (!mounted) return; if (!ok) _snack(context, c.errorMessage ?? 'Request failed'); else await load();
  }
  Future<void> openTournamentMatch(String matchId) async {
    final c = AppScope.of(context);
    final match = await c.getMatch(matchId);
    if (!mounted || match == null) { _snack(context, c.errorMessage ?? 'Could not open tournament match'); return; }
    final status = _text(match['status']);
    if (status == 'READY' || status == 'WAITING') {
      final started = await c.startMatch(matchId);
      if (!mounted) return;
      if (started == null) {
        final refreshed = await c.getMatch(matchId);
        if (!mounted || refreshed == null || _text(refreshed['status']) != 'ACTIVE') {
          _snack(context, c.errorMessage ?? 'Could not start tournament match');
          return;
        }
      }
    }
    if (!mounted) return;
    Navigator.pushNamed(context, Routes.game, arguments: {'matchId': matchId});
  }
  @override Widget build(BuildContext context) {
    final c = AppScope.of(context);
    if (loading) return const AppPage(title: 'Tournament details', child: Center(child: Padding(padding: EdgeInsets.all(60), child: CircularProgressIndicator(color: AppColors.gold))));
    if (data == null) return AppPage(title: 'Tournament details', child: EmptyState(icon: Icons.error_outline_rounded, title: 'Tournament unavailable', message: c.errorMessage ?? 'Could not load tournament.'));
    final t = data!; final status = _text(t['status']); final joined = t['joined'] == true; final fee = _doubleValue(t['entryFee']); final pairings = ((t['pairings'] as List?) ?? const []).whereType<Map>().map((x) => x.cast<String,dynamic>()).toList();
    final name = c.isArabic ? _text(t['nameAr']) : _text(t['nameEn']); final description = c.isArabic ? _text(t['descriptionAr']) : _text(t['descriptionEn']);
    final currentUser = _text(c.currentUser?['id']);
    final myReady = pairings.where((p) => (_text(p['playerAUserId']) == currentUser || _text(p['playerBUserId']) == currentUser) && _text(p['matchId']).isNotEmpty && !['COMPLETED','BYE','CANCELLED'].contains(_text(p['status']))).toList();
    return AppPage(title: 'Tournament details', actions: [IconButton(onPressed: load, icon: const Icon(Icons.refresh_rounded))], child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      AppReveal(child: GradientPanel(gradient: AppGradients.purple, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Row(children: [const Icon(Icons.emoji_events_rounded, color: AppColors.gold, size: 38), const SizedBox(width: 12), Expanded(child: Text(name, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 21))), StatusBadge(status, color: _statusColor(status))]), if (description.isNotEmpty) ...[const SizedBox(height: 12), Text(description, style: const TextStyle(color: AppColors.muted, height: 1.4))]]))),
      const SizedBox(height: 12),
      Wrap(spacing: 9, runSpacing: 9, children: [StatusBadge('${t['entrants'] ?? 0}/${t['maxPlayers'] ?? 0} ${context.tr('players')}', color: AppColors.cyan), StatusBadge('${context.tr('Rule')}: ${t['ruleCode'] ?? 'CLASSIC'}', color: AppColors.purpleLight), StatusBadge(fee > 0 ? '${context.tr('Entry')} ${fee.toStringAsFixed(0)} ${t['currency'] ?? 'MRU'}' : context.tr('Free entry'), color: fee > 0 ? AppColors.gold : AppColors.green)]),
      if (status == 'OPEN') ...[const SizedBox(height: 16), GoldButton(label: joined ? 'Withdraw from tournament' : 'Join tournament', loading: c.busy, onPressed: c.busy ? null : toggleJoin, icon: joined ? Icons.logout_rounded : Icons.login_rounded)],
      if (myReady.isNotEmpty) ...[const SizedBox(height: 12), BreathingGlow(child: GoldButton(label: 'Open my tournament match', icon: Icons.sports_esports_rounded, loading: c.busy, onPressed: c.busy ? null : () => openTournamentMatch(_text(myReady.first['matchId']))))],
      const SizedBox(height: 12),
      PurpleButton(label: 'View bracket', icon: Icons.account_tree_rounded, onPressed: () => Navigator.pushNamed(context, Routes.bracket, arguments: {'id': widget.id})),
      const SizedBox(height: 20),
      SectionTitle('Participants', subtitle: '${t['entrants'] ?? 0} ${context.tr('players')}'),
      ...(((t['entries'] as List?) ?? const []).whereType<Map>().take(30).map((raw) { final e=raw.cast<String,dynamic>(); final u=(e['user'] as Map?)?.cast<String,dynamic>() ?? const <String,dynamic>{}; final p=(u['profile'] as Map?)?.cast<String,dynamic>() ?? const <String,dynamic>{}; return GradientPanel(margin:const EdgeInsets.only(bottom:8),padding:const EdgeInsets.all(12),child:Row(children:[PlayerAvatar(name:_text(p['displayName']).isNotEmpty?_text(p['displayName']):_text(u['username']),size:42,avatarUrl:_text(p['avatarUrl'])),const SizedBox(width:10),Expanded(child:Text(_text(p['displayName']).isNotEmpty?_text(p['displayName']):_text(u['username']),style:const TextStyle(fontWeight:FontWeight.w800))),StatusBadge(_text(e['status']),color:_statusColor(_text(e['status'])))])); })),
    ]));
  }
}

class FinalBracketScreen extends StatefulWidget {
  const FinalBracketScreen({super.key, required this.id}); final String id;
  @override State<FinalBracketScreen> createState() => _FinalBracketScreenState();
}
class _FinalBracketScreenState extends State<FinalBracketScreen> {
  Map<String,dynamic>? data; bool loading=true;
  @override void initState(){super.initState();Future.microtask(load);} Future<void> load()async{final r=await AppScope.of(context).tournamentDetails(widget.id);if(mounted)setState((){data=r;loading=false;});}
  String player(Map<String,dynamic> pairing,String key){final u=(pairing[key] as Map?)?.cast<String,dynamic>();if(u==null)return 'TBD';final p=(u['profile'] as Map?)?.cast<String,dynamic>();return _text(p?['displayName']).isNotEmpty?_text(p?['displayName']):_text(u['username']);}
  @override Widget build(BuildContext context){if(loading)return const AppPage(title:'Tournament bracket',child:Center(child:CircularProgressIndicator(color:AppColors.gold)));if(data==null)return const AppPage(title:'Tournament bracket',child:EmptyState(icon:Icons.account_tree_outlined,title:'Bracket unavailable',message:'Could not load the tournament bracket.'));
    final list=((data!['pairings'] as List?)??const[]).whereType<Map>().map((e)=>e.cast<String,dynamic>()).toList();final rounds=<int,List<Map<String,dynamic>>>{};for(final p in list){rounds.putIfAbsent(_intValue(p['roundNumber']),()=>[]).add(p);}return AppPage(title:'Tournament bracket',actions:[IconButton(onPressed:load,icon:const Icon(Icons.refresh_rounded))],child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      if(rounds.isEmpty) const EmptyState(icon:Icons.account_tree_outlined,title:'Bracket not generated yet',message:'The bracket is generated when administration starts the tournament.'),
      ...rounds.entries.map((round)=>Column(crossAxisAlignment:CrossAxisAlignment.start,children:[SectionTitle('${context.tr('Round')} ${round.key}'),...round.value.map((p){final status=_text(p['status']);final winner=player(p,'winner');return AppReveal(child:GradientPanel(margin:const EdgeInsets.only(bottom:10),child:Column(children:[Row(children:[Expanded(child:Text(player(p,'playerA'),style:const TextStyle(fontWeight:FontWeight.w800))),const Text('VS',style:TextStyle(color:AppColors.gold,fontWeight:FontWeight.w900)),Expanded(child:Text(player(p,'playerB'),textAlign:TextAlign.end,style:const TextStyle(fontWeight:FontWeight.w800)))]),const SizedBox(height:8),Row(children:[StatusBadge(status,color:_statusColor(status)),const Spacer(),if(_text(p['winnerUserId']).isNotEmpty) Text('${context.tr('Winner')}: $winner',style:const TextStyle(color:AppColors.green,fontSize:11,fontWeight:FontWeight.w800))])])));}),const SizedBox(height:14)])),
    ]));}
}

class FinalLeaderboardScreen extends StatefulWidget { const FinalLeaderboardScreen({super.key}); @override State<FinalLeaderboardScreen> createState()=>_FinalLeaderboardScreenState(); }
class _FinalLeaderboardScreenState extends State<FinalLeaderboardScreen>{List<Map<String,dynamic>> items=[];bool loading=true;@override void initState(){super.initState();Future.microtask(load);}Future<void> load()async{final r=await AppScope.of(context).loadLeaderboard();if(mounted)setState((){items=r;loading=false;});}@override Widget build(BuildContext context){return AppPage(title:'Leaderboard',actions:[IconButton(onPressed:load,icon:const Icon(Icons.refresh_rounded))],child:loading?const Center(child:Padding(padding:EdgeInsets.all(60),child:CircularProgressIndicator(color:AppColors.gold))):items.isEmpty?const EmptyState(icon:Icons.leaderboard_outlined,title:'No ranking data yet',message:'Complete online matches to appear on the leaderboard.'):Column(children:items.asMap().entries.map((entry){final x=entry.value;final rank=_intValue(x['rank']);final name=_text(x['displayName']).isNotEmpty?_text(x['displayName']):_text(x['username']);final medal=rank==1?Icons.emoji_events_rounded:rank==2?Icons.workspace_premium_rounded:rank==3?Icons.military_tech_rounded:Icons.person_rounded;return AppReveal(delay:Duration(milliseconds:40*entry.key.clamp(0,7).toInt()),child:GradientPanel(margin:const EdgeInsets.only(bottom:9),child:Row(children:[CircleAvatar(backgroundColor:(rank<=3?AppColors.gold:AppColors.purple).withValues(alpha:.18),child:Icon(medal,color:rank<=3?AppColors.gold:AppColors.purpleLight)),const SizedBox(width:12),Text('#$rank',style:const TextStyle(color:AppColors.gold,fontWeight:FontWeight.w900)),const SizedBox(width:12),Expanded(child:Text(name,style:const TextStyle(fontWeight:FontWeight.w900))),Text('${x['wins']??0} ${context.tr('wins')}',style:const TextStyle(color:AppColors.green,fontWeight:FontWeight.w800))])));}).toList()));}}

class FinalAchievementsScreen extends StatefulWidget { const FinalAchievementsScreen({super.key}); @override State<FinalAchievementsScreen> createState()=>_FinalAchievementsScreenState(); }
class _FinalAchievementsScreenState extends State<FinalAchievementsScreen>{bool loaded=false;@override void didChangeDependencies(){super.didChangeDependencies();if(!loaded){loaded=true;Future.microtask(()=>AppScope.of(context).loadAchievements());}}@override Widget build(BuildContext context){final c=AppScope.of(context);return AppPage(title:'Achievements',actions:[IconButton(onPressed:c.loadAchievements,icon:const Icon(Icons.refresh_rounded))],child:c.achievements.isEmpty?const EmptyState(icon:Icons.military_tech_outlined,title:'No achievements yet',message:'Achievement definitions will appear after the server seed is applied.'):Column(children:c.achievements.asMap().entries.map((entry){final a=entry.value;final title=c.isArabic?_text(a['titleAr']):_text(a['titleEn']);final desc=c.isArabic?_text(a['descriptionAr']):_text(a['descriptionEn']);final progress=_doubleValue(a['progress']);final target=_doubleValue(a['target']).clamp(1,double.infinity).toDouble();final unlocked=a['unlocked']==true;final claimed=a['claimed']==true;return AppReveal(delay:Duration(milliseconds:45*entry.key.clamp(0,6).toInt()),child:GradientPanel(margin:const EdgeInsets.only(bottom:11),borderColor:unlocked?AppColors.gold:AppColors.divider,child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Row(children:[CircleAvatar(backgroundColor:(unlocked?AppColors.gold:AppColors.surface).withValues(alpha:.18),child:Icon(unlocked?Icons.military_tech_rounded:Icons.lock_outline_rounded,color:unlocked?AppColors.gold:AppColors.muted)),const SizedBox(width:12),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(title,style:const TextStyle(fontWeight:FontWeight.w900)),if(desc.isNotEmpty)Text(desc,style:const TextStyle(color:AppColors.muted,fontSize:11))])),if(claimed)const StatusBadge('CLAIMED',color:AppColors.green)]),const SizedBox(height:12),ClipRRect(borderRadius:BorderRadius.circular(12),child:LinearProgressIndicator(value:(progress/target).clamp(0,1).toDouble(),minHeight:8,backgroundColor:AppColors.background,valueColor:AlwaysStoppedAnimation(unlocked?AppColors.gold:AppColors.purpleLight))),const SizedBox(height:7),Row(children:[Text('${progress.toStringAsFixed(0)}/${target.toStringAsFixed(0)}',style:const TextStyle(color:AppColors.muted,fontSize:11)),const Spacer(),Text('+${a['rewardCoins']??0} 🪙  +${a['rewardGems']??0} 💎',style:const TextStyle(color:AppColors.gold,fontWeight:FontWeight.w800)),if(unlocked&&!claimed)...[const SizedBox(width:8),FilledButton(onPressed:c.busy?null:()async{final ok=await c.claimAchievement(_text(a['id']));if(!context.mounted)return;_snack(context,ok?'Reward claimed':(c.errorMessage??'Request failed'));},child:Text(context.tr('Claim')))]])])));}).toList()));}}

class FinalReferralsScreen extends StatefulWidget { const FinalReferralsScreen({super.key}); @override State<FinalReferralsScreen> createState()=>_FinalReferralsScreenState(); }
class _FinalReferralsScreenState extends State<FinalReferralsScreen>{final code=TextEditingController();bool loaded=false;@override void dispose(){code.dispose();super.dispose();}@override void didChangeDependencies(){super.didChangeDependencies();if(!loaded){loaded=true;Future.microtask(()=>AppScope.of(context).loadReferralOverview());}}@override Widget build(BuildContext context){final c=AppScope.of(context);final d=c.referralOverview;return AppPage(title:'Invite friends',actions:[IconButton(onPressed:c.loadReferralOverview,icon:const Icon(Icons.refresh_rounded))],child:d==null?const Center(child:Padding(padding:EdgeInsets.all(60),child:CircularProgressIndicator(color:AppColors.gold))):Column(children:[AppReveal(child:GradientPanel(gradient:AppGradients.gold,child:Column(children:[const Icon(Icons.group_add_rounded,color:AppColors.background2,size:44),const SizedBox(height:8),Text(context.tr('Your invitation code'),style:const TextStyle(color:AppColors.background2,fontWeight:FontWeight.w800)),const SizedBox(height:6),Text(_text(d['code']),style:const TextStyle(color:AppColors.background2,fontWeight:FontWeight.w900,fontSize:26,letterSpacing:2)),const SizedBox(height:10),OutlinedButton.icon(onPressed:()async{await Clipboard.setData(ClipboardData(text:_text(d['code'])));if(context.mounted)_snack(context,'Code copied');},icon:const Icon(Icons.copy_rounded),label:Text(context.tr('Copy code')))]))),const SizedBox(height:12),GradientPanel(child:Row(mainAxisAlignment:MainAxisAlignment.spaceAround,children:[_MiniMetric(label:'Invited',value:'${d['invitedCount']??0}',icon:Icons.people_alt_rounded),_MiniMetric(label:'Reward',value:'${d['rewardCoins']??0} 🪙',icon:Icons.card_giftcard_rounded)])),const SizedBox(height:16),if(d['alreadyReferred']!=true)...[AppTextField(controller:code,label:'Enter invitation code',textDirection:TextDirection.ltr,icon:Icons.redeem_rounded),const SizedBox(height:10),GoldButton(label:'Apply invitation code',loading:c.busy,onPressed:c.busy?null:()async{final ok=await c.applyReferralCode(code.text);if(!context.mounted)return;_snack(context,ok?'Invitation code applied':(c.errorMessage??'Request failed'));})],const SizedBox(height:18),SectionTitle('Invited players'),...(((d['referrals'] as List?)??const[]).whereType<Map>().map((raw){final r=raw.cast<String,dynamic>();final u=(r['user'] as Map?)?.cast<String,dynamic>()??const <String,dynamic>{};final p=(u['profile'] as Map?)?.cast<String,dynamic>()??const <String,dynamic>{};final n=_text(p['displayName']).isNotEmpty?_text(p['displayName']):_text(u['username']);return GradientPanel(margin:const EdgeInsets.only(bottom:8),padding:const EdgeInsets.all(12),child:Row(children:[const Icon(Icons.person_add_alt_1_rounded,color:AppColors.green),const SizedBox(width:10),Expanded(child:Text(n,style:const TextStyle(fontWeight:FontWeight.w800))),const StatusBadge('REWARDED',color:AppColors.green)]));})),if(((d['referrals'] as List?)??const[]).isEmpty)Text(context.tr('No invited players yet'),style:const TextStyle(color:AppColors.muted))]));}}

class _MiniMetric extends StatelessWidget { const _MiniMetric({required this.label,required this.value,required this.icon});final String label,value;final IconData icon;@override Widget build(BuildContext context)=>Column(children:[Icon(icon,color:AppColors.gold),const SizedBox(height:4),Text(value,style:const TextStyle(fontSize:18,fontWeight:FontWeight.w900)),Text(context.tr(label),style:const TextStyle(color:AppColors.muted,fontSize:10))]);}

class FinalPrivacySettingsScreen extends StatefulWidget { const FinalPrivacySettingsScreen({super.key}); @override State<FinalPrivacySettingsScreen> createState()=>_FinalPrivacySettingsScreenState(); }
class _FinalPrivacySettingsScreenState extends State<FinalPrivacySettingsScreen>{bool online=true,messages=true,invites=true,loaded=false;@override void didChangeDependencies(){super.didChangeDependencies();if(!loaded){loaded=true;Future.microtask(load);}}Future<void> load()async{final r=await AppScope.of(context).loadPrivacySettings();if(!mounted||r==null)return;setState((){online=r['showOnlineStatus']!=false;messages=r['allowDirectMessages']!=false;invites=r['allowInvites']!=false;});}Future<void> save()async{final c=AppScope.of(context);final ok=await c.savePrivacySettings(showOnlineStatus:online,allowDirectMessages:messages,allowInvites:invites);if(!mounted)return;_snack(context,ok?'Privacy settings saved':(c.errorMessage??'Request failed'));}@override Widget build(BuildContext context){final c=AppScope.of(context);return AppPage(title:'Privacy',child:Column(children:[GradientPanel(child:Column(children:[SwitchListTile(value:online,activeThumbColor:AppColors.gold,onChanged:(v)=>setState(()=>online=v),title:Text(context.tr('Show online status'))),SwitchListTile(value:messages,activeThumbColor:AppColors.gold,onChanged:(v)=>setState(()=>messages=v),title:Text(context.tr('Allow direct messages'))),SwitchListTile(value:invites,activeThumbColor:AppColors.gold,onChanged:(v)=>setState(()=>invites=v),title:Text(context.tr('Allow friend invitations')))])),const SizedBox(height:14),GoldButton(label:'Save privacy settings',loading:c.busy,onPressed:c.busy?null:save,icon:Icons.shield_rounded)]));}}

class FinalIdentityScreen extends StatefulWidget {
  const FinalIdentityScreen({super.key});
  @override State<FinalIdentityScreen> createState() => _FinalIdentityScreenState();
}

class _FinalIdentityScreenState extends State<FinalIdentityScreen> {
  final name = TextEditingController();
  final country = TextEditingController(text: 'MR');
  final picker = ImagePicker();
  DateTime? dob;
  XFile? front;
  XFile? back;
  XFile? selfie;
  String existingFrontId = '';
  String existingBackId = '';
  String existingSelfieId = '';
  String existingFrontName = '';
  String existingBackName = '';
  String existingSelfieName = '';
  bool loaded = false;

  @override void dispose() { name.dispose(); country.dispose(); super.dispose(); }
  @override void didChangeDependencies() { super.didChangeDependencies(); if (!loaded) { loaded = true; Future.microtask(load); } }

  Future<void> load() async {
    final r = await AppScope.of(context).loadIdentityVerification();
    if (!mounted || r == null) return;
    name.text = _text(r['legalName']);
    country.text = _text(r['countryCode']).isEmpty ? 'MR' : _text(r['countryCode']);
    dob = DateTime.tryParse(_text(r['dateOfBirth']));
    final f = r['documentFront'] is Map ? (r['documentFront'] as Map) : const {};
    final b = r['documentBack'] is Map ? (r['documentBack'] as Map) : const {};
    final sf = r['selfie'] is Map ? (r['selfie'] as Map) : const {};
    existingFrontId = _text(f['id']); existingFrontName = _text(f['originalName']);
    existingBackId = _text(b['id']); existingBackName = _text(b['originalName']);
    existingSelfieId = _text(sf['id']); existingSelfieName = _text(sf['originalName']);
    setState(() {});
  }

  Future<void> chooseDate() async {
    final d = await showDatePicker(context: context, firstDate: DateTime(1900), lastDate: DateTime.now().subtract(const Duration(days: 365 * 18)), initialDate: dob ?? DateTime(1995));
    if (d != null) setState(() => dob = d);
  }

  Future<XFile?> pickEvidence({bool camera = false}) => picker.pickImage(source: camera ? ImageSource.camera : ImageSource.gallery, imageQuality: 84, maxWidth: 2200);

  Future<String?> uploadEvidence(XFile? file, String existingId) async {
    if (file == null) return existingId.isEmpty ? null : existingId;
    final result = await AppScope.of(context).uploadIdentityDocumentBytes(await file.readAsBytes(), file.name);
    return result?['fileId']?.toString();
  }

  Future<void> submit() async {
    if (name.text.trim().length < 2 || dob == null || country.text.trim().length < 2) { _snack(context, 'Complete identity information'); return; }
    if (front == null && existingFrontId.isEmpty) { _snack(context, 'Upload the front of your identity document'); return; }
    if (selfie == null && existingSelfieId.isEmpty) { _snack(context, 'Upload a clear selfie for identity review'); return; }
    final c = AppScope.of(context);
    final frontId = await uploadEvidence(front, existingFrontId);
    if (!mounted || frontId == null) { _snack(context, c.errorMessage ?? 'Identity document upload failed'); return; }
    final backId = await uploadEvidence(back, existingBackId);
    if (!mounted) return;
    final selfieId = await uploadEvidence(selfie, existingSelfieId);
    if (!mounted || selfieId == null) { _snack(context, c.errorMessage ?? 'Selfie upload failed'); return; }
    final ok = await c.submitIdentity(
      legalName: name.text, dateOfBirth: dob!, countryCode: country.text,
      documentFrontFileId: frontId, documentBackFileId: backId, selfieFileId: selfieId,
    );
    if (!mounted) return;
    _snack(context, ok ? 'Identity information submitted' : (c.errorMessage ?? 'Request failed'));
    if (ok) { front = null; back = null; selfie = null; await load(); }
  }

  Widget evidenceTile({required String title, required String subtitle, required IconData icon, required XFile? selected, required String existingName, required VoidCallback onTap, bool required = false}) {
    final ready = selected != null || existingName.isNotEmpty;
    return GradientPanel(
      onTap: onTap,
      borderColor: ready ? AppColors.green : (required ? AppColors.orange : AppColors.divider),
      child: Row(children: [
        Icon(ready ? Icons.verified_rounded : icon, color: ready ? AppColors.green : AppColors.gold, size: 30),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(context.tr(title), style: const TextStyle(fontWeight: FontWeight.w900)),
          const SizedBox(height: 4),
          Text(selected?.name ?? (existingName.isNotEmpty ? existingName : context.tr(subtitle)), maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppColors.muted, fontSize: 11)),
        ])),
        const Icon(Icons.upload_file_rounded, color: AppColors.muted),
      ]),
    );
  }

  @override Widget build(BuildContext context) {
    final c = AppScope.of(context);
    final status = _text(c.identityVerification?['status']).isEmpty ? 'UNVERIFIED' : _text(c.identityVerification?['status']);
    return AppPage(title: 'Identity & age verification', child: Column(children: [
      AppReveal(child: GradientPanel(child: Row(children: [
        const Icon(Icons.verified_user_rounded, color: AppColors.gold, size: 36), const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(context.tr('Verification status'), style: const TextStyle(fontWeight: FontWeight.w800)), const SizedBox(height: 5), StatusBadge(status, color: _statusColor(status))])),
      ]))),
      const SizedBox(height: 14),
      AppReveal(delay: const Duration(milliseconds: 60), child: AppTextField(controller: name, label: 'Legal name', icon: Icons.badge_outlined)),
      const SizedBox(height: 10),
      AppReveal(delay: const Duration(milliseconds: 100), child: AppTextField(controller: country, label: 'Country code', hint: 'MR', icon: Icons.flag_outlined, textDirection: TextDirection.ltr)),
      const SizedBox(height: 10),
      AppReveal(delay: const Duration(milliseconds: 140), child: GradientPanel(onTap: chooseDate, child: Row(children: [const Icon(Icons.cake_outlined, color: AppColors.gold), const SizedBox(width: 12), Expanded(child: Text(dob == null ? context.tr('Select date of birth') : '${dob!.year}-${dob!.month.toString().padLeft(2,'0')}-${dob!.day.toString().padLeft(2,'0')}')), const Icon(Icons.calendar_month_rounded)]))),
      const SizedBox(height: 14),
      AppReveal(delay: const Duration(milliseconds: 180), child: evidenceTile(title: 'Identity document — front', subtitle: 'Required • JPEG, PNG or WEBP', icon: Icons.credit_card_rounded, selected: front, existingName: existingFrontName, required: true, onTap: () async { final x = await pickEvidence(); if (x != null && mounted) setState(() => front = x); })),
      const SizedBox(height: 10),
      AppReveal(delay: const Duration(milliseconds: 220), child: evidenceTile(title: 'Identity document — back', subtitle: 'Optional if your document has no back side', icon: Icons.credit_card_outlined, selected: back, existingName: existingBackName, onTap: () async { final x = await pickEvidence(); if (x != null && mounted) setState(() => back = x); })),
      const SizedBox(height: 10),
      AppReveal(delay: const Duration(milliseconds: 260), child: evidenceTile(title: 'Verification selfie', subtitle: 'Required • use a clear recent photo', icon: Icons.face_retouching_natural_rounded, selected: selfie, existingName: existingSelfieName, required: true, onTap: () async { final x = await pickEvidence(camera: true); if (x != null && mounted) setState(() => selfie = x); })),
      const SizedBox(height: 16),
      GoldButton(label: status == 'VERIFIED' ? 'Resubmit identity information' : 'Submit for review', loading: c.busy, onPressed: c.busy ? null : submit, icon: Icons.verified_user_rounded),
      const SizedBox(height: 12),
      Text(context.tr('Identity evidence is stored privately and can only be opened by authorized staff. This manual review is a product control and does not replace any legally required KYC provider or licensing process.'), textAlign: TextAlign.center, style: const TextStyle(color: AppColors.muted, fontSize: 11, height: 1.4)),
    ]));
  }
}

class FinalSupportScreen extends StatefulWidget {
  const FinalSupportScreen({super.key});

  @override
  State<FinalSupportScreen> createState() => _FinalSupportScreenState();
}

class _FinalSupportScreenState extends State<FinalSupportScreen> {
  bool loaded = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!loaded) {
      loaded = true;
      Future.microtask(() => AppScope.of(context).loadSupportTickets());
    }
  }

  Future<void> create() async {
    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (_) => const _CreateTicketDialog(),
    );
    if (result == null || !mounted) return;

    final c = AppScope.of(context);
    final ticket = await c.createSupportTicket(
      subject: result['subject']!,
      category: result['category']!,
      message: result['message']!,
    );
    if (!mounted) return;

    if (ticket == null) {
      _snack(context, c.errorMessage ?? 'Could not create support ticket');
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => FinalSupportTicketScreen(id: _text(ticket['id'])),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = AppScope.of(context);
    return AppPage(
      title: 'Support',
      actions: [
        IconButton(
          onPressed: c.loadSupportTickets,
          icon: const Icon(Icons.refresh_rounded),
        ),
      ],
      floatingActionButton: FloatingActionButton(
        onPressed: create,
        backgroundColor: AppColors.gold,
        foregroundColor: AppColors.background,
        child: const Icon(Icons.add_comment_rounded),
      ),
      child: Column(
        children: [
          AppReveal(
            child: GradientPanel(
              child: Row(
                children: [
                  const Icon(
                    Icons.support_agent_rounded,
                    color: AppColors.gold,
                    size: 36,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      context.tr(
                        'Create a support ticket and keep the full conversation in your account. Support staff replies are stored by the server and also create notifications.',
                      ),
                      style: const TextStyle(
                        color: AppColors.muted,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          if (c.supportTickets.isEmpty)
            EmptyState(
              icon: Icons.support_agent_outlined,
              title: 'No support tickets',
              message:
                  'If you need help, create a ticket and the support team can reply from the administration panel.',
              action: GoldButton(
                label: 'Create ticket',
                onPressed: create,
                expanded: false,
              ),
            )
          else
            ...c.supportTickets.map(
              (t) => AppReveal(
                child: GradientPanel(
                  margin: const EdgeInsets.only(bottom: 10),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) =>
                          FinalSupportTicketScreen(id: _text(t['id'])),
                    ),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        backgroundColor:
                            _statusColor(_text(t['status'])).withValues(alpha: .16),
                        child: Icon(
                          Icons.support_agent_rounded,
                          color: _statusColor(_text(t['status'])),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _text(t['subject']),
                              style: const TextStyle(fontWeight: FontWeight.w900),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${t['category'] ?? ''} • ${t['updatedAt'] ?? ''}',
                              style: const TextStyle(
                                color: AppColors.muted,
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ),
                      ),
                      StatusBadge(
                        _text(t['status']),
                        color: _statusColor(_text(t['status'])),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _CreateTicketDialog extends StatefulWidget { const _CreateTicketDialog(); @override State<_CreateTicketDialog> createState()=>_CreateTicketDialogState(); }
class _CreateTicketDialogState extends State<_CreateTicketDialog>{final subject=TextEditingController(),message=TextEditingController();String category='GENERAL';@override void dispose(){subject.dispose();message.dispose();super.dispose();}@override Widget build(BuildContext context)=>AlertDialog(title:Text(context.tr('Create support ticket')),content:SizedBox(width:420,child:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,children:[AppTextField(controller:subject,label:'Subject'),const SizedBox(height:10),DropdownButtonFormField<String>(initialValue:category,items:['GENERAL','PAYMENT','MATCH','ACCOUNT','ABUSE'].map((x)=>DropdownMenuItem(value:x,child:Text(x))).toList(),onChanged:(v)=>setState(()=>category=v??'GENERAL'),decoration:InputDecoration(labelText:context.tr('Category'))),const SizedBox(height:10),AppTextField(controller:message,label:'Message',maxLines:5)]))),actions:[TextButton(onPressed:()=>Navigator.pop(context),child:Text(context.tr('Cancel'))),FilledButton(onPressed:(){if(subject.text.trim().length>=3&&message.text.trim().length>=2)Navigator.pop(context,{'subject':subject.text.trim(),'category':category,'message':message.text.trim()});},child:Text(context.tr('Create')))]);}

class FinalSupportTicketScreen extends StatefulWidget { const FinalSupportTicketScreen({super.key,required this.id});final String id;@override State<FinalSupportTicketScreen> createState()=>_FinalSupportTicketScreenState(); }
class _FinalSupportTicketScreenState extends State<FinalSupportTicketScreen>{Map<String,dynamic>? data;bool loading=true;final message=TextEditingController();@override void initState(){super.initState();Future.microtask(load);}@override void dispose(){message.dispose();super.dispose();}Future<void> load()async{final r=await AppScope.of(context).supportTicket(widget.id);if(mounted)setState((){data=r;loading=false;});}Future<void> send()async{if(message.text.trim().isEmpty)return;final c=AppScope.of(context);final ok=await c.sendSupportMessage(widget.id,message.text);if(!mounted)return;if(!ok)_snack(context,c.errorMessage??'Message failed');else{message.clear();await load();}}@override Widget build(BuildContext context){if(loading)return const AppPage(title:'Support ticket',child:Center(child:CircularProgressIndicator(color:AppColors.gold)));if(data==null)return const AppPage(title:'Support ticket',child:EmptyState(icon:Icons.error_outline_rounded,title:'Ticket unavailable',message:'Could not load this support ticket.'));final messages=((data!['messages'] as List?)??const[]).whereType<Map>().map((e)=>e.cast<String,dynamic>()).toList();final closed=_text(data!['status'])=='CLOSED';return AppPage(title:'Support ticket',actions:[IconButton(onPressed:load,icon:const Icon(Icons.refresh_rounded))],child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[GradientPanel(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Row(children:[Expanded(child:Text(_text(data!['subject']),style:const TextStyle(fontWeight:FontWeight.w900,fontSize:18))),StatusBadge(_text(data!['status']),color:_statusColor(_text(data!['status'])))]),const SizedBox(height:6),Text(_text(data!['category']),style:const TextStyle(color:AppColors.muted))])),const SizedBox(height:12),...messages.map((m){final staff=m['isStaff']==true;return Align(alignment:staff?Alignment.centerLeft:Alignment.centerRight,child:Container(constraints:const BoxConstraints(maxWidth:420),margin:const EdgeInsets.only(bottom:8),padding:const EdgeInsets.all(12),decoration:BoxDecoration(color:staff?AppColors.surface2:AppColors.purple.withValues(alpha:.45),borderRadius:BorderRadius.circular(16)),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(staff?context.tr('Support team'):context.tr('You'),style:TextStyle(color:staff?AppColors.gold:AppColors.cyan,fontWeight:FontWeight.w800,fontSize:10)),const SizedBox(height:4),Text(_text(m['text']))])));}),if(!closed)...[const SizedBox(height:12),AppTextField(controller:message,label:'Write a reply',maxLines:3,icon:Icons.chat_bubble_outline_rounded),const SizedBox(height:8),GoldButton(label:'Send reply',onPressed:send,icon:Icons.send_rounded),const SizedBox(height:8),TextButton(onPressed:()async{final c=AppScope.of(context);final ok=await c.closeSupportTicket(widget.id);if(!context.mounted)return;if(ok)await load();},child:Text(context.tr('Close ticket')))],if(closed)const StatusBadge('CLOSED',color:AppColors.red)]));}}
