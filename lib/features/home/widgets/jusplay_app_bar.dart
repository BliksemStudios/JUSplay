import 'package:flutter/material.dart';

/// Tidal-inspired gradient app bar for the home screen.
///
/// Shows a left-to-right accent colour bleed, a glass music-note icon,
/// a gradient wordmark, and a server status pill.
class JUSPlayAppBar extends StatelessWidget implements PreferredSizeWidget {
  const JUSPlayAppBar({
    super.key,
    required this.accentColor,
    this.serverName,
    this.isConnected = false,
  });

  final Color accentColor;
  final String? serverName;
  final bool isConnected;

  @override
  Size get preferredSize => const Size.fromHeight(64);

  @override
  Widget build(BuildContext context) {
    return Container(
      height: preferredSize.height + MediaQuery.of(context).padding.top,
      padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
      ),
      child: Stack(
        children: [
          // Left gradient bleed
          Positioned.fill(
            child: Align(
              alignment: Alignment.centerLeft,
              child: Container(
                width: 280,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      accentColor.withValues(alpha: 0.18),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ),
          // Content row — Positioned.fill so Row fills the 64px area and can centre vertically
          Positioned.fill(
            child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Glass icon container
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    color: accentColor.withValues(alpha: 0.12),
                    border: Border.all(
                      color: accentColor.withValues(alpha: 0.25),
                    ),
                  ),
                  child: Icon(
                    Icons.music_note,
                    color: accentColor,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                // Gradient wordmark
                ShaderMask(
                  shaderCallback: (bounds) => LinearGradient(
                    colors: [
                      accentColor,
                      accentColor.withValues(alpha: 0.6),
                    ],
                  ).createShader(bounds),
                  child: const Text(
                    'JUSPlay',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                      color: Colors.white, // overridden by ShaderMask
                    ),
                  ),
                ),
                const Spacer(),
                // Server status pill
                _StatusPill(
                  isConnected: isConnected,
                  serverName: serverName,
                ),
              ],
            ),
            ),
          ),
          // Bottom hairline accent
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              height: 1,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.transparent,
                    accentColor.withValues(alpha: 0.5),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.isConnected, this.serverName});

  final bool isConnected;
  final String? serverName;

  @override
  Widget build(BuildContext context) {
    final color = isConnected ? const Color(0xFF10B981) : Colors.red;
    final label = isConnected ? (serverName ?? 'Connected') : 'Offline';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
