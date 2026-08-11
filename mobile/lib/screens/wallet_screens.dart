import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/app_controller.dart';
import '../core/app_theme.dart';
import '../core/routes.dart';
import '../core/widgets.dart';
import '../core/localization.dart';

class WalletScreen extends StatelessWidget {
  const WalletScreen({super.key, this.embedded = false});
  final bool embedded;

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    final content = RefreshIndicator(
      onRefresh: controller.refreshAll,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(18, 14, 18, 28),
        children: [
          if (embedded) Row(children: [Expanded(child: Text(context.tr('Wallet'), style: Theme.of(context).textTheme.headlineSmall)), IconButton(onPressed: controller.refreshAll, icon: const Icon(Icons.refresh_rounded))]),
          const SizedBox(height: 10),
          GradientPanel(
            gradient: AppGradients.purple,
            borderColor: AppColors.gold,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(context.tr('Cash balance'), style: const TextStyle(color: Colors.white70)),
              const SizedBox(height: 8),
              Text('${controller.walletBalance.toStringAsFixed(2)} MRU', style: const TextStyle(fontSize: 31, fontWeight: FontWeight.w900)),
              const SizedBox(height: 18),
              Row(children: [
                Expanded(child: _BalanceBox(label: 'Bonus balance', value: controller.rewardBalance, icon: Icons.card_giftcard_rounded, color: AppColors.gold)),
                const SizedBox(width: 9),
                Expanded(child: _BalanceBox(label: 'Locked balance', value: controller.lockedBalance, icon: Icons.lock_outline_rounded, color: AppColors.orange)),
              ]),
            ]),
          ),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(child: GoldButton(label: 'Deposit', icon: Icons.add_card_rounded, onPressed: () => Navigator.pushNamed(context, Routes.deposit))),
            const SizedBox(width: 10),
            Expanded(child: PurpleButton(label: 'Withdraw', icon: Icons.payments_outlined, onPressed: () => Navigator.pushNamed(context, Routes.withdrawal))),
          ]),
          const SizedBox(height: 22),
          SectionTitle('Recent transactions', trailing: TextButton(onPressed: () => Navigator.pushNamed(context, Routes.transactions), child: Text(context.tr('View all')))),
          if (controller.transactions.isEmpty)
            const EmptyState(icon: Icons.receipt_long_outlined, title: 'No transactions', message: 'Approved deposits, withdrawals, match prizes and wallet reservations will appear here.')
          else
            ...controller.transactions.take(6).map((item) => _TransactionTile(transaction: item)),
        ],
      ),
    );
    return embedded ? content : Scaffold(backgroundColor: AppColors.background, appBar: AppBar(title: Text(context.tr('Wallet'))), body: Container(decoration: const BoxDecoration(gradient: AppGradients.background), child: content));
  }
}

class _BalanceBox extends StatelessWidget {
  const _BalanceBox({required this.label, required this.value, required this.icon, required this.color});
  final String label;
  final double value;
  final IconData icon;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(padding: const EdgeInsets.all(13), decoration: BoxDecoration(color: Colors.black.withValues(alpha: .18), borderRadius: BorderRadius.circular(16), border: Border.all(color: color.withValues(alpha: .5))), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Icon(icon, color: color), const SizedBox(height: 8), Text(context.tr(label), style: const TextStyle(color: Colors.white70, fontSize: 10)), const SizedBox(height: 4), Text('${value.toStringAsFixed(2)} MRU', style: const TextStyle(fontWeight: FontWeight.w900))]));
}

class DepositScreen extends StatefulWidget {
  const DepositScreen({super.key});
  @override
  State<DepositScreen> createState() => _DepositScreenState();
}

