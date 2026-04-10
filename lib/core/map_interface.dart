enum MapType { mapbox, google, naver }

abstract class IMapController {
  void moveTo(double lat, double lng, {double zoom, double pitch, double bearing});
  void toggleLayer(String layerId, bool visible);
  void setPitch(double pitch);
}

class CameraInfo {
  final double lat;
  final double lng;
  final double zoom;
  final double pitch;
  final double bearing;

  CameraInfo({
    required this.lat,
    required this.lng,
    required this.zoom,
    required this.pitch,
    required this.bearing,
  });
}
