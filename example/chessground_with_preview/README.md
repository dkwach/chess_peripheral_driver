# BLE Chess Preview Example

This is an example for `chessground` that includes a minimal set of e-board features, including preview.

## Basic Flow

The basic flow for handling an e-board/peripheral is:

* Do the handshake and register for events related to the peripheral flow.

```dart
Future<void> _initPeripheral() async {
  final mtu = bleConnector.createMtu();
  final requestedMtu = await mtu.request(mtu: maxStringSize);
  ...

  final features = [
    Features.getState,
  ];
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
```
* handle initializedStream/roundInitializedStream/ for initialization
* handle stateSynchronizeStream to monitor  central/peripheral synchronization
* handle moveStream to get moves from peripheral
* handle errStream for potential errors

From central we need
* initialize game: `peripheral.handleBegin()`
* pass moves to e-board `peripheral.handleMove()`
* finish game: like a typical game end, or after clicking the End Round button. In that case, the central sends the end reason with `peripheral.handleEnd()`.

## Preview

For preview, we provide a simple dialog/widget:
`example/chessground_with_preview/lib/peripheral_preview_dialog.dart`.

To implement preview, follow these steps:

1. Include `Features.getState` in the peripheral feature list.
2. Check whether the connected peripheral supports it with `peripheral.isFeatureSupported(Features.getState)`.
3. When preview is needed(round should be not active), open `PeripheralPreviewDialog` with the current `peripheral` and call `peripheral.handleGetState()` to request the current e-board state.
4. Subscribe to `peripheral.roundUpdateStream` while preview is open. In this example, `PeripheralPreviewDialog` reads the latest preview position from `peripheral.round.fen` after each update.
5. Render known pieces as a normal `chessground` position and render unknown pieces as board annotations.

Remember that for e-boards with binary sensors, or e-boards that can only recognize colors, you can get a FEN like:

```text
????????/????????/8/8/8/8/????????/????????
```

or

```text
uuuuuuuu/uuuuuuuu/8/8/8/8/UUUUUUUU/UUUUUUUU
```

or

```text
rnbqkbnr/pp????pp/8/8/8/8/PP????PP/RNBQKBNR
```

https://github.com/vovagorodok/chess_peripheral_protocol:

> Peripheral can send u (unknown black), U (unknown white) or ? (unknown) instead of full piece information depending on internal sensors and knowledge.

In this example:

* `?` is rendered as a `?` annotation.
* `U` is rendered as a `W?` annotation.
* `u` is rendered as a `B?` annotation.
* The Begin Round button in the preview dialog is disabled until the FEN is fully recognizable.