class _DepositScreenState extends State<DepositScreen> {
  final amount = TextEditingController();
  final phone = TextEditingController();
  String? methodCode;
  @override
  void dispose() { amount.dispose(); phone.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    final methods = controller.paymentMethods.where((x) => x['supportsDeposit'] == true).toList();
    if (methods.isNotEmpty && !methods.any((x) => '${x['code']}' == methodCode)) methodCode = '${methods.first['code']}';
    return AppPage(title: 'Deposit', child: Column(children: [
      const ScreenHeader(title: 'Create a deposit request', subtitle: 'Choose an active payment method configured by administration. Manual transfers require receipt approval; online methods use the provider checkout.', icon: Icons.add_card_rounded),
      const SizedBox(height: 20),
      AppTextField(label: 'Amount', hint: 'Enter amount in MRU', controller: amount, keyboardType: const TextInputType.numberWithOptions(decimal: true), icon: Icons.payments_rounded),
      const SizedBox(height: 14),
      AppTextField(label: 'Phone number', hint: 'Optional for online payment', controller: phone, keyboardType: TextInputType.phone, icon: Icons.phone_android_rounded),
      const SizedBox(height: 16),
      const SectionTitle('Payment method'),
      if (methods.isEmpty)
        const EmptyState(icon: Icons.account_balance_wallet_outlined, title: 'No payment methods are active', message: 'Activate a deposit method from the administration panel.')
      else
        ...methods.map((item) {
          final code='${item['code']}';
          final title=controller.isArabic?'${item['nameAr'] ?? code}':'${item['nameEn'] ?? code}';
          final provider='${item['provider'] ?? ''}';
          final min=_num(item['minAmount']); final max=_num(item['maxAmount']);
          return _PaymentMethodTile(title:title, subtitle:'$provider • ${min.toStringAsFixed(0)}–${max.toStringAsFixed(0)} ${item['currency'] ?? 'MRU'}', selected:methodCode==code, icon:provider=='MANUAL'?Icons.account_balance_wallet_rounded:Icons.language_rounded, onTap:()=>setState(()=>methodCode=code));
        }),
      const SizedBox(height: 22),
      GoldButton(label: 'Continue', loading: controller.busy, onPressed: methods.isEmpty || controller.busy ? null : () async {
        final value = double.tryParse(amount.text.trim());
        final selected = methods.cast<Map<String,dynamic>>().firstWhere((x) => '${x['code']}' == methodCode);
        final min=_num(selected['minAmount']); final max=_num(selected['maxAmount']);
        if (value == null || value < min || value > max) { _message(context, '${context.tr('Amount must be between')} ${min.toStringAsFixed(0)} ${context.tr('and')} ${max.toStringAsFixed(0)} ${selected['currency'] ?? 'MRU'}'); return; }
        if ('${selected['provider']}' == 'MANUAL') {
          Navigator.pushNamed(context, Routes.transferDetails, arguments: {'amount': value, 'methodCode': methodCode, 'method': selected});
          return;
        }
        final result = await controller.createPaymentIntent(methodCode: methodCode!, amount: value, phoneNumber: phone.text.trim());
        if (!context.mounted) return;
        if (result == null) { _message(context, controller.errorMessage ?? 'Payment request failed'); return; }
        final intent=(result['intent'] as Map?)?.cast<String,dynamic>() ?? const <String,dynamic>{};
        final checkout='${intent['checkoutUrl'] ?? ''}';
        if (checkout.isEmpty) { _message(context, 'Payment request created'); Navigator.pushNamed(context, Routes.transactions); return; }
        final opened=await launchUrl(Uri.parse(checkout), mode: LaunchMode.externalApplication);
        if (!opened && context.mounted) _message(context, 'Could not open payment page');
      }),
    ]));
  }
}

