import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import '../core/map_interface.dart';

class MapboxEngine extends StatefulWidget {
  final CameraInfo initialCamera;
  final Function(IMapController) onMapCreated;

  const MapboxEngine({
    super.key,
    required this.initialCamera,
    required this.onMapCreated,
  });

  @override
  State<MapboxEngine> createState() => _MapboxEngineState();
}

class _MapboxEngineState extends State<MapboxEngine> implements IMapController {
  MapboxMap? _mapboxMap;

  @override
  void moveTo(double lat, double lng, {double? zoom, double? pitch, double? bearing}) {
    _mapboxMap?.flyTo(
      CameraOptions(
        center: Point(coordinates: Position(lng, lat)),
        zoom: zoom,
        pitch: pitch,
        bearing: bearing,
      ),
      MapAnimationOptions(duration: 1500),
    );
  }

  @override
  void setPitch(double pitch) {
    _mapboxMap?.setCamera(CameraOptions(pitch: pitch));
  }

  @override
  void toggleLayer(String layerId, bool visible) {
    _mapboxMap?.style.setStyleLayerProperty(layerId, 'visibility', visible ? 'visible' : 'none');
  }

  void _onMapCreated(MapboxMap mapboxMap) {
    _mapboxMap = mapboxMap;
    widget.onMapCreated(this);
    
    // 조명 설정 대신 레이어 가시성을 수동으로 한 번 더 체크 (선택 사항)
    _mapboxMap?.style.styleLayerExists('building').then((exists) {
      if (exists) {
        toggleLayer('building', true);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return MapWidget(
      onMapCreated: _onMapCreated,
      cameraOptions: CameraOptions(
        center: Point(coordinates: Position(widget.initialCamera.lng, widget.initialCamera.lat)),
        zoom: 15.0, // 3D 건물을 보기 위해 줌을 조금 더 당깁니다
        pitch: 45.0, // 초기 각도를 주어 입체감을 살립니다
        bearing: widget.initialCamera.bearing,
      ),
      // Mapbox Standard 스타일을 사용하여 3D 건물을 기본으로 활성화합니다.
      styleUri: MapboxStyles.STANDARD,
    );
  }
}
