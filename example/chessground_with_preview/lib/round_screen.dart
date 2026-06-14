import 'dart:async';
import 'dart:math';

import 'package:ble_backend/ble_connector.dart';
import 'package:ble_backend/ble_peripheral.dart';
import 'package:ble_backend_screens/ui/ui_consts.dart';
import 'package:ble_chess_peripheral_driver/ble_chess_peripheral_driver.dart';
import 'package:ble_chess_peripheral_driver/chess_peripheral_driver.dart';
import 'package:chessground/chessground.dart';
import 'package:dartchess/dartchess.dart';
import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'peripheral_preview_dialog.dart';

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

class RoundScreenState extends State<RoundScreen> {
  StreamSubscription? _subscription;
  Peripheral peripheral = DummyPeripheral();
  Position position = Chess.initial;
  String fen = Chess.initial.fen;
  NormalMove? lastMove;
  NormalMove? promotionMove;
  ValidMoves validMoves = IMap(const {});

  BlePeripheral get blePeripheral => widget.blePeripheral;
  BleConnector get bleConnector => widget.bleConnector;

  Future<void> _beginRound({String? fen}) async {
    late final Position nextPosition;
    try {
      nextPosition =
          fen == null ? Chess.initial : Chess.fromSetup(Setup.parseFen(fen));
    } catch (err) {
      _showError('Invalid FEN: $err');
      return;
    }

    setState(() {
      position = nextPosition;
      this.fen = position.fen;
      validMoves = makeLegalMoves(position);
      lastMove = null;
      promotionMove = null;
    });

    await peripheral.handleBegin(
      fen: position.fen,
      variant: Variants.standard,
      side: Sides.both,
      lastMove: lastMove?.uci,
      check: _getCheck(),
    );
  }

  Future<void> _showPreview() async {
    await peripheral.handleGetState();
    final fen = await showDialog<String>(
      context: context,
      builder: (context) => PeripheralPreviewDialog(
        peripheral: peripheral,
      ),
    );

    if (fen != null) {
      await _beginRound(fen: fen);
    }
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
    setState(() {
      promotionMove = null;
    });
  }

  void _handlePeripheralRoundInitialized(_) {
    setState(() {
      if (!peripheral.round.isVariantSupported) {
        _showMessage('Unsupported variant');
      }
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
    } else if (position.isStalemate || position.isInsufficientMaterial) {
      _showMessage('Draw');
      peripheral.handleEnd(
        reason: EndReasons.draw,
      );
    } else if (position.isVariantEnd) {
      _showMessage('Variant end');
      peripheral.handleEnd(reason: EndReasons.undefined);
    }
  }

  void _handlePeripheralMove(String uci) {
    final move = NormalMove.fromUci(uci);
    if (position.isLegal(move)) {
      _playMove(move);
    } else {
      peripheral.handleReject();
      _showMessage('Rejected');
    }
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
    final features = [Features.getState];
    final variants = [Variants.standard];
    peripheral = CppPeripheral(
      stringSerial: serial,
      features: features,
      variants: variants,
    );
    peripheral.initializedStream.listen(_handlePeripheralInitialized);
    peripheral.roundInitializedStream.listen(_handlePeripheralRoundInitialized);
    peripheral.stateSynchronizeStream.listen(_handlePeripheralStateSynchronize);
    peripheral.moveStream.listen(_handlePeripheralMove);
    peripheral.errStream.listen(_showError);
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

  void _onPromotionSelection(Role? role) {
    if (role == null) {
      setState(() {
        promotionMove = null;
      });
    } else if (promotionMove != null) {
      _playMove(promotionMove!.withPromotion(role));
    }
  }

  void _playMove(NormalMove move, {bool? isDrop}) {
    if (_isPromotionPawnMove(move)) {
      setState(() {
        promotionMove = move;
      });
      return;
    }

    if (!position.isLegal(move)) return;

    setState(() {
      position = position.playUnchecked(move);
      lastMove = move;
      fen = position.fen;
      validMoves = makeLegalMoves(position);
      promotionMove = null;
    });
    _handleCentralMove(move);
  }

  bool _isPromotionPawnMove(NormalMove move) {
    return move.promotion == null &&
        position.board.roleAt(move.from) == Role.pawn &&
        ((move.to.rank == Rank.first && position.turn == Side.black) ||
            (move.to.rank == Rank.eighth && position.turn == Side.white));
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

  Widget _buildChessBoardWidget() => Center(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return Chessboard(
              size: min(constraints.maxWidth, constraints.maxHeight),
              orientation: Side.white,
              fen: fen,
              lastMove: peripheral.round.isStateSynchronized ? lastMove : null,
              game: GameData(
                playerSide: PlayerSide.both,
                validMoves: validMoves,
                sideToMove: position.turn,
                isCheck: peripheral.round.isStateSynchronized
                    ? position.isCheck
                    : false,
                promotionMove: promotionMove,
                onMove: _playMove,
                onPromotionSelection: _onPromotionSelection,
              ),
            );
          },
        ),
      );

  Widget _buildBeginButton() => FilledButton.icon(
        icon: const Icon(Icons.play_arrow_rounded),
        label: const Text('New Round'),
        onPressed: peripheral.isInitialized ? _beginRound : null,
      );

  Widget _buildPreviewButton() => FilledButton.icon(
        icon: const Icon(Icons.preview_rounded),
        label: const Text('From Peripheral'),
        onPressed: peripheral.isInitialized ? _showPreview : null,
      );

  Widget _buildControlButtons() => Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          if (peripheral.isFeatureSupported(Features.getState))
            SizedBox(
              height: buttonHeight,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(child: _buildPreviewButton()),
                ],
              ),
            ),
          const SizedBox(height: buttonsSplitter),
          SizedBox(
            height: buttonHeight,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: _buildBeginButton()),
              ],
            ),
          ),
        ],
      );

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
