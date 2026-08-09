import 'package:flutter/material.dart';
import '../core/app_controller.dart';
import '../core/api_config.dart';
import '../core/app_theme.dart';
import '../core/widgets.dart';
import '../core/localization.dart';

class StoreScreen extends StatefulWidget {
  const StoreScreen({super.key, this.embedded = false});
  final bool embedded;
  @override
  State<StoreScreen> createState() => _StoreScreenState();
}

class _StoreScreenState extends State<StoreScreen> {
  String type = 'BOARD';
  static const types = ['BOARD','DICE','DICE_FRAME','BACKGROUND','AVATAR_FRAME','EMOTE','SKILL','COIN_PACK','GEM_PACK'];

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    final items = controller.catalogItems.where((x) => '${x['type']}' == type).toList();
    final campaign = controller.activeCampaign('STORE_BANNER');
    final content = RefreshIndicator(
      onRefresh: controller.refreshAll,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 28),
        children: [
          if (campaign != null) _CampaignBanner(campaign: campaign),
          Text(context.tr('Store'), style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 12),
          SizedBox(
            height: 42,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: types.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, i) {
                final value = types[i];
                return ChoiceChip(
                  selected: type == value,
                  label: Text(_typeLabel(context, value)),
                  onSelected: (_) => setState(() => type = value),
                  selectedColor: AppColors.gold,
                  backgroundColor: AppColors.surface,
                  labelStyle: TextStyle(color: type == value ? AppColors.background2 : Colors.white),
                );
              },
            ),
          ),
          const SizedBox(height: 14),
          if (items.isEmpty)
            const EmptyState(icon: Icons.inventory_2_outlined, title: 'No items in this category', message: 'The administrator can add products and visual options from the control panel.')
          else
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, childAspectRatio: .68, crossAxisSpacing: 12, mainAxisSpacing: 12),
              itemCount: items.length,
              itemBuilder: (_, i) => _StoreItemCard(item: items[i]),
            ),
        ],
      ),
    );
    if (widget.embedded) return content;
    return AppPage(title: 'Store', padding: EdgeInsets.zero, scrollable: false, child: content);
  }

  String _typeLabel(BuildContext context, String value) {
    final labels = <String,String>{
      'BOARD':'Boards','DICE':'Dice','DICE_FRAME':'Frames','BACKGROUND':'Backgrounds','AVATAR_FRAME':'Avatar frames','EMOTE':'Emotes','SKILL':'Skills','COIN_PACK':'Coins','GEM_PACK':'Gems',
    };
    return context.tr(labels[value] ?? value);
  }
}

class _CampaignBanner extends StatelessWidget {
  const _CampaignBanner({required this.campaign});
  final Map<String,dynamic> campaign;
  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    final image = ApiConfig.resolveAssetUrl(campaign['imageUrl']);
    final title = controller.isArabic ? '${campaign['nameAr'] ?? ''}' : '${campaign['nameEn'] ?? ''}';
    return Container(
      height: 140,
      margin: const EdgeInsets.only(bottom: 18),
      padding: const EdgeInsets.all(18),
      alignment: Alignment.bottomLeft,
      decoration: BoxDecoration(
        color: _hex('${campaign['backgroundColor'] ?? ''}') ?? AppColors.surface2,
        image: image.isEmpty ? null : DecorationImage(image: NetworkImage(image), fit: BoxFit.cover, colorFilter: ColorFilter.mode(Colors.black.withValues(alpha: .25), BlendMode.darken)),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.gold.withValues(alpha: .55)),
      ),
      child: Text(title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
    );
  }
}

class _StoreItemCard extends StatelessWidget {
  const _StoreItemCard({required this.item});
  final Map<String,dynamic> item;
  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    final id = '${item['id']}';
    final owned = controller.ownsItem(id) || item['isDefault'] == true;
    final equipped = controller.isEquipped(id);
    final name = controller.isArabic ? '${item['nameAr'] ?? ''}' : '${item['nameEn'] ?? ''}';
    final image = ApiConfig.resolveAssetUrl(item['imageUrl'] ?? item['previewUrl']);
    final price = double.tryParse('${item['price']}') ?? 0;
    final wallet = '${item['priceWallet'] ?? 'COINS'}';
    return GradientPanel(
      padding: const EdgeInsets.all(10),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Expanded(child: ClipRRect(borderRadius: BorderRadius.circular(16), child: image.isEmpty
          ? Container(color: AppColors.background2, child: Icon(_icon('${item['type']}'), size: 48, color: AppColors.gold))
          : Image.network(image, fit: BoxFit.cover, errorBuilder: (_,__,___) => Container(color: AppColors.background2, child: const Icon(Icons.broken_image_outlined, color: AppColors.muted))))),
        const SizedBox(height: 9),
        Text(name, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w900)),
        const SizedBox(height: 4),
        Row(children: [StatusBadge('${item['rarity'] ?? 'COMMON'}', color: AppColors.purpleLight), const Spacer(), Text('Lv.${item['minLevel'] ?? 1}', style: const TextStyle(color: AppColors.muted, fontSize: 10))]),
        const SizedBox(height: 8),
        if (equipped)
          const StatusBadge('EQUIPPED', color: AppColors.green)
        else if (owned)
          PurpleButton(label: 'Equip', onPressed: controller.busy ? null : () async { final ok=await controller.equipCatalogItem(id); if(!ok&&context.mounted)_error(context,controller.errorMessage); })
        else
          GoldButton(label: price == 0 ? 'Get' : '${price.toStringAsFixed(price.truncateToDouble()==price?0:2)} $wallet', onPressed: controller.busy ? null : () async { final ok=await controller.purchaseCatalogItem(id); if(!ok&&context.mounted)_error(context,controller.errorMessage); }),
      ]),
    );
  }
  static IconData _icon(String type) => switch(type){'BOARD'=>Icons.grid_4x4_rounded,'DICE'=>Icons.casino_rounded,'DICE_FRAME'=>Icons.crop_square_rounded,'BACKGROUND'=>Icons.wallpaper_rounded,'AVATAR_FRAME'=>Icons.account_circle_outlined,'EMOTE'=>Icons.emoji_emotions_outlined,'SKILL'=>Icons.auto_awesome_rounded,_=>Icons.shopping_bag_outlined};
  static void _error(BuildContext context,String? message)=>ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(message??'Request failed')));
}

class PurchaseSuccessScreen extends StatelessWidget {
  const PurchaseSuccessScreen({super.key});
  @override
  Widget build(BuildContext context) => const AppPage(title: 'Store', child: EmptyState(icon: Icons.check_circle_outline_rounded, title: 'Purchase completed', message: 'The item is now available in your inventory.'));
}

Color? _hex(String raw) {
  final value = raw.replaceAll('#','').trim();
  if (value.length != 6 && value.length != 8) return null;
  return Color(int.parse(value.length == 6 ? 'FF$value' : value, radix: 16));
}
