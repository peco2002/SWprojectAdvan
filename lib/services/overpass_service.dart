import 'dart:convert';
import 'dart:math' as math;
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

// ─────────────────────────────────────────────────────────────
// 그래프 자료구조
// ─────────────────────────────────────────────────────────────

class OsmNode {
  final String id;
  final double lat;
  final double lon;
  final bool isTrafficSignal;

  const OsmNode({
    required this.id,
    required this.lat,
    required this.lon,
    this.isTrafficSignal = false,
  });
}

class OsmEdge {
  final String toId;
  final double distM;

  const OsmEdge(this.toId, this.distM);
}

class OsmGraph {
  final Map<String, OsmNode> nodes;
  final Map<String, List<OsmEdge>> adj;

  const OsmGraph({required this.nodes, required this.adj});

  bool get isEmpty => nodes.isEmpty;
}

// ─────────────────────────────────────────────────────────────
// 공원/트랙 결과
// ─────────────────────────────────────────────────────────────

class LeisureArea {
  final String name;
  final String type; // 'track' | 'park'
  final LatLng center;
  final double perimeterM;
  final List<LatLng> polygon;

  const LeisureArea({
    required this.name,
    required this.type,
    required this.center,
    required this.perimeterM,
    required this.polygon,
  });
}

// ─────────────────────────────────────────────────────────────
// Overpass API 서비스
// ─────────────────────────────────────────────────────────────

class OverpassService {
  static const _endpoints = [
    'https://overpass-api.de/api/interpreter',
    'https://lz4.overpass-api.de/api/interpreter',
    'https://z.overpass-api.de/api/interpreter',
  ];

  static const _highwayFilter =
      'footway|path|pedestrian|cycleway|living_street';

  static const _headers = {
    'Content-Type': 'application/x-www-form-urlencoded',
    'User-Agent': 'RunRight/1.0 (bjw1055@gmail.com)',
  };

  /// [center] 반경 [radiusM]m 이내 도로 그래프 + 신호등 노드를 쿼리한다.
  static Future<OsmGraph?> queryRoadGraph(LatLng center, double radiusM) async {
    final r = radiusM.clamp(300, 3000).toInt();
    final lat = center.latitude;
    final lon = center.longitude;

    final query = '''
[out:json][timeout:35];
(
  way["highway"~"$_highwayFilter"](around:$r,$lat,$lon);
  node["highway"="traffic_signals"](around:$r,$lat,$lon);
  node["crossing"="traffic_signals"](around:$r,$lat,$lon);
);
out body;
>;
out body;
''';

    for (final endpoint in _endpoints) {
      try {
        final res = await http
            .post(
              Uri.parse(endpoint),
              body: 'data=${Uri.encodeQueryComponent(query)}',
              headers: _headers,
            )
            .timeout(const Duration(seconds: 45));

        if (res.statusCode != 200) continue;
        final graph = _parseRoadGraph(
            jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>);
        if (!graph.isEmpty) return graph;
      } catch (_) {
        continue;
      }
    }
    return null;
  }

  /// 공원 내부 산책로/러닝로 그래프를 쿼리한다.
  static Future<OsmGraph?> queryParkGraph(LatLng center, double radiusM) async {
    final r = radiusM.clamp(100, 1500).toInt();
    final lat = center.latitude;
    final lon = center.longitude;

    final query = '''
[out:json][timeout:30];
(
  way["highway"~"footway|path|pedestrian|cycleway"](around:$r,$lat,$lon);
);
out body;
>;
out body;
''';

    for (final endpoint in _endpoints) {
      try {
        final res = await http
            .post(
              Uri.parse(endpoint),
              body: 'data=${Uri.encodeQueryComponent(query)}',
              headers: _headers,
            )
            .timeout(const Duration(seconds: 35));

        if (res.statusCode != 200) continue;
        final graph = _parseRoadGraph(
            jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>);
        if (!graph.isEmpty) return graph;
      } catch (_) {
        continue;
      }
    }
    return null;
  }

  /// [center] 반경 [radiusM]m 이내 트랙/공원을 쿼리한다.
  static Future<List<LeisureArea>> queryLeisureAreas(
      LatLng center, double radiusM) async {
    final r = radiusM.clamp(300, 3000).toInt();
    final lat = center.latitude;
    final lon = center.longitude;

    final query = '''
[out:json][timeout:25];
(
  way["leisure"="track"](around:$r,$lat,$lon);
  way["sport"="athletics"](around:$r,$lat,$lon);
  way["leisure"="park"](around:$r,$lat,$lon);
  way["landuse"="recreation_ground"](around:$r,$lat,$lon);
);
out geom;
''';

    for (final endpoint in _endpoints) {
      try {
        final res = await http
            .post(
              Uri.parse(endpoint),
              body: 'data=${Uri.encodeQueryComponent(query)}',
              headers: _headers,
            )
            .timeout(const Duration(seconds: 35));

        if (res.statusCode != 200) continue;
        final areas = _parseLeisureAreas(
          jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>,
          center,
        );
        if (areas.isNotEmpty) return areas;
      } catch (_) {
        continue;
      }
    }
    return [];
  }

