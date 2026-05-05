// lib/core/tcx_parser.dart
import 'dart:convert';

class TcxData {
  final int? bpm;
  final DateTime? startTime; // 로컬 시간 (Mi Fitness가 로컬 시간에 Z를 잘못 붙임)
  TcxData({this.bpm, this.startTime});
}

class TcxParser {
  /// TCX 전체 파싱: 평균 심박수 + 운동 시작 시간(UTC)
  static TcxData parse(List<int> bytes) {
    final content = utf8.decode(bytes, allowMalformed: true);

    final bpmMatch =
        RegExp(r'<HeartRateBpm>(\d+)</HeartRateBpm>').firstMatch(content);
    final bpm =
        bpmMatch != null ? int.tryParse(bpmMatch.group(1)!) : null;

    final idMatch = RegExp(r'<Id>([^<]+)</Id>').firstMatch(content);
    DateTime? startTime;
    if (idMatch != null) {
      // Mi Fitness가 로컬 시간에 Z suffix를 잘못 붙이므로 Z를 제거해 로컬로 파싱
      final raw = idMatch.group(1)!.trim().replaceFirst('Z', '');
      startTime = DateTime.tryParse(raw);
    }

    return TcxData(bpm: bpm, startTime: startTime);
  }

  /// 하위 호환 – 평균 심박수만 필요한 경우 (result/session_detail 화면용)
  static int? parseAverageHeartRate(List<int> bytes) => parse(bytes).bpm;
}
