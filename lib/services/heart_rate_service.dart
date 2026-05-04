// lib/services/heart_rate_service.dart
// Health Connect에서 심박수 데이터를 읽어오는 서비스

import 'package:health/health.dart';

class HeartRateService {
  static final _health = Health();
  static const _types = [HealthDataType.HEART_RATE];

  // 실제 권한 여부 확인 (requestAuthorization과 별개)
  static Future<bool?> hasPermission() async {
    try {
      return await _health.hasPermissions(
        _types,
        permissions: [HealthDataAccess.READ],
      );
    } catch (_) {
      return null;
    }
  }

  // 러닝 시작 시 권한 요청 (한 번만 표시됨)
  static Future<bool> requestPermission() async {
    try {
      return await _health.requestAuthorization(
        _types,
        permissions: [HealthDataAccess.READ],
      );
    } catch (_) {
      return false;
    }
  }

  // 러닝 종료 시 해당 시간대의 평균 심박수 반환
  // Health Connect에 데이터 없거나 권한 없으면 null 반환
  static Future<int?> getAverageHeartRate(
      DateTime startTime, DateTime endTime) async {
    try {
      final points = await getHeartRatePoints(startTime, endTime);
      if (points.isEmpty) return null;
      return points.map((p) => p.bpm).reduce((a, b) => a + b) ~/
          points.length;
    } catch (_) {
      return null;
    }
  }

  // 시간대별 심박수 시계열 반환 (그래프용)
  static Future<List<({DateTime timestamp, int bpm})>> getHeartRatePoints(
      DateTime startTime, DateTime endTime) async {
    try {
      final data = await _health.getHealthDataFromTypes(
        types: _types,
        startTime: startTime,
        endTime: endTime,
      );
      final points = data
          .where((d) => d.type == HealthDataType.HEART_RATE)
          .map((d) => (
                timestamp: d.dateFrom,
                bpm: (d.value as NumericHealthValue).numericValue.toInt(),
              ))
          .where((p) => p.bpm > 0)
          .toList()
        ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
      return points;
    } catch (_) {
      return [];
    }
  }

  // 디버그용 – 예외를 삼키지 않고 중간 결과와 함께 반환
  // returns (points, diagnosticLog)
  static Future<(List<({DateTime timestamp, int bpm})>, String)>
      getHeartRatePointsDebug(DateTime startTime, DateTime endTime) async {
    final log = StringBuffer();
    try {
      final hasPerm = await _health.hasPermissions(
        _types,
        permissions: [HealthDataAccess.READ],
      );
      log.writeln('hasPermissions: $hasPerm');

      final data = await _health.getHealthDataFromTypes(
        types: _types,
        startTime: startTime,
        endTime: endTime,
      );
      log.writeln('raw count: ${data.length}');

      final hrData =
          data.where((d) => d.type == HealthDataType.HEART_RATE).toList();
      log.writeln('HR type count: ${hrData.length}');

      if (hrData.isNotEmpty) {
        final f = hrData.first;
        log.writeln(
            'first: ${f.dateFrom.hour}:${f.dateFrom.minute.toString().padLeft(2, '0')} '
            'val=${f.value} type=${f.value.runtimeType}');
      }

      final points = hrData
          .map((d) => (
                timestamp: d.dateFrom,
                bpm: (d.value as NumericHealthValue).numericValue.toInt(),
              ))
          .where((p) => p.bpm > 0)
          .toList()
        ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

      log.writeln('filtered count: ${points.length}');
      return (points, log.toString());
    } catch (e, st) {
      log.writeln('EXCEPTION: $e');
      log.writeln(st.toString().split('\n').take(4).join('\n'));
      return (<({DateTime timestamp, int bpm})>[], log.toString());
    }
  }
}
