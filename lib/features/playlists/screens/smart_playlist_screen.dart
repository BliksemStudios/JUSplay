import 'package:flutter/material.dart';

class SmartPlaylistScreen extends StatelessWidget {
  const SmartPlaylistScreen({super.key, this.initialPrompt = ''});
  final String initialPrompt;

  @override
  Widget build(BuildContext context) =>
      Scaffold(appBar: AppBar(title: const Text('Smart Playlist')));
}
