# BLE Chess Preview Example

This is an example for `flutter_chess_board` that includes a minimal set of e-board features, including preview.

## Basic Flow

The basic flow for handling an e-board/peripheral is:

* Do the handshake and register for events related to the peripheral flow.

```dart
Future<void> _initPeripheral() async {
  final mtu = bleConnector.createMtu();
  final requestedMtu = await mtu.request(mtu: maxStringSize);
  ...

  final features = [Features.msg, Features.option, Features.getState];
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
  peripheral.msgStream.listen(_showMessage);
}
```

In this example, we support a basic game, message exchange, e-board options, and `getState` for preview.

* With preview support, you can either start preview or start a new game from the default FEN.
* The game finishes like a typical game end, or after clicking the Stop button. In that case, the central sends the end reason with `peripheral.handleEnd(reason: <reason>)`.

## Preview

For preview, we provide a simple widget:
`example/flutter_chess_board_with_preview/lib/peripheral_preview_chess_board.dart`.

To implement preview, follow these steps:

1. Include `Features.getState` in the peripheral feature list.
2. Check whether the connected peripheral supports it with `peripheral.isFeatureSupported(Features.getState)`.
3. When preview is needed, call `peripheral.handleGetState()` to request the current e-board state.
4. Subscribe to `peripheral.roundUpdateStream` (in this example, the preview dialog subscribes to `roundUpdateStream` while it is open). While no round is active, each update may contain a preview position. Read it from `peripheral.round.fen`.

Remember that for e-boards with binary sensors, or e-boards that can only recognize colors, you can get a FEN like:
```
????????/????????/8/8/8/8/????????/????????
```
or
```
uuuuuuuu/uuuuuuuu/8/8/8/8/UUUUUUUU/UUUUUUUU
```
or
```
rnbqkbnr/pp????pp/8/8/8/8/PP????PP/RNBQKBNR
```

https://github.com/vovagorodok/chess_peripheral_protocol:

> Peripheral can send u (unknown black), U (unknown white) or ? (unknown) instead of full piece information depending on internal sensors and knowledge.
