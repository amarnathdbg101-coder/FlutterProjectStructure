import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../pos/controllers/ai_features_controller.dart';
import '../../../core/utils/whatsapp_share_helper.dart';

class FestiveCampaignModal {
  static void show(BuildContext context) {
    final festCtrl = TextEditingController(text: 'Diwali Dhamaka Sale');
    final offerCtrl = TextEditingController(text: 'Flat 20% OFF on all Grocery & Garments + Free Gift on ₹2000');
    final audCtrl = TextEditingController(text: 'Local colony families & regular customers');

    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setState) {
          final aiCtrl = ctx.watch<AIFeaturesController>();
          final campaign = aiCtrl.lastMarketingCampaign;
          final isGenerating = aiCtrl.isGeneratingCampaign;

          Future<void> shareWhatsApp(String text) async {
            await WhatsAppShareHelper.shareToWhatsApp(
              context: dialogCtx,
              message: text,
            );
          }

          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Row(
              children: [
                Icon(Icons.campaign_rounded, color: Color(0xFFD97706), size: 26),
                SizedBox(width: 8),
                Text('AI Festive Marketing Studio', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ],
            ),
            content: SizedBox(
              width: double.maxFinite,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'AI crafts high-conversion WhatsApp broadcast messages, social media posters, and festive promotion copy for your store:',
                      style: TextStyle(fontSize: 12.5, color: Color(0xFF64748B)),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: festCtrl,
                      decoration: InputDecoration(
                        labelText: 'Festival / Occasion',
                        hintText: 'e.g. Diwali, Eid, New Year Sale',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: offerCtrl,
                      maxLines: 2,
                      decoration: InputDecoration(
                        labelText: 'Discount / Deal Details',
                        hintText: 'e.g. Buy 1 Get 1 Free on all kurtis',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        contentPadding: const EdgeInsets.all(12),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: audCtrl,
                      decoration: InputDecoration(
                        labelText: 'Target Customers',
                        hintText: 'e.g. Local neighborhood families',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFD97706),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        onPressed: isGenerating
                            ? null
                            : () => aiCtrl.generateMarketingCampaign(
                                  festivalName: festCtrl.text.trim(),
                                  offerDetails: offerCtrl.text.trim(),
                                  targetAudience: audCtrl.text.trim(),
                                ),
                        icon: isGenerating
                            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.auto_awesome_rounded, size: 18),
                        label: const Text('Generate Festive Copy', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),

                    if (campaign != null) ...[
                      const SizedBox(height: 18),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFFBEB),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFFDE68A)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              campaign.headline,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF92400E)),
                            ),
                            const Divider(height: 14),
                            const Text(
                              'WhatsApp Broadcast Message:',
                              style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF78350F)),
                            ),
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: const Color(0xFFFDE68A)),
                              ),
                              child: Text(
                                campaign.whatsappMessage,
                                style: const TextStyle(fontSize: 12, color: Color(0xFF1E293B)),
                              ),
                            ),
                            const SizedBox(height: 10),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                OutlinedButton.icon(
                                  onPressed: () {
                                    Clipboard.setData(ClipboardData(text: campaign.socialPostText));
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Social post copied!')),
                                    );
                                  },
                                  icon: const Icon(Icons.copy_rounded, size: 14),
                                  label: const Text('Copy Post', style: TextStyle(fontSize: 11)),
                                ),
                                const SizedBox(width: 8),
                                ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF25D366),
                                    foregroundColor: Colors.white,
                                  ),
                                  onPressed: () => shareWhatsApp(campaign.whatsappMessage),
                                  icon: const Icon(Icons.send_rounded, size: 14),
                                  label: const Text('Send Broadcast', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  aiCtrl.clearCampaign();
                  Navigator.pop(dialogCtx);
                },
                child: const Text('Close'),
              ),
            ],
          );
        },
      ),
    );
  }
}

