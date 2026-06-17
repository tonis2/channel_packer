import 'package:flutter/material.dart';

import 'core/settings.dart';
import 'core/storage.dart';
import 'pages/editor_page.dart';
import 'state.dart';

void main() {
  // Restore persisted preferences before any save/run can read them.
  PackerSettings.embedImages = loadEmbedImages();
  PackerSettings.depthModelPath = loadDepthModelPath();
  PackerSettings.depthBinaryPath = loadDepthBinaryPath();
  runApp(Inherited(notifier: AppState(), child: const ChannelPackerApp()));
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
        // The M3 dark default accent is a pink/mauve, which the node sliders and
        // checkboxes pick up and which clashes with the dark nodes. Retheme them
        // onto amber — the same accent the output ports already use.
        sliderTheme: SliderThemeData(
          activeTrackColor: Colors.amber,
          inactiveTrackColor: Colors.white24,
          thumbColor: Colors.amber,
          overlayColor: Colors.amber.withValues(alpha: 0.15),
          valueIndicatorColor: panel,
          valueIndicatorTextStyle: const TextStyle(color: Colors.white),
          // Hide the per-division tick marks; with 80–100 divisions they clutter.
          activeTickMarkColor: Colors.transparent,
          inactiveTickMarkColor: Colors.transparent,
        ),
        checkboxTheme: CheckboxThemeData(
          fillColor: WidgetStateProperty.resolveWith(
            (states) =>
                states.contains(WidgetState.selected) ? Colors.amber : null,
          ),
          checkColor: WidgetStateProperty.all(Colors.black),
        ),
      ),
      home: const EditorPage(),
    );
  }
}