class TransferDetailsScreen extends StatelessWidget {
  const TransferDetailsScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final args = _args(context);
    final controller = AppScope.of(context);
    final method = (args['method'] as Map?)?.cast<String,dynamic>() ?? const <String,dynamic>{};
    final config = (method['publicConfig'] as Map?)?.cast<String,dynamic>() ?? const <String,dynamic>{};
    final settings = controller.publicSettings ?? const <String, dynamic>{};
    final account = '${config['accountNumber'] ?? settings['deposit_account'] ?? settings['depositAccount'] ?? context.tr('Not configured by administration')}';
    final methodName = controller.isArabic ? '${method['nameAr'] ?? args['methodCode'] ?? ''}' : '${method['nameEn'] ?? args['methodCode'] ?? ''}';
    final instructions = controller.isArabic ? '${config['instructionsAr'] ?? ''}' : '${config['instructionsEn'] ?? ''}';
    return AppPage(title: 'Transfer details', child: Column(children: [
      const ScreenHeader(title: 'Transfer the exact amount', subtitle: 'Then upload the receipt and transfer reference for administrative review.', icon: Icons.qr_code_2_rounded),
      const SizedBox(height: 20),
      GradientPanel(borderColor: AppColors.gold, child: Column(children: [
        _ReviewRow('Method', methodName),
        _ReviewRow('Amount', '${_num(args['amount']).toStringAsFixed(2)} MRU', strong: true),
        _ReviewRow('Administration account', account),
      ])),
      if (instructions.isNotEmpty) ...[const SizedBox(height: 14), GradientPanel(child: Text(instructions, style: const TextStyle(color: AppColors.muted, height: 1.4)))],
      const SizedBox(height: 18),
      GradientPanel(borderColor: AppColors.orange, child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [const Icon(Icons.info_outline_rounded, color: AppColors.orange), const SizedBox(width: 10), Expanded(child: Text(context.tr('Do not consider the deposit completed until its status becomes COMPLETED in the transaction list.'), style: const TextStyle(color: AppColors.muted, height: 1.4)))])),
      const SizedBox(height: 22),
      GoldButton(label: 'Upload receipt', icon: Icons.upload_file_rounded, onPressed: () => Navigator.pushNamed(context, Routes.receipt, arguments: args)),
    ]));
  }
}

class ReceiptUploadScreen extends StatefulWidget {
  const ReceiptUploadScreen({super.key});
  @override
  State<ReceiptUploadScreen> createState() => _ReceiptUploadScreenState();
}

class _ReceiptUploadScreenState extends State<ReceiptUploadScreen> {
  final reference = TextEditingController();
  XFile? receipt;
  @override
  void dispose() { reference.dispose(); super.dispose(); }

  Future<void> _pick() async {
    final selected = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 82, maxWidth: 1800);
    if (selected != null && mounted) setState(() => receipt = selected);
  }

  Future<void> _submit(Map<String, dynamic> args) async {
    final controller = AppScope.of(context);
    if (receipt == null) { _message(context, 'Select the transfer receipt'); return; }
    final uploaded = await controller.uploadReceiptBytes(await receipt!.readAsBytes(), receipt!.name);
    final fileId = uploaded?['fileId']?.toString() ?? '';
    if (fileId.isEmpty || !mounted) { _message(context, controller.errorMessage ?? 'Receipt upload failed'); return; }
    final result = await controller.createPaymentIntent(methodCode: '${args['methodCode'] ?? ''}', amount: _num(args['amount']), externalRef: reference.text.trim(), receiptFileId: fileId);
    if (!mounted) return;
    if (result != null) Navigator.pushNamedAndRemoveUntil(context, Routes.depositSuccess, (route) => route.settings.name == Routes.shell || route.isFirst);
    else _message(context, controller.errorMessage ?? 'Deposit request failed');
  }

  @override
  Widget build(BuildContext context) {
    final args = _args(context);
    final controller = AppScope.of(context);
    return AppPage(title: 'Upload receipt', child: Column(children: [
      const ScreenHeader(title: 'Submit transfer proof', subtitle: 'This creates a pending transaction. The administration must approve it before your balance changes.', icon: Icons.receipt_long_rounded),
      const SizedBox(height: 20),
      GradientPanel(onTap: _pick, borderColor: receipt == null ? AppColors.divider : AppColors.green, child: SizedBox(width: double.infinity, height: 150, child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(receipt == null ? Icons.add_photo_alternate_outlined : Icons.check_circle_rounded, size: 48, color: receipt == null ? AppColors.gold : AppColors.green), const SizedBox(height: 10), Text(receipt?.name ?? context.tr('Choose receipt image'), textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w800))]))),
      const SizedBox(height: 16),
      AppTextField(label: 'Transfer reference', hint: 'Optional transaction number', controller: reference, icon: Icons.tag_rounded),
      const SizedBox(height: 22),
      GoldButton(label: 'Submit deposit request', loading: controller.busy, onPressed: controller.busy ? null : () => _submit(args)),
    ]));
  }
}

