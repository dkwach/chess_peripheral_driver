import 'dart:async';

import 'package:logging/logging.dart';
import './string_consts.dart';
import './utils.dart';
import './cpp_peripheral_state.dart';

final logger = Logger('cpp_peripheral');

class IterableExchangeState extends CppPeripheralState {
  IterableExchangeState(
    this.iter,
    this.result,
    this.cmdName,
    this.nextState,
  );

  final Iterator<String> iter;
  final List<String> result;
  final String cmdName;
  final CppPeripheralState nextState;

  @override
  void onEnter() {
    moveIterator();
  }

  @override
  Future<void> handlePeripheralCommand(String cmd) async {
    if (cmd == Commands.ok) {
      logger.info('Peripheral ${cmdName} ${iter.current} supported');
      result.add(iter.current);
    } else if (cmd == Commands.nok) {
      logger.info('Peripheral ${cmdName} ${iter.current} unsupported');
    } else {
      super.handlePeripheralCommand(cmd);
    }

    moveIterator();
  }

  void moveIterator() {
    if (iter.moveNext())
      sendCommandToPrtipheral(join(cmdName, iter.current));
    else
      transitionTo(nextState);
  }
}

class InitializedState extends CppPeripheralState {
  @override
  void onEnter() {
    transitionTo(IdleState());
    context.isCppInitialized = true;
    sendInitializedToCentral();
  }
}

class IdleState extends CppPeripheralState {
  @override
  Future<void> handlePeripheralCommand(String cmd) async {
    if (cmd.startsWith(Commands.state)) {
      round.isMoveRejected = false;
      round.fen = getCommandParams(cmd);
      sendRoundUpdateToCentral();
    } else if (cmd.startsWith(Commands.err)) {
      sendErrToCentral(getCommandParams(cmd));
    } else if (cmd.startsWith(Commands.msg)) {
      sendMsgToCentral(getCommandParams(cmd));
    } else if (cmd.startsWith(Commands.setOption)) {
      if (!context.cppOptions.setPeripheralOption(getCommandParams(cmd))) {
        sendErrToCentral('Option set failed: $cmd');
      } else if (context.areCppOptionsInitialized) {
        sendOptionsUpdateToCentral();
      }
    } else if (cmd.startsWith(Commands.optionsEnd)) {
      context.areCppOptionsInitialized = true;
      sendOptionsUpdateToCentral();
    } else if (cmd.startsWith(Commands.optionsReset)) {
      context.cppOptions.reset();
      sendOptionsUpdateToCentral();
    } else if (cmd.startsWith(Commands.option)) {
      if (!context.cppOptions.addPeripheralOption(getCommandParams(cmd))) {
        sendErrToCentral('Option add failed: $cmd');
      }
    } else {
      await super.handlePeripheralCommand(cmd);
    }
  }

  @override
  Future<void> handleCentralBegin({
    required String fen,
    String? variant,
    String? side,
    String? lastMove,
    String? check,
    String? time,
  }) async {
    round.lastMove = null;
    round.isMoveRejected = false;

    if (variant != null && round.variant != variant) {
      await sendCommandToPrtipheral(join(Commands.setVariant, variant));
      round.isVariantSupported = isVariantSupported(variant);
      if (!round.isVariantSupported) {
        round.variant = variant;
        transitionTo(IdleState());
        sendRoundInitializedToCentral();
        return;
      }
    }
    round.variant = variant;

    if (side != null && isFeatureSupported(Features.side)) {
      await sendCommandToPrtipheral(join(Commands.side, side));
    }

    transitionTo(RoundBeginState());
    await sendCommandToPrtipheral(join(Commands.begin, fen));

    if (lastMove != null && isFeatureSupported(Features.lastMove)) {
      await sendCommandToPrtipheral(join(Commands.lastMove, lastMove));
    }
    if (check != null && isFeatureSupported(Features.check)) {
      await sendCommandToPrtipheral(join(Commands.check, check));
    }
    if (time != null && isFeatureSupported(Features.time)) {
      await sendCommandToPrtipheral(join(Commands.time, time));
    }
  }

  @override
  Future<void> handleCentralErr({
    required String err,
  }) async {
    await sendCommandToPrtipheral(join(Commands.err, err));
  }

  @override
  Future<void> handleCentralMsg({
    required String msg,
  }) async {
    if (isFeatureSupported(Features.msg)) {
      await sendCommandToPrtipheral(join(Commands.msg, msg));
    }
  }

  @override
  Future<void> handleCentralGetState() async {
    await sendCommandToPrtipheral(Commands.getState);
  }

