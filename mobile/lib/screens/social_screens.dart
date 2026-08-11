import 'dart:async';
import 'package:flutter/material.dart';
import '../core/app_controller.dart';
import '../core/app_theme.dart';
import '../core/routes.dart';
import '../core/widgets.dart';
import '../core/localization.dart';

class RoomsScreen extends StatefulWidget {
  const RoomsScreen({super.key, this.embedded = false});
  final bool embedded;
  @override State<RoomsScreen> createState() => _RoomsScreenState();
}
class _RoomsScreenState extends State<RoomsScreen> {
  bool loaded=false;
  @override void didChangeDependencies(){super.didChangeDependencies();if(!loaded){loaded=true;Future.microtask(()=>AppScope.of(context).loadSocialRooms());}}
  @override Widget build(BuildContext context){
    final c=AppScope.of(context); final rooms=c.socialRooms;
    final body=RefreshIndicator(onRefresh:c.loadSocialRooms,child:ListView(padding:const EdgeInsets.fromLTRB(18,16,18,28),children:[
      Row(children:[Expanded(child:Text(context.tr('Rooms'),style:Theme.of(context).textTheme.headlineSmall)),IconButton.filledTonal(onPressed:()=>Navigator.pushNamed(context,Routes.createVoiceRoom),icon:const Icon(Icons.add_rounded))]),
      const SizedBox(height:8),
      const GradientPanel(child:Row(children:[Icon(Icons.forum_rounded,color:AppColors.gold),SizedBox(width:10),Expanded(child:Text('Text chat is handled by the MAURITANIA LUDO backend. Voice rooms use the configured live-audio provider when its API is enabled.',style:TextStyle(color:AppColors.muted,height:1.4,fontSize:10)))])),
      const SizedBox(height:14),
      if(rooms.isEmpty) const EmptyState(icon:Icons.forum_outlined,title:'No rooms yet',message:'Create the first text or voice room.') else ...rooms.map((room){
        final count=((room['_count'] as Map?)?['members']??(room['members'] as List?)?.length??0).toString();
        final voice='${room['type']}'=='VOICE';
        return GradientPanel(margin:const EdgeInsets.only(bottom:10),onTap:()=>Navigator.pushNamed(context,Routes.voiceRoom,arguments:room),child:Row(children:[CircleAvatar(backgroundColor:(voice?AppColors.gold:AppColors.cyan).withValues(alpha:.15),child:Icon(voice?Icons.mic_rounded:Icons.chat_bubble_outline_rounded,color:voice?AppColors.gold:AppColors.cyan)),const SizedBox(width:12),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text('${room['name']??''}',style:const TextStyle(fontWeight:FontWeight.w900)),const SizedBox(height:4),Text('$count ${context.tr('members')} • ${context.tr(voice?'Voice room':'Text room')}',style:const TextStyle(color:AppColors.muted,fontSize:10))])),const Icon(Icons.chevron_right_rounded)]));
      }),
    ]));
    if(widget.embedded)return body;return Scaffold(appBar:AppBar(title:Text(context.tr('Rooms'))),body:body);
  }
}

class CreateVoiceRoomScreen extends StatefulWidget { const CreateVoiceRoomScreen({super.key}); @override State<CreateVoiceRoomScreen> createState()=>_CreateVoiceRoomScreenState(); }
class _CreateVoiceRoomScreenState extends State<CreateVoiceRoomScreen>{
  final name=TextEditingController(); bool voice=true; int max=12;
  @override void dispose(){name.dispose();super.dispose();}
  Future<void> create()async{if(name.text.trim().length<2)return;final room=await AppScope.of(context).createSocialRoom(name:name.text.trim(),voice:voice,maxParticipants:max);if(!mounted)return;if(room!=null){await AppScope.of(context).loadSocialRooms();if(mounted)Navigator.pushReplacementNamed(context,Routes.voiceRoom,arguments:room);}else{ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(AppScope.of(context).errorMessage??context.tr('Could not create room'))));}}
  @override Widget build(BuildContext context)=>AppPage(title:'Create room',child:Column(children:[
    AppTextField(controller:name,label:'Room name',icon:Icons.forum_outlined),const SizedBox(height:14),
    SegmentedButton<bool>(segments:[ButtonSegment(value:false,label:Text(context.tr('Text room')),icon:const Icon(Icons.chat_bubble_outline_rounded)),ButtonSegment(value:true,label:Text(context.tr('Voice room')),icon:const Icon(Icons.mic_rounded))],selected:{voice},onSelectionChanged:(v)=>setState(()=>voice=v.first)),
    const SizedBox(height:14),DropdownButtonFormField<int>(initialValue:max,items:[4,8,12,20,30].map((n)=>DropdownMenuItem(value:n,child:Text('$n ${context.tr('members')}'))).toList(),onChanged:(v)=>setState(()=>max=v??12),decoration:const InputDecoration(labelText:'Maximum participants')),
    const SizedBox(height:20),GoldButton(label:'Create room',icon:Icons.add_rounded,onPressed:create),
  ]));
}

