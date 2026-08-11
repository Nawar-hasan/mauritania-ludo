import 'package:flutter/material.dart';
import 'app_controller.dart';
import 'api_config.dart';
import 'localization.dart';
import 'app_theme.dart';
import 'motion.dart';

class AppPage extends StatelessWidget {
  const AppPage({
    super.key,
    required this.child,
    this.title,
    this.actions,
    this.bottomNavigationBar,
    this.floatingActionButton,
    this.padding = const EdgeInsets.all(20),
    this.scrollable = true,
    this.showBack = true,
  });

  final Widget child;
  final String? title;
  final List<Widget>? actions;
  final Widget? bottomNavigationBar;
  final Widget? floatingActionButton;
  final EdgeInsets padding;
  final bool scrollable;
  final bool showBack;

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    final campaign = controller.activeCampaign('APP_BACKGROUND');
    final equippedBackground = controller.equippedItem('BACKGROUND');
    final imageUrl = ApiConfig.resolveAssetUrl(campaign?['imageUrl'] ?? equippedBackground?['imageUrl']);
    final body = Container(
      decoration: BoxDecoration(
        gradient: AppGradients.background,
        image: imageUrl.isEmpty
            ? null
            : DecorationImage(
                image: NetworkImage(imageUrl),
                fit: BoxFit.cover,
                colorFilter: ColorFilter.mode(Colors.black.withValues(alpha: .34), BlendMode.darken),
              ),
      ),
      child: SafeArea(
        child: scrollable
            ? SingleChildScrollView(
                padding: padding,
                child: child,
              )
            : Padding(padding: padding, child: child),
      ),
    );

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: title == null
          ? null
          : AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              automaticallyImplyLeading: showBack,
              title: Text(context.tr(title!), style: TextStyle(fontWeight: FontWeight.w800)),
              actions: actions,
            ),
      extendBodyBehindAppBar: false,
      body: body,
      bottomNavigationBar: bottomNavigationBar,
      floatingActionButton: floatingActionButton,
    );
  }
}

class GradientPanel extends StatelessWidget {
  const GradientPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.margin,
    this.gradient,
    this.borderColor = AppColors.divider,
    this.radius = 22,
    this.onTap,
  });

  final Widget child;
  final EdgeInsets padding;
  final EdgeInsets? margin;
  final Gradient? gradient;
  final Color borderColor;
  final double radius;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final panel = Container(
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        gradient: gradient ?? const LinearGradient(
          colors: [AppColors.surface2, AppColors.surface],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: borderColor.withValues(alpha: 0.9)),
        boxShadow: [
          BoxShadow(
            color: AppColors.purple.withValues(alpha: 0.18),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: child,
    );
    if (onTap == null) return panel;
    return PressScale(
      child: InkWell(
        onTap: onTap == null ? null : () {
          AppScope.of(context).interactionFeedback();
          onTap!();
        },
        borderRadius: BorderRadius.circular(radius),
        child: panel,
      ),
    );
  }
}

class GoldButton extends StatelessWidget {
  const GoldButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.expanded = true,
    this.loading = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool expanded;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final button = DecoratedBox(
      decoration: BoxDecoration(
        gradient: onPressed == null
            ? const LinearGradient(colors: [Colors.grey, Colors.black45])
            : AppGradients.gold,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          if (onPressed != null)
            BoxShadow(
              color: AppColors.gold.withValues(alpha: 0.28),
              blurRadius: 18,
              offset: const Offset(0, 7),
            ),
        ],
      ),
      child: ElevatedButton.icon(
        onPressed: onPressed == null ? null : () {
          AppScope.of(context).interactionFeedback(strong: true);
          onPressed!();
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          foregroundColor: const Color(0xFF2C1538),
          minimumSize: const Size(0, 56),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        ),
        icon: loading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF2C1538)),
              )
            : Icon(icon ?? Icons.arrow_forward_rounded),
        label: Text(context.tr(label), style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
      ),
    );
    final animated = PressScale(enabled: onPressed != null, child: button);
    return expanded ? SizedBox(width: double.infinity, child: animated) : animated;
  }
}

class PurpleButton extends StatelessWidget {
  const PurpleButton({super.key, required this.label, required this.onPressed, this.icon});
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return PressScale(
      enabled: onPressed != null,
      child: SizedBox(
      width: double.infinity,
      child: DecoratedBox(
        decoration: BoxDecoration(gradient: AppGradients.purple, borderRadius: BorderRadius.circular(18)),
        child: ElevatedButton.icon(
          onPressed: onPressed == null ? null : () {
            AppScope.of(context).interactionFeedback();
            onPressed!();
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            foregroundColor: Colors.white,
            minimumSize: const Size(0, 54),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          ),
          icon: Icon(icon ?? Icons.arrow_forward_rounded),
          label: Text(context.tr(label), style: TextStyle(fontWeight: FontWeight.w800)),
        ),
      ),
    ));
  }
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.title, {super.key, this.subtitle, this.trailing});
  final String title;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(context.tr(title), style: Theme.of(context).textTheme.titleLarge),
                if (subtitle != null) ...[
                  const SizedBox(height: 4),
                  Text(context.tr(subtitle!), style: Theme.of(context).textTheme.bodyMedium),
                ],
              ],
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

