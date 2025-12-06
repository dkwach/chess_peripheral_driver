import 'dart:async';
import 'dart:math';

import 'package:ble_backend/ble_connector.dart';
import 'package:ble_backend/ble_peripheral.dart';
import 'package:ble_backend_screens/ui/ui_consts.dart';
import 'package:ble_chess_example/options_screen.dart';
import 'package:ble_chess_peripheral_driver/ble_chess_peripheral_driver.dart';
import 'package:ble_chess_peripheral_driver/chess_peripheral_driver.dart';
import 'package:chessground/chessground.dart';
import 'package:dartchess/dartchess.dart';
import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'peripheral_fen.dart';

class RoundScreen extends StatefulWidget {
  RoundScreen({
    required this.bleConnector,
    required this.blePeripheral,
    super.key,
  });

  final BleConnector bleConnector;
  final BlePeripheral blePeripheral;

  @override
  State<RoundScreen> createState() => RoundScreenState();
}

enum PlayMode {
  bot,
  free,
}

enum Ack {
  yes,
  no,
}

class RoundScreenState extends State<RoundScreen> {
  StreamSubscription? _subscription;
  Peripheral peripheral = DummyPeripheral();
  bool isAutocompleteOngoing = false;
  bool isOfferOngoing = false;
  Position position = Chess.initial;
  Side orientation = Side.white;
  String fen = kInitialBoardFEN;
  NormalMove? lastMove;
  NormalMove? promotionMove;
  NormalMove? premove;
  ValidMoves validMoves = IMap(const {});
  PlayMode playMode = PlayMode.free;
  Position? lastPos;

  BlePeripheral get blePeripheral => widget.blePeripheral;
  BleConnector get bleConnector => widget.bleConnector;

  Future<void> _beginNewRound() async {
    await _beginFromPosition(Chess.initial);
  }

  Future<void> _beginPeripheralRound() async {
    await peripheral.handleGetState();
    final pos = await _waitForPeripheralPosition();
    await _beginFromPosition(pos);
  }

  Future<void> _beginFromPosition(Position pos) async {
    setState(() {
      position = pos;
      fen = position.fen;
      validMoves = makeLegalMoves(position);
      lastMove = null;
      lastPos = null;
    });
    playMode = await _showChoicesPicker<PlayMode>(
      context: context,
      title: 'Select play mode',
      choices: PlayMode.values,
      defaultValue: playMode,
    );
    await peripheral.handleBegin(
      fen: fen,
      variant: Variants.standard,
      side: playMode == PlayMode.bot ? Sides.white : Sides.both,
      lastMove: lastMove?.uci,
      check: _getCheck(),
    );
  }

  String? _getCheck() {
    final king = position.board.kingOf(position.turn);
    return king != null && position.checkers.isNotEmpty ? king.name : null;
  }

  void _showMessage(String msg) {
    Fluttertoast.showToast(msg: msg, fontSize: 18.0);
  }

  void _showError(String err) {
    Fluttertoast.showToast(
      msg: err,
      toastLength: Toast.LENGTH_LONG,
      backgroundColor: Colors.red,
      textColor: Colors.white,
      fontSize: 18.0,
    );
  }

  void _handlePeripheralInitialized(_) {
    _beginNewRound();
  }

  void _handlePeripheralRoundInitialized(_) {
    setState(() {
      isAutocompleteOngoing = false;
      isOfferOngoing = false;
      if (!peripheral.round.isVariantSupported) {
        _showMessage('Unsupported variant');
      }
    });
  }

  void _handlePeripheralRoundUpdate(_) {
    setState(() {
      isAutocompleteOngoing = false;
      isOfferOngoing = false;
    });
  }

  void _handlePeripheralStateSynchronize(bool isSynchronized) {
    _showMessage(isSynchronized ? 'Synchronized' : 'Unsynchronized');
  }

  void _handleCentralMove(NormalMove move) {
    peripheral.handleMove(
      move: move.uci,
      check: _getCheck(),
    );
    _handleCentralEnd();
  }

