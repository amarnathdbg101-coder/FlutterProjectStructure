import 'package:flutter/material.dart';
import '../localization/language_controller.dart';
import '../network/network_status_service.dart';

/// Non-intrusive global floating pill that informs the merchant when device is offline
/// and working reliably from local cache storage.
class OfflineStatusOverlay extends StatelessWidget {
  final Widget child;

  const OfflineStatusOverlay({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: NetworkStatusService(),
      builder: (context, _) {
        final isOnline = NetworkStatusService().isOnline;

        return Stack(
          children: [
            child,
            Positioned(
              top: MediaQuery.of(context).padding.top + 8,
              left: 16,
              right: 16,
              child: AnimatedSlide(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOutCubic,
                offset: isOnline ? const Offset(0, -1.5) : Offset.zero,
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 250),
                  opacity: isOnline ? 0.0 : 1.0,
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: Container(
                      constraints: const BoxConstraints(maxWidth: 420),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E293B), // Premium Slate 800
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.25),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                        border: Border.all(
                          color: const Color(0xFFF59E0B).withValues(alpha: 0.6), // Amber warning border
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: Color(0xFFF59E0B),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Icon(
                            Icons.wifi_off_rounded,
                            size: 15,
                            color: Color(0xFFFCD34D),
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              context.isHindi
                                  ? 'ऑफलाइन मोड • लोकल डेटा से चालू है'
                                  : 'Offline Mode • Local Cache Active',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                decoration: TextDecoration.none,
                              ),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