class BalancePill extends StatelessWidget {
  const BalancePill({super.key, required this.icon, required this.value, required this.color, this.label});
  final IconData icon;
  final String value;
  final Color color;
  final String? label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: color.withValues(alpha: 0.75)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 7),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (label != null) Text(context.tr(label!), style: TextStyle(fontSize: 9, color: AppColors.muted)),
              AnimatedSwitcher(duration: AppMotion.normal, transitionBuilder: (child, animation) => FadeTransition(opacity: animation, child: ScaleTransition(scale: Tween<double>(begin: .9, end: 1).animate(animation), child: child)), child: Text(value, key: ValueKey(value), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13))),
            ],
          ),
        ],
      ),
    );
  }
}

class PlayerAvatar extends StatelessWidget {
  const PlayerAvatar({
    super.key,
    required this.name,
    this.size = 54,
    this.level = 1,
    this.color = AppColors.gold,
    this.avatarUrl,
  });
  final String name;
  final double size;
  final int level;
  final Color color;
  final String? avatarUrl;

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    final resolvedAvatar = ApiConfig.resolveAssetUrl(avatarUrl ?? (name == controller.displayName || name == controller.username ? controller.avatarUrl : null));
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(colors: [color, AppColors.purple]),
            border: Border.all(color: color, width: 2.5),
          ),
          alignment: Alignment.center,
          child: resolvedAvatar.isNotEmpty
              ? ClipOval(
                  child: Image.network(
                    resolvedAvatar,
                    width: size,
                    height: size,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _AvatarInitial(name: name, size: size),
                  ),
                )
              : _AvatarInitial(name: name, size: size),
        ),
        Positioned(
          bottom: -4,
          right: -4,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(12), border: Border.all(color: color)),
            child: Text('$level', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900)),
          ),
        ),
      ],
    );
  }
}

class _AvatarInitial extends StatelessWidget {
  const _AvatarInitial({required this.name, required this.size});
  final String name;
  final double size;
  @override
  Widget build(BuildContext context) => Text(
        name.isEmpty ? '?' : name.characters.first.toUpperCase(),
        style: TextStyle(fontWeight: FontWeight.w900, fontSize: size * 0.35),
      );
}

class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.icon, required this.title, required this.message, this.action});
  final IconData icon;
  final String title;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 52),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(shape: BoxShape.circle, color: AppColors.surface2.withValues(alpha: 0.65)),
            child: Icon(icon, size: 58, color: AppColors.gold),
          ),
          const SizedBox(height: 20),
          Text(context.tr(title), style: Theme.of(context).textTheme.titleLarge, textAlign: TextAlign.center),
          const SizedBox(height: 8),
          Text(context.tr(message), style: Theme.of(context).textTheme.bodyMedium, textAlign: TextAlign.center),
          if (action != null) ...[const SizedBox(height: 24), action!],
        ],
      ),
    );
  }
}

class StatusBadge extends StatelessWidget {
  const StatusBadge(this.label, {super.key, this.color = AppColors.green});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: AppMotion.normal,
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.16), borderRadius: BorderRadius.circular(20), border: Border.all(color: color.withValues(alpha: 0.6))),
      child: AnimatedSwitcher(duration: AppMotion.fast, child: Text(context.tr(label), key: ValueKey(label), style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: color))),
    );
  }
}

class AppTextField extends StatelessWidget {
  const AppTextField({
    super.key,
    required this.label,
    this.hint,
    this.controller,
    this.icon,
    this.keyboardType,
    this.obscureText = false,
    this.maxLines = 1,
    this.suffix,
    this.textDirection,
    this.textAlign,
  });
  final String label;
  final String? hint;
  final TextEditingController? controller;
  final IconData? icon;
  final TextInputType? keyboardType;
  final bool obscureText;
  final int maxLines;
  final Widget? suffix;
  final TextDirection? textDirection;
  final TextAlign? textAlign;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscureText,
      maxLines: maxLines,
      textDirection: textDirection,
      textAlign: textAlign ?? TextAlign.start,
      decoration: InputDecoration(
        labelText: context.tr(label),
        hintText: hint == null ? null : context.tr(hint!),
        prefixIcon: icon == null ? null : Icon(icon, color: AppColors.gold),
        suffixIcon: suffix,
      ),
    );
  }
}

class OptionTile extends StatelessWidget {
  const OptionTile({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.color = AppColors.purpleLight,
    this.trailing,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final Color color;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return GradientPanel(
      margin: const EdgeInsets.only(bottom: 12),
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(color: color.withValues(alpha: 0.18), borderRadius: BorderRadius.circular(16)),
            child: Icon(icon, color: color, size: 29),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(context.tr(title), style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                const SizedBox(height: 4),
                Text(context.tr(subtitle), style: TextStyle(color: AppColors.muted, fontSize: 12)),
              ],
            ),
          ),
          trailing ?? const Icon(Icons.chevron_right_rounded, color: AppColors.muted),
        ],
      ),
    );
  }
}

class ScreenHeader extends StatelessWidget {
  const ScreenHeader({super.key, required this.title, required this.subtitle, required this.icon});
  final String title;
  final String subtitle;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 86,
          height: 86,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: AppGradients.gold,
            boxShadow: [BoxShadow(color: AppColors.gold.withValues(alpha: 0.3), blurRadius: 30)],
          ),
          child: Icon(icon, color: AppColors.background2, size: 43),
        ),
        const SizedBox(height: 18),
        Text(context.tr(title), style: Theme.of(context).textTheme.headlineMedium, textAlign: TextAlign.center),
        const SizedBox(height: 8),
        Text(context.tr(subtitle), style: Theme.of(context).textTheme.bodyMedium, textAlign: TextAlign.center),
      ],
    );
  }
}
