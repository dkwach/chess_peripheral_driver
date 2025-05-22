import './option.dart';
import './string_consts.dart';

class CppOptions {
  final Map<String, Option> map = {};
  final List<Option> list = [];

  List<Option> get values => list;

  bool add(String cmd) {
    try {
      final split = cmd.split(' ');
      final name = split[0];
      final type = split[1];

      if (type == OptionTypes.bool) {
        _add(BoolOption(
          name: name,
          defaultValue: bool.parse(split[2]),
        ));
      } else if (type == OptionTypes.enu) {
        _add(EnumOption(
          name: name,
          defaultValue: split[2],
          enumValues: split.sublist(3),
        ));
      } else if (type == OptionTypes.str) {
        _add(StrOption(
          name: name,
          defaultValue: split.sublist(2).join(' '),
        ));
      } else if (type == OptionTypes.int) {
        _add(IntOption(
          name: name,
          defaultValue: int.parse(split[2]),
          min: int.parse(split[3]),
          max: int.parse(split[4]),
          step: split.length > 5 ? int.parse(split[5]) : null,
        ));
      } else if (type == OptionTypes.float) {
        _add(FloatOption(
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

  bool set(String cmd) {
    try {
      final split = cmd.split(' ');
      final name = split[0];
      final value = split[1];
      final option = map[name];

      if (option is BoolOption) {
        option.value = bool.parse(value);
      } else if (option is EnumOption) {
        option.value = value;
      } else if (option is StrOption) {
        option.value = split.sublist(1).join(' ');
      } else if (option is IntOption) {
        option.value = int.parse(value);
      } else if (option is FloatOption) {
        option.value = double.parse(value);
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  void reset() {
    for (var option in values) {
      if (option is BoolOption) {
        option.value = option.defaultValue;
      } else if (option is EnumOption) {
        option.value = option.defaultValue;
      } else if (option is StrOption) {
        option.value = option.defaultValue;
      } else if (option is IntOption) {
        option.value = option.defaultValue;
      } else if (option is FloatOption) {
        option.value = option.defaultValue;
      }
    }
  }

  void _add(Option option) {
    map[option.name] = option;
    list.add(option);
  }
}
