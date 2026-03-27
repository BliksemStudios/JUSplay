import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../../core/models/models.dart';
import '../../../core/providers/providers.dart';
import '../../../core/api/api.dart';
import '../../../core/router.dart';

/// Server login / add screen.
///
/// Displays a list of previously saved servers and a form to add a new one.
/// The user can test the connection before saving, select an existing server,
/// or delete servers they no longer need.
class ServerLoginScreen extends ConsumerStatefulWidget {
  const ServerLoginScreen({super.key});

  @override
  ConsumerState<ServerLoginScreen> createState() => _ServerLoginScreenState();
}

class _ServerLoginScreenState extends ConsumerState<ServerLoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _urlController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isTesting = false;
  bool _isConnecting = false;
  bool _obscurePassword = true;
  String? _testResult; // null = no result, 'success', or an error message
  List<Server> _savedServers = [];
  bool _loadingServers = true;

  @override
  void initState() {
    super.initState();
    _loadServers();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _urlController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _loadServers() async {
    final storage = ref.read(serverStorageProvider);
    final servers = await storage.getServers();
    if (mounted) {
      setState(() {
        _savedServers = servers;
        _loadingServers = false;
      });
    }
  }

  Server _buildServer() {
    return Server.create(
      id: const Uuid().v4(),
      name: _nameController.text.trim(),
      url: _urlController.text.trim(),
      username: _usernameController.text.trim(),
      password: _passwordController.text,
    );
  }

  Future<void> _testConnection() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isTesting = true;
      _testResult = null;
    });

    try {
      final server = _buildServer();
      final api = SubsonicApi(server);
      final ok = await api.ping();

      if (!mounted) return;
      setState(() {
        _isTesting = false;
        _testResult = ok ? 'success' : 'Server responded but ping failed.';
      });
    } on Exception catch (e) {
      if (!mounted) return;
      setState(() {
        _isTesting = false;
        _testResult = e.toString();
      });
    }
  }

  Future<void> _connect() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isConnecting = true;
      _testResult = null;
    });

    try {
      final server = _buildServer();
      final api = SubsonicApi(server);
      final ok = await api.ping();

      if (!mounted) return;

      if (!ok) {
        setState(() {
          _isConnecting = false;
          _testResult = 'Connection failed. Check your server URL and credentials.';
        });
        return;
      }

      // Save server and set as active.
      final storage = ref.read(serverStorageProvider);
      await storage.saveServer(server);
      ref.read(activeServerProvider.notifier).setServer(server);
      ref.read(isAuthenticatedProvider.notifier).state = true;

      if (mounted) {
        context.go('/home');
      }
    } on Exception catch (e) {
      if (!mounted) return;
      setState(() {
        _isConnecting = false;
        _testResult = e.toString();
      });
    }
  }

  Future<void> _selectServer(Server server) async {
    setState(() => _isConnecting = true);

    try {
      final api = SubsonicApi(server);
      final ok = await api.ping();

      if (!mounted) return;

      if (!ok) {
        setState(() {
          _isConnecting = false;
          _testResult = 'Could not reach "${server.name}". The server may be offline.';
        });
        return;
      }

      ref.read(activeServerProvider.notifier).setServer(server);
      ref.read(isAuthenticatedProvider.notifier).state = true;

      if (mounted) {
        context.go('/home');
      }
    } on Exception catch (e) {
      if (!mounted) return;
      setState(() {
        _isConnecting = false;
        _testResult = e.toString();
      });
    }
  }

  Future<void> _deleteServer(Server server) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Server'),
        content: Text('Remove "${server.name}" from saved servers?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final storage = ref.read(serverStorageProvider);
      await storage.deleteServer(server.id);

      // If this was the active server, clear it.
      final active = ref.read(activeServerProvider);
      if (active?.id == server.id) {
        ref.read(activeServerProvider.notifier).clear();
      }

      await _loadServers();
    }
  }

  void _clearForm() {
    _nameController.clear();
    _urlController.clear();
    _usernameController.clear();
    _passwordController.clear();
    setState(() => _testResult = null);
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Header
                  _buildHeader(theme, colorScheme),
                  const SizedBox(height: 32),

                  // Saved servers list
                  if (_savedServers.isNotEmpty) ...[
                    _buildSavedServers(theme, colorScheme),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        const Expanded(child: Divider()),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Text(
                            'or add a new server',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                        const Expanded(child: Divider()),
                      ],
                    ),
                    const SizedBox(height: 24),
                  ],

                  // Add server form
                  _buildForm(theme, colorScheme),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(ThemeData theme, ColorScheme colorScheme) {
    return Column(
      children: [
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            color: colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Icon(
            Icons.music_note_rounded,
            size: 36,
            color: colorScheme.onPrimaryContainer,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'JUSPlay',
          style: theme.textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Connect to your Subsonic server',
          style: theme.textTheme.bodyLarge?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _buildSavedServers(ThemeData theme, ColorScheme colorScheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Saved Servers',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        ..._savedServers.map((server) {
          final active = ref.watch(activeServerProvider);
          final isActive = active?.id == server.id;

          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: isActive
                    ? BorderSide(color: colorScheme.primary, width: 2)
                    : BorderSide.none,
              ),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: colorScheme.primaryContainer,
                  child: Icon(
                    Icons.dns_outlined,
                    color: colorScheme.onPrimaryContainer,
                    size: 20,
                  ),
                ),
                title: Text(server.name),
                subtitle: Text(
                  server.url,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isActive)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: Chip(
                          label: const Text('Active'),
                          labelStyle: TextStyle(
                            fontSize: 11,
                            color: colorScheme.primary,
                          ),
                          side: BorderSide.none,
                          padding: EdgeInsets.zero,
                          visualDensity: VisualDensity.compact,
                          backgroundColor:
                              colorScheme.primary.withValues(alpha: 0.12),
                        ),
                      ),
                    IconButton(
                      icon: Icon(
                        Icons.delete_outline,
                        color: colorScheme.error,
                        size: 20,
                      ),
                      onPressed: () => _deleteServer(server),
                      tooltip: 'Remove server',
                    ),
                  ],
                ),
                onTap: _isConnecting ? null : () => _selectServer(server),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildForm(ThemeData theme, ColorScheme colorScheme) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Server Name
          TextFormField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: 'Server Name',
              hintText: 'My Navidrome',
              prefixIcon: Icon(Icons.label_outline),
            ),
            textInputAction: TextInputAction.next,
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Please enter a server name';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),

          // Server URL
          TextFormField(
            controller: _urlController,
            decoration: const InputDecoration(
              labelText: 'Server URL',
              hintText: 'https://your-server.com',
              prefixIcon: Icon(Icons.link),
            ),
            keyboardType: TextInputType.url,
            textInputAction: TextInputAction.next,
            autocorrect: false,
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Please enter a server URL';
              }
              final uri = Uri.tryParse(value.trim());
              if (uri == null || !uri.hasScheme || !uri.hasAuthority) {
                return 'Please enter a valid URL (e.g. https://your-server.com)';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),

          // Username
          TextFormField(
            controller: _usernameController,
            decoration: const InputDecoration(
              labelText: 'Username',
              prefixIcon: Icon(Icons.person_outline),
            ),
            textInputAction: TextInputAction.next,
            autocorrect: false,
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Please enter your username';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),

          // Password
          TextFormField(
            controller: _passwordController,
            decoration: InputDecoration(
              labelText: 'Password',
              prefixIcon: const Icon(Icons.lock_outline),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscurePassword
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                ),
                onPressed: () =>
                    setState(() => _obscurePassword = !_obscurePassword),
              ),
            ),
            obscureText: _obscurePassword,
            textInputAction: TextInputAction.done,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter your password';
              }
              return null;
            },
          ),
          const SizedBox(height: 24),

          // Test result message
          if (_testResult != null) ...[
            _buildTestResultBanner(colorScheme),
            const SizedBox(height: 16),
          ],

          // Action buttons
          Row(
            children: [
              // Test Connection
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: (_isTesting || _isConnecting)
                      ? null
                      : _testConnection,
                  icon: _isTesting
                      ? SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: colorScheme.primary,
                          ),
                        )
                      : const Icon(Icons.wifi_tethering, size: 18),
                  label: Text(_isTesting ? 'Testing...' : 'Test Connection'),
                ),
              ),
              const SizedBox(width: 12),
              // Connect
              Expanded(
                child: FilledButton.icon(
                  onPressed: (_isTesting || _isConnecting) ? null : _connect,
                  icon: _isConnecting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.login, size: 18),
                  label: Text(_isConnecting ? 'Connecting...' : 'Connect'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTestResultBanner(ColorScheme colorScheme) {
    final isSuccess = _testResult == 'success';
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isSuccess
            ? Colors.green.withValues(alpha: 0.12)
            : colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(
            isSuccess ? Icons.check_circle_outline : Icons.error_outline,
            size: 20,
            color: isSuccess ? Colors.green : colorScheme.onErrorContainer,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              isSuccess ? 'Connection successful!' : _testResult!,
              style: TextStyle(
                color: isSuccess ? Colors.green : colorScheme.onErrorContainer,
                fontSize: 13,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 18),
            onPressed: () => setState(() => _testResult = null),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }
}
