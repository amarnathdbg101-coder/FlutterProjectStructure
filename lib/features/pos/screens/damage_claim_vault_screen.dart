import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../controllers/damage_claim_controller.dart';

class DamageClaimVaultScreen extends StatefulWidget {
  const DamageClaimVaultScreen({super.key});

  @override
  State<DamageClaimVaultScreen> createState() => _DamageClaimVaultScreenState();
}

class _DamageClaimVaultScreenState extends State<DamageClaimVaultScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<DamageClaimController>().loadClaims();
    });
  }

  Color _getStatusColor(String status) {
    switch (status.toUpperCase()) {
      case 'PENDING':
        return const Color(0xFFD97706);
      case 'APPROVED':
        return const Color(0xFF2563EB);
      case 'SETTLED':
        return const Color(0xFF16A34A);
      case 'REJECTED':
        return const Color(0xFFDC2626);
      default:
        return const Color(0xFF64748B);
    }
  }

  void _showNewClaimDialog() {
    final distCtrl = TextEditingController();
    final prodCtrl = TextEditingController();
    final batchCtrl = TextEditingController();
    final qtyCtrl = TextEditingController(text: '1');
    final costCtrl = TextEditingController();
    String reason = 'DAMAGED_IN_TRANSIT';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogCtx, setState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.assignment_return_rounded, color: AppColors.primary, size: 24),
              SizedBox(width: 8),
              Text('Log Company Damage Claim', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Record damaged or expired inventory lots for company credit note return:',
                  style: TextStyle(fontSize: 12.5, color: Color(0xFF64748B)),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: distCtrl,
                  decoration: InputDecoration(
                    labelText: 'Distributor / Supplier Name',
                    hintText: 'e.g. HUL Super Agency',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: prodCtrl,
                  decoration: InputDecoration(
                    labelText: 'Product Name',
                    hintText: 'e.g. Fortune Sunflower Oil 1L',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: batchCtrl,
                  decoration: InputDecoration(
                    labelText: 'Batch / Lot Number',
                    hintText: 'e.g. BATCH-2026-X1',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: qtyCtrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: InputDecoration(
                          labelText: 'Quantity',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: costCtrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: InputDecoration(
                          labelText: 'Unit Cost (₹)',
                          prefixText: '₹ ',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue: reason,
                  decoration: InputDecoration(
                    labelText: 'Damage Reason',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'DAMAGED_IN_TRANSIT', child: Text('Damaged in Transit / Leaked')),
                    DropdownMenuItem(value: 'EXPIRED_LOT', child: Text('Expired Lot (Company Return)')),
                    DropdownMenuItem(value: 'DEFECTIVE_BATCH', child: Text('Factory Defect / Bad Seal')),
                    DropdownMenuItem(value: 'PEST_INFESTED', child: Text('Damaged in Godown')),
                  ],
                  onChanged: (val) {
                    if (val != null) setState(() => reason = val);
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () async {
                final qty = double.tryParse(qtyCtrl.text.trim()) ?? 1.0;
                final cost = double.tryParse(costCtrl.text.trim()) ?? 0.0;
                final ok = await context.read<DamageClaimController>().createClaim(
                      distributorName: distCtrl.text.trim(),
                      productId: 'PROD-CUSTOM',
                      productName: prodCtrl.text.trim(),
                      batchNumber: batchCtrl.text.trim(),
                      quantity: qty,
                      unitCost: cost,
                      reason: reason,
                    );
                if (ok && ctx.mounted) {
                  Navigator.pop(ctx);
                }
              },
              child: const Text('Save Claim'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final claimCtrl = context.watch<DamageClaimController>();
    final claims = claimCtrl.filteredClaims;
    final activeFilter = claimCtrl.activeStatusFilter;

    final totalClaimed = claims.fold(0.0, (acc, c) => acc + c.claimAmount);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Damage Claim Vault', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => claimCtrl.loadClaims(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Log Claim'),
        onPressed: _showNewClaimDialog,
      ),
      body: Column(
        children: [
          // KPI Banner
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFBFDBFE)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Total Claim Amount', style: TextStyle(fontSize: 12, color: Color(0xFF1E40AF))),
                        const SizedBox(height: 4),
                        Text(
                          '₹${totalClaimed.toStringAsFixed(2)}',
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1E3A8A)),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF3C7),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFFDE68A)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Active Claims Count', style: TextStyle(fontSize: 12, color: Color(0xFF92400E))),
                        const SizedBox(height: 4),
                        Text(
                          '${claims.length} Lots',
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF78350F)),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Status Filter Tabs
          Container(
            height: 48,
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: ['ALL', 'PENDING', 'APPROVED', 'SETTLED', 'REJECTED'].map((filter) {
                final isSelected = activeFilter == filter;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(filter, style: TextStyle(fontSize: 12, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
                    selected: isSelected,
                    selectedColor: AppColors.primary.withValues(alpha: 0.15),
                    onSelected: (_) => claimCtrl.setFilter(filter),
                  ),
                );
              }).toList(),
            ),
          ),
          const Divider(height: 1),

          // Claims List
          Expanded(
            child: claimCtrl.isLoading
                ? const Center(child: CircularProgressIndicator())
                : claims.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.inventory_2_outlined, size: 56, color: Colors.grey[400]),
                            const SizedBox(height: 12),
                            Text(
                              'No claims recorded under "$activeFilter"',
                              style: const TextStyle(fontSize: 14, color: Color(0xFF64748B)),
                            ),
                          ],
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: claims.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 10),
                        itemBuilder: (context, idx) {
                          final claim = claims[idx];
                          final color = _getStatusColor(claim.status);
                          final dateStr = DateFormat('dd MMM yyyy').format(claim.createdAt);

                          return Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.02),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        claim.productName,
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: color.withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(color: color.withValues(alpha: 0.4)),
                                      ),
                                      child: Text(
                                        claim.status,
                                        style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'Distributor: ${claim.distributorName} • Batch #${claim.batchNumber}',
                                  style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Qty: ${claim.quantity.toStringAsFixed(0)} • Reason: ${claim.reason}',
                                      style: const TextStyle(fontSize: 12, color: Color(0xFF475569)),
                                    ),
                                    Text(
                                      'Claim: ₹${claim.claimAmount.toStringAsFixed(2)}',
                                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                                    ),
                                  ],
                                ),
                                const Divider(height: 16),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(dateStr, style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
                                    if (claim.status != 'SETTLED') ...[
                                      PopupMenuButton<String>(
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFF1F5F9),
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: const Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Text('Update Status', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                                              Icon(Icons.arrow_drop_down_rounded, size: 16),
                                            ],
                                          ),
                                        ),
                                        onSelected: (newStatus) {
                                          claimCtrl.updateClaimStatus(claim.id, newStatus);
                                        },
                                        itemBuilder: (ctx) => const [
                                          PopupMenuItem(value: 'APPROVED', child: Text('Mark Approved')),
                                          PopupMenuItem(value: 'SETTLED', child: Text('Mark Settled (Credit Note Received)')),
                                          PopupMenuItem(value: 'REJECTED', child: Text('Mark Rejected')),
                                        ],
                                      ),
                                    ],
                                  ],
                                ),
                              ],
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
