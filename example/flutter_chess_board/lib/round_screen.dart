import 'dart:async';

import 'package:ble_backend/ble_connector.dart';
import 'package:ble_backend/ble_peripheral.dart';
import 'package:ble_backend_screens/ui/ui_consts.dart';
import 'package:ble_chess_example/options_screen.dart';
import 'package:ble_chess_peripheral_driver/ble_chess_peripheral_driver.dart';
import 'package:ble_chess_peripheral_driver/chess_peripheral_driver.dart';
import 'package:flutter/material.dart';
import 'package:flutter_chess_board/flutter_chess_board.dart';
import 'package:fluttertoast/fluttertoast.dart';

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
  ChessBoardController chessController = ChessBoardController();
  Peripheral peripheral = DummyPeripheral();
  bool isAutocompleteOngoing = false;

  BlePeripheral get blePeripheral => widget.blePeripheral;
  BleConnector get bleConnector => widget.bleConnector;
  Chess get game => chessController.game;

  void _beginNewRound() {
    chessController.resetBoard();
    peripheral.handleBegin(
      fen: chessController.getFen(),
      variant: Variants.standard,
      side: Sides.both,
      lastMove: lastMove,
    );
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
      _beginNewRound();
    });
  }

  void _handlePeripheralRoundInitialized(_) {
    setState(() {
      isAutocompleteOngoing = false;
      if (!peripheral.round.isVariantSupported) {
        _showMessage('Unsupported variant');
      }
    });
  }

  void _handlePeripheralRoundUpdate(_) {
    setState(() {
      isAutocompleteOngoing = false;
    });
  }

  void _handlePeripheralStateSynchronize(bool isSynchronized) {
    _showMessage(isSynchronized ? 'Synchronized' : 'Unsynchronized');
  }

  void _handleCentralMove() {
    peripheral.handleMove(move: lastMove!);
    _handleCentralEnd();
  }

  void _handleCentralEnd() {
    if (game.in_checkmate) {
      _showMessage('Checkmate');
      peripheral.handleEnd(reason: EndReasons.checkmate);
    } else if (game.in_stalemate) {
      _showMessage('Stalemate');
      peripheral.handleEnd(
        reason: EndReasons.draw,
        drawReason: DrawReasons.stalemate,
      );
    } else if (game.in_threefold_repetition) {
      _showMessage('Threefold repetition');
      peripheral.handleEnd(
        reason: EndReasons.draw,
        drawReason: DrawReasons.threefoldRepetition,
      );
    } else if (game.insufficient_material) {
      _showMessage('Insufficient material');
      peripheral.handleEnd(
        reason: EndReasons.draw,
        drawReason: DrawReasons.insufficientMaterial,
      );
    } else if (game.in_draw) {
      _showMessage('Draw');
      peripheral.handleEnd(reason: EndReasons.draw);
    }
  }

  void _handlePeripheralMove(String uci) {
    if (chessController.makeMoveUci(uci: uci)) {
      _handleCentralMove();
    } else {
      peripheral.handleReject();
      _showMessage('Rejected');
    }
  }

  void _handleAutocomplete() {
    setState(() {
      isAutocompleteOngoing = true;
      peripheral.handleSetState();
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
      Features.side,
      Features.setState,
      Features.submoveState,
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

  @override
  void initState() {
    super.initState();
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

  String? get lastMove {
    final history = game.history;
    if (history.isEmpty) return null;
    final lastMove = history.last.move;
    String uci = lastMove.fromAlgebraic + lastMove.toAlgebraic;
    final promotion = lastMove.promotion;
    if (promotion != null) uci += promotion.name;
    return uci;
  }

  Widget _buildChessBoardWidget() => ChessBoard(
        controller: chessController,
        boardColor: BoardColor.darkBrown,
        boardOrientation: PlayerColor.white,
        onMove: _handleCentralMove,
      );

  Widget _buildNewRoundButton() => FilledButton.icon(
        icon: const Icon(Icons.refresh_rounded),
        label: Text('New Round'),
        onPressed: peripheral.isInitialized ? _beginNewRound : null,
      );

  Widget _buildAutocompleteButton() => FilledButton.icon(
        icon: const Icon(Icons.auto_awesome_rounded),
        label: Text('Autocomplete'),
        onPressed: peripheral.round.isStateSettable && !isAutocompleteOngoing
            ? _handleAutocomplete
            : null,
      );

  Widget _buildControlButtons() => SizedBox(
        height: buttonHeight,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(child: _buildNewRoundButton()),
            if (peripheral.isFeatureSupported(Features.setState))
              const SizedBox(width: buttonsSplitter),
            if (peripheral.isFeatureSupported(Features.setState))
              Expanded(child: _buildAutocompleteButton()),
          ],
        ),
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
