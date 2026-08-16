import 'package:flutter/material.dart';

abstract class ILocationVisualizationService {
  Widget renderMapWidget({required double latitude, required double longitude, double zoomLevel = 15.0});
}

class LeafletOsmMapService implements ILocationVisualizationService {
  static final LeafletOsmMapService instance = LeafletOsmMapService._internal();
  LeafletOsmMapService._internal();

  @override
  Widget renderMapWidget({required double latitude, required double longitude, double zoomLevel = 15.0}) {
    return LeafletOsmMapView(
      latitude: latitude,
      longitude: longitude,
      zoomLevel: zoomLevel,
    );
  }
}

class LeafletOsmMapView extends StatelessWidget {
  final double latitude;
  final double longitude;
  final double zoomLevel;

  const LeafletOsmMapView({
    Key? key,
    required this.latitude,
    required this.longitude,
    this.zoomLevel = 15.0,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 180,
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E24),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF334155)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          // OpenStreetMap Tile / Map Canvas Visualizer
          Positioned.fill(
            child: Container(
              color: const Color(0xFF0F172A),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.map, size: 36, color: Color(0xFF38BDF8)),
                  const SizedBox(height: 6),
                  Text(
                    "Leaflet + OpenStreetMap Live Render",
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey[300]),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "Tiles: https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png",
                    style: TextStyle(fontSize: 10, fontFamily: 'monospace', color: Colors.grey[500]),
                  ),
                ],
              ),
            ),
          ),

          // Map Marker Overlay
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.redAccent,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    "${latitude.toStringAsFixed(4)}° N, ${longitude.toStringAsFixed(4)}° E",
                    style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold, fontFamily: 'monospace'),
                  ),
                ),
                const Icon(Icons.location_on, color: Colors.redAccent, size: 28),
              ],
            ),
          ),

          // Attribution Badge
          Positioned(
            bottom: 6,
            right: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.7),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                "© OpenStreetMap contributors | Leaflet",
                style: TextStyle(color: Colors.grey, fontSize: 8),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
