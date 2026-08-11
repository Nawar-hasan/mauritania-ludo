import 'dart:async';
import 'package:flutter/material.dart';
import '../core/app_controller.dart';
import '../core/app_theme.dart';
import '../core/routes.dart';
import '../core/widgets.dart';
import '../core/localization.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..repeat(reverse: true);
    _openNext();
  }

  Future<void> _openNext() async {
    await Future<void>.delayed(const Duration(milliseconds: 850));
    if (!mounted) return;
    final controller = AppScope.of(context);
    while (!controller.initialized && mounted) {
      await Future<void>.delayed(const Duration(milliseconds: 80));
    }
    if (!mounted) return;
    final route = !controller.hasSeenOnboarding
        ? Routes.onboarding
        : controller.isLoggedIn
            ? Routes.shell
            : Routes.login;
    Navigator.pushReplacementNamed(context, route);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppGradients.background),
        child: Center(
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, child) => Transform.scale(scale: 0.94 + (_controller.value * 0.08), child: child),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 220,
                  height: 220,
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(36),
                    boxShadow: [BoxShadow(color: AppColors.gold.withValues(alpha: 0.22), blurRadius: 50)],
                  ),
                  child: Image.asset('assets/branding/mauritania_ludo_logo.png', fit: BoxFit.contain),
                ),
                const SizedBox(height: 20),
                const Text('MAURITANIA LUDO', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: AppColors.gold, letterSpacing: 2)),
                const SizedBox(height: 28),
                const SizedBox(width: 32, height: 32, child: CircularProgressIndicator(color: AppColors.gold, strokeWidth: 3)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _page = 0;

  final _items = const [
    (Icons.casino_rounded, 'Play real server Ludo', 'Create 2-player and 4-player matches with dice, moves and rules validated by the server.'),
    (Icons.storefront_rounded, 'Customize your game', 'Buy and equip real boards, dice and frames from the connected store and inventory.'),
    (Icons.workspace_premium_rounded, 'Progress and wallet', 'Earn XP, move through levels and stages, and track real wallet and transaction records.'),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppPage(
      showBack: false,
      scrollable: false,
      child: Column(
        children: [
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: TextButton(
              onPressed: () => Navigator.pushReplacementNamed(context, Routes.language),
              child: Text(context.tr('Skip'), style: TextStyle(color: AppColors.gold)),
            ),
          ),
          Expanded(
            child: PageView.builder(
              controller: _pageController,
              itemCount: _items.length,
              onPageChanged: (value) => setState(() => _page = value),
              itemBuilder: (context, index) {
                final item = _items[index];
                return Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 190,
                      height: 190,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: index == 1 ? AppGradients.gold : AppGradients.purple,
                        boxShadow: [BoxShadow(color: AppColors.purpleLight.withValues(alpha: 0.28), blurRadius: 50)],
                      ),
                      child: Icon(item.$1, size: 94, color: index == 1 ? AppColors.background2 : Colors.white),
                    ),
                    const SizedBox(height: 42),
                    Text(context.tr(item.$2), style: Theme.of(context).textTheme.headlineMedium, textAlign: TextAlign.center),
                    const SizedBox(height: 14),
                    Text(context.tr(item.$3), style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: AppColors.muted, height: 1.5), textAlign: TextAlign.center),
                  ],
                );
              },
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              _items.length,
              (index) => AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                margin: const EdgeInsets.symmetric(horizontal: 4),
                width: index == _page ? 28 : 9,
                height: 9,
                decoration: BoxDecoration(color: index == _page ? AppColors.gold : AppColors.divider, borderRadius: BorderRadius.circular(20)),
              ),
            ),
          ),
          const SizedBox(height: 28),
          GoldButton(
            label: _page == _items.length - 1 ? 'Get Started' : 'Continue',
            onPressed: () {
              if (_page == _items.length - 1) {
                Navigator.pushReplacementNamed(context, Routes.language);
              } else {
                _pageController.nextPage(duration: const Duration(milliseconds: 350), curve: Curves.easeOutCubic);
              }
            },
          ),
        ],
      ),
    );
  }
}

