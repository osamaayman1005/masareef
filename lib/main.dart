import 'package:masareef/app.dart';
import 'package:material_ui/material_ui.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(MasareefApp(controller: await createController()));
}