class DepositSuccessScreen extends StatelessWidget {
  const DepositSuccessScreen({super.key});
  @override
  Widget build(BuildContext context) => AppPage(title: 'Request submitted', child: Column(children: [
    const EmptyState(icon: Icons.schedule_rounded, title: 'Deposit is pending review', message: 'Track the request in Transactions. The cash balance will change only after approval.'),
    GoldButton(label: 'Open transactions', onPressed: () => Navigator.pushReplacementNamed(context, Routes.transactions)),
  ]));
}

class WithdrawalScreen extends StatefulWidget {
  const WithdrawalScreen({super.key});
  @override
  State<WithdrawalScreen> createState() => _WithdrawalScreenState();
}

class _WithdrawalScreenState extends State<WithdrawalScreen> {
  final amount = TextEditingController();
  final account = TextEditingController();
  final name = TextEditingController();
  String? methodCode;
  @override
  void dispose() { amount.dispose(); account.dispose(); name.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    final methods = controller.paymentMethods.where((x) => x['supportsWithdrawal'] == true).toList();
    if (methods.isNotEmpty && !methods.any((x) => '${x['code']}' == methodCode)) methodCode = '${methods.first['code']}';
    return AppPage(title: 'Withdraw', child: Column(children: [
      GradientPanel(gradient: AppGradients.purple, child: Row(children: [const Icon(Icons.account_balance_wallet_rounded, color: AppColors.gold, size: 40), const SizedBox(width: 12), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(context.tr('Available to withdraw'), style: const TextStyle(color: Colors.white70)), const SizedBox(height: 5), Text('${controller.withdrawableBalance.toStringAsFixed(2)} MRU', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 25))]))])),
      const SizedBox(height: 18),
      AppTextField(label: 'Amount', controller: amount, keyboardType: const TextInputType.numberWithOptions(decimal: true), icon: Icons.payments_rounded),
      const SizedBox(height: 14),
      AppTextField(label: 'Account number', controller: account, keyboardType: TextInputType.phone, icon: Icons.numbers_rounded),
      const SizedBox(height: 14),
      AppTextField(label: 'Full name', controller: name, icon: Icons.badge_outlined),
      const SizedBox(height: 16),
      if (methods.isEmpty)
        const EmptyState(icon: Icons.money_off_csred_outlined, title: 'No withdrawal method is active', message: 'Enable a withdrawal method from the administration panel.')
      else
        ...methods.map((item) {
          final code='${item['code']}';
          final title=controller.isArabic?'${item['nameAr'] ?? code}':'${item['nameEn'] ?? code}';
          return _PaymentMethodTile(title:title, subtitle:'${item['provider']} • ${item['currency'] ?? 'MRU'}', selected:methodCode==code, icon:Icons.account_balance_wallet_rounded, onTap:()=>setState(()=>methodCode=code));
        }),
      const SizedBox(height: 22),
      GoldButton(label: 'Review withdrawal', onPressed: methods.isEmpty ? null : () {
        final value = double.tryParse(amount.text.trim());
        final selected = methods.cast<Map<String,dynamic>>().firstWhere((x) => '${x['code']}' == methodCode);
        final min=_num(selected['minAmount']); final max=_num(selected['maxAmount']);
        if (value == null || value < min || value > max || value > controller.withdrawableBalance) { _message(context, 'The amount cannot be withdrawn from the current balance.'); return; }
        if (account.text.trim().isEmpty || name.text.trim().isEmpty) { _message(context, 'Complete the recipient information'); return; }
        Navigator.pushNamed(context, Routes.withdrawalReview, arguments: {'amount': value, 'method': methodCode, 'methodData': selected, 'accountNumber': account.text.trim(), 'accountName': name.text.trim()});
      }),
    ]));
  }
}

