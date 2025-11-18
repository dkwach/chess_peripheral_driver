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
    handleCentralUnexpected(Commands.begin);
  }

  Future<void> handleCentralMove({
    required String move,
    String? check,
    String? time,
  }) async {
    handleCentralUnexpected(Commands.move);
  }

  Future<void> handleCentralReject() async {
    handleCentralUnexpected(Commands.nok);
  }

  Future<void> handleCentralEnd({
    String? reason,
    String? drawReason,
    String? variantReason,
    String? score,
  }) async {
    handleCentralUnexpected(Commands.end);
  }

  Future<void> handleCentralErr({required String err}) async {
    handleCentralUnexpected(Commands.err);
  }

  Future<void> handleCentralMsg({required String msg}) async {
    handleCentralUnexpected(Commands.msg);
  }

  Future<void> handleCentralUndo({
    required String fen,
    String? lastMove,
    String? check,
    String? time,
  }) async {
    handleCentralUnexpected(Commands.undo);
  }

  Future<void> handleCentralRedo({
    required String fen,
    String? lastMove,
    String? check,
    String? time,
  }) async {
    handleCentralUnexpected(Commands.redo);
  }

  Future<void> handleCentralUndoOffer() async {
    handleCentralUnexpected(Commands.undoOffer);
  }

  Future<void> handleCentralDrawOffer() async {
    handleCentralUnexpected(Commands.drawOffer);
  }

  Future<void> handleCentralGetState() async {
    handleCentralUnexpected(Commands.getState);
  }

  Future<void> handleCentralSetState() async {
    handleCentralUnexpected(Commands.setState);
  }

  Future<void> handleCentralState({required String fen}) async {
    handleCentralUnexpected(Commands.state);
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
}
