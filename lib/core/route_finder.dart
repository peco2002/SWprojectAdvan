import 'dart:math' as math;
import 'package:latlong2/latlong.dart';
import '../services/overpass_service.dart';

const _kSignalPenaltyM = 150.0;

// ─────────────────────────────────────────────────────────────
// 결과 모델
// ─────────────────────────────────────────────────────────────

class RouteResult {
  final List<LatLng> points;
  final double distanceM;
  final int signalCount;

  const RouteResult({
    required this.points,
    required this.distanceM,
    required this.signalCount,
  });

  double get distanceKm => distanceM / 1000;
}

// ─────────────────────────────────────────────────────────────
// 경로 탐색기
// ─────────────────────────────────────────────────────────────

class RouteFinder {
  /// [start]를 기준으로 [targetDistanceM] 길이의 순환 경로를 반환한다.
  ///
  /// 방향성 그리디 보행(80%)으로 자연스러운 루프를 형성한 뒤
  /// 다익스트라로 출발점에 귀환한다. 3방향(시계/반시계/대각)을 시도한다.
  static RouteResult? findLoopRoute(
      OsmGraph graph, LatLng start, double targetDistanceM) {
    if (graph.isEmpty) return null;

    final startId = _nearestNode(graph, start);
    if (startId == null) return null;

    // 시계방향 / 반시계방향 / 45° 오프셋 순으로 시도
    const offsets = [90.0, -90.0, 135.0];
    for (final offset in offsets) {
      final result =
          _greedyLoop(graph, startId, start, targetDistanceM, offset);
      if (result != null) return result;
    }
    return null;
  }

  // ── 방향성 그리디 보행 + 다익스트라 귀환 ────────────────────

  static RouteResult? _greedyLoop(OsmGraph graph, String startId, LatLng start,
      double targetM, double rotationOffset) {
    final visited = <String>{startId};
    final pathIds = <String>[startId];
    double dist = 0;
    String current = startId;

    // Phase 1: 목표거리의 80%까지 방향성 그리디 보행
    while (dist < targetM * 0.80) {
      final cn = graph.nodes[current]!;
      final currentPos = LatLng(cn.lat, cn.lon);

      // 이상적 방위: 출발점→현재 방위에 rotationOffset을 더해 원형 운동 유도
      final toCurrentBearing = _bearingBetween(start, currentPos);
      final idealBearing = (toCurrentBearing + rotationOffset) % 360;

      // 미방문 이웃 노드만 후보로
      final edges = (graph.adj[current] ?? [])
          .where((e) => !visited.contains(e.toId))
          .toList();

      if (edges.isEmpty) break; // 막힌 경우 Phase 1 조기 종료

      // 이상적 방위에 가장 가까운 엣지 선택
      edges.sort((a, b) {
        final na = graph.nodes[a.toId]!;
        final nb = graph.nodes[b.toId]!;
        final ba = _bearingBetween(currentPos, LatLng(na.lat, na.lon));
        final bb = _bearingBetween(currentPos, LatLng(nb.lat, nb.lon));
        return _angularDiff(ba, idealBearing)
            .compareTo(_angularDiff(bb, idealBearing));
      });

      final next = edges.first;
      visited.add(next.toId);
      pathIds.add(next.toId);
      dist += next.distM;
      current = next.toId;
    }

    // 그리디 보행이 전혀 진행되지 않으면 이 방향 포기
    if (pathIds.length < 2) return null;

    // Phase 2: 현재 위치에서 출발점으로 다익스트라 귀환
    final returnSeg = _dijkstra(graph, current, startId);
    if (returnSeg == null) return null;

    final totalDist = dist + returnSeg.realDistM;
    // 목표 거리의 15% 미만이면 유효하지 않은 루프로 간주
    if (totalDist < targetM * 0.15) return null;

    // 경로 합성
    final allPoints = <LatLng>[];
    int signals = 0;

    for (final id in pathIds) {
      final n = graph.nodes[id]!;
      allPoints.add(LatLng(n.lat, n.lon));
      if (n.isTrafficSignal) signals++;
    }
    for (final id in returnSeg.path.skip(1)) {
      final n = graph.nodes[id]!;
      allPoints.add(LatLng(n.lat, n.lon));
      if (n.isTrafficSignal) signals++;
    }

    if (allPoints.length < 3) return null;

    return RouteResult(
      points: allPoints,
      distanceM: totalDist,
      signalCount: signals,
    );
  }

  // ── 폴리곤 내부로 그래프 필터링 ──────────────────────────────

  /// [polygon] 내부 노드만 남긴 새 그래프를 반환한다.
  static OsmGraph filterToPolygon(OsmGraph graph, List<LatLng> polygon) {
    if (polygon.length < 3) return graph;

    final validIds = graph.nodes.entries
        .where((e) =>
            _pointInPolygon(LatLng(e.value.lat, e.value.lon), polygon))
        .map((e) => e.key)
        .toSet();

    final filteredNodes = Map<String, OsmNode>.fromEntries(
      graph.nodes.entries.where((e) => validIds.contains(e.key)),
    );
    final filteredAdj = <String, List<OsmEdge>>{};
    for (final id in validIds) {
      final edges = (graph.adj[id] ?? [])
          .where((e) => validIds.contains(e.toId))
          .toList();
      if (edges.isNotEmpty) filteredAdj[id] = edges;
    }

    return OsmGraph(nodes: filteredNodes, adj: filteredAdj);
  }

  // ── 다익스트라 (귀환 경로용) ──────────────────────────────────

