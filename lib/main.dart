import 'dart:async';

import 'package:flutter/material.dart';

import 'src/app.dart';
import 'src/inventory_store.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const VineatApp());
  // Hydrate after the first frame so the seeded demo opens instantly.
  unawaited(restoreInventory());
}
