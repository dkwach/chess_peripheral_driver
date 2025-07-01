import './option.dart';
import './peripheral.dart';

class DummyRound implements Round {
  @override
  bool get isVariantSupported => false;
  @override
  bool get isStateSynchronized => false;
  @override
  bool get isStateSetible => false;
  @override
  String? get fen => null;
  @override
  String? get rejectedMove => null;
}

class DummyPeripheral implements Peripheral {
  final dummyRound = DummyRound();

  @override
  bool isFeatureSupported(String feature) => false;
  @override
  bool isVariantSupported(String variant) => false;

  @override
  bool get isInitialized => false;
  @override
  Round get round => dummyRound;
  @override
  bool get areOptionsInitialized => false;
  @override
  List<Option> get options => [];

  @override
  Stream<void> get initializedStream => Stream.empty();
  @override
  Stream<void> get roundInitializedStream => Stream.empty();
  @override
  Stream<void> get roundUpdateStream => Stream.empty();
  @override
  Stream<bool> get stateSynchronizeStream => Stream.empty();
  @override
  Stream<String> get moveStream => Stream.empty();
  @override
  Stream<String> get errStream => Stream.empty();
  @override
  Stream<String> get msgStream => Stream.empty();
  @override
  Stream<void> get movedStream => Stream.empty();
  @override
  Stream<void> get resignStream => Stream.empty();
  @override
  Stream<void> get undoOfferStream => Stream.empty();
  @override
  Stream<bool> get undoOfferAckStream => Stream.empty();
  @override
  Stream<void> get drawOfferStream => Stream.empty();
  @override
  Stream<bool> get drawOfferAckStream => Stream.empty();
  @override
  Stream<void> get optionsUpdateStream => Stream.empty();

  @override
  Future<void> handleBegin({
    required String fen,
    String? variant,
    String? side,
    String? lastMove,
    String? check,
    String? time,
  }) async {}
  @override
  Future<void> handleMove({
    required String move,
    String? check,
    String? time,
  }) async {}
  @override
  Future<void> handleReject() async {}
  @override
  Future<void> handleEnd({
    String? reason,
    String? drawReason,
    String? variantReason,
    String? score,
  }) async {}
  @override
  Future<void> handleErr({
    required String err,
  }) async {}
  @override
  Future<void> handleMsg({
    required String msg,
  }) async {}
  @override
  Future<void> handleUndo({
    required String fen,
    String? lastMove,
    String? check,
    String? time,
  }) async {}
  @override
  Future<void> handleUndoOffer() async {}
  @override
  Future<void> handleDrawOffer() async {}
  @override
  Future<void> handleGetState() async {}
  @override
  Future<void> handleSetState() async {}
  @override
  Future<void> handleState({
    required String fen,
  }) async {}
  @override
  Future<void> handleOptionsBegin() async {}
  @override
  Future<void> handleOptionsReset() async {}
}
