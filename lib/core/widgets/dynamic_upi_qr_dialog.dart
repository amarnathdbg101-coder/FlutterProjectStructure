import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../constants/app_colors.dart';
import '../localization/language_controller.dart';
import '../../features/auth/controllers/auth_controller.dart';
import '../../features/dashboard/models/shop_model.dart';

/// Shows an instant Dynamic UPI QR Code for the exact bill amount
/// Scannable by Google Pay, PhonePe, Paytm, BHIM, and any UPI app.
void showDynamicUpiQrDialog(
  BuildContext context, {
  required double amount,
  String? billNumber,
}) {
  final auth = context.read<AuthController>();
  final shop = auth.currentShop;
  final initialUpiId = shop?.upiId ?? '';

  showDialog(
    context: context,
    builder: (ctx) => _DynamicUpiQrModal(
      amount: amount,
      billNumber: billNumber,
      shop: shop,
      initialUpiId: initialUpiId,
    ),
  );
}

class _DynamicUpiQrModal extends StatefulWidget {
  final double amount;
  final String? billNumber;
  final ShopModel? shop;
  final String initialUpiId;

  const _DynamicUpiQrModal({
    required this.amount,
    this.billNumber,
    this.shop,
    required this.initialUpiId,
  });

  @override
  State<_DynamicUpiQrModal> createState() => _DynamicUpiQrModalState();
}

class _DynamicUpiQrModalState extends State<_DynamicUpiQrModal> {
  late final TextEditingController _upiCtrl;
  late String _currentUpiId;
  bool _isEditingUpi = false;
  bool _isSavingUpi = false;

  @override
  void initState() {
    super.initState();
    _currentUpiId = widget.initialUpiId.trim();
    _upiCtrl = TextEditingController(text: _currentUpiId);
    _isEditingUpi = _currentUpiId.isEmpty;
  }

  @override
  void dispose() {
    _upiCtrl.dispose();
    super.dispose();
  }

  String _buildUpiUri() {
    final payeeName = widget.shop?.name.isNotEmpty == true ? widget.shop!.name : 'ShopSilo Store';
    final encName = Uri.encodeComponent(payeeName);
    final amtStr = widget.amount.toStringAsFixed(2);
    final note = widget.billNumber != null && widget.billNumber!.isNotEmpty
        ? Uri.encodeComponent('Bill ${widget.billNumber}')
        : Uri.encodeComponent('Retail Purchase');

    return 'upi://pay?pa=$_currentUpiId&pn=$encName&am=$amtStr&cu=INR&tn=$note';
  }

  Future<void> _saveUpiId() async {
    final newId = _upiCtrl.text.trim();
    if (newId.isEmpty || !newId.contains('@')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid UPI ID (e.g. mobile@paytm or name@okhdfcbank)'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() => _isSavingUpi = true);
    final auth = context.read<AuthController>();
    final ok = await auth.updateShop({'upi_id': newId});
    if (!mounted) return;
    setState(() => _isSavingUpi = false);

    if (ok) {
      setState(() {
        _currentUpiId = newId;
        _isEditingUpi = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.tr('pos_upi_save_id')),
          backgroundColor: AppColors.success,
        ),
      );
    } else {
      // Still allow local preview even if offline
      setState(() {
        _currentUpiId = newId;
        _isEditingUpi = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final shopName = widget.shop?.name.isNotEmpty == true ? widget.shop!.name : 'ShopSilo Store';

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      backgroundColor: context.colorSurface,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: context.colorPrimaryLight,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.qr_code_scanner_rounded, color: AppColors.primary, size: 20),
                      ),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            context.tr('pos_upi_qr_title'),
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: context.colorTextPrimary,
                            ),
                          ),
                          Text(
                            shopName,
                            style: TextStyle(
                              fontSize: 11,
                              color: context.colorTextSecondary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  IconButton(
                    icon: Icon(Icons.close_rounded, size: 20, color: context.colorTextSecondary),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Divider(height: 1, color: context.colorBorder),
              const SizedBox(height: 16),

              // Prominent Amount Box
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                decoration: BoxDecoration(
                  color: context.colorSurfaceSubtle,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: context.colorBorder),
                ),
                child: Column(
                  children: [
                    Text(
                      widget.billNumber != null && widget.billNumber!.isNotEmpty
                          ? 'Bill #${widget.billNumber}'
                          : 'Counter Sale',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: context.colorTextSecondary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        '₹${widget.amount.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.w900,
                          color: AppColors.primary,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // QR Code or Setup UPI Box
              if (_currentUpiId.isEmpty || _isEditingUpi) ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: context.colorSurfaceSubtle,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: context.colorBorder),
                  ),
                  child: Column(
                    children: [
                      const Icon(Icons.account_balance_wallet_outlined, size: 36, color: AppColors.primary),
                      const SizedBox(height: 8),
                      Text(
                        context.tr('pos_upi_enter_id'),
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.bold,
                          color: context.colorTextPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        context.tr('pos_upi_not_configured'),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 11,
                          color: context.colorTextSecondary,
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _upiCtrl,
                        autofocus: true,
                        decoration: InputDecoration(
                          hintText: 'e.g. yourname@okhdfcbank or 9876543210@paytm',
                          hintStyle: TextStyle(fontSize: 12, color: context.colorTextMuted),
                          filled: true,
                          fillColor: context.colorSurface,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(color: context.colorBorder),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            padding: const EdgeInsets.symmetric(vertical: 10),
                          ),
                          onPressed: _isSavingUpi ? null : _saveUpiId,
                          child: _isSavingUpi
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                )
                              : Text(
                                  context.tr('pos_upi_save_id'),
                                  style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ] else ...[
                // Scannable Real Dynamic UPI QR
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: context.colorBorder, width: 1.5),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.06),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      QrImageView(
                        data: _buildUpiUri(),
                        version: QrVersions.auto,
                        size: 210,
                        backgroundColor: Colors.white,
                        errorCorrectionLevel: QrErrorCorrectLevel.M,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Scan to Pay ₹${widget.amount.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // Supported UPI Apps Row
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    _buildAppBadge('GPay'),
                    _buildAppBadge('PhonePe'),
                    _buildAppBadge('Paytm'),
                    _buildAppBadge('BHIM'),
                    _buildAppBadge('CRED'),
                  ],
                ),
                const SizedBox(height: 12),

                // Active UPI ID display + Edit / Copy Actions
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: context.colorSurfaceSubtle,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: context.colorBorder),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.verified_user_outlined, size: 16, color: AppColors.success),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'VPA: $_currentUpiId',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.bold,
                            color: context.colorTextPrimary,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      InkWell(
                        onTap: () {
                          Clipboard.setData(ClipboardData(text: _currentUpiId));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('UPI ID copied to clipboard'),
                              duration: Duration(seconds: 1),
                            ),
                          );
                        },
                        child: const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 4),
                          child: Icon(Icons.copy_rounded, size: 15, color: AppColors.primary),
                        ),
                      ),
                      const SizedBox(width: 4),
                      InkWell(
                        onTap: () => setState(() => _isEditingUpi = true),
                        child: const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 4),
                          child: Icon(Icons.edit_outlined, size: 15, color: AppColors.primary),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 16),
              // Close Button
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    context.tr('btn_close'),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAppBadge(String name) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: context.colorSurfaceSubtle,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: context.colorBorder),
      ),
      child: Text(
        name,
        style: TextStyle(
          fontSize: 9.5,
          fontWeight: FontWeight.w700,
          color: context.colorTextSecondary,
        ),
      ),
    );
  }
}