  void _handleCentralEnd() {
    if (position.isCheckmate) {
      _showMessage('Checkmate');
      peripheral.handleEnd(reason: EndReasons.checkmate);
    } else if (position.isStalemate) {
      _showMessage('Stalemate');
      peripheral.handleEnd(
        reason: EndReasons.draw,
        drawReason: DrawReasons.stalemate,
      );
    } else if (position.isInsufficientMaterial) {
      _showMessage('Insufficient material');
      peripheral.handleEnd(
        reason: EndReasons.draw,
        drawReason: DrawReasons.insufficientMaterial,
      );
    } else if (position.isVariantEnd) {
      _showMessage('Variant end');
      peripheral.handleEnd(reason: EndReasons.undefined);
    }
  }

  void _handlePeripheralMove(String uci) {
    final move = NormalMove.fromUci(uci);
    if (position.isLegal(move)) {
      playMode == PlayMode.bot ? _onUserMoveAgainstBot(move) : _playMove(move);
    } else {
      setState(() {
        peripheral.handleReject();
        _showMessage('Rejected');
      });
    }
  }

  void _handleAutocomplete() {
    setState(() {
      isAutocompleteOngoing = true;
      peripheral.handleSetState();
    });
  }

  void _handleGetRound() {
    _beginPeripheralRound();
  }

  void _handlePeripheralResign(_) {
    _showMessage("Resign");
  }

  bool _canUndo() => playMode == PlayMode.free && lastPos != null;

  Future<void> _handleCentralUndo() async {
    setState(() {
      position = lastPos ?? position;
      fen = position.fen;
      validMoves = makeLegalMoves(position);
      lastPos = null;
      lastMove = null;
    });
    await peripheral.handleUndo(
      fen: position.fen,
      lastMove: lastMove?.uci,
      check: _getCheck(),
    );
  }

  Future<void> _handlePeripheralUndoOffer(_) async {
    final ack = _canUndo()
        ? await _showChoicesPicker<Ack>(
            context: context,
            title: 'Undo?',
            choices: Ack.values,
            defaultValue: Ack.no,
          )
        : Ack.no;
    if (ack == Ack.yes) {
      await peripheral.handleUndoOffer();
      await _handleCentralUndo();
    } else {
      await peripheral.handleReject();
    }
  }

  void _handleCentralUndoOffer() {
    setState(() {
      isOfferOngoing = true;
      peripheral.handleUndoOffer();
    });
  }

  void _handleCentralUndoOfferAck(bool ack) {
    setState(() {
      isOfferOngoing = false;
      if (ack) {
        _showMessage('Undo accepted');
        _handleCentralUndo();
      } else {
        _showMessage('Undo rejected');
      }
    });
  }

  Future<void> _handlePeripheralDrawOffer(_) async {
    final ack = await _showChoicesPicker<Ack>(
      context: context,
      title: 'Draw?',
      choices: Ack.values,
      defaultValue: Ack.no,
    );
    if (ack == Ack.yes) {
      await peripheral.handleDrawOffer();
      _showMessage('Draw');
      await peripheral.handleEnd(
        reason: EndReasons.draw,
        drawReason: DrawReasons.drawOffer,
      );
    } else {
      await peripheral.handleReject();
    }
  }

  void _handleCentralDrawOffer() {
    setState(() {
      isOfferOngoing = true;
      peripheral.handleDrawOffer();
    });
  }

  void _handleCentralDrawOfferAck(bool ack) {
    setState(() {
      isOfferOngoing = false;
      if (ack) {
        _showMessage('Draw accepted');
        peripheral.handleEnd(
          reason: EndReasons.draw,
          drawReason: DrawReasons.drawOffer,
        );
      } else {
        _showMessage('Draw rejected');
      }
    });
  }

