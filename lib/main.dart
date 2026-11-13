import 'package:flutter/material.dart';
import 'package:masareef/app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(MasareefApp(controller: await createController()));
}
