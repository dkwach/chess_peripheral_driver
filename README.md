# Chess Peripheral Driver

Play chess on physical device using [CPP](https://github.com/vovagorodok/chess_peripheral_protocol) protocol
e.g. over BLE

## Usage
Create `CppPeripheral` when peripheral connected and begin round only after peripheral initialized:
```dart
final serial = BleStringSerial(
    bleSerial: bleConnector.createSerial(
    serviceId: serviceUuid,
    rxCharacteristicId: characteristicUuidRx,
    txCharacteristicId: characteristicUuidTx));
final peripheral = CppPeripheral(
    stringSerial: serial,
    features: [],
    variants: [Variants.standard]);

peripheral.initializedStream.listen((_) {
    print('Initialized');
    peripheral.handleBegin(fen: 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1');
});
peripheral.roundInitializedStream.listen((_) {
    final round = peripheral.round;
    print('Round ${round.isSynchronized ? 'synchronized' : 'unsynchronized'} ${round.fen}');
    peripheral.handleMove(move: 'a2a3');
});
peripheral.roundUpdateStream.listen((_) {
    final round = peripheral.round;
    print('Round ${round.isSynchronized ? 'synchronized' : 'unsynchronized'} ${round.fen}');
});
peripheral.moveStream.listen((move) {
    print('Move ${move}');
    isValid(move) ? peripheral.handleMove(move: move) : peripheral.handleReject();
});
```

`BleSerial` can be created by own (see [ble_backends](https://github.com/vovagorodok/ble_backends/tree/main/packages)). Example for `flutter_reactive_ble` library:
```dart
final bleSerial = BleSerial(
    characteristicRx: FlutterReactiveBleCharacteristic(
        backend: FlutterReactiveBle()
        deviceId: deviceId,
        serviceId: Uuid.parse(serviceUuid),
        characteristicId: Uuid.parse(characteristicUuidRx)),
    characteristicTx: FlutterReactiveBleCharacteristic(
        backend: FlutterReactiveBle()
        deviceId: deviceId,
        serviceId: Uuid.parse(serviceUuid),
        characteristicId: Uuid.parse(characteristicUuidTx)),
);
```

Call feature specific methods only if feature is supported by peripheral:
```dart
if (peripheral.isFeatureSupported(Features.undoOffer)) {
    peripheral.handleUndoOffer();
}
if (peripheral.isFeatureSupported(Features.drawOffer)) {
    peripheral.handleDrawOffer();
}
if (peripheral.isFeatureSupported(Features.setState) && peripheral.round.isStateSettable) {
    peripheral.handleSetState();
}
```
