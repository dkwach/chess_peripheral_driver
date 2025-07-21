import './peripheral.dart';

class CppRound implements Round {
  bool _isVariantSupported = false;
  bool _isStateSynchronized = false;
  bool _isStateSettable = false;
  String? _fen;
  String? _variant;
  String? _lastMove;
  bool _isMoveRejected = false;

  @override
  bool get isVariantSupported => _isVariantSupported;
  @override
  bool get isStateSynchronized => _isStateSynchronized;
  @override
  bool get isStateSettable => _isStateSettable;
  @override
  String? get fen => _fen;
  @override
  String? get rejectedMove => _isMoveRejected ? _lastMove : null;

  String? get variant => _variant;
  String? get lastMove => _lastMove;
  bool get isMoveRejected => _isMoveRejected;

  set isVariantSupported(bool isSupported) {
    _isVariantSupported = isSupported;
  }

  set isStateSynchronized(bool isSynchronized) {
    _isStateSynchronized = isSynchronized;
  }

  set isStateSettable(bool isSettable) {
    _isStateSettable = isSettable;
  }

  set fen(String? fen) {
    _fen = fen;
  }

  set variant(String? variant) {
    _variant = variant;
  }

  set lastMove(String? lastMove) {
    _lastMove = lastMove;
  }

  set isMoveRejected(bool isRejected) {
    _isMoveRejected = isRejected;
  }
}
