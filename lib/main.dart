import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';

import 'providers/document_provider.dart';
import 'screens/camera_screen.dart';
import 'screens/categorize_screen.dart';
import 'screens/document_viewer_screen.dart';
import 'screens/edit_screen.dart';
import 'screens/home_screen.dart';
import 'services/notification_service.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");
  await NotificationService.instance.init();

  runApp(
    ChangeNotifierProvider(
      create: (_) => DocumentProvider()..loadDocuments(),
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DocuBot',
      theme: appTheme,
      home: const HomeScreen(),
      routes: {
        '/camera': (_) => const CameraScreen(),
        '/categorize': (_) => const CategorizeScreen(),
        '/view': (_) => const DocumentViewerScreen(),
        '/edit': (_) => const EditScreen(),
      },
    );
  }
}
