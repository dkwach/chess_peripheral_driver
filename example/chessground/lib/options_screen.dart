import 'dart:async';

import 'package:ble_chess_peripheral_driver/chess_peripheral_driver.dart';
import 'package:flutter/material.dart';

class OptionsScreen extends StatefulWidget {
  const OptionsScreen({required this.peripheral, super.key});

  final Peripheral peripheral;

  @override
  State<OptionsScreen> createState() => OptionsScreenState();
}

class OptionsScreenState extends State<OptionsScreen> {
  StreamSubscription? _subscription;

  Peripheral get peripheral => widget.peripheral;
  bool get areOptionsInitialized => peripheral.areOptionsInitialized;
  List<Option> get options => peripheral.options;

  @override
  void initState() {
    super.initState();
    _subscription = peripheral.optionsUpdateStream.listen(_updateOptions);
    peripheral.handleOptionsBegin();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  void _updateOptions(_) {
    setState(() {});
  }

  String _convertToReadable(String str) => str
      .split('_')
      .map((word) => word[0].toUpperCase() + word.substring(1))
      .join(' ');

  Widget _createTitle(Option option) => Text(
    _convertToReadable(option.name),
    style: const TextStyle(fontWeight: FontWeight.bold),
  );

  Widget _createBoolOption(BoolOption option) => ListTile(
    title: _createTitle(option),
    trailing: Switch(
      value: option.value,
      onChanged: (bool value) {
        setState(() {
          option.value = value;
          peripheral.handleSetOption(
            name: option.name,
            value: option.valueString,
          );
        });
      },
    ),
  );

  Widget _createEnumOption(EnumOption option) => ListTile(
    title: _createTitle(option),
    trailing: DropdownMenu<String>(
      initialSelection: option.value,
      dropdownMenuEntries:
          option.enumValues.map((String value) {
            return DropdownMenuEntry<String>(
              value: value,
              label: _convertToReadable(value),
            );
          }).toList(),
      onSelected: (String? value) {
        setState(() {
          option.value = value!;
          peripheral.handleSetOption(
            name: option.name,
            value: option.valueString,
          );
        });
      },
    ),
  );

  Widget _createStrOption(StrOption option) => ListTile(
    title: _createTitle(option),
    subtitle: TextFormField(
      controller: TextEditingController(text: option.value),
      decoration: InputDecoration(
        hintText: 'Enter a value',
        border: OutlineInputBorder(),
      ),
      onFieldSubmitted: (String value) {
        setState(() {
          option.value = value;
          peripheral.handleSetOption(
            name: option.name,
            value: option.valueString,
          );
        });
      },
    ),
  );

  Widget _createIntOption(IntOption option) => ListTile(
    title: _createTitle(option),
    subtitle: Slider(
      value: option.value.toDouble(),
      min: option.min.toDouble(),
      max: option.max.toDouble(),
      divisions:
          option.step != null
              ? ((option.max - option.min) / option.step!).round()
              : null,
      label: option.valueString,
      onChanged: (double value) {
        setState(() {
          option.value = value.toInt();
          peripheral.handleSetOption(
            name: option.name,
            value: option.valueString,
          );
        });
      },
    ),
  );

  Widget _createFloatOption(FloatOption option) => ListTile(
    title: _createTitle(option),
    subtitle: Slider(
      value: option.value,
      min: option.min,
      max: option.max,
      divisions:
          option.step != null
              ? ((option.max - option.min) / option.step!).round()
              : null,
      label: option.valueString,
      onChanged: (double value) {
        setState(() {
          option.value = value;
          peripheral.handleSetOption(
            name: option.name,
            value: option.valueString,
          );
        });
      },
    ),
  );

  Widget _createOption(Option option) {
    switch (option.runtimeType) {
      case BoolOption:
        return _createBoolOption(option as BoolOption);
      case EnumOption:
        return _createEnumOption(option as EnumOption);
      case StrOption:
        return _createStrOption(option as StrOption);
      case IntOption:
        return _createIntOption(option as IntOption);
      case FloatOption:
        return _createFloatOption(option as FloatOption);
      default:
        return const SizedBox.shrink();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      primary: MediaQuery.of(context).orientation == Orientation.portrait,
      appBar: AppBar(
        title: Text('Options'),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.cached_rounded),
            onPressed:
                areOptionsInitialized ? peripheral.handleOptionsReset : null,
          ),
        ],
      ),
      body: SafeArea(
        child: ListView.builder(
          itemCount: areOptionsInitialized ? options.length : 0,
          itemBuilder: (BuildContext context, int index) {
            return _createOption(options[index]);
          },
        ),
      ),
    );
  }
}
