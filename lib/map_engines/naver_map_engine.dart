import 'package:flutter/material.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import '../core/map_interface.dart';

class NaverMapEngine extends StatefulWidget {
  final CameraInfo initialCamera;
  final Function(IMapController) onMapCreated;

  const NaverMapEngine({
    super.key,
    required this.initialCamera,
    required this.onMapCreated,
  });

  @override
  State<NaverMapEngine> createState() => _NaverMapEngineState();
}

class _NaverMapEngineState extends State<NaverMapEngine> implements IMapController {
  NaverMapController? _controller;

  @override
  void moveTo(double lat, double lng, {double? zoom, double? pitch, double? bearing}) {
    final cameraUpdate = NCameraUpdate.withParams(
      target: NLatLng(lat, lng),
      zoom: zoom,
      tilt: pitch,
      bearing: bearing,
    );
    cameraUpdate.setAnimation(animation: NCameraAnimation.fly, duration: const Duration(seconds: 1));
    _controller?.updateCamera(cameraUpdate);
  }

  @override
  void setPitch(double pitch) {
    _controller?.updateCamera(NCameraUpdate.withParams(tilt: pitch));
  }

  @override
  void toggleLayer(String layerId, bool visible) {
    // Naver Map 전용 레이어 제어 (필요 시 추가)
  }

  @override
  Widget build(BuildContext context) {
    return NaverMap(
      options: NaverMapViewOptions(
        initialCameraPosition: NCameraPosition(
          target: NLatLng(widget.initialCamera.lat, widget.initialCamera.lng),
          zoom: widget.initialCamera.zoom,
          tilt: widget.initialCamera.pitch,
          bearing: widget.initialCamera.bearing,
        ),
        indoorEnable: true,
        locationButtonEnable: false,
        consumeSymbolTapEvents: false,
      ),
      onMapReady: (controller) {
        _controller = controller;
        widget.onMapCreated(this);
      },
    );
  }
}