  @override
  Future<void> handleCentralSetState() async {
    await sendCommandToPrtipheral(Commands.setState);
  }

  @override
  Future<void> handleCentralState({
    required String fen,
  }) async {
    await sendCommandToPrtipheral(join(Commands.state, fen));
  }

  @override
  Future<void> handleOptionsBegin() async {
    if (!context.areCppOptionsInitialized) {
      await sendCommandToPrtipheral(Commands.optionsBegin);
    }
  }

  @override
  Future<void> handleOptionsReset() async {
    await sendCommandToPrtipheral(Commands.optionsReset);
    context.cppOptions.reset();
    sendOptionsUpdateToCentral();
  }

  @override
  Future<void> handleSetOption({
    required String name,
    required String value,
  }) async {
    await sendCommandToPrtipheral(join(Commands.setOption, join(name, value)));
  }
}

class RoundState extends IdleState {
  @override
  Future<void> handleCentralMove({
    required String move,
    String? check,
    String? time,
  }) async {
    round.isMoveRejected = false;
    sendRoundUpdateToCentral();

    await sendCommandToPrtipheral(join(Commands.move, move));

    if (check != null && isFeatureSupported(Features.check)) {
      await sendCommandToPrtipheral(join(Commands.check, check));
    }
    if (time != null && isFeatureSupported(Features.time)) {
      await sendCommandToPrtipheral(join(Commands.time, time));
    }
  }

  @override
  Future<void> handleCentralEnd({
    String? reason,
    String? drawReason,
    String? variantReason,
    String? score,
  }) async {
    if (drawReason != null && isFeatureSupported(Features.drawReason)) {
      await sendCommandToPrtipheral(join(Commands.end, drawReason));
    } else if (variantReason != null &&
        isFeatureSupported(Features.variantReason)) {
      await sendCommandToPrtipheral(join(Commands.end, variantReason));
    } else if (reason != null) {
      await sendCommandToPrtipheral(join(Commands.end, reason));
    } else {
      sendCommandToPrtipheral(join(Commands.end, EndReasons.undefined));
    }

    if (score != null && isFeatureSupported(Features.score)) {
      await sendCommandToPrtipheral(join(Commands.score, score));
    }
  }

  @override
  Future<void> handleCentralUndo({
    required String fen,
    String? lastMove,
    String? check,
    String? time,
  }) async {
    round.isMoveRejected = false;
    sendRoundUpdateToCentral();

    await sendCommandToPrtipheral(join(Commands.undo, fen));

    if (lastMove != null && isFeatureSupported(Features.lastMove)) {
      await sendCommandToPrtipheral(join(Commands.lastMove, lastMove));
    }
    if (check != null && isFeatureSupported(Features.check)) {
      await sendCommandToPrtipheral(join(Commands.check, check));
    }
    if (time != null && isFeatureSupported(Features.time)) {
      await sendCommandToPrtipheral(join(Commands.time, time));
    }
  }

  @override
  Future<void> handleCentralUndoOffer() async {
    transitionTo(CentralUndoOfferState());
    await sendCommandToPrtipheral(Commands.undoOffer);
  }

  @override
  Future<void> handleCentralDrawOffer() async {
    transitionTo(CentralDrawOfferState());
    await sendCommandToPrtipheral(Commands.drawOffer);
  }
}

class RoundBeginState extends RoundState {
  @override
  Future<void> handlePeripheralCommand(String cmd) async {
    if (cmd.startsWith(Commands.sync)) {
      round.isStateSynchronized = true;
      round.isStateSetible = false;
      round.fen = getCommandParams(cmd);
      round.isMoveRejected = false;
      transitionTo(RoundOngoingState());
      sendRoundInitializedToCentral();
      sendStateSynchronizeToCentral(true);
    } else if (cmd.startsWith(Commands.unsyncSetible)) {
      round.isStateSynchronized = false;
      round.isStateSetible = true;
      round.fen = getCommandParams(cmd);
      round.isMoveRejected = false;
      transitionTo(RoundOngoingState());
      sendRoundInitializedToCentral();
      sendStateSynchronizeToCentral(false);
    } else if (cmd.startsWith(Commands.unsync)) {
      round.isStateSynchronized = false;
      round.isStateSetible = false;
      round.fen = getCommandParams(cmd);
      round.isMoveRejected = false;
      transitionTo(RoundOngoingState());
      sendRoundInitializedToCentral();
      sendStateSynchronizeToCentral(false);
    } else {
      await super.handlePeripheralCommand(cmd);
    }
  }
}