class LanguageScreen extends StatelessWidget {
  const LanguageScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    return AppPage(
      showBack: false,
      child: Column(
        children: [
          const SizedBox(height: 36),
          const ScreenHeader(
            title: 'Choose your language',
            subtitle: 'You can change the language later from settings.',
            icon: Icons.language_rounded,
          ),
          const SizedBox(height: 44),
          _LanguageCard(
            flag: '🇺🇸',
            title: 'English',
            subtitle: 'English interface',
            selected: !controller.isArabic,
            onTap: () => controller.setArabic(false),
          ),
          const SizedBox(height: 14),
          _LanguageCard(
            flag: '🇸🇦',
            title: 'العربية',
            subtitle: 'واجهة عربية كاملة من اليمين إلى اليسار',
            selected: controller.isArabic,
            onTap: () => controller.setArabic(true),
          ),
          const SizedBox(height: 34),
          GoldButton(label: 'Continue', onPressed: () async { await controller.completeOnboarding(); if (context.mounted) Navigator.pushReplacementNamed(context, Routes.login); }),
        ],
      ),
    );
  }
}

class _LanguageCard extends StatelessWidget {
  const _LanguageCard({required this.flag, required this.title, required this.subtitle, required this.selected, required this.onTap});
  final String flag;
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GradientPanel(
      onTap: onTap,
      borderColor: selected ? AppColors.gold : AppColors.divider,
      child: Row(
        children: [
          Text(flag, style: const TextStyle(fontSize: 35)),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(context.tr(title), style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                Text(context.tr(subtitle), style: TextStyle(color: AppColors.muted, fontSize: 12)),
              ],
            ),
          ),
          Icon(selected ? Icons.check_circle_rounded : Icons.circle_outlined, color: selected ? AppColors.gold : AppColors.muted),
        ],
      ),
    );
  }
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _identifier = TextEditingController();
  final _password = TextEditingController();
  bool _obscure = true;
  bool _remember = true;

  @override
  void dispose() {
    _identifier.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_identifier.text.trim().isEmpty || _password.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.tr('Enter your account and password'))));
      return;
    }
    final controller = AppScope.of(context);
    final ok = await controller.login(identifier: _identifier.text, password: _password.text);
    if (!mounted) return;
    if (ok) {
      Navigator.pushNamedAndRemoveUntil(context, Routes.shell, (_) => false);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(controller.errorMessage ?? context.tr('Login failed'))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    return AppPage(
      showBack: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 18),
          const Center(child: ScreenHeader(title: 'Welcome back', subtitle: 'Log in to continue your Ludo journey.', icon: Icons.casino_rounded)),
          const SizedBox(height: 36),
          AppTextField(controller: _identifier, label: 'Email, phone or username', hint: 'Enter your account', icon: Icons.person_outline_rounded, textDirection: TextDirection.ltr),
          const SizedBox(height: 14),
          AppTextField(
            controller: _password,
            label: 'Password',
            textDirection: TextDirection.ltr,
            hint: 'Enter password',
            icon: Icons.lock_outline_rounded,
            obscureText: _obscure,
            suffix: IconButton(
              onPressed: () => setState(() => _obscure = !_obscure),
              icon: Icon(_obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Checkbox(value: _remember, activeColor: AppColors.gold, onChanged: (value) => setState(() => _remember = value ?? false)),
              Text(context.tr('Remember me')),
              const Spacer(),
              TextButton(
                onPressed: () => Navigator.pushNamed(context, Routes.forgotPassword),
                child: Text(context.tr('Forgot password?'), style: const TextStyle(color: AppColors.gold)),
              ),
            ],
          ),
          const SizedBox(height: 18),
          GoldButton(label: 'Log In', icon: Icons.login_rounded, loading: controller.busy, onPressed: controller.busy ? null : _submit),
          const SizedBox(height: 10),
          PurpleButton(label: 'Play Offline', icon: Icons.offline_bolt_rounded, onPressed: () => Navigator.pushNamed(context, Routes.offlineMode)),
          const SizedBox(height: 22),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(context.tr("Don't have an account? "), style: const TextStyle(color: AppColors.muted)),
              TextButton(onPressed: () => Navigator.pushNamed(context, Routes.register), child: Text(context.tr('Create account'), style: const TextStyle(color: AppColors.gold, fontWeight: FontWeight.w800))),
            ],
          ),
          Center(child: TextButton(onPressed: () => Navigator.pushNamed(context, Routes.terms), child: Text(context.tr('Terms, privacy and wagering policy')))),
        ],
      ),
    );
  }
}

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _name = TextEditingController();
  final _username = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool accepted = false;

  @override
  void dispose() {
    for (final controller in [_name, _username, _phone, _email, _password, _confirm]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    final name = _name.text.trim();
    final username = _username.text.trim();
    final phone = _phone.text.trim();
    final email = _email.text.trim();
    if (name.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.tr('Enter your full name'))));
      return;
    }
    if (!RegExp(r'^[a-zA-Z0-9_]{3,24}$').hasMatch(username)) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.tr('Player name must contain 3 to 24 English letters, numbers or underscores'))));
      return;
    }
    if (email.isEmpty || !RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.tr('Enter a valid email address'))));
      return;
    }
    if (phone.isNotEmpty && !RegExp(r'^\+?[0-9]{7,15}$').hasMatch(phone)) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.tr('Enter a valid phone number including country code'))));
      return;
    }
    if (_password.text.length < 10) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.tr('Password must contain at least 10 characters'))));
      return;
    }
    if (_password.text != _confirm.text) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.tr('Passwords do not match'))));
      return;
    }
    final controller = AppScope.of(context);
    final ok = await controller.register(
      displayName: name,
      username: username,
      phone: phone,
      email: email,
      password: _password.text,
    );
    if (!mounted) return;
    if (ok) {
      Navigator.pushNamedAndRemoveUntil(context, Routes.shell, (_) => false);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(controller.errorMessage ?? context.tr('Registration failed'))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    return AppPage(
      title: 'Create Account',
      child: Column(
        children: [
          AppTextField(controller: _name, label: 'Full name', icon: Icons.badge_outlined),
          const SizedBox(height: 12),
          AppTextField(controller: _username, label: 'Player name', hint: 'Visible to other players', icon: Icons.sports_esports_outlined, textDirection: TextDirection.ltr),
          const SizedBox(height: 12),
          AppTextField(controller: _phone, label: 'Phone number', icon: Icons.phone_outlined, keyboardType: TextInputType.phone, textDirection: TextDirection.ltr),
          const SizedBox(height: 12),
          AppTextField(controller: _email, label: 'Email', icon: Icons.email_outlined, keyboardType: TextInputType.emailAddress, textDirection: TextDirection.ltr),
          const SizedBox(height: 12),
          AppTextField(controller: _password, label: 'Password', hint: 'At least 10 characters', icon: Icons.lock_outline_rounded, obscureText: true, textDirection: TextDirection.ltr),
          const SizedBox(height: 12),
          AppTextField(controller: _confirm, label: 'Confirm password', icon: Icons.lock_reset_rounded, obscureText: true, textDirection: TextDirection.ltr),
          const SizedBox(height: 12),
          GradientPanel(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Checkbox(value: accepted, activeColor: AppColors.gold, onChanged: (value) => setState(() => accepted = value ?? false)),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 11),
                    child: GestureDetector(
                      onTap: () => Navigator.pushNamed(context, Routes.terms),
                      child: Text(context.tr('I confirm that I meet the required age and accept the terms, privacy policy and game rules.')),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          GoldButton(label: 'Create Account', loading: controller.busy, onPressed: accepted && !controller.busy ? _submit : null),
        ],
      ),
    );
  }
}

class TermsScreen extends StatelessWidget {
  const TermsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    const sections = [
      ('Age and identity', 'Real-money wallet functions must only be available to eligible users after identity and age verification.'),
      ('Fair play', 'Dice generation and movement validation are performed by the authoritative backend. Paid skills are disabled in wager matches.'),
      ('Wagering', 'The entry amount is locked before the match. It is settled after the verified result, refunded if the server cancels the match, and lost on confirmed forfeit.'),
      ('Deposits and withdrawals', 'Every request has a status, reference number and review trail. Withdrawal account details must match verified identity information.'),
      ('Community safety', 'Abuse, cheating, spam and inappropriate content can be reported and may result in account restrictions.'),
    ];
    return AppPage(
      title: 'Terms & Policies',
      child: Column(
        children: sections
            .map((item) => GradientPanel(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(context.tr(item.$1), style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17, color: AppColors.gold)),
                    const SizedBox(height: 8),
                    Text(context.tr(item.$2), style: TextStyle(color: AppColors.muted, height: 1.45)),
                  ]),
                ))
            .toList(),
      ),
    );
  }
}