class VoiceRoomScreen extends StatefulWidget { const VoiceRoomScreen({super.key}); @override State<VoiceRoomScreen> createState()=>_VoiceRoomScreenState(); }
class _VoiceRoomScreenState extends State<VoiceRoomScreen>{
  final message=TextEditingController(); Timer? poll; Map<String,dynamic>? room; List<Map<String,dynamic>> messages=[]; bool joined=false; bool loading=true;
  @override void didChangeDependencies(){super.didChangeDependencies();if(room==null){final arg=((ModalRoute.of(context)?.settings.arguments as Map?)??const{}).cast<String,dynamic>();room=arg;_open();}}
  @override void dispose(){poll?.cancel();message.dispose();super.dispose();}
  String get id=>'${room?['id']??''}';
  Future<void> _open()async{if(id.isEmpty){setState(()=>loading=false);return;}final c=AppScope.of(context);final joinedRoom=await c.joinSocialRoom(id);if(!mounted)return;room=joinedRoom??room;joined=true;await _loadMessages();poll=Timer.periodic(const Duration(seconds:3),(_)=>_loadMessages(silent:true));setState(()=>loading=false);}
  Future<void> _loadMessages({bool silent=false})async{if(id.isEmpty)return;final rows=await AppScope.of(context).socialMessages(id);if(mounted)setState(()=>messages=rows);}
  Future<void> _send()async{final text=message.text.trim();if(text.isEmpty)return;message.clear();await AppScope.of(context).sendSocialMessage(id,text);await _loadMessages();}
  Future<void> _voice()async{final c=AppScope.of(context);final result=await c.requestVoiceSession(id);if(!mounted)return;if(result==null){ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(c.errorMessage??context.tr('Voice provider is not configured yet'))));return;}showDialog<void>(context:context,builder:(_)=>AlertDialog(title:Text(context.tr('Voice session ready')),content:Text(context.tr('The voice provider returned a session successfully. Native media transport can now use the returned provider token.')),actions:[TextButton(onPressed:()=>Navigator.pop(context),child:Text(context.tr('OK')))]));}
  Future<void> _leave()async{poll?.cancel();await AppScope.of(context).leaveSocialRoom(id);if(mounted)Navigator.pop(context);}
  @override Widget build(BuildContext context){if(loading)return AppPage(title:'Rooms',child:const Center(child:CircularProgressIndicator()));if(room==null||id.isEmpty)return const AppPage(title:'Rooms',child:EmptyState(icon:Icons.error_outline_rounded,title:'Room unavailable',message:'Open a room from the rooms list.'));
    final voice='${room!['type']}'=='VOICE';final members=(room!['members'] as List?)??const[];
    return Scaffold(appBar:AppBar(title:Text('${room!['name']??context.tr('Room')}'),actions:[if(voice)IconButton(onPressed:_voice,icon:const Icon(Icons.mic_rounded)),IconButton(onPressed:_leave,icon:const Icon(Icons.logout_rounded))]),body:Container(decoration:const BoxDecoration(gradient:AppGradients.background),child:SafeArea(child:Column(children:[
      SizedBox(height:76,child:ListView.separated(scrollDirection:Axis.horizontal,padding:const EdgeInsets.all(10),itemCount:members.length,separatorBuilder:(_,__)=>const SizedBox(width:8),itemBuilder:(_,i){final m=(members[i] as Map).cast<String,dynamic>();final u=((m['user'] as Map?)??const{}).cast<String,dynamic>();final p=((u['profile'] as Map?)??const{}).cast<String,dynamic>();final n='${p['displayName']??u['username']??''}';return Column(children:[PlayerAvatar(name:n,avatarUrl:p['avatarUrl']?.toString(),size:44),Text(n,style:const TextStyle(fontSize:8))]);})),
      if(voice) Padding(padding:const EdgeInsets.symmetric(horizontal:12),child:GradientPanel(borderColor:AppColors.gold,child:Row(children:[const Icon(Icons.graphic_eq_rounded,color:AppColors.gold),const SizedBox(width:10),Expanded(child:Text(context.tr('Voice room: chat is live now. Audio starts when VOICE_TOKEN_ENDPOINT and VOICE_API_KEY are configured on the backend.'),style:const TextStyle(color:AppColors.muted,fontSize:10,height:1.4))),IconButton(onPressed:_voice,icon:const Icon(Icons.mic_rounded,color:AppColors.gold))]))),
      Expanded(child:messages.isEmpty?const EmptyState(icon:Icons.chat_bubble_outline_rounded,title:'No messages yet',message:'Say hello to the room.'):ListView.builder(padding:const EdgeInsets.all(12),itemCount:messages.length,itemBuilder:(_,i){final m=messages[i];final u=((m['user'] as Map?)??const{}).cast<String,dynamic>();final p=((u['profile'] as Map?)??const{}).cast<String,dynamic>();final n='${p['displayName']??u['username']??''}';return Padding(padding:const EdgeInsets.only(bottom:8),child:Row(crossAxisAlignment:CrossAxisAlignment.start,children:[PlayerAvatar(name:n,avatarUrl:p['avatarUrl']?.toString(),size:34),const SizedBox(width:8),Expanded(child:Container(padding:const EdgeInsets.all(10),decoration:BoxDecoration(color:AppColors.surface2,borderRadius:BorderRadius.circular(14)),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(n,style:const TextStyle(color:AppColors.gold,fontWeight:FontWeight.w800,fontSize:10)),const SizedBox(height:3),Text('${m['text']??''}')])))]));})),
      Padding(padding:const EdgeInsets.fromLTRB(10,6,10,10),child:Row(children:[Expanded(child:TextField(controller:message,maxLength:500,onSubmitted:(_)=>_send(),decoration:InputDecoration(counterText:'',hintText:context.tr('Write a message...')))),const SizedBox(width:8),IconButton.filled(onPressed:_send,icon:const Icon(Icons.send_rounded))])),
    ]))));
  }
}

class TournamentsScreen extends StatelessWidget { const TournamentsScreen({super.key}); @override Widget build(BuildContext context)=>const AppPage(title:'Tournaments',child:EmptyState(icon:Icons.emoji_events_outlined,title:'Tournaments',message:'Tournament gameplay is separate from the wager and offline finalization patch.')); }
class TournamentDetailsScreen extends StatelessWidget { const TournamentDetailsScreen({super.key}); @override Widget build(BuildContext context)=>const AppPage(title:'Tournament details',child:EmptyState(icon:Icons.emoji_events_outlined,title:'Tournament details',message:'No tournament selected.')); }
class BracketScreen extends StatelessWidget { const BracketScreen({super.key}); @override Widget build(BuildContext context)=>const AppPage(title:'Tournament bracket',child:EmptyState(icon:Icons.account_tree_outlined,title:'Bracket',message:'No bracket selected.')); }
class LeaderboardScreen extends StatelessWidget { const LeaderboardScreen({super.key}); @override Widget build(BuildContext context)=>const AppPage(title:'Leaderboard',child:EmptyState(icon:Icons.leaderboard_outlined,title:'Leaderboard',message:'Rankings will be connected in the tournament module.')); }
