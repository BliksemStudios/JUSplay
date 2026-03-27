import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

const _presets = [
  ('Workout 💪', 'high energy workout songs'),
  ('Focus 🎯', 'instrumental focus music'),
  ('Chill 😌', 'relaxing chill songs'),
  ('Party 🎉', 'upbeat party anthems'),
  ('Sad hours 🌧', 'melancholic emotional songs'),
  ('Road trip 🚗', 'road trip driving songs'),
  ('Sleep 🌙', 'calm sleep music'),
  ('Morning coffee ☕', 'light acoustic morning songs'),
];

/// Horizontal row of preset AI playlist chips shown at the top of HomeScreen.
class SmartPlaylistsRow extends ConsumerWidget {
  const SmartPlaylistsRow({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final accentColor = theme.colorScheme.primary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
          child: Row(
            children: [
              Icon(Icons.auto_awesome, color: accentColor, size: 18),
              const SizedBox(width: 8),
              Text(
                'Smart Playlists',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 44,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _presets.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (context, i) {
              final (label, prompt) = _presets[i];
              return ActionChip(
                label: Text(label),
                onPressed: () {
                  final encoded = Uri.encodeComponent(prompt);
                  context.push('/smart-playlist?prompt=$encoded');
                },
              );
            },
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}
