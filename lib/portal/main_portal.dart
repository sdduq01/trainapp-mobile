import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import '../firebase_options.dart';
import 'portal_app.dart';

/// Punto de entrada del portal web de gimnasios (`/gimnasio` en Hosting).
/// Se compila aparte de la app: `scripts/build_portal.sh`.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const PortalApp());
}
