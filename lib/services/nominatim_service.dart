import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

class NominatimService {
  static Future<LatLng?> search(String query) async {
    final uri = Uri.https('nominatim.openstreetmap.org', '/search', {
      'q': query,
      'format': 'json',
      'limit': '1',
    });

    try {
      final res = await http.get(uri, headers: {
        'User-Agent': 'RunRight/1.0 (bjw1055@gmail.com)',
        'Accept-Language': 'ko,en',
      }).timeout(const Duration(seconds: 10));

      if (res.statusCode != 200) return null;
      final list = jsonDecode(res.body) as List<dynamic>;
      if (list.isEmpty) return null;

      final lat = double.tryParse(list[0]['lat'] as String);
      final lon = double.tryParse(list[0]['lon'] as String);
      if (lat == null || lon == null) return null;

      return LatLng(lat, lon);
    } catch (_) {
      return null;
    }
  }
}