  Future<void> _initPeripheral() async {
    final mtu = bleConnector.createMtu();
    final requestedMtu = await mtu.request(mtu: maxStringSize);
    if (requestedMtu < maxStringSize) {
      bleConnector.disconnect();
      _showError(
        'Mtu: $requestedMtu, is less than the required: ${maxStringSize}',
      );
      return;
    }

    final serial = BleStringSerial(
      bleSerial: bleConnector.createSerial(
        serviceId: serviceUuid,
        rxCharacteristicId: characteristicUuidRx,
        txCharacteristicId: characteristicUuidTx,
      ),
    );
    final features = [
      Features.msg,
      Features.lastMove,
      Features.check,
      Features.side,
      Features.resign,
      Features.undoRedo,
      Features.undoOffer,
      Features.drawOffer,
      Features.getState,
      Features.setState,
      Features.stateStream,
      Features.drawReason,
      Features.option,
    ];
    final variants = [Variants.standard];
    peripheral = CppPeripheral(
      stringSerial: serial,
      features: features,
      variants: variants,
    );
    peripheral.initializedStream.listen(_handlePeripheralInitialized);
    peripheral.roundInitializedStream.listen(_handlePeripheralRoundInitialized);
    peripheral.roundUpdateStream.listen(_handlePeripheralRoundUpdate);
    peripheral.stateSynchronizeStream.listen(_handlePeripheralStateSynchronize);
    peripheral.moveStream.listen(_handlePeripheralMove);
    peripheral.errStream.listen(_showError);
    peripheral.msgStream.listen(_showMessage);
    peripheral.resignStream.listen(_handlePeripheralResign);
    peripheral.undoOfferStream.listen(_handlePeripheralUndoOffer);
    peripheral.undoOfferAckStream.listen(_handleCentralUndoOfferAck);
    peripheral.drawOfferStream.listen(_handlePeripheralDrawOffer);
    peripheral.drawOfferAckStream.listen(_handleCentralDrawOfferAck);
  }

  void _onConnectionStateChanged(BleConnectorStatus state) {
    setState(() {
      if (state == BleConnectorStatus.disconnected) {
        peripheral = DummyPeripheral();
      } else if (state == BleConnectorStatus.connected) {
        _initPeripheral();
      }
    });
  }

  void _tryPlayPremove() {
    if (premove != null) {
      Timer.run(() {
        _playMove(premove!, isPremove: true);
      });
    }
  }

