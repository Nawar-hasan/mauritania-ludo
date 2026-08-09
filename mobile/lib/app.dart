import 'package:flutter/material.dart';
import 'core/app_controller.dart';
import 'core/app_theme.dart';
import 'core/routes.dart';
import 'screens/auth_screens.dart';
import 'screens/game_screens.dart';
import 'screens/remote_game_screen.dart';
import 'screens/home_screens.dart';
import 'screens/profile_screens.dart';
import 'screens/social_screens.dart';
import 'screens/store_screens.dart';
import 'screens/wallet_screens.dart';

class LudoChampionApp extends StatefulWidget {
  const LudoChampionApp({super.key});
  @override
  State<LudoChampionApp> createState() => _LudoChampionAppState();
}

class _LudoChampionAppState extends State<LudoChampionApp> {
  final controller = AppController();

  @override
  void initState() {
    super.initState();
    controller.initialize();
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppScope(
      controller: controller,
      child: AnimatedBuilder(
        animation: controller,
        builder: (context, _) => MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'MAURITANIA LUDO',
          theme: buildAppTheme(),
          locale: controller.isArabic ? const Locale('ar') : const Locale('en'),
          builder: (context, child) => Directionality(
            textDirection: controller.isArabic ? TextDirection.rtl : TextDirection.ltr,
            child: child ?? const SizedBox.shrink(),
          ),
          initialRoute: Routes.splash,
          onGenerateRoute: _onGenerateRoute,
        ),
      ),
    );
  }

  Route<dynamic> _onGenerateRoute(RouteSettings settings) {
    final screen = switch (settings.name) {
      Routes.splash => const SplashScreen(),
      Routes.onboarding => const OnboardingScreen(),
      Routes.language => const LanguageScreen(),
      Routes.login => const LoginScreen(),
      Routes.register => const RegisterScreen(),
      Routes.forgotPassword => const ForgotPasswordScreen(),
      Routes.otp => const OtpScreen(),
      Routes.resetPassword => const ResetPasswordScreen(),
      Routes.resetSuccess => const ResetSuccessScreen(),
      Routes.terms => const TermsScreen(),
      Routes.shell => const MainShellScreen(),
      Routes.notifications => const NotificationsScreen(),
      Routes.playModes => const PlayModesScreen(),
      Routes.playerCount => const PlayerCountScreen(),
      Routes.rules => const RulesScreen(),
      Routes.wager => const WagerSelectionScreen(),
      Routes.wagerConfirm => const WagerConfirmScreen(),
      Routes.matchmaking => const MatchmakingScreen(),
      Routes.opponentFound => const OpponentFoundScreen(),
      Routes.privateRoom => const PrivateRoomScreen(),
      Routes.joinRoom => const JoinRoomScreen(),
      Routes.roomPreview => const RoomPreviewScreen(),
      Routes.waitingRoom => const WaitingRoomScreen(),
      Routes.game => const RemoteLudoGameScreen(),
      Routes.gameFour => const RemoteLudoGameScreen(),
      Routes.resultWin => const MatchResultScreen(type: 'win'),
      Routes.resultLose => const MatchResultScreen(type: 'lose'),
      Routes.resultForfeit => const MatchResultScreen(type: 'forfeit'),
      Routes.resultTimeout => const MatchResultScreen(type: 'timeout'),
      Routes.resultCancelled => const MatchResultScreen(type: 'cancelled'),
      Routes.matchDetails => const MatchDetailsScreen(),
      Routes.wallet => const WalletScreen(),
      Routes.deposit => const DepositScreen(),
      Routes.transferDetails => const TransferDetailsScreen(),
      Routes.receipt => const ReceiptUploadScreen(),
      Routes.depositSuccess => const DepositSuccessScreen(),
      Routes.withdrawal => const WithdrawalScreen(),
      Routes.withdrawalReview => const WithdrawalReviewScreen(),
      Routes.withdrawalSuccess => const WithdrawalSuccessScreen(),
      Routes.transactions => const TransactionsScreen(),
      Routes.transactionDetails => const TransactionDetailsScreen(),
      Routes.store => const StoreScreen(),
      Routes.purchaseSuccess => const PurchaseSuccessScreen(),
      Routes.tournaments => const TournamentsScreen(),
      Routes.tournamentDetails => const TournamentDetailsScreen(),
      Routes.bracket => const BracketScreen(),
      Routes.leaderboard => const LeaderboardScreen(),
      Routes.rooms => const RoomsScreen(),
      Routes.createVoiceRoom => const CreateVoiceRoomScreen(),
      Routes.voiceRoom => const VoiceRoomScreen(),
      Routes.profile => const ProfileScreen(),
      Routes.editProfile => const EditProfileScreen(),
      Routes.stats => const StatsScreen(),
      Routes.matchHistory => const MatchHistoryScreen(),
      Routes.inventory => const InventoryScreen(),
      Routes.achievements => const AchievementsScreen(),
      Routes.referrals => const ReferralsScreen(),
      Routes.accountSettings => const AccountSettingsScreen(),
      Routes.privacySettings => const PrivacySettingsScreen(),
      Routes.soundSettings => const SoundSettingsScreen(),
      Routes.support => const SupportScreen(),
      Routes.about => const AboutScreen(),
      Routes.catalog => const ScreenCatalogScreen(),
      _ => const MainShellScreen(),
    };

    return MaterialPageRoute<void>(builder: (_) => screen, settings: settings);
  }
}
