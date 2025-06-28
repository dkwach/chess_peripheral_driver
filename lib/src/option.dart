abstract class Option {
  String get name;
  String get valueString;
}

abstract class TypedOption<T> extends Option {
  T get value;
  set value(T newValue);
}

abstract class BoolOption extends TypedOption<bool> {}

abstract class EnumOption extends TypedOption<String> {
  List<String> get enumValues;
}

abstract class StrOption extends TypedOption<String> {}

abstract class IntOption extends TypedOption<int> {
  int get min;
  int get max;
  int? get step;
}

abstract class FloatOption extends TypedOption<double> {
  double get min;
  double get max;
  double? get step;
}
