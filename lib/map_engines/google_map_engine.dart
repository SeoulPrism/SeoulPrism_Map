import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../core/map_interface.dart';

class GoogleMapEngine extends StatefulWidget {
  final CameraInfo initialCamera;
  final Function(IMapController) onMapCreated;

  const GoogleMapEngine({
    super.key,
    required this.initialCamera,
    required this.onMapCreated,
  });

  @override
  State<GoogleMapEngine> createState() => _GoogleMapEngineState();
}

class _GoogleMapEngineState extends State<GoogleMapEngine> implements IMapController {
  GoogleMapController? _controller;

  @override
  void moveTo(double lat, double lng, {double? zoom, double? pitch, double? bearing}) {
    _controller?.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(
          target: LatLng(lat, lng),
          zoom: zoom ?? widget.initialCamera.zoom,
          tilt: pitch ?? widget.initialCamera.pitch,
          bearing: bearing ?? 0,
        ),
      ),
    );
  }

  @override
  void setPitch(double pitch) {
    // Google Maps는 현재 상태에서 Tilt만 변경하는 직접적인 명령이 없으므로 카메라 위치와 함께 업데이트
  }

  @override
  void toggleLayer(String layerId, bool visible) {
    // Google Maps는 특정 레이어 제어가 제한적임
  }

  @override
  Widget build(BuildContext context) {
    return GoogleMap(
      initialCameraPosition: CameraPosition(
        target: LatLng(widget.initialCamera.lat, widget.initialCamera.lng),
        zoom: widget.initialCamera.zoom,
        tilt: widget.initialCamera.pitch,
      ),
      onMapCreated: (controller) {
        _controller = controller;
        widget.onMapCreated(this);
      },
      zoomControlsEnabled: false,
      myLocationButtonEnabled: false,
    );
  }
}
