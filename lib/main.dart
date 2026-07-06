import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'models/game_state.dart';
import 'screens/loading_screen.dart';
import 'theme/app_colors.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: AppColors.deepIce,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );
  // The loading screen is allowed to rotate freely; gameplay screens lock
  // themselves back to portrait as soon as they mount.
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  runApp(const FrozenCatchApp());
}

class FrozenCatchApp extends StatelessWidget {
  const FrozenCatchApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => GameState(),
      child: MaterialApp(
        title: 'Frozen Catch',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          colorSchemeSeed: AppColors.midIce,
          scaffoldBackgroundColor: AppColors.deepIce,
          fontFamily: 'Roboto',
        ),
        home: const LoadingScreen(),
      ),
    );
  }
}
