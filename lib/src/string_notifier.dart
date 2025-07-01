import 'dart:async';

import 'package:meta/meta.dart';

abstract class StringNotifier {
  final _stringStreamController = StreamController<String>.broadcast();
  Stream<String> get stringStream => _stringStreamController.stream;

  @protected
  void notifyString(String str) {
    if (canNotifyString()) _stringStreamController.add(str);
  }

  @protected
  bool canNotifyString() {
    return !_stringStreamController.isClosed;
  }

  @mustCallSuper
  void dispose() {
    _stringStreamController.close();
  }
}
