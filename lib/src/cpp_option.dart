import './option.dart';
import './cpp_options.dart';
import './timer_wrapper.dart';

abstract class CppTypedOption<T> extends TypedOption<T> {
  final CppOptions _options;
  final String _name;
  final T _defaultValue;
  T _value;
  final _timer = TimerWrapper();
  bool _isHandled = false;

  CppTypedOption({
    required CppOptions options,
    required String name,
    required T defaultValue,
  })  : _options = options,
        _name = name,
        _defaultValue = defaultValue,
        _value = defaultValue;

  @override
  String get name => _name;

  @override
  T get value => _value;

  @override
  set value(T newValue) {
    _value = newValue;
    if (_timer.isActive()) {
      _isHandled = false;
    } else {
      _handleValue();
    }
  }

  set peripheralValue(T newValue) {
    _value = newValue;
    _timer.stop();
  }

  void reset() {
    _value = _defaultValue;
    _timer.stop();
  }

  void _handleValue() {
    _isHandled = true;
    _timer.start(
      const Duration(milliseconds: 100),
      _handleTimeout,
    );
    _options.setCentralOption(this);
  }

  void _handleTimeout() {
    if (!_isHandled) {
      _handleValue();
    }
  }
}

class CppBoolOption extends CppTypedOption<bool> implements BoolOption {
  CppBoolOption({
    required CppOptions options,
    required String name,
    required bool defaultValue,
  }) : super(options: options, name: name, defaultValue: defaultValue);

  @override
  String get valueString => value.toString();
}

class CppEnumOption extends CppTypedOption<String> implements EnumOption {
  final List<String> _enumValues;

  CppEnumOption({
    required CppOptions options,
    required String name,
    required String defaultValue,
    required List<String> enumValues,
  })  : _enumValues = enumValues,
        super(options: options, name: name, defaultValue: defaultValue);

  @override
  String get valueString => value;
  @override
  List<String> get enumValues => _enumValues;
}

class CppStrOption extends CppTypedOption<String> implements StrOption {
  CppStrOption({
    required CppOptions options,
    required String name,
    required String defaultValue,
  }) : super(options: options, name: name, defaultValue: defaultValue);

  @override
  String get valueString => value;
}

class CppIntOption extends CppTypedOption<int> implements IntOption {
  final int _min;
  final int _max;
  final int? _step;

  CppIntOption({
    required CppOptions options,
    required String name,
    required int defaultValue,
    required int min,
    required int max,
    int? step,
  })  : _min = min,
        _max = max,
        _step = step,
        super(options: options, name: name, defaultValue: defaultValue);

  @override
  int get min => _min;
  @override
  int get max => _max;
  @override
  int? get step => _step;
  @override
  String get valueString => value.toString();
}

class CppFloatOption extends CppTypedOption<double> implements FloatOption {
  final double _min;
  final double _max;
  final double? _step;

  CppFloatOption({
    required CppOptions options,
    required String name,
    required double defaultValue,
    required double min,
    required double max,
    double? step,
  })  : _min = min,
        _max = max,
        _step = step,
        super(options: options, name: name, defaultValue: defaultValue);

  @override
  double get min => _min;
  @override
  double get max => _max;
  @override
  double? get step => _step;
  @override
  String get valueString => value.toStringAsFixed(2);
}
