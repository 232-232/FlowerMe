import 'dart:convert';

import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;

// ─────────────────────────────────────────────────────────────────────────────
//  API key
//  Replace with your real Google Cloud API key.
//  Required APIs to enable in Google Cloud Console:
//    • Maps SDK for Android
//    • Maps SDK for iOS
//    • Places API
//    • Geocoding API
// ─────────────────────────────────────────────────────────────────────────────

const String kGoogleApiKey = 'YOUR_GOOGLE_API_KEY';

// ─────────────────────────────────────────────────────────────────────────────
//  Model
// ─────────────────────────────────────────────────────────────────────────────

class PlaceSuggestion {
  const PlaceSuggestion({
    required this.placeId,
    required this.mainText,
    required this.secondaryText,
  });

  final String placeId;
  final String mainText;
  final String secondaryText;

  String get fullText =>
      secondaryText.isNotEmpty ? '$mainText, $secondaryText' : mainText;
}

// ─────────────────────────────────────────────────────────────────────────────
//  Service
// ─────────────────────────────────────────────────────────────────────────────

class PlacesService {
  static const String _autocompleteUrl =
      'https://maps.googleapis.com/maps/api/place/autocomplete/json';
  static const String _detailsUrl =
      'https://maps.googleapis.com/maps/api/place/details/json';

  /// Fetches autocomplete suggestions from Google Places API.
  ///
  /// [sessionToken] groups queries for billing; generate one UUID per
  /// search session, reset after a [getDetails] call.
  static Future<List<PlaceSuggestion>> autocomplete(
    String input, {
    String? sessionToken,
  }) async {
    if (input.trim().isEmpty) return [];
    try {
      final params = <String, String>{
        'input': input.trim(),
        'key': kGoogleApiKey,
        'types': 'geocode',
      };
      if (sessionToken != null) params['sessiontoken'] = sessionToken;
      final uri = Uri.parse(_autocompleteUrl).replace(queryParameters: params);
      final response =
          await http.get(uri).timeout(const Duration(seconds: 8));
      if (response.statusCode != 200) return [];
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      if (data['status'] != 'OK') return [];
      final predictions = data['predictions'] as List<dynamic>;
      return predictions.map((raw) {
        final map = raw as Map<String, dynamic>;
        final sf = map['structured_formatting'] as Map<String, dynamic>?;
        return PlaceSuggestion(
          placeId: map['place_id'] as String,
          mainText: (sf?['main_text'] as String?) ??
              (map['description'] as String? ?? ''),
          secondaryText: (sf?['secondary_text'] as String?) ?? '',
        );
      }).toList();
    } catch (_) {
      return [];
    }
  }

  /// Fetches the lat/lng for a given [placeId] via the Places Details API.
  ///
  /// Pass the same [sessionToken] used during autocomplete; this closes the
  /// billing session and the next search should use a fresh token.
  static Future<LatLng?> getDetails(
    String placeId, {
    String? sessionToken,
  }) async {
    try {
      final params = <String, String>{
        'place_id': placeId,
        'fields': 'geometry',
        'key': kGoogleApiKey,
      };
      if (sessionToken != null) params['sessiontoken'] = sessionToken;
      final uri = Uri.parse(_detailsUrl).replace(queryParameters: params);
      final response =
          await http.get(uri).timeout(const Duration(seconds: 8));
      if (response.statusCode != 200) return null;
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      if (data['status'] != 'OK') return null;
      final result = data['result'] as Map<String, dynamic>;
      final geometry = result['geometry'] as Map<String, dynamic>;
      final loc = geometry['location'] as Map<String, dynamic>;
      return LatLng(
        (loc['lat'] as num).toDouble(),
        (loc['lng'] as num).toDouble(),
      );
    } catch (_) {
      return null;
    }
  }
}
