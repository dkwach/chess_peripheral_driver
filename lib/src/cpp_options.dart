import './cpp_peripheral.dart';
import './option.dart';
import './cpp_option.dart';
import './string_consts.dart';

class CppOptions {
  final Map<String, Option> _map = {};
  final List<Option> _list = [];
  final CppPeripheral _peripheral;

  CppOptions({required CppPeripheral peripheral}) : _peripheral = peripheral;

  List<Option> get list => _list;

  bool addPeripheralOption(String cmd) {
    try {
      final split = cmd.split(' ');
      final name = split[0];
      final type = split[1];

      if (type == OptionTypes.bool) {
        _add(CppBoolOption(
          options: this,
          name: name,
          defaultValue: bool.parse(split[2]),
        ));
      } else if (type == OptionTypes.enu) {
        _add(CppEnumOption(
          options: this,
          name: name,
          defaultValue: split[2],
          enumValues: split.sublist(3),
        ));
      } else if (type == OptionTypes.str) {
        _add(CppStrOption(
          options: this,
          name: name,
          defaultValue: split.sublist(2).join(' '),
        ));
      } else if (type == OptionTypes.int) {
        _add(CppIntOption(
          options: this,
          name: name,
          defaultValue: int.parse(split[2]),
          min: int.parse(split[3]),
          max: int.parse(split[4]),
          step: split.length > 5 ? int.parse(split[5]) : null,
        ));
      } else if (type == OptionTypes.float) {
        _add(CppFloatOption(
          options: this,
          name: name,
          defaultValue: double.parse(split[2]),
          min: double.parse(split[3]),
          max: double.parse(split[4]),
          step: split.length > 5 ? double.parse(split[5]) : null,
        ));
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  bool setPeripheralOption(String cmd) {
    try {
      final split = cmd.split(' ');
      final name = split[0];
      final value = split[1];
      final option = _map[name];

      if (option is CppBoolOption) {
        option.peripheralValue = bool.parse(value);
      } else if (option is CppEnumOption) {
        option.peripheralValue = value;
      } else if (option is CppStrOption) {
        option.peripheralValue = split.sublist(1).join(' ');
      } else if (option is CppIntOption) {
        option.peripheralValue = int.parse(value);
      } else if (option is CppFloatOption) {
        option.peripheralValue = double.parse(value);
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  void setCentralOption(Option option) {
    _peripheral.handleSetOption(
      name: option.name,
      value: option.valueString,
    );
  }

  void reset() {
    for (var option in _list) {
      if (option is CppTypedOption) {
        option.reset();
      }
    }
  }

  void _add(Option option) {
    _map[option.name] = option;
    _list.add(option);
  }
}
