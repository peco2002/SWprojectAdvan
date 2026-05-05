// lib/services/tcx_share_service.dart
import 'package:flutter/services.dart';
import '../core/tcx_parser.dart';

class TcxShareService {
  static const _channel =
      MethodChannel('com.example.runright_app/tcx_share');

  /// 네이티브에서 대기 중인 공유 파일을 읽어 TcxData(bpm, startTime)를 반환한다.
  /// 공유 파일이 없거나 심박수 데이터가 없으면 null 반환.
  static Future<TcxData?> getPendingData() async {
    try {
      final bytes =
          await _channel.invokeMethod<Uint8List>('getPendingSharedFile');
      if (bytes == null || bytes.isEmpty) return null;
      final data = TcxParser.parse(bytes);
      if (data.bpm == null) return null;
      return data;
    } catch (_) {
      return null;
    }
  }
}
