import 'package:flutter/foundation.dart';

/// Lets routes outside [MainShell] switch the shell tab without pushing another shell.
class ShellTabBus {
  ShellTabBus._();

  static final ValueNotifier<int?> pendingBodyIndex = ValueNotifier<int?>(null);

  /// 0 Feed, 1 Discover, 2 Chat, 3 Profile
  static void requestTab(int bodyIndex) {
    pendingBodyIndex.value = bodyIndex;
  }
}