class WithdrawalReviewScreen extends StatelessWidget {
  const WithdrawalReviewScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final args = _args(context);
    final controller = AppScope.of(context);
    final methodData = (args['methodData'] as Map?)?.cast<String,dynamic>() ?? const <String,dynamic>{};
    final methodName = controller.isArabic ? '${methodData['nameAr'] ?? args['method'] ?? ''}' : '${methodData['nameEn'] ?? args['method'] ?? ''}';
    final gross = _num(args['amount']);
    final fee = _num(methodData['feeFixed']) + gross * _num(methodData['feeRate']);
    final net = gross - fee;
    return AppPage(title: 'Review withdrawal', child: Column(children: [
      const ScreenHeader(title: 'Confirm withdrawal request', subtitle: 'The amount will move from cash to locked balance while the request is pending.', icon: Icons.verified_user_outlined),
      const SizedBox(height: 20),
      GradientPanel(borderColor: AppColors.gold, child: Column(children: [
        _ReviewRow('Amount', '${gross.toStringAsFixed(2)} MRU', strong: true),
        _ReviewRow('Fees', '${fee.toStringAsFixed(2)} MRU'),
        _ReviewRow('Net amount', '${net.toStringAsFixed(2)} MRU', strong: true),
        _ReviewRow('Method', methodName),
        _ReviewRow('Account number', '${args['accountNumber'] ?? ''}'),
        _ReviewRow('Full name', '${args['accountName'] ?? ''}'),
      ])),
      const SizedBox(height: 22),
      GoldButton(label: 'Submit withdrawal request', loading: controller.busy, onPressed: controller.busy ? null : () async {
        final ok = await controller.createWithdrawalRequest(amount: _num(args['amount']), method: '${args['method']}', accountNumber: '${args['accountNumber']}', accountName: '${args['accountName']}');
        if (!context.mounted) return;
        if (ok) Navigator.pushNamedAndRemoveUntil(context, Routes.withdrawalSuccess, (route) => route.settings.name == Routes.shell || route.isFirst);
        else _message(context, controller.errorMessage ?? 'Withdrawal request failed');
      }),
    ]));
  }
}

class WithdrawalSuccessScreen extends StatelessWidget {
  const WithdrawalSuccessScreen({super.key});
  @override
  Widget build(BuildContext context) => AppPage(title: 'Request submitted', child: Column(children: [
    const EmptyState(icon: Icons.schedule_send_rounded, title: 'Withdrawal is pending review', message: 'The requested amount is now locked. Approval completes the withdrawal; rejection returns it to cash balance.'),
    GoldButton(label: 'Open transactions', onPressed: () => Navigator.pushReplacementNamed(context, Routes.transactions)),
  ]));
}

class TransactionsScreen extends StatelessWidget {
  const TransactionsScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    return AppPage(title: 'Transactions', actions: [IconButton(onPressed: controller.refreshAll, icon: const Icon(Icons.refresh_rounded))], child: controller.transactions.isEmpty
        ? const EmptyState(icon: Icons.receipt_long_outlined, title: 'No transactions', message: 'There are no real wallet transactions for this account yet.')
        : Column(children: controller.transactions.map((item) => _TransactionTile(transaction: item)).toList()));
  }
}

class TransactionDetailsScreen extends StatelessWidget {
  const TransactionDetailsScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final transaction = _args(context);
    final metadata = (transaction['metadata'] as Map?)?.cast<String, dynamic>() ?? const <String, dynamic>{};
    return AppPage(title: 'Transaction details', child: Column(children: [
      GradientPanel(borderColor: _statusColor('${transaction['status']}'), child: Column(children: [
        _ReviewRow('Transaction ID', '${transaction['id'] ?? ''}'),
        _ReviewRow('Type', '${transaction['type'] ?? ''}'),
        _ReviewRow('Status', '${transaction['status'] ?? ''}', strong: true),
        _ReviewRow('Amount', '${_num(transaction['amount']).toStringAsFixed(2)} ${transaction['currency'] ?? 'MRU'}', strong: true),
        _ReviewRow('Fee', '${_num(transaction['fee']).toStringAsFixed(2)} ${transaction['currency'] ?? 'MRU'}'),
        if (transaction['description'] != null) _ReviewRow('Description', '${transaction['description']}'),
        if (metadata['method'] != null) _ReviewRow('Method', _methodLabel('${metadata['method']}')),
        if (transaction['externalRef'] != null) _ReviewRow('Transfer reference', '${transaction['externalRef']}'),
      ])),
    ]));
  }
}