class RoundOngoingState extends RoundState {
  @override
  Future<void> handlePeripheralCommand(String cmd) async {
    if (cmd.startsWith(Commands.move)) {
      final move = getCommandParams(cmd);
      round.lastMove = move;
      round.isMoveRejected = false;
      transitionTo(PeripheralMoveState());
      sendMoveToCentral(move);
    } else if (cmd.startsWith(Commands.sync)) {
      round.isStateSynchronized = true;
      round.isStateSetible = false;
      round.fen = getCommandParams(cmd);
      round.isMoveRejected = false;
      sendRoundUpdateToCentral();
      sendStateSynchronizeToCentral(true);
    } else if (cmd.startsWith(Commands.unsyncSetible)) {
      round.isStateSynchronized = false;
      round.isStateSetible = true;
      round.fen = getCommandParams(cmd);
      round.isMoveRejected = false;
      sendRoundUpdateToCentral();
      sendStateSynchronizeToCentral(false);
    } else if (cmd.startsWith(Commands.unsync)) {
      round.isStateSynchronized = false;
      round.isStateSetible = false;
      round.fen = getCommandParams(cmd);
      round.isMoveRejected = false;
      sendRoundUpdateToCentral();
      sendStateSynchronizeToCentral(false);
    } else if (cmd.startsWith(Commands.moved)) {
      sendMovedToCentral();
    } else if (cmd.startsWith(Commands.undoOffer)) {
      round.isMoveRejected = false;
      transitionTo(PeripheralUndoOfferState());
      sendUndoOfferToCentral();
    } else if (cmd.startsWith(Commands.drawOffer)) {
      round.isMoveRejected = false;
      transitionTo(PeripheralDrawOfferState());
      sendDrawOfferToCentral();
    } else {
      await super.handlePeripheralCommand(cmd);
    }
  }
}

class PeripheralMoveState extends RoundOngoingState {
  @override
  Future<void> handleCentralMove({
    required String move,
    String? check,
    String? time,
  }) async {
    round.isMoveRejected = false;
    sendRoundUpdateToCentral();

    final last = round.lastMove!;
    if (move == last) {
      await sendCommandToPrtipheral(Commands.ok);
    } else if (hasUciPromotion(move) && !hasUciPromotion(last)) {
      await sendCommandToPrtipheral(join(Commands.promote, move));
    } else {
      handleCentralUnexpected(Commands.move);
      transitionTo(IdleState());
      return;
    }

    transitionTo(RoundOngoingState());
    if (check != null && isFeatureSupported(Features.check)) {
      await sendCommandToPrtipheral(join(Commands.check, check));
    }
    if (time != null && isFeatureSupported(Features.time)) {
      await sendCommandToPrtipheral(join(Commands.time, time));
    }
  }

  Future<void> handleCentralReject() async {
    round.isMoveRejected = true;
    sendRoundUpdateToCentral();

    transitionTo(RoundOngoingState());
    await sendCommandToPrtipheral(Commands.nok);
  }
}

class PeripheralUndoOfferState extends RoundOngoingState {
  @override
  Future<void> handleCentralUndoOffer() async {
    transitionTo(RoundOngoingState());
    await sendCommandToPrtipheral(Commands.ok);
  }

  Future<void> handleCentralReject() async {
    transitionTo(RoundOngoingState());
    await sendCommandToPrtipheral(Commands.nok);
  }
}

class CentralUndoOfferState extends RoundOngoingState {
  @override
  Future<void> handlePeripheralCommand(String cmd) async {
    if (cmd == Commands.ok) {
      transitionTo(RoundOngoingState());
      sendUndoOfferAckToCentral(true);
    } else if (cmd == Commands.nok) {
      transitionTo(RoundOngoingState());
      sendUndoOfferAckToCentral(false);
    } else {
      await super.handlePeripheralCommand(cmd);
    }
  }
}

class PeripheralDrawOfferState extends RoundOngoingState {
  @override
  Future<void> handleCentralDrawOffer() async {
    transitionTo(RoundOngoingState());
    await sendCommandToPrtipheral(Commands.ok);
  }

  Future<void> handleCentralReject() async {
    transitionTo(RoundOngoingState());
    await sendCommandToPrtipheral(Commands.nok);
  }
}

class CentralDrawOfferState extends RoundOngoingState {
  @override
  Future<void> handlePeripheralCommand(String cmd) async {
    if (cmd == Commands.ok) {
      transitionTo(RoundOngoingState());
      sendDrawOfferAckToCentral(true);
    } else if (cmd == Commands.nok) {
      transitionTo(RoundOngoingState());
      sendDrawOfferAckToCentral(false);
    } else {
      await super.handlePeripheralCommand(cmd);
    }
  }
}
