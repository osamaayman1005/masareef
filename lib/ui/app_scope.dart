import 'package:flutter/widgets.dart';
import 'package:masareef/state/app_controller.dart';

/// Gives every screen the [AppController] and rebuilds them when it changes.
class AppScope extends InheritedNotifier<AppController> {
  const AppScope(
      {required AppController controller, required super.child, super.key})
      : super(notifier: controller);

  static AppController of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppScope>()!.notifier!;

  /// For callbacks: reads without subscribing to rebuilds.
  static AppController read(BuildContext context) =>
      context.getInheritedWidgetOfExactType<AppScope>()!.notifier!;
}
