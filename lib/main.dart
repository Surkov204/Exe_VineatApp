import 'dart:async';

import 'package:flutter/material.dart';

import 'src/app.dart';
import 'src/app_services.dart';
import 'src/inventory_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppServices.initialize();
  runApp(const VineatApp());
  // Hydrate after the first frame so the seeded demo opens instantly.
  unawaited(restoreLocalDemoData());
}
