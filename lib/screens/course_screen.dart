import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import '../core/constants.dart';
import '../core/route_finder.dart';
import '../services/nominatim_service.dart';
import '../services/overpass_service.dart';

class CourseScreen extends StatefulWidget {
  final bool isActive;
  const CourseScreen({super.key, this.isActive = false});

  @override
  State<CourseScreen> createState() => _CourseScreenState();
}

class _CourseScreenState extends State<CourseScreen> {
  // 지도
  final _mapController = MapController();
  LatLng _pinLocation = const LatLng(37.5665, 126.9780);

  // 핀 드래그
  bool _isPinDragging = false;
  Offset? _dragStart;
  LatLng? _pinAtDragStart;

  // 검색
  final _searchCtrl = TextEditingController();
  bool _isSearching = false;

  // 경로 결과
  List<LatLng> _routePoints = [];
  RouteResult? _routeResult;
  LeisureArea? _leisureResult;

  // UI 상태
  bool _isLoading = false;
  String? _errorMsg;
  bool _gpsInitialized = false;

  @override
  void initState() {
    super.initState();
  }

  @override
  void didUpdateWidget(CourseScreen old) {
    super.didUpdateWidget(old);
    if (widget.isActive && !old.isActive && !_gpsInitialized) {
      _gpsInitialized = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _moveToCurrentLocation(moveMap: false);
      });
    }
  }

  @override
  void dispose() {
    _mapController.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  // ── GPS ──────────────────────────────────────────────────────

  Future<void> _moveToCurrentLocation({bool moveMap = true}) async {
    try {
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        return;
      }

      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      ).timeout(const Duration(seconds: 10));

      final latLng = LatLng(pos.latitude, pos.longitude);
      setState(() => _pinLocation = latLng);
      if (moveMap) _mapController.move(latLng, 15.0);
    } catch (_) {
      // 위치 오류 시 기본값 유지
    }
  }

  // ── 주소 검색 ────────────────────────────────────────────────

  Future<void> _onSearch(String query) async {
    if (query.trim().isEmpty) return;
    setState(() => _isSearching = true);

    final result = await NominatimService.search(query.trim());
    setState(() => _isSearching = false);

    if (!mounted) return;
    if (result != null) {
      setState(() => _pinLocation = result);
      _mapController.move(result, 15.0);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('주소를 찾을 수 없습니다.'),
          backgroundColor: AppColors.card,
        ),
      );
    }
  }

  // ── 코스 추천 다이얼로그 ──────────────────────────────────────

  Future<void> _showCourseDialog() async {
    double selectedKm = 5.0;
    String selectedType = 'city'; // 'city' | 'leisure'

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialog) => AlertDialog(
          backgroundColor: AppColors.surface,
          title: const Text(
            '러닝 코스 추천',
            style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 17,
                fontWeight: FontWeight.bold),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '목표 거리: ${selectedKm.toStringAsFixed(0)} km',
                style: const TextStyle(
                    color: AppColors.textPrimary, fontSize: 14),
              ),
              Slider(
                value: selectedKm,
                min: 1,
                max: 20,
                divisions: 19,
                activeColor: AppColors.primary,
                inactiveColor: AppColors.divider,
                label: '${selectedKm.toStringAsFixed(0)} km',
                onChanged: (v) => setDialog(() => selectedKm = v),
              ),
              const SizedBox(height: 8),
              const Text(
                '코스 유형',
                style:
                    TextStyle(color: AppColors.textSecondary, fontSize: 13),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _dialogButton(
                      icon: Icons.location_city,
                      label: '시티런',
                      selected: selectedType == 'city',
                      onTap: () => setDialog(() => selectedType = 'city'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _dialogButton(
                      icon: Icons.park,
                      label: '트랙·공원',
                      selected: selectedType == 'leisure',
                      onTap: () => setDialog(() => selectedType = 'leisure'),
                    ),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.black),
              onPressed: () {
                Navigator.pop(ctx);
                if (selectedType == 'city') {
                  _generateCityRun(selectedKm * 1000);
                } else {
                  _findLeisureRoute();
                }
              },
              child: const Text('확인',
                  style: TextStyle(fontWeight: FontWeight.bold)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('취소',
                  style: TextStyle(color: AppColors.textHint)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _dialogButton({
    required IconData icon,
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return ElevatedButton.icon(
      icon: Icon(icon, size: 16),
      label: Text(label, style: const TextStyle(fontSize: 13)),
      style: ElevatedButton.styleFrom(
        backgroundColor: selected ? AppColors.primary : AppColors.card,
        foregroundColor: selected ? Colors.black : AppColors.textPrimary,
        padding: const EdgeInsets.symmetric(vertical: 10),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: selected
              ? BorderSide.none
              : const BorderSide(color: AppColors.divider),
        ),
        elevation: 0,
      ),
      onPressed: onTap,
    );
  }

  // ── 시티런 경로 생성 ──────────────────────────────────────────

  Future<void> _generateCityRun(double targetM) async {
    _clearResults();
    setState(() => _isLoading = true);

    // 쿼리 반경: 순환 반경의 1.5배
    final radiusM = (targetM / (2 * math.pi) * 1.5).clamp(400.0, 2500.0);

    final graph =
        await OverpassService.queryRoadGraph(_pinLocation, radiusM);

    if (graph == null || graph.isEmpty) {
      setState(() {
        _isLoading = false;
        _errorMsg = '도로 데이터를 불러오지 못했습니다. 잠시 후 다시 시도해주세요.';
      });
      return;
    }

    final result = RouteFinder.findLoopRoute(graph, _pinLocation, targetM);

    setState(() {
      _isLoading = false;
      if (result != null) {
        _routePoints = result.points;
        _routeResult = result;
        _mapController.move(_pinLocation, 14.5);
      } else {
        _errorMsg = '이 위치에서 적합한 순환 경로를 찾지 못했습니다.';
      }
    });
  }

  // ── 트랙·공원 경로 찾기 ───────────────────────────────────────

  Future<void> _findLeisureRoute() async {
    _clearResults();
    setState(() => _isLoading = true);

    final areas = await OverpassService.queryLeisureAreas(_pinLocation, 2000);

    if (areas.isEmpty) {
      setState(() {
        _isLoading = false;
        _errorMsg = '반경 2km 내에 트랙이나 공원이 없습니다.';
      });
      return;
    }

    final area = areas.first;

    // 육상 트랙: 경계선이 곧 러닝 경로
    if (area.type == 'track') {
      setState(() {
        _isLoading = false;
        _leisureResult = area;
        _routePoints = area.polygon;
        _mapController.move(area.center, 16.0);
      });
      return;
    }

    // 공원: 내부 산책로/러닝로 쿼리 → 폴리곤 내부로 필터 → 루프 생성
    final searchRadius =
        (area.perimeterM / (2 * math.pi) * 1.2).clamp(150.0, 1500.0);
    final rawGraph =
        await OverpassService.queryParkGraph(area.center, searchRadius);

    if (rawGraph != null && !rawGraph.isEmpty) {
      final graph = RouteFinder.filterToPolygon(rawGraph, area.polygon);
      if (!graph.isEmpty) {
        final result =
            RouteFinder.findLoopRoute(graph, area.center, area.perimeterM);
        if (result != null) {
          setState(() {
            _isLoading = false;
            _leisureResult = area;
            _routePoints = result.points;
            _mapController.move(area.center, 16.0);
          });
          return;
        }
      }
    }

    // 폴백: 내부 경로 데이터 없으면 공원 외곽선
    setState(() {
      _isLoading = false;
      _leisureResult = area;
      _routePoints = area.polygon;
      _mapController.move(area.center, 16.0);
    });
  }

  void _clearResults() {
    setState(() {
      _routePoints = [];
      _routeResult = null;
      _leisureResult = null;
      _errorMsg = null;
    });
  }

  // ── 빌드 ───────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (!widget.isActive) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: SizedBox.shrink(),
      );
    }
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          _buildMap(),
          _buildSearchBar(),
          _buildZoomButtons(),
          _buildGpsButton(),
          _buildCourseButton(),
          if (_routeResult != null) _buildRouteInfoCard(),
          if (_leisureResult != null) _buildLeisureInfoCard(),
          if (_errorMsg != null) _buildErrorBanner(),
          if (_isLoading) _buildLoadingOverlay(),
        ],
      ),
    );
  }

  // ── 지도 위젯 ────────────────────────────────────────────────

  Widget _buildMap() {
    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: _pinLocation,
        initialZoom: 15.0,
        interactionOptions: InteractionOptions(
          flags: _isPinDragging
              ? InteractiveFlag.none
              : InteractiveFlag.all,
        ),
        onTap: (_, latLng) => setState(() => _pinLocation = latLng),
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.runright.app',
          maxZoom: 19,
        ),
        if (_routePoints.isNotEmpty)
          PolylineLayer(
            polylines: [
              Polyline(
                points: _routePoints,
                color: AppColors.primary,
                strokeWidth: 4.5,
                borderColor: Colors.black26,
                borderStrokeWidth: 1.0,
              ),
            ],
          ),
        MarkerLayer(
          markers: [
            Marker(
              point: _pinLocation,
              width: 48,
              height: 56,
              alignment: Alignment.bottomCenter,
              child: _buildDraggablePin(),
            ),
          ],
        ),
        const SimpleAttributionWidget(
          source: Text('© OpenStreetMap contributors',
              style: TextStyle(fontSize: 10)),
        ),
      ],
    );
  }

  // ── 드래그 가능 핀 ────────────────────────────────────────────

  Widget _buildDraggablePin() {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onPanStart: (details) {
        _dragStart = details.globalPosition;
        _pinAtDragStart = _pinLocation;
        setState(() => _isPinDragging = true);
      },
      onPanUpdate: (details) {
        if (!_isPinDragging || _dragStart == null || _pinAtDragStart == null) {
          return;
        }
        final delta = details.globalPosition - _dragStart!;
        final camera = _mapController.camera;
        final startPt = camera.latLngToScreenPoint(_pinAtDragStart!);
        final newPt = math.Point<double>(
          startPt.x + delta.dx,
          startPt.y + delta.dy,
        );
        final newLatLng = camera.pointToLatLng(newPt);
        setState(() => _pinLocation = newLatLng);
      },
      onPanEnd: (_) {
        setState(() {
          _isPinDragging = false;
          _dragStart = null;
          _pinAtDragStart = null;
        });
      },
      child: const Icon(
        Icons.location_pin,
        size: 48,
        color: AppColors.primary,
      ),
    );
  }

  // ── 검색바 ───────────────────────────────────────────────────

  Widget _buildSearchBar() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
        child: Material(
          elevation: 4,
          borderRadius: BorderRadius.circular(12),
          color: AppColors.surface,
          child: TextField(
            controller: _searchCtrl,
            style:
                const TextStyle(color: AppColors.textPrimary, fontSize: 14),
            decoration: InputDecoration(
              hintText: '주소 검색',
              hintStyle:
                  const TextStyle(color: AppColors.textHint, fontSize: 14),
              prefixIcon: _isSearching
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: AppColors.primary),
                      ),
                    )
                  : const Icon(Icons.search,
                      color: AppColors.textSecondary, size: 22),
              suffixIcon: _searchCtrl.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear,
                          color: AppColors.textHint, size: 18),
                      onPressed: () {
                        _searchCtrl.clear();
                        setState(() {});
                      },
                    )
                  : null,
              border: InputBorder.none,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 4, vertical: 14),
            ),
            textInputAction: TextInputAction.search,
            onSubmitted: _onSearch,
            onChanged: (_) => setState(() {}),
          ),
        ),
      ),
    );
  }

  // ── 줌 버튼 ─────────────────────────────────────────────────

  Widget _buildZoomButtons() {
    return Positioned(
      right: 12,
      bottom: 196,
      child: Column(
        children: [
          _zoomButton(Icons.add, () {
            final z = (_mapController.camera.zoom + 1).clamp(3.0, 19.0);
            _mapController.move(_mapController.camera.center, z);
          }),
          const SizedBox(height: 4),
          _zoomButton(Icons.remove, () {
            final z = (_mapController.camera.zoom - 1).clamp(3.0, 19.0);
            _mapController.move(_mapController.camera.center, z);
          }),
        ],
      ),
    );
  }

  Widget _zoomButton(IconData icon, VoidCallback onTap) {
    return Material(
      color: AppColors.surface,
      elevation: 4,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: SizedBox(
          width: 36,
          height: 36,
          child: Icon(icon, color: AppColors.textPrimary, size: 20),
        ),
      ),
    );
  }

  // ── GPS 버튼 ────────────────────────────────────────────────

  Widget _buildGpsButton() {
    return Positioned(
      right: 12,
      bottom: 100,
      child: FloatingActionButton.small(
        heroTag: 'gps_course',
        backgroundColor: AppColors.surface,
        elevation: 4,
        onPressed: () => _moveToCurrentLocation(),
        child: const Icon(Icons.my_location, color: AppColors.primary),
      ),
    );
  }

  // ── 코스 추천 버튼 ────────────────────────────────────────────

  Widget _buildCourseButton() {
    return Positioned(
      left: 16,
      right: 16,
      bottom: 24,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.black,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 4,
        ),
        onPressed: _showCourseDialog,
        child: const Text(
          '현재 위치로 러닝 코스 추천',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  // ── 시티런 결과 카드 ──────────────────────────────────────────

  Widget _buildRouteInfoCard() {
    final r = _routeResult!;
    final km = r.distanceKm.toStringAsFixed(1);
    final estimatedMin = (r.distanceKm * 6).round();

    return _infoCard(
      title: '시티런 코스 • $km km',
      subtitle: '신호등 ${r.signalCount}개 통과 • 약 $estimatedMin분 예상 (6분/km 기준)',
      icon: Icons.directions_run,
      onClose: () => setState(() {
        _routeResult = null;
        _routePoints = [];
      }),
    );
  }

  // ── 트랙·공원 결과 카드 ───────────────────────────────────────

  Widget _buildLeisureInfoCard() {
    final a = _leisureResult!;
    final lapKm = (a.perimeterM / 1000).toStringAsFixed(2);
    final typeLabel = a.type == 'track' ? '🏟 트랙' : '🌳 공원';

    return _infoCard(
      title: '${a.name} ($typeLabel)',
      subtitle: '한 바퀴 $lapKm km',
      icon: a.type == 'track' ? Icons.sports_score : Icons.park,
      onClose: () => setState(() {
        _leisureResult = null;
        _routePoints = [];
      }),
    );
  }

  // ── 공통 정보 카드 ────────────────────────────────────────────

  Widget _infoCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required VoidCallback onClose,
  }) {
    return Positioned(
      left: 12,
      right: 12,
      top: 76,
      child: Material(
        elevation: 4,
        borderRadius: BorderRadius.circular(12),
        color: AppColors.surface,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
          child: Row(
            children: [
              Icon(icon, color: AppColors.primary, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(title,
                        style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.bold,
                            fontSize: 14)),
                    const SizedBox(height: 2),
                    Text(subtitle,
                        style: const TextStyle(
                            color: AppColors.textSecondary, fontSize: 12)),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close,
                    color: AppColors.textHint, size: 18),
                onPressed: onClose,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── 에러 배너 ────────────────────────────────────────────────

  Widget _buildErrorBanner() {
    return Positioned(
      left: 12,
      right: 12,
      top: 76,
      child: Material(
        elevation: 4,
        borderRadius: BorderRadius.circular(12),
        color: AppColors.card,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
          child: Row(
            children: [
              const Icon(Icons.warning_amber_rounded,
                  color: Colors.orange, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _errorMsg!,
                  style: const TextStyle(
                      color: AppColors.textPrimary, fontSize: 13),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close,
                    color: AppColors.textHint, size: 18),
                onPressed: () => setState(() => _errorMsg = null),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── 로딩 오버레이 ─────────────────────────────────────────────

  Widget _buildLoadingOverlay() {
    return Container(
      color: Colors.black54,
      child: const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: AppColors.primary),
            SizedBox(height: 16),
            Text(
              '경로를 탐색 중입니다...',
              style: TextStyle(color: Colors.white, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }
}
