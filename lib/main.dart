import 'package:flutter/material.dart';

import 'screens/auth_screen.dart';
import 'theme/app_theme.dart';

void main() => runApp(const NeedMarketplaceApp());

class NeedMarketplaceApp extends StatelessWidget {
  const NeedMarketplaceApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'NeedHub',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: const AuthScreen(),
    );
  }
}
