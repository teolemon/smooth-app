import 'package:intl/intl.dart';
import 'package:openfoodfacts/interface/JsonObject.dart';
import 'package:openfoodfacts/model/Nutrient.dart';
import 'package:openfoodfacts/model/Nutriments.dart';
import 'package:openfoodfacts/model/OrderedNutrient.dart';
import 'package:openfoodfacts/model/OrderedNutrients.dart';
import 'package:openfoodfacts/model/Product.dart';
import 'package:openfoodfacts/utils/UnitHelper.dart';
import 'package:smooth_app/pages/text_field_helper.dart';

/// Nutrition data, for nutrient order and conversions.
class NutritionContainer {
  NutritionContainer({
    required final OrderedNutrients orderedNutrients,
    required final Product product,
  }) {
    _loadNutrients(orderedNutrients.nutrients);
    final Map<String, dynamic>? json = product.nutriments?.toJson();
    if (json != null) {
      _loadUnits(json);
      _loadValues(json);
    }
    _servingSize = product.servingSize;
    _barcode = product.barcode!;
    noNutritionData = product.noNutritionData ?? false;
  }

  static const String energyId = 'energy';

  /// special case: present id [OrderedNutrient] but not in [Nutriments] map.
  static const String energyKJId = 'energy-kj';
  static const String _energyKCalId = 'energy-kcal';
  static const String fakeNutrientIdServingSize = '_servingSize';

  static const Map<Unit, Unit> _nextWeightUnits = <Unit, Unit>{
    Unit.G: Unit.MILLI_G,
    Unit.MILLI_G: Unit.MICRO_G,
    Unit.MICRO_G: Unit.G,
  };

  // For the moment we only care about "weight or not weight?"
  // Could be refined with values taken from https://static.openfoodfacts.org/data/taxonomies/nutrients.json
  // Fun fact: most of them are not supported (yet) by [Nutriments].
  static const Map<String, Unit> _defaultNotWeightUnits = <String, Unit>{
    energyId: Unit.KJ,
    _energyKCalId: Unit.KCAL,
    'alcohol': Unit.PERCENT,
    'cocoa': Unit.PERCENT,
    'collagen-meat-protein-ratio': Unit.PERCENT,
    'fruits-vegetables-nuts': Unit.PERCENT,
    'fruits-vegetables-nuts-dried': Unit.PERCENT,
    'fruits-vegetables-nuts-estimate': Unit.PERCENT,
  };

  /// All the nutrients (country-related).
  final List<OrderedNutrient> _nutrients = <OrderedNutrient>[];

  /// Nutrient values for 100g and serving.
  final Map<String, double> _values = <String, double>{};

  /// Nutrient units.
  final Map<String, Unit> _units = <String, Unit>{};

  /// Initial nutrient units.
  final Map<String, Unit> _initialUnits = <String, Unit>{};

  /// Nutrient Ids added by the end-user
  final Set<String> _added = <String>{};

  String? _servingSize;

  String? get servingSize => _servingSize;

  late final String _barcode;

  late bool noNutritionData;

  /// Returns the not interesting nutrients, for a "Please add me!" list.
  Iterable<OrderedNutrient> getLeftoverNutrients() => _nutrients.where(
        (final OrderedNutrient element) => _isNotRelevant(element),
      );

  /// Returns the interesting nutrients that need to be displayed.
  Iterable<OrderedNutrient> getDisplayableNutrients() => _nutrients.where(
        (final OrderedNutrient element) => !_isNotRelevant(element),
      );

  /// Returns true if the [OrderedNutrient] is not relevant.
  bool _isNotRelevant(final OrderedNutrient orderedNutrient) {
    final String nutrientId = orderedNutrient.id;
    final double? value100g = getValue(getValueKey(
      nutrientId,
      NutritionUnit.per100g,
    ));
    final double? valueServing = getValue(getValueKey(
      nutrientId,
      NutritionUnit.perServing,
    ));
    return value100g == null &&
        valueServing == null &&
        (!orderedNutrient.important) &&
        (!_added.contains(nutrientId));
  }

  /// Returns a [Product] with changed nutrients data.
  Product getProduct(Product product) {
    product.barcode = _barcode;
    product.noNutritionData = noNutritionData;
    product.nutriments = _getNutriments();
    product.servingSize = _servingSize;
    return product;
  }

  void copyUnitsFrom(final NutritionContainer other) =>
      _units.addAll(other._units);