  static _DijkResult? _dijkstra(OsmGraph graph, String from, String to) {
    final costMap = <String, double>{};
    final realMap = <String, double>{};
    final prev = <String, String?>{};
    final pq = _MinHeap();

    costMap[from] = 0;
    realMap[from] = 0;
    pq.push(from, 0);

    while (!pq.isEmpty) {
      final curr = pq.pop();
      if (curr.id == to) break;
      if (curr.cost > (costMap[curr.id] ?? double.infinity)) continue;

      for (final edge in (graph.adj[curr.id] ?? [])) {
        final penalty = graph.nodes[edge.toId]?.isTrafficSignal == true
            ? _kSignalPenaltyM
            : 0.0;
        final newCost = curr.cost + edge.distM + penalty;
        final newReal = (realMap[curr.id] ?? 0) + edge.distM;

        if (newCost < (costMap[edge.toId] ?? double.infinity)) {
          costMap[edge.toId] = newCost;
          realMap[edge.toId] = newReal;
          prev[edge.toId] = curr.id;
          pq.push(edge.toId, newCost);
        }
      }
    }

    if (!costMap.containsKey(to)) return null;

    final path = <String>[];
    String? cur = to;
    while (cur != null) {
      path.add(cur);
      cur = prev[cur];
    }
    return _DijkResult(path.reversed.toList(), realMap[to] ?? 0);
  }

  // ── 유틸 ──────────────────────────────────────────────────

  static String? _nearestNode(OsmGraph graph, LatLng point) {
    String? best;
    double bestDist = double.infinity;
    for (final node in graph.nodes.values) {
      // 엣지가 없는 고립 노드(신호등 등)는 제외
      if ((graph.adj[node.id] ?? []).isEmpty) continue;
      final d = _haversineM(point.latitude, point.longitude, node.lat, node.lon);
      if (d < bestDist) {
        bestDist = d;
        best = node.id;
      }
    }
    return best;
  }

  /// 두 지점 간의 방위각(0~360°)을 계산한다.
  static double _bearingBetween(LatLng from, LatLng to) {
    final lat1 = from.latitude * math.pi / 180;
    final lat2 = to.latitude * math.pi / 180;
    final dLon = (to.longitude - from.longitude) * math.pi / 180;
    final y = math.sin(dLon) * math.cos(lat2);
    final x = math.cos(lat1) * math.sin(lat2) -
        math.sin(lat1) * math.cos(lat2) * math.cos(dLon);
    return (math.atan2(y, x) * 180 / math.pi + 360) % 360;
  }

  /// 두 방위각의 절댓값 차이(0~180°)를 반환한다.
  static double _angularDiff(double a, double b) {
    final diff = ((a - b + 540) % 360) - 180;
    return diff.abs();
  }

  /// Ray-casting 알고리즘으로 point-in-polygon 판정.
  static bool _pointInPolygon(LatLng p, List<LatLng> polygon) {
    int crossings = 0;
    for (int i = 0; i < polygon.length; i++) {
      final a = polygon[i];
      final b = polygon[(i + 1) % polygon.length];
      if ((a.latitude <= p.latitude && p.latitude < b.latitude) ||
          (b.latitude <= p.latitude && p.latitude < a.latitude)) {
        final t = (p.latitude - a.latitude) / (b.latitude - a.latitude);
        if (p.longitude < a.longitude + t * (b.longitude - a.longitude)) {
          crossings++;
        }
      }
    }
    return crossings % 2 == 1;
  }

  static double _haversineM(
      double lat1, double lon1, double lat2, double lon2) {
    const r = 6371000.0;
    final dphi = (lat2 - lat1) * math.pi / 180;
    final dlambda = (lon2 - lon1) * math.pi / 180;
    final phi1 = lat1 * math.pi / 180;
    final phi2 = lat2 * math.pi / 180;
    final a = math.sin(dphi / 2) * math.sin(dphi / 2) +
        math.cos(phi1) *
            math.cos(phi2) *
            math.sin(dlambda / 2) *
            math.sin(dlambda / 2);
    return r * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  }
}

// ─────────────────────────────────────────────────────────────
// 내부 자료구조
// ─────────────────────────────────────────────────────────────

class _DijkResult {
  final List<String> path;
  final double realDistM;
  const _DijkResult(this.path, this.realDistM);
}

class _HeapNode {
  final String id;
  final double cost;
  const _HeapNode(this.id, this.cost);
}

class _MinHeap {
  final _data = <_HeapNode>[];

  bool get isEmpty => _data.isEmpty;

  void push(String id, double cost) {
    _data.add(_HeapNode(id, cost));
    _bubbleUp(_data.length - 1);
  }

  _HeapNode pop() {
    if (_data.length == 1) return _data.removeLast();
    final min = _data[0];
    _data[0] = _data.removeLast();
    _siftDown(0);
    return min;
  }

  void _bubbleUp(int i) {
    while (i > 0) {
      final p = (i - 1) ~/ 2;
      if (_data[p].cost <= _data[i].cost) break;
      final tmp = _data[p];
      _data[p] = _data[i];
      _data[i] = tmp;
      i = p;
    }
  }

  void _siftDown(int i) {
    final n = _data.length;
    while (true) {
      final l = 2 * i + 1;
      final r = 2 * i + 2;
      int s = i;
      if (l < n && _data[l].cost < _data[s].cost) s = l;
      if (r < n && _data[r].cost < _data[s].cost) s = r;
      if (s == i) break;
      final tmp = _data[s];
      _data[s] = _data[i];
      _data[i] = tmp;
      i = s;
    }
  }
}