  // ── 파서: 도로 그래프 ─────────────────────────────────────

  static OsmGraph _parseRoadGraph(Map<String, dynamic> data) {
    final elements = data['elements'] as List<dynamic>;

    final nodes = <String, OsmNode>{};

    // 1단계: 모든 노드 수집 (신호등 태그 포함)
    for (final el in elements) {
      if (el['type'] != 'node') continue;
      final id = el['id'].toString();
      final lat = (el['lat'] as num).toDouble();
      final lon = (el['lon'] as num).toDouble();
      final tags = el['tags'] as Map<String, dynamic>? ?? {};
      final isSignal = tags['highway'] == 'traffic_signals' ||
          tags['crossing'] == 'traffic_signals';
      nodes[id] = OsmNode(id: id, lat: lat, lon: lon, isTrafficSignal: isSignal);
    }

    // 2단계: way의 node 배열로 인접 리스트 구성
    final adj = <String, List<OsmEdge>>{};

    for (final el in elements) {
      if (el['type'] != 'way') continue;
      final wayNodes =
          (el['nodes'] as List<dynamic>).map((n) => n.toString()).toList();

      for (int i = 0; i < wayNodes.length - 1; i++) {
        final a = wayNodes[i];
        final b = wayNodes[i + 1];
        final na = nodes[a];
        final nb = nodes[b];
        if (na == null || nb == null) continue;

        final d = _haversineM(na.lat, na.lon, nb.lat, nb.lon);
        adj.putIfAbsent(a, () => []).add(OsmEdge(b, d));
        adj.putIfAbsent(b, () => []).add(OsmEdge(a, d));
      }
    }

    return OsmGraph(nodes: nodes, adj: adj);
  }

  // ── 파서: 공원/트랙 ───────────────────────────────────────

  static List<LeisureArea> _parseLeisureAreas(
      Map<String, dynamic> data, LatLng center) {
    final elements = data['elements'] as List<dynamic>;
    final results = <LeisureArea>[];

    for (final el in elements) {
      if (el['type'] != 'way') continue;
      final geometry = el['geometry'] as List<dynamic>?;
      if (geometry == null || geometry.length < 3) continue;

      final points = geometry.map((g) {
        return LatLng(
          (g['lat'] as num).toDouble(),
          (g['lon'] as num).toDouble(),
        );
      }).toList();

      // 둘레 계산
      double perimeter = 0;
      for (int i = 0; i < points.length - 1; i++) {
        perimeter += _haversineM(
          points[i].latitude, points[i].longitude,
          points[i + 1].latitude, points[i + 1].longitude,
        );
      }
      if (perimeter < 200) continue;

      final tags = el['tags'] as Map<String, dynamic>? ?? {};
      final leisure = tags['leisure'] as String?;
      final type = leisure == 'track' || tags['sport'] == 'athletics'
          ? 'track'
          : 'park';
      final name = tags['name'] as String? ?? (type == 'track' ? '운동 트랙' : '공원');

      final centerLat =
          points.map((p) => p.latitude).reduce((a, b) => a + b) / points.length;
      final centerLon =
          points.map((p) => p.longitude).reduce((a, b) => a + b) / points.length;

      results.add(LeisureArea(
        name: name,
        type: type,
        center: LatLng(centerLat, centerLon),
        perimeterM: perimeter,
        polygon: points,
      ));
    }

    // 핀에서 가까운 순 정렬
    results.sort((a, b) {
      final da = _haversineM(
          center.latitude, center.longitude, a.center.latitude, a.center.longitude);
      final db = _haversineM(
          center.latitude, center.longitude, b.center.latitude, b.center.longitude);
      return da.compareTo(db);
    });

    return results;
  }

  // ── 유틸 ──────────────────────────────────────────────────

  static double _haversineM(
      double lat1, double lon1, double lat2, double lon2) {
    const r = 6371000.0;
    final phi1 = lat1 * math.pi / 180;
    final phi2 = lat2 * math.pi / 180;
    final dphi = (lat2 - lat1) * math.pi / 180;
    final dlambda = (lon2 - lon1) * math.pi / 180;
    final a = math.sin(dphi / 2) * math.sin(dphi / 2) +
        math.cos(phi1) *
            math.cos(phi2) *
            math.sin(dlambda / 2) *
            math.sin(dlambda / 2);
    return r * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  }
}