class _TransactionTile extends StatelessWidget {
  const _TransactionTile({required this.transaction});
  final Map<String, dynamic> transaction;
  @override
  Widget build(BuildContext context) {
    final type = '${transaction['type'] ?? ''}';
    final status = '${transaction['status'] ?? ''}';
    final amount = _num(transaction['amount']);
    final incoming = type == 'DEPOSIT' || type == 'MATCH_PRIZE' || type == 'REFUND' || type == 'REWARD';
    return GradientPanel(margin: const EdgeInsets.only(bottom: 10), onTap: () => Navigator.pushNamed(context, Routes.transactionDetails, arguments: transaction), child: Row(children: [
      CircleAvatar(backgroundColor: (incoming ? AppColors.green : AppColors.orange).withValues(alpha: .14), child: Icon(incoming ? Icons.south_west_rounded : Icons.north_east_rounded, color: incoming ? AppColors.green : AppColors.orange)),
      const SizedBox(width: 12),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(context.tr(type), style: const TextStyle(fontWeight: FontWeight.w900)), const SizedBox(height: 4), Text(context.tr(status), style: TextStyle(color: _statusColor(status), fontSize: 10))])),
      Text('${incoming ? '+' : '-'}${amount.toStringAsFixed(2)}', style: TextStyle(color: incoming ? AppColors.green : AppColors.orange, fontWeight: FontWeight.w900)),
      const SizedBox(width: 5),
      const Icon(Icons.chevron_right_rounded, color: AppColors.muted),
    ]));
  }
}

class _PaymentMethodTile extends StatelessWidget {
  const _PaymentMethodTile({required this.title, required this.subtitle, required this.selected, required this.icon, required this.onTap});
  final String title;
  final String subtitle;
  final bool selected;
  final IconData icon;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => GradientPanel(margin: const EdgeInsets.only(bottom: 9), borderColor: selected ? AppColors.gold : AppColors.divider, onTap: onTap, child: Row(children: [Icon(icon, color: selected ? AppColors.gold : AppColors.muted), const SizedBox(width: 12), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(context.tr(title), style: const TextStyle(fontWeight: FontWeight.w900)), const SizedBox(height: 3), Text(context.tr(subtitle), style: const TextStyle(color: AppColors.muted, fontSize: 10))])), Icon(selected ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded, color: selected ? AppColors.gold : AppColors.muted)]));
}

class _ReviewRow extends StatelessWidget {
  const _ReviewRow(this.label, this.value, {this.strong = false});
  final String label;
  final String value;
  final bool strong;
  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.symmetric(vertical: 9), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(child: Text(context.tr(label), style: const TextStyle(color: AppColors.muted))), const SizedBox(width: 10), Flexible(child: Text(context.tr(value), textAlign: TextAlign.end, style: TextStyle(fontWeight: strong ? FontWeight.w900 : FontWeight.w700, color: strong ? AppColors.gold : Colors.white)))]));
}

Map<String, dynamic> _args(BuildContext context) => ((ModalRoute.of(context)?.settings.arguments as Map?) ?? const <String, dynamic>{}).cast<String, dynamic>();
double _num(dynamic value) => double.tryParse('$value') ?? 0;
String _methodLabel(String method) => switch (method.toUpperCase()) { 'BANKILY' => 'Bankily', 'SEDAD' => 'Sedad', _ => 'Other' };
Color _statusColor(String status) => switch (status) { 'COMPLETED' => AppColors.green, 'REJECTED' || 'CANCELLED' => AppColors.red, 'PENDING' || 'PROCESSING' => AppColors.orange, _ => AppColors.muted };
void _message(BuildContext context, String value) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.tr(value))));
