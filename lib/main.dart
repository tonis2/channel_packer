import 'package:flutter/material.dart';

import 'pages/editor_page.dart';
import 'state.dart';

void main() {
  runApp(Inherited(
    notifier: AppState(),
    child: const ChannelPackerApp(),
  ));
}

class ChannelPackerApp extends StatelessWidget {
  const ChannelPackerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Channel Packer',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(useMaterial3: true),
      home: const EditorPage(),
    );
  }
}