  /// Converts all the data to a [Nutriments].
  ///
  /// When we WRITE, that's rather simple.
  /// If we want to say "120 mg", we put "120" as value and "mg" as unit.
  /// When we READ it's not the same, as the weight values are ALWAYS in g.
  /// If the server data is "120 mg", we get "0.12" as value (in g)
  /// and "mg" as unit (as suggested unit).
  Nutriments _getNutriments() {
    final Map<String, dynamic> map = <String, dynamic>{};
    for (final OrderedNutrient orderedNutrient in getDisplayableNutrients()) {
      final String nutrientId = orderedNutrient.id;
      final String key100g = getValueKey(
        nutrientId,
        NutritionUnit.per100g,
      );
      final String keyServing = getValueKey(
        nutrientId,
        NutritionUnit.perServing,
      );
      final double? value100g = getValue(key100g);
      final double? valueServing = getValue(keyServing);
      if (value100g == null && valueServing == null) {
        continue;
      }
      final Unit unit = getUnit(nutrientId);
      if (value100g != null) {
        map[key100g] = value100g;
      }
      if (valueServing != null) {
        map[keyServing] = valueServing;
      }
      map[getUnitKey(nutrientId)] = UnitHelper.unitToString(unit);
    }

    return Nutriments.fromJson(map);
  }

  /// Returns the stored product nutrient's value.
  double? getValue(final String valueKey) => _values[valueKey];

  /// Stores the text from the end-user input.
  void setControllerText(final String controllerKey, final String? text) {
    if (controllerKey == fakeNutrientIdServingSize) {
      _servingSize = text?.trim().isNotEmpty == false ? null : text;
      return;
    }

    double? value;
    if (text?.isNotEmpty == true) {
      try {
        value = double.parse(text!.replaceAll(',', '.'));
      } catch (e) {
        //
      }
    }
    if (value == null) {
      _values.remove(controllerKey);
    } else {
      _values[controllerKey] = value;
    }
  }

  /// Typical use-case: should we make the [Unit] button clickable?
  static bool isEditableWeight(final OrderedNutrient orderedNutrient) =>
      getDefaultUnit(orderedNutrient.id) == null;

  /// Typical use-case: [Unit] button action.
  void setNextWeightUnit(final OrderedNutrient orderedNutrient) {
    final Unit unit = getUnit(orderedNutrient.id);
    _setUnit(orderedNutrient.id, _nextWeightUnits[unit] ?? unit, init: false);
  }

  /// Returns the nutrient [Unit], after possible alterations.
  Unit getUnit(String nutrientId) {
    nutrientId = _fixNutrientId(nutrientId);
    switch (nutrientId) {
      case energyId:
      case energyKJId:
        return Unit.KJ;
      case _energyKCalId:
        return Unit.KCAL;
      default:
        return _units[nutrientId] ?? getDefaultUnit(nutrientId) ?? Unit.G;
    }
  }

  /// Returns the probable nutrient [Unit], after possible alterations.
  static Unit getProbableUnit(String nutrientId) {
    nutrientId = _fixNutrientId(nutrientId);
    switch (nutrientId) {
      case energyId:
      case energyKJId:
        return Unit.KJ;
      case _energyKCalId:
        return Unit.KCAL;
      default:
        return getDefaultUnit(nutrientId) ?? Unit.G;
    }
  }

  /// Stores the nutrient [Unit].
  void _setUnit(
    final String nutrientId,
    final Unit unit, {
    required final bool init,
  }) {
    final String tag = _fixNutrientId(nutrientId);
    _units[tag] = unit;
    if (init) {
      _initialUnits[tag] = unit;
    }
  }

  static Unit? getDefaultUnit(final String nutrientId) =>
      _defaultNotWeightUnits[_fixNutrientId(nutrientId)];

  /// To be used when an [OrderedNutrient] is added to the input list
  void add(final OrderedNutrient orderedNutrient) =>
      _added.add(orderedNutrient.id);

  /// Returns the [Nutriments] map key for the nutrient value.
  ///
  /// * [perServing] true: per serving.
  /// * [perServing] false: per 100g.
  static String getValueKey(
    String nutrientId,
    final NutritionUnit nutritionUnit,
  ) {
    final bool perServing = nutritionUnit == NutritionUnit.perServing;
    nutrientId = _fixNutrientId(nutrientId);

    // 'energy-kcal' is directly for serving (no 'energy-kcal_serving')
    if (nutrientId == _energyKCalId && perServing) {
      return _energyKCalId;
    }
    return '$nutrientId${perServing ? '_serving' : '_100g'}';
  }

