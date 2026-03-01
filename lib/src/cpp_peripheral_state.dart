import 'dart:async';

import 'package:logging/logging.dart';
import './string_consts.dart';
import './cpp_round.dart';
import './cpp_peripheral.dart';

final logger = Logger('cpp_peripheral');

class CppPeripheralState {
  late CppPeripheral context;

  CppRound get round => context.cppRound;

  bool isFeatureSupported(String feature) {
    return context.isFeatureSupported(feature);
  }

  bool isVariantSupported(String variant) {
    return context.isVariantSupported(variant);
  }

  void sendInitializedToCentral() {
    context.initializedController.add(null);
  }

  void sendRoundInitializedToCentral() {
    context.roundInitializedController.add(null);
  }

  void sendRoundUpdateToCentral() {
    context.roundUpdateController.add(null);
  }

  void sendStateSynchronizeToCentral(bool isSynchronized) {
    context.stateSynchronizeController.add(isSynchronized);
  }

  void sendMoveToCentral(String move) {
    context.moveController.add(move);
  }

  void sendErrToCentral(String err) {
    context.errController.add(err);
    logger.warning(err);
  }

  void sendMsgToCentral(String msg) {
    context.msgController.add(msg);
  }

  void sendMovedToCentral() {
    context.movedController.add(null);
  }

  void sendResignToCentral() {
    context.resignController.add(null);
  }

  void sendUndoOfferToCentral() {
    context.undoOfferController.add(null);
  }

  void sendUndoOfferAckToCentral(bool ack) {
    context.undoOfferAckController.add(ack);
  }

  void sendDrawOfferToCentral() {
    context.drawOfferController.add(null);
  }

  void sendDrawOfferAckToCentral(bool ack) {
    context.drawOfferAckController.add(ack);
  }

  void sendOptionsUpdateToCentral() {
    context.optionsUpdateController.add(null);
  }

  Future<void> sendCommandToPrtipheral(String cmd) async {
    await context.sendCommandToPrtipheral(cmd);
  }

  void transitionTo(CppPeripheralState nextState) {
    context.transitionTo(nextState);
  }

  void onEnter() {}

  Future<void> handlePeripheralCommand(String cmd) async {
    sendErrToCentral('Unexpected: $runtimeType: periphrtal $cmd');
  }

  Future<void> handleCentralBegin({
    required String fen,
    String? variant,
    String? side,
    String? lastMove,
    String? check,
    String? time,
  }) async {
    handleCentralIgnored(Commands.begin);
  }

  Future<void> handleCentralMove({
    required String move,
    String? check,
    String? time,
  }) async {
    handleCentralIgnored(Commands.move);
  }

  Future<void> handleCentralReject() async {
    handleCentralIgnored(Commands.nok);
  }

  Future<void> handleCentralEnd({
    String? reason,
    String? drawReason,
    String? variantReason,
    String? score,
  }) async {
    handleCentralIgnored(Commands.end);
  }

  Future<void> handleCentralErr({required String err}) async {
    handleCentralIgnored(Commands.err);
  }

  Future<void> handleCentralMsg({required String msg}) async {
    handleCentralIgnored(Commands.msg);
  }

  Future<void> handleCentralUndo({
    required String fen,
    String? lastMove,
    String? check,
    String? time,
  }) async {
    handleCentralIgnored(Commands.undo);
  }

  Future<void> handleCentralRedo({
    required String fen,
    String? lastMove,
    String? check,
    String? time,
  }) async {
    handleCentralIgnored(Commands.redo);
  }

  Future<void> handleCentralUndoOffer() async {
    handleCentralIgnored(Commands.undoOffer);
  }

  Future<void> handleCentralDrawOffer() async {
    handleCentralIgnored(Commands.drawOffer);
  }

  Future<void> handleCentralGetState() async {
    handleCentralIgnored(Commands.getState);
  }

  Future<void> handleCentralSetState() async {
    handleCentralIgnored(Commands.setState);
  }

  Future<void> handleCentralState({required String fen}) async {
    handleCentralIgnored(Commands.state);
  }

  Future<void> handleOptionsBegin() async {
    handleCentralUnexpected(Commands.optionsBegin);
  }

  Future<void> handleOptionsReset() async {
    handleCentralUnexpected(Commands.optionsReset);
  }

  Future<void> handleSetOption({
    required String name,
    required String value,
  }) async {
    handleCentralUnexpected(Commands.setOption);
  }

  void handleCentralUnexpected(String event) {
    sendErrToCentral('Unexpected: $runtimeType: central $event');
  }

  void handleCentralIgnored(String event) {
    logger.info('Ignored: $runtimeType: central $event');
  }
}
