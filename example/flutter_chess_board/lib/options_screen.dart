import 'dart:async';

import 'package:ble_backend_screens/ui/ui_consts.dart';
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
        trailing: ConstrainedBox(
          constraints:
              BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.25),
          child: Text(
            _convertToReadable(option.valueString),
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.end,
            maxLines: 2,
          ),
        ),
        onTap: () => _showEnumOptionPicker(
          context,
          option: option,
          onSelected: (String value) {
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

  Widget _createStrOption(StrOption option) => ListTile(
        title: _createTitle(option),
        subtitle: Text(
          option.valueString,
          maxLines: 5,
          style: ListTileTheme.of(context).subtitleTextStyle?.copyWith(
                fontSize: Theme.of(context).textTheme.bodySmall?.fontSize,
              ),
        ),
        onTap: () => _showStrOptionPicker(
          context,
          option: option,
          onSelected: (String value) {
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
        title: Row(children: [
          _createTitle(option),
          Text(': '),
          Text(
            option.valueString,
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ]),
        subtitle: Slider(
          value: option.value.toDouble(),
          min: option.min.toDouble(),
          max: option.max.toDouble(),
          divisions: ((option.max - option.min) /
                  (option.step != null ? option.step! : 1))
              .round(),
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
          year2023: false,
        ),
      );

  Widget _createFloatOption(FloatOption option) => ListTile(
        title: Row(children: [
          _createTitle(option),
          Text(': '),
          Text(
            option.valueString,
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ]),
        subtitle: Slider(
          value: option.value,
          min: option.min,
          max: option.max,
          divisions: ((option.max - option.min) /
                  (option.step != null ? option.step! : 0.01))
              .round(),
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
          year2023: false,
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

  void _showEnumOptionPicker(
    BuildContext context, {
    required EnumOption option,
    required void Function(String choice) onSelected,
  }) {
    showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          contentPadding: const EdgeInsets.only(top: 12),
          scrollable: true,
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: option.enumValues.map((value) {
              return RadioListTile(
                title: Text(_convertToReadable(value)),
                value: value,
                groupValue: option.value,
                onChanged: (value) {
                  if (value != null) onSelected(value);
                  Navigator.of(context).pop();
                },
              );
            }).toList(growable: false),
          ),
          actions: [
            ElevatedButton(
              child: const Text('Cancel'),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        );
      },
    );
  }

  void _showStrOptionPicker(
    BuildContext context, {
    required StrOption option,
    required void Function(String choice) onSelected,
  }) {
    showDialog(
      context: context,
      builder: (context) {
        final controller = TextEditingController(text: option.value);
        return AlertDialog(
          content: TextFormField(
            controller: controller,
            autofocus: true,
            maxLines: 5,
            decoration: const InputDecoration(
              hintText: 'Enter a value',
            ),
            onFieldSubmitted: (String value) {
              onSelected(value);
              Navigator.of(context).pop();
            },
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                onSelected(controller.text);
                Navigator.of(context).pop();
              },
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
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
        child: areOptionsInitialized
            ? Padding(
                padding: EdgeInsets.all(screenPadding),
                child: ListView(
                  children: [
                    Card(
                      child: Column(
                        children: options.map(_createOption).toList(),
                      ),
                    )
                  ],
                ),
              )
            : const SizedBox.shrink(),
      ),
    );
  }
}
