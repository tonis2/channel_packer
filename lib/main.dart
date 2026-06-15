import 'package:flutter/material.dart';

import 'core/settings.dart';
import 'core/storage.dart';
import 'pages/editor_page.dart';
import 'state.dart';

void main() {
  // Restore the persisted "embed images" preference before any save can run.
  PackerSettings.embedImages = loadEmbedImages();
  runApp(Inherited(
    notifier: AppState(),
    child: const ChannelPackerApp(),
  ));
}

class ChannelPackerApp extends StatelessWidget {
  const ChannelPackerApp({super.key});

  @override
  Widget build(BuildContext context) {
    final base = ThemeData.dark(useMaterial3: true);
    // Near-black panel color shared by the top toolbar and the canvas right-click
    // menu. easy_nodes paints its context menus with colorScheme.secondary, and
    // the M3 dark default for that is a pink/mauve that washes out the white menu
    // text — so we override it here (and match the AppBar) for a consistent look.
    const panel = Color(0xFF202124);
    return MaterialApp(
      title: 'Channel Packer',
      debugShowCheckedModeBanner: false,
      theme: base.copyWith(
        colorScheme: base.colorScheme.copyWith(secondary: panel),
        appBarTheme: const AppBarTheme(
          backgroundColor: panel,
          foregroundColor: Colors.white,
        ),
      ),
      home: const EditorPage(),
    );
  }
}
