// TFLite 추론 서비스
// 입력: [나이, 성별_encoded(M=0/F=1), 신장_cm, 체중_kg, 체지방율?]
// 출력: VO2max (ml/kg/min)

import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:tflite_flutter/tflite_flutter.dart';

class VO2maxModel {
  VO2maxModel._();
  static final VO2maxModel instance = VO2maxModel._();

  bool _ready = false;
  bool get isReady => _ready;

  Interpreter? _interpreter;
  late List<double> _mean;
  late List<double> _std;
  late List<String> _featureNames;

  Future<void> initialize() async {
    if (_ready) return;
    try {
      final normJson = await rootBundle.loadString('assets/norm_params.json');
      final norm = jsonDecode(normJson) as Map<String, dynamic>;
      _featureNames = List<String>.from(norm['feature_names'] as List);
      _mean = List<double>.from((norm['mean'] as List).map((e) => (e as num).toDouble()));
      _std  = List<double>.from((norm['std']  as List).map((e) => (e as num).toDouble()));

      _interpreter = await Interpreter.fromAsset('assets/vo2max_model.tflite');
      _ready = true;
    } catch (_) {
      _ready = false;
    }
  }

  /// VO2max 예측 (ml/kg/min). 모델 미로드 시 null 반환.
  double? predict({
    required double age,
    required double genderEncoded,
    required double heightCm,
    required double weightKg,
    double? bodyFatPercent,
  }) {
    if (!_ready || _interpreter == null) return null;

    final hasBodyFat = _featureNames.contains('체지방율') && bodyFatPercent != null;
    final raw = hasBodyFat
        ? [age, genderEncoded, heightCm, weightKg, bodyFatPercent!]
        : [age, genderEncoded, heightCm, weightKg];

    if (raw.length != _mean.length) return null;

    final normalized = List<double>.generate(
      raw.length, (i) => (raw[i] - _mean[i]) / _std[i],
    );

    final input  = [normalized];                     // shape: [1, numFeatures]
    final output = [List<double>.filled(1, 0.0)];    // shape: [1, 1]

    _interpreter!.run(input, output);

    return output[0][0].clamp(15.0, 70.0);
  }
}