  /// Returns a vertical list of nutrients from a tree structure.
  ///
  /// Typical use-case: to be used from BE's tree nutrients in order to get
  /// a simple one-dimension list, easier to display and parse.
  /// For some countries, there's energy or energyKJ, or both
  /// cf. https://github.com/openfoodfacts/openfoodfacts-server/blob/main/lib/ProductOpener/Food.pm
  /// Regarding our list of nutrients here, we need one and only one of them.
  void _loadNutrients(
    final List<OrderedNutrient> nutrients,
  ) {
    bool alreadyEnergyKJ = false;

    // inner method, in order to use alreadyEnergyKJ without a private variable.
    void populateOrderedNutrientList(final List<OrderedNutrient> list) {
      for (final OrderedNutrient nutrient in list) {
        if (nutrient.id != energyKJId &&
            !Nutrient.values.map((Nutrient e) {
              return e.offTag;
            }).contains(nutrient.id)) {
          continue;
        }
        final bool nowEnergy =
            nutrient.id == energyId || nutrient.id == energyKJId;
        bool addNutrient = true;
        if (nowEnergy) {
          if (alreadyEnergyKJ) {
            addNutrient = false;
          }
          alreadyEnergyKJ = true;
        }
        if (addNutrient) {
          _nutrients.add(nutrient);
        }
        if (nutrient.subNutrients != null) {
          populateOrderedNutrientList(nutrient.subNutrients!);
        }
      }
    }

    populateOrderedNutrientList(nutrients);

    if (!alreadyEnergyKJ) {
      throw Exception('no energy or energyKJ found: very suspicious!');
    }
  }

  /// Returns the unit key according to [Nutriments] json map.
  static String getUnitKey(final String nutrientId) =>
      '${_fixNutrientId(nutrientId)}_unit';

  static String _fixNutrientId(final String nutrientId) =>
      nutrientId == energyKJId ? energyId : nutrientId;

  /// Converts a double (weight) value from grams.
  ///
  /// Typical use-case: after receiving a value from the BE.
  static double? convertWeightFromG(final double? value, final Unit unit) {
    if (value == null) {
      return null;
    }
    if (unit == Unit.MILLI_G) {
      return value * 1E3;
    }
    if (unit == Unit.MICRO_G) {
      return value * 1E6;
    }
    return value;
  }

  /// Loads product nutrient units into a map.
  ///
  /// Needs nutrients to be loaded first.
  void _loadUnits(final Map<String, dynamic> json) {
    for (final OrderedNutrient orderedNutrient in _nutrients) {
      final String nutrientId = orderedNutrient.id;
      final String unitKey = getUnitKey(nutrientId);
      final dynamic value = json[unitKey];
      if (value == null || value is! String) {
        continue;
      }
      final Unit? unit = UnitHelper.stringToUnit(value);
      if (unit != null) {
        _setUnit(nutrientId, unit, init: true);
      }
    }
  }

  /// Loads product nutrients into a map.
  ///
  /// Needs nutrients and units to be loaded first.
  void _loadValues(final Map<String, dynamic> json) {
    for (final OrderedNutrient orderedNutrient in _nutrients) {
      final String nutrientId = orderedNutrient.id;
      final Unit unit = getUnit(nutrientId);
      for (int i = 0; i < 2; i++) {
        final NutritionUnit perServing =
            i == 0 ? NutritionUnit.perServing : NutritionUnit.per100g;
        final String valueKey = getValueKey(nutrientId, perServing);
        final double? value = convertWeightFromG(
          JsonObject.parseDouble(json[valueKey]),
          unit,
        );
        if (value != null) {
          _values[valueKey] = value;
        }
      }
    }
  }

  bool isEdited(
    final Map<String, TextEditingControllerWithInitialValue> controllers,
    final NumberFormat numberFormat,
    final bool noNutritionData,
    final bool nutritionUnitHasChanged,
  ) {
    if (_isEditedControllers(controllers)) {
      return true;
    }
    if (this.noNutritionData != noNutritionData) {
      return true;
    }
    if (nutritionUnitHasChanged) {
      return true;
    }
    if (_isEditedUnits()) {
      return true;
    }
    return false;
  }

  bool _isEditedControllers(
    final Map<String, TextEditingControllerWithInitialValue> controllers,
  ) {
    for (final String key in controllers.keys) {
      if (controllers[key]!.valueHasChanged) {
        return true;
      }
    }
    return false;
  }

  bool _isEditedUnits() {
    for (final String tag in _units.keys) {
      if (_initialUnits[tag] != _units[tag]) {
        return true;
      }
    }
    return false;
  }
}

enum NutritionUnit {
  per100g,
  perServing,
}