  Future<Position> _waitForPeripheralPosition() async {
    if (isPeripheralFenSettable(peripheral.round.fen))
      return Chess.fromSetup(Setup.parseFen(peripheral.round.fen!));

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            StreamSubscription? sub;
            sub ??= peripheral.roundUpdateStream.listen((_) {
              if (isPeripheralFenSettable(peripheral.round.fen)) {
                Navigator.of(context).pop();
                sub?.cancel();
              }
            });
            return AlertDialog(
              title: Text(peripheral.round.fen == null
                  ? 'Waiting for peripheral position...'
                  : 'Waiting for peripheral valid position...'),
              content: const SizedBox(
                height: 60,
                child: Center(child: CircularProgressIndicator()),
              ),
              actions: [
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    sub?.cancel();
                  },
                  child: const Text('Cancel'),
                ),
              ],
            );
          },
        );
      },
    );

    return isPeripheralFenSettable(peripheral.round.fen)
        ? Chess.fromSetup(Setup.parseFen(peripheral.round.fen!))
        : Chess.initial;
  }

  Future<T> _showChoicesPicker<T extends Enum>({
    required BuildContext context,
    required String title,
    required List<T> choices,
    required T defaultValue,
  }) async {
    final selectedValue = await showDialog<T>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          title: Center(child: Text(title)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: choices.map((value) {
              return Card(
                child: ListTile(
                  title: Center(child: Text(value.name)),
                  onTap: () {
                    Navigator.of(context).pop(value);
                  },
                ),
              );
            }).toList(),
          ),
        );
      },
    );
    return selectedValue != null ? selectedValue : defaultValue;
  }

  void _onSetPremove(NormalMove? move) {
    setState(() {
      premove = move;
    });
  }

  void _onPromotionSelection(Role? role) {
    if (role == null) {
      _onPromotionCancel();
    } else if (promotionMove != null) {
      if (playMode == PlayMode.bot) {
        _onUserMoveAgainstBot(promotionMove!.withPromotion(role));
      } else {
        _playMove(promotionMove!.withPromotion(role));
      }
    }
  }

  void _onPromotionCancel() {
    setState(() {
      promotionMove = null;
    });
  }

  void _playMove(NormalMove move, {bool? isDrop, bool? isPremove}) {
    lastPos = position;
    if (_isPromotionPawnMove(move)) {
      setState(() {
        promotionMove = move;
      });
    } else if (position.isLegal(move)) {
      setState(() {
        position = position.playUnchecked(move);
        lastMove = move;
        fen = position.fen;
        validMoves = makeLegalMoves(position);
        promotionMove = null;
        if (isPremove == true) {
          premove = null;
        }
        _handleCentralMove(move);
      });
    }
  }

  Future<void> _onUserMoveAgainstBot(NormalMove move, {isDrop}) async {
    lastPos = position;
    if (_isPromotionPawnMove(move)) {
      setState(() {
        promotionMove = move;
      });
    } else {
      setState(() {
        position = position.playUnchecked(move);
        lastMove = move;
        fen = position.fen;
        validMoves = IMap(const {});
        promotionMove = null;
      });
      _handleCentralMove(move);
      await _playBlackMove();
      _tryPlayPremove();
    }
  }

  Future<void> _playBlackMove() async {
    Future.delayed(const Duration(milliseconds: 100)).then((value) {
      setState(() {});
    });
    if (position.isGameOver) return;

    final random = Random();
    await Future.delayed(Duration(milliseconds: random.nextInt(1000) + 500));
    final allMoves = [
      for (final entry in position.legalMoves.entries)
        for (final dest in entry.value.squares)
          NormalMove(from: entry.key, to: dest)
    ];
    if (allMoves.isNotEmpty) {
      NormalMove mv = (allMoves..shuffle()).first;
      // Auto promote to a random non-pawn role
      if (_isPromotionPawnMove(mv)) {
        final potentialRoles =
            Role.values.where((role) => role != Role.pawn).toList();
        final role = potentialRoles[random.nextInt(potentialRoles.length)];
        mv = mv.withPromotion(role);
      }

      setState(() {
        position = position.playUnchecked(mv);
        lastMove =
            NormalMove(from: mv.from, to: mv.to, promotion: mv.promotion);
        fen = position.fen;
        validMoves = makeLegalMoves(position);
      });
      lastPos = position;
      _handleCentralMove(mv);
    }
  }

  bool _isPromotionPawnMove(NormalMove move) {
    return move.promotion == null &&
        position.board.roleAt(move.from) == Role.pawn &&
        ((move.to.rank == Rank.first && position.turn == Side.black) ||
            (move.to.rank == Rank.eighth && position.turn == Side.white));
  }

  void _onTouchedSquare(Square square) {
    if (peripheral.isFeatureSupported(Features.stateStream) &&
        position.board.pieceAt(square) != null)
      peripheral.handleState(fen: position.board.removePieceAt(square).fen);
  }

  @override
  void initState() {
    super.initState();
    validMoves = makeLegalMoves(position);
    _subscription = bleConnector.stateStream.listen(_onConnectionStateChanged);
    bleConnector.connect();
  }

  @override
  void dispose() {
    () async {
      await bleConnector.disconnect();
      await _subscription?.cancel();
    }.call();
    bleConnector.dispose();
    super.dispose();
  }

  IMap<Square, SquareHighlight> _createSquareHighlights() {
    const Color rejectedMoveColor = Color.fromRGBO(199, 0, 109, 0.41);
    const Color pieceRemoveColor = Color.fromRGBO(255, 60, 60, 0.50);
    const Color pieceAddColor = Color.fromRGBO(60, 255, 60, 0.50);
    const Color pieceReplaceColor = Color.fromRGBO(60, 60, 255, 0.50);
    const Color pieceChangeColor = Color.fromRGBO(20, 85, 30, 0.376);
    final isSynchronized = peripheral.round.isStateSynchronized;
    final isStreamSup = peripheral.isFeatureSupported(Features.stateStream);
    IMap<Square, SquareHighlight> highlights = IMap();

    if (peripheral.round.fen != null && (isStreamSup || !isSynchronized)) {
      final remColor = isSynchronized ? pieceChangeColor : pieceRemoveColor;
      final addColor = isSynchronized ? pieceChangeColor : pieceAddColor;
      final rplColor = isSynchronized ? pieceChangeColor : pieceReplaceColor;
      final peripheralPieces = readPeripheralFen(peripheral.round.fen!);
      final centralPieces = readFen(fen);
      for (final entry in centralPieces.entries) {
        final square = entry.key;
        final centralPiece = entry.value;
        final peripheralPiece = peripheralPieces[square];
        if (peripheralPiece == null) {
          highlights = highlights.add(
              square,
              SquareHighlight(
                details: HighlightDetails(
                  solidColor: addColor,
                ),
              ));
        } else if ((peripheralPiece.role != null &&
                peripheralPiece.role != centralPiece.role) ||
            (peripheralPiece.color != null &&
                peripheralPiece.color != centralPiece.color)) {
          highlights = highlights.add(
              square,
              SquareHighlight(
                details: HighlightDetails(
                  solidColor: rplColor,
                ),
              ));
        }
      }
      for (final entry in peripheralPieces.entries) {
        final square = entry.key;
        final centralPiece = centralPieces[square];
        if (centralPiece == null) {
          highlights = highlights.add(
              square,
              SquareHighlight(
                details: HighlightDetails(
                  solidColor: remColor,
                ),
              ));
        }
      }
    }
    if (peripheral.round.rejectedMove != null) {
      final rejectedMove = NormalMove.fromUci(peripheral.round.rejectedMove!);
      highlights = highlights.add(
          rejectedMove.from,
          SquareHighlight(
            details: HighlightDetails(
              solidColor: rejectedMoveColor,
            ),
          ));
      highlights = highlights.add(
          rejectedMove.to,
          SquareHighlight(
            details: HighlightDetails(
              solidColor: rejectedMoveColor,
            ),
          ));
    }
    return highlights;
  }

  Widget _buildChessBoardWidget() => Center(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return Chessboard(
              size: min(constraints.maxWidth, constraints.maxHeight),
              orientation: orientation,
              fen: fen,
              lastMove: peripheral.round.isStateSynchronized ? lastMove : null,
              squareHighlights: _createSquareHighlights(),
              onTouchedSquare: _onTouchedSquare,
              game: GameData(
                playerSide: playMode == PlayMode.bot
                    ? PlayerSide.white
                    : (position.turn == Side.white
                        ? PlayerSide.white
                        : PlayerSide.black),
                validMoves: validMoves,
                sideToMove:
                    position.turn == Side.white ? Side.white : Side.black,
                isCheck: peripheral.round.isStateSynchronized
                    ? position.isCheck
                    : false,
                promotionMove: promotionMove,
                onMove: playMode == PlayMode.bot
                    ? _onUserMoveAgainstBot
                    : _playMove,
                onPromotionSelection: _onPromotionSelection,
                premovable: (
                  onSetPremove: _onSetPremove,
                  premove: premove,
                ),
              ),
            );
          },
        ),
      );

  Widget _buildNewRoundButton() => FilledButton.icon(
        icon: const Icon(Icons.refresh_rounded),
        label: Text('New Round'),
        onPressed: peripheral.isInitialized ? _beginNewRound : null,
      );

  Widget _buildUndoButton() => FilledButton.icon(
        icon: const Icon(Icons.undo_rounded),
        label: Text('Undo'),
        onPressed:
            peripheral.isInitialized && _canUndo() ? _handleCentralUndo : null,
      );

  Widget _buildDrawOfferButton() => FilledButton.icon(
        icon: const Icon(Icons.announcement_rounded),
        label: Text('Offer draw'),
        onPressed: peripheral.isInitialized && !isOfferOngoing
            ? _handleCentralDrawOffer
            : null,
      );

  Widget _buildUndoOfferButton() => FilledButton.icon(
        icon: const Icon(Icons.announcement_rounded),
        label: Text('Offer Undo'),
        onPressed: peripheral.isInitialized && _canUndo() && !isOfferOngoing
            ? _handleCentralUndoOffer
            : null,
      );

  Widget _buildAutocompleteButton() => FilledButton.icon(
        icon: const Icon(Icons.auto_awesome_rounded),
        label: Text('Autocomplete'),
        onPressed: peripheral.round.isStateSettable && !isAutocompleteOngoing
            ? _handleAutocomplete
            : null,
      );

  Widget _buildGetRoundButton() => FilledButton.icon(
        icon: const Icon(Icons.download_rounded),
        label: Text('Get Round'),
        onPressed: peripheral.isInitialized ? _handleGetRound : null,
      );

  Widget _buildControlButtons() {
    final isSetStateSup = peripheral.isFeatureSupported(Features.setState);
    final isGetStateSup = peripheral.isFeatureSupported(Features.getState);
    final isUndoSup = peripheral.isFeatureSupported(Features.undoRedo);
    final isUndoOfferSup = peripheral.isFeatureSupported(Features.undoOffer);
    final isDrawOfferSup = peripheral.isFeatureSupported(Features.drawOffer);
    final areGetAndSetOfferSup = isGetStateSup && isSetStateSup;
    final areGetOrSetOfferSup = isGetStateSup || isSetStateSup;
    final areUndoAndDrawOfferSup = isUndoOfferSup && isDrawOfferSup;
    final areUndoOrDrawOfferSup = isUndoOfferSup || isDrawOfferSup;

    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        if (areGetOrSetOfferSup)
          SizedBox(
            height: buttonHeight,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (isSetStateSup) Expanded(child: _buildAutocompleteButton()),
                if (areGetAndSetOfferSup)
                  const SizedBox(width: buttonsSplitter),
                if (isGetStateSup) Expanded(child: _buildGetRoundButton()),
              ],
            ),
          ),
        if (areGetOrSetOfferSup) const SizedBox(height: buttonsSplitter),
        if (areUndoOrDrawOfferSup)
          SizedBox(
            height: buttonHeight,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (isDrawOfferSup) Expanded(child: _buildDrawOfferButton()),
                if (areUndoAndDrawOfferSup)
                  const SizedBox(width: buttonsSplitter),
                if (isUndoOfferSup) Expanded(child: _buildUndoOfferButton()),
              ],
            ),
          ),
        if (areUndoOrDrawOfferSup) const SizedBox(height: buttonsSplitter),
        SizedBox(
          height: buttonHeight,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: _buildNewRoundButton()),
              if (isUndoSup) const SizedBox(width: buttonsSplitter),
              if (isUndoSup) Expanded(child: _buildUndoButton()),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPortrait() => Padding(
        padding: EdgeInsets.symmetric(vertical: screenPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(child: Center(child: _buildChessBoardWidget())),
            const SizedBox(height: screenPortraitSplitter),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: screenPadding),
              child: _buildControlButtons(),
            ),
          ],
        ),
      );

  Widget _buildLandscape() => Padding(
        padding: const EdgeInsets.all(screenPadding),
        child: Row(
          children: [
            Expanded(child: Center(child: _buildChessBoardWidget())),
            const SizedBox(width: screenLandscapeSplitter),
            Expanded(
              child: Align(
                alignment: Alignment.bottomCenter,
                child: _buildControlButtons(),
              ),
            ),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) => Scaffold(
        primary: MediaQuery.of(context).orientation == Orientation.portrait,
        appBar: AppBar(
          title: Text(blePeripheral.name ?? ''),
          centerTitle: true,
          actions: [
            if (peripheral.isFeatureSupported(Features.option))
              IconButton(
                icon: const Icon(Icons.settings_rounded),
                onPressed: peripheral.isInitialized
                    ? () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                OptionsScreen(peripheral: peripheral),
                          ),
                        );
                      }
                    : null,
              ),
          ],
        ),
        body: SafeArea(
          child: OrientationBuilder(
            builder: (context, orientation) =>
                orientation == Orientation.portrait
                    ? _buildPortrait()
                    : _buildLandscape(),
          ),
        ),
      );
}
