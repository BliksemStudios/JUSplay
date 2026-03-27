import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/models/models.dart';
import '../../../core/providers/providers.dart';
import '../../../core/storage/settings_storage.dart';
import '../../../core/theme/app_theme.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  // ---------------------------------------------------------------------------
  // Quality options
  // ---------------------------------------------------------------------------

  static const _streamingQualities = <int, String>{
    0: 'Raw (Original)',
    128: '128 kbps',
    192: '192 kbps',
    320: '320 kbps',
  };

  static const _downloadQualities = <int, String>{
    0: 'Raw (Original)',
    128: '128 kbps',
    192: '192 kbps',
    320: '320 kbps',
  };

  static const _cacheSizes = <int, String>{
    250: '250 MB',
    500: '500 MB',
    1000: '1 GB',
    2000: '2 GB',
    5000: '5 GB',
  };

  static const _themeModes = <String, String>{
    'dark': 'Dark',
    'light': 'Light',
    'system': 'System',
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final settings = ref.watch(settingsStorageProvider);
    final activeServer = ref.watch(activeServerProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: ListView(
        children: [
          // -----------------------------------------------------------------
          // Server section
          // -----------------------------------------------------------------
          _SectionHeader(title: 'Server', colorScheme: colorScheme),
          ListTile(
            leading: const Icon(Icons.dns_outlined),
            title: const Text('Current server'),
            subtitle: Text(activeServer?.name ?? 'Not connected'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showServerOptions(context),
          ),
          ListTile(
            leading: const Icon(Icons.swap_horiz),
            title: const Text('Switch server'),
            onTap: () => _showServerSwitcher(context),
          ),
          ListTile(
            leading: const Icon(Icons.add),
            title: const Text('Add server'),
            onTap: () => context.go('/login'),
          ),
          const Divider(),

          // -----------------------------------------------------------------
          // Playback section
          // -----------------------------------------------------------------
          _SectionHeader(title: 'Playback', colorScheme: colorScheme),
          ListTile(
            leading: const Icon(Icons.high_quality_outlined),
            title: const Text('Streaming quality'),
            subtitle: Text(
              _streamingQualities[settings.streamingQuality] ?? 'Unknown',
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showDropdownPicker<int>(
              context: context,
              title: 'Streaming Quality',
              options: _streamingQualities,
              currentValue: settings.streamingQuality,
              onSelected: (value) => settings.setStreamingQuality(value),
            ),
          ),
          SwitchListTile(
            secondary: const Icon(Icons.graphic_eq_outlined),
            title: const Text('Gapless playback'),
            subtitle: const Text('Seamless transitions between tracks'),
            value: settings.gaplessPlayback,
            onChanged: (value) {
              settings.setGaplessPlayback(value);
              setState(() {});
            },
          ),
          SwitchListTile(
            secondary: const Icon(Icons.volume_up_outlined),
            title: const Text('ReplayGain'),
            subtitle: const Text('Normalize volume between tracks'),
            value: settings.replayGain,
            onChanged: (value) {
              settings.setReplayGain(value);
              setState(() {});
            },
          ),
          const Divider(),

          // -----------------------------------------------------------------
          // Downloads section
          // -----------------------------------------------------------------
          _SectionHeader(title: 'Downloads', colorScheme: colorScheme),
          ListTile(
            leading: const Icon(Icons.download_outlined),
            title: const Text('Download quality'),
            subtitle: Text(
              _downloadQualities[settings.downloadQuality] ?? 'Unknown',
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showDropdownPicker<int>(
              context: context,
              title: 'Download Quality',
              options: _downloadQualities,
              currentValue: settings.downloadQuality,
              onSelected: (value) => settings.setDownloadQuality(value),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.sd_storage_outlined),
            title: const Text('Cache size limit'),
            subtitle: Text(
              _cacheSizes[settings.cacheSize] ?? '${settings.cacheSize} MB',
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showDropdownPicker<int>(
              context: context,
              title: 'Cache Size Limit',
              options: _cacheSizes,
              currentValue: settings.cacheSize,
              onSelected: (value) => settings.setCacheSize(value),
            ),
          ),
          const Divider(),

          // -----------------------------------------------------------------
          // Network section
          // -----------------------------------------------------------------
          _SectionHeader(title: 'Network', colorScheme: colorScheme),
          SwitchListTile(
            secondary: const Icon(Icons.wifi),
            title: const Text('Wi-Fi only streaming'),
            subtitle: const Text('Only stream over Wi-Fi connections'),
            value: settings.wifiOnly,
            onChanged: (value) {
              settings.setWifiOnly(value);
              setState(() {});
            },
          ),
          const Divider(),

          // -----------------------------------------------------------------
          // Scrobbling section
          // -----------------------------------------------------------------
          _SectionHeader(title: 'Scrobbling', colorScheme: colorScheme),
          SwitchListTile(
            secondary: const Icon(Icons.history),
            title: const Text('Scrobbling'),
            subtitle: const Text('Report plays to the server'),
            value: settings.scrobblingEnabled,
            onChanged: (value) {
              settings.setScrobblingEnabled(value);
              setState(() {});
            },
          ),
          const Divider(),

          // -----------------------------------------------------------------
          // Appearance section
          // -----------------------------------------------------------------
          _SectionHeader(title: 'Appearance', colorScheme: colorScheme),
          ListTile(
            leading: const Icon(Icons.palette_outlined),
            title: const Text('Theme'),
            subtitle: Text(_themeModes[settings.themeMode] ?? 'System'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showDropdownPicker<String>(
              context: context,
              title: 'Theme Mode',
              options: _themeModes,
              currentValue: settings.themeMode,
              onSelected: (value) => settings.setThemeMode(value),
            ),
          ),
          const _AccentThemePicker(),
          const Divider(),

          // -----------------------------------------------------------------
          // AI Features section
          // -----------------------------------------------------------------
          _SectionHeader(title: 'AI Features', colorScheme: colorScheme),
          _GeminiApiKeyField(settings: settings),
          const Divider(),

          // -----------------------------------------------------------------
          // About section
          // -----------------------------------------------------------------
          _SectionHeader(title: 'About', colorScheme: colorScheme),
          const ListTile(
            leading: Icon(Icons.info_outline),
            title: Text('Version'),
            subtitle: Text('0.1.0'),
          ),
          ListTile(
            leading: const Icon(Icons.code),
            title: const Text('Source code'),
            subtitle: const Text('GitHub'),
            trailing: const Icon(Icons.open_in_new, size: 18),
            onTap: () {
              // TODO: Open GitHub URL via url_launcher
            },
          ),
          ListTile(
            leading: const Icon(Icons.favorite_outline),
            title: const Text('Support the project'),
            subtitle: const Text('Donate'),
            trailing: const Icon(Icons.open_in_new, size: 18),
            onTap: () {
              // TODO: Open donate URL via url_launcher
            },
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Dialogs
  // ---------------------------------------------------------------------------

  void _showServerOptions(BuildContext context) {
    final server = ref.read(activeServerProvider);
    if (server == null) {
      context.go('/login');
      return;
    }

    showDialog(
      context: context,
      builder: (context) {
        final colorScheme = Theme.of(context).colorScheme;
        return AlertDialog(
          title: Text(server.name),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('URL: ${server.url}',
                  style: TextStyle(color: colorScheme.onSurfaceVariant)),
              const SizedBox(height: 4),
              Text('User: ${server.username}',
                  style: TextStyle(color: colorScheme.onSurfaceVariant)),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showServerSwitcher(BuildContext context) async {
    final storage = ref.read(serverStorageProvider);
    final servers = await storage.getServers();

    if (!mounted) return;

    if (servers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No servers configured')),
      );
      return;
    }

    final selected = await showDialog<Server>(
      context: context,
      builder: (context) {
        final activeServer = ref.read(activeServerProvider);
        return SimpleDialog(
          title: const Text('Switch Server'),
          children: servers.map((server) {
            final isActive = activeServer?.id == server.id;
            return SimpleDialogOption(
              onPressed: () => Navigator.of(context).pop(server),
              child: Row(
                children: [
                  Icon(
                    isActive
                        ? Icons.radio_button_checked
                        : Icons.radio_button_unchecked,
                    color: isActive
                        ? Theme.of(context).colorScheme.primary
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          server.name,
                          style: TextStyle(
                            fontWeight:
                                isActive ? FontWeight.w600 : FontWeight.normal,
                          ),
                        ),
                        Text(
                          server.url,
                          style: TextStyle(
                            fontSize: 12,
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        );
      },
    );

    if (selected != null && mounted) {
      await ref.read(activeServerProvider.notifier).setServer(selected);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Switched to ${selected.name}')),
        );
      }
    }
  }

  Future<void> _showDropdownPicker<T>({
    required BuildContext context,
    required String title,
    required Map<T, String> options,
    required T currentValue,
    required ValueChanged<T> onSelected,
  }) async {
    final selected = await showDialog<T>(
      context: context,
      builder: (context) {
        return SimpleDialog(
          title: Text(title),
          children: options.entries.map((entry) {
            final isActive = entry.key == currentValue;
            return SimpleDialogOption(
              onPressed: () => Navigator.of(context).pop(entry.key),
              child: Row(
                children: [
                  Icon(
                    isActive
                        ? Icons.radio_button_checked
                        : Icons.radio_button_unchecked,
                    color: isActive
                        ? Theme.of(context).colorScheme.primary
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    entry.value,
                    style: TextStyle(
                      fontWeight:
                          isActive ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        );
      },
    );

    if (selected != null) {
      onSelected(selected);
      setState(() {});
    }
  }
}

// -----------------------------------------------------------------------------
// Accent theme picker widget
// -----------------------------------------------------------------------------

class _AccentThemePicker extends ConsumerWidget {
  const _AccentThemePicker();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentKey = ref.watch(accentThemeProvider);
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Row(
        children: AppTheme.themeConfigs.entries.map((entry) {
          final isSelected = entry.key == currentKey;
          final color = entry.value.accent;

          return Padding(
            padding: const EdgeInsets.only(right: 16),
            child: GestureDetector(
              onTap: () =>
                  ref.read(accentThemeProvider.notifier).setTheme(entry.key),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      border: isSelected
                          ? Border.all(
                              color: colorScheme.onSurface,
                              width: 3,
                            )
                          : Border.all(
                              color: colorScheme.outlineVariant,
                              width: 1,
                            ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    // Short label: last word of display name (e.g. "Amber", "Teal")
                    entry.value.displayName.split(' ').last,
                    style: TextStyle(
                      fontSize: 10,
                      color: isSelected
                          ? colorScheme.primary
                          : colorScheme.onSurfaceVariant,
                      fontWeight: isSelected
                          ? FontWeight.w600
                          : FontWeight.normal,
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Gemini API key field widget
// -----------------------------------------------------------------------------

class _GeminiApiKeyField extends StatefulWidget {
  const _GeminiApiKeyField({required this.settings});
  final SettingsStorage settings;

  @override
  State<_GeminiApiKeyField> createState() => _GeminiApiKeyFieldState();
}

class _GeminiApiKeyFieldState extends State<_GeminiApiKeyField> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.settings.geminiApiKey);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: TextField(
            obscureText: true,
            controller: _controller,
            decoration: const InputDecoration(
              labelText: 'Gemini API Key',
              hintText: 'Paste your Gemini API key here',
              prefixIcon: Icon(Icons.vpn_key_outlined),
            ),
            onChanged: (value) => widget.settings.setGeminiApiKey(value),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
          child: Text(
            'Used to generate smart playlists when on-device AI is unavailable.',
            style: TextStyle(
              fontSize: 12,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }
}

// -----------------------------------------------------------------------------
// Section header widget
// -----------------------------------------------------------------------------

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    required this.colorScheme,
  });

  final String title;
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: colorScheme.primary,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
