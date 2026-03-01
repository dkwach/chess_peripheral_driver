import 'dart:async';

import 'package:logging/logging.dart';
import './option.dart';
import './peripheral.dart';
import './string_serial.dart';
import './string_consts.dart';
import './cpp_round.dart';
import './cpp_options.dart';
import './cpp_peripheral_state.dart';
import './cpp_peripheral_states.dart';

final logger = Logger('cpp_peripheral');

class CppPeripheral implements Peripheral {
  CppPeripheral({
    required StringSerial stringSerial,
    required List<String> features,
    required List<String> variants,
  }) : serial = stringSerial {
    cppOptions = CppOptions(peripheral: this);
    init(features: features, variants: variants);
  }

  final StringSerial serial;
  final List<String> cppFeatures = [];
  final List<String> cppVariants = [];
  bool isCppInitialized = false;
  final CppRound cppRound = CppRound();
  bool areCppOptionsInitialized = false;
  late CppOptions cppOptions;
  final initializedController = StreamController<void>.broadcast();
  final roundInitializedController = StreamController<void>.broadcast();
  final roundUpdateController = StreamController<void>.broadcast();
  final stateSynchronizeController = StreamController<bool>.broadcast();
  final moveController = StreamController<String>.broadcast();
  final errController = StreamController<String>.broadcast();
  final msgController = StreamController<String>.broadcast();
  final movedController = StreamController<void>.broadcast();
  final resignController = StreamController<void>.broadcast();
  final undoOfferController = StreamController<void>.broadcast();
  final undoOfferAckController = StreamController<bool>.broadcast();
  final drawOfferController = StreamController<void>.broadcast();
  final drawOfferAckController = StreamController<bool>.broadcast();
  final optionsUpdateController = StreamController<void>.broadcast();
  late CppPeripheralState state;
  StreamSubscription<String>? subscription;

  @override
  bool isFeatureSupported(String feature) => cppFeatures.contains(feature);
  @override
  bool isVariantSupported(String variant) => cppVariants.contains(variant);

  @override
  bool get isInitialized => isCppInitialized;
  @override
  Round get round => cppRound;
  @override
  bool get areOptionsInitialized => areCppOptionsInitialized;
  @override
  List<Option> get options => cppOptions.list;

  @override
  Stream<void> get initializedStream => initializedController.stream;
  @override
  Stream<void> get roundInitializedStream => roundInitializedController.stream;
  @override
  Stream<void> get roundUpdateStream => roundUpdateController.stream;
  @override
  Stream<bool> get stateSynchronizeStream => stateSynchronizeController.stream;
  @override
  Stream<String> get moveStream => moveController.stream;
  @override
  Stream<String> get errStream => errController.stream;
  @override
  Stream<String> get msgStream => msgController.stream;
  @override
  Stream<void> get movedStream => movedController.stream;
  @override
  Stream<void> get resignStream => resignController.stream;
  @override
  Stream<void> get undoOfferStream => undoOfferController.stream;
  @override
  Stream<bool> get undoOfferAckStream => undoOfferAckController.stream;
  @override
  Stream<void> get drawOfferStream => drawOfferController.stream;
  @override
  Stream<bool> get drawOfferAckStream => drawOfferAckController.stream;
  @override
  Stream<void> get optionsUpdateStream => optionsUpdateController.stream;

  @override
  Future<void> handleBegin({
    required String fen,
    String? variant,
    String? side,
    String? lastMove,
    String? check,
    String? time,
  }) async {
    await state.handleCentralBegin(
      fen: fen,
      variant: variant,
      side: side,
      lastMove: lastMove,
      check: check,
      time: time,
    );
  }

  @override
  Future<void> handleMove({
    required String move,
    String? check,
    String? time,
  }) async {
    await state.handleCentralMove(
      move: move,
      check: check,
      time: time,
    );
  }

  @override
  Future<void> handleReject() async {
    await state.handleCentralReject();
  }

  @override
  Future<void> handleEnd({
    String? reason,
    String? drawReason,
    String? variantReason,
    String? score,
  }) async {
    await state.handleCentralEnd(
      reason: reason,
      drawReason: drawReason,
      variantReason: variantReason,
      score: score,
    );
  }

  @override
  Future<void> handleErr({
    required String err,
  }) async {
    await state.handleCentralErr(
      err: err,
    );
  }

  Future<void> handleMsg({
    required String msg,
  }) async {
    await state.handleCentralMsg(
      msg: msg,
    );
  }

  @override
  Future<void> handleUndo({
    required String fen,
    String? lastMove,
    String? check,
    String? time,
  }) async {
    await state.handleCentralUndo(
      fen: fen,
      lastMove: lastMove,
      check: check,
      time: time,
    );
  }

  @override
  Future<void> handleRedo({
    required String fen,
    String? lastMove,
    String? check,
    String? time,
  }) async {
    await state.handleCentralRedo(
      fen: fen,
      lastMove: lastMove,
      check: check,
      time: time,
    );
  }

  @override
  Future<void> handleUndoOffer() async {
    await state.handleCentralUndoOffer();
  }

  @override
  Future<void> handleDrawOffer() async {
    await state.handleCentralDrawOffer();
  }

  @override
  Future<void> handleGetState() async {
    await state.handleCentralGetState();
  }

  @override
  Future<void> handleSetState() async {
    await state.handleCentralSetState();
  }

  @override
  Future<void> handleState({
    required String fen,
  }) async {
    await state.handleCentralState(
      fen: fen,
    );
  }

  @override
  Future<void> handleOptionsBegin() async {
    await state.handleOptionsBegin();
  }

  @override
  Future<void> handleOptionsReset() async {
    await state.handleOptionsReset();
  }

  Future<void> handleSetOption({
    required String name,
    required String value,
  }) async {
    await state.handleSetOption(
      name: name,
      value: value,
    );
  }

  Future<void> handlePeripheralCommand(String cmd) async {
    logger.info('Peripheral: $cmd');
    await state.handlePeripheralCommand(cmd);
  }

  Future<void> sendCommandToPrtipheral(String cmd) async {
    logger.info('Central: $cmd');
    await serial.send(str: cmd);
  }

  Future<void> init({
    required List<String> features,
    required List<String> variants,
  }) async {
    subscription = serial.stringStream.listen(handlePeripheralCommand);
    await serial.startNotifications();
    final checkVariants = IterableExchangeState(
      variants.iterator,
      cppVariants,
      Commands.variant,
      InitializedState(),
    );
    final checkFeatures = IterableExchangeState(
      features.iterator,
      cppFeatures,
      Commands.feature,
      checkVariants,
    );
    transitionTo(checkFeatures);
  }

  void transitionTo(CppPeripheralState nextState) {
    logger.info('Transition to: ${nextState.runtimeType}');
    state = nextState;
    state.context = this;
    state.onEnter();
  }

  @override
  Future<void> dispose() async {
    await subscription?.cancel();
    await serial.stopNotifications();
    await initializedController.close();
    await roundInitializedController.close();
    await roundUpdateController.close();
    await stateSynchronizeController.close();
    await moveController.close();
    await errController.close();
    await msgController.close();
    await movedController.close();
    await resignController.close();
    await undoOfferController.close();
    await undoOfferAckController.close();
    await drawOfferController.close();
    await drawOfferAckController.close();
    await optionsUpdateController.close();
  }
}
