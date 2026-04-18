import 'package:flutter/material.dart';
import '../models/subway_models.dart';
import '../data/seoul_subway_data.dart';
import '../core/api_keys.dart';
import '../services/seoul_subway_service.dart';
import '../services/environment_service.dart';
import 'subway_overlay.dart';

/// 지하철 실시간 정보 제어 패널 (접기/펼치기 지원)
class SubwayControlPanel extends StatefulWidget {
  final SubwayOverlayController controller;
  final VoidCallback onRefresh;

  const SubwayControlPanel({
    super.key,
    required this.controller,
    required this.onRefresh,
  });

  @override
  State<SubwayControlPanel> createState() => _SubwayControlPanelState();
}

class _SubwayControlPanelState extends State<SubwayControlPanel> {
  bool _isCollapsed = false;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.black.withValues(alpha: 0.9),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        width: 220,
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildHeader(),
            if (!_isCollapsed) ...[
              const Divider(height: 16, color: Colors.white10),
              _buildWeatherInfo(),
              const Divider(height: 16, color: Colors.white10),
              _buildStatusInfo(),
              const Divider(height: 16, color: Colors.white10),
              _buildToggles(),
              const Divider(height: 16, color: Colors.white10),
              _buildLineFilter(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Icon(
          Icons.train,
          color: widget.controller.isActive ? Colors.greenAccent : Colors.grey,
          size: 18,
        ),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: () {
            // 모드 토글: DEMO ↔ LIVE
            final next = widget.controller.mode == SubwayMode.demo
                ? SubwayMode.live
                : SubwayMode.demo;
            widget.controller.setMode(next);
            widget.onRefresh();
          },
          child: Text(
            widget.controller.mode == SubwayMode.demo ? 'DEMO' : 'LIVE',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 12,
              color: widget.controller.mode == SubwayMode.demo
                  ? Colors.orangeAccent
                  : Colors.white,
              letterSpacing: 1.2,
            ),
          ),
        ),
        const Spacer(),
        GestureDetector(
          onTap: () => setState(() => _isCollapsed = !_isCollapsed),
          child: Icon(
            _isCollapsed ? Icons.expand_more : Icons.expand_less,
            color: Colors.white54,
            size: 20,
          ),
        ),
        const SizedBox(width: 4),
        _PowerButton(
          isActive: widget.controller.isActive,
          onPressed: () {
            if (widget.controller.isActive) {
              widget.controller.stop();
            } else {
              widget.controller.start();
            }
            widget.onRefresh();
          },
        ),
      ],
    );
  }

  Widget _buildWeatherInfo() {
    final env = widget.controller.environment;
    if (env == null) {
      return const Text(
        '날씨 로딩 중...',
        style: TextStyle(fontSize: 9, color: Colors.grey),
      );
    }

    final timeIcon = _timeIcon(env.timeOfDay);
    final sunriseStr = '${env.sunrise.hour.toString().padLeft(2, '0')}:${env.sunrise.minute.toString().padLeft(2, '0')}';
    final sunsetStr = '${env.sunset.hour.toString().padLeft(2, '0')}:${env.sunset.minute.toString().padLeft(2, '0')}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 날씨 메인 라인
        Row(
          children: [
            Icon(env.weatherIcon, size: 16, color: _weatherColor(env.weather)),
            const SizedBox(width: 6),
            Text(
              '${env.temperature.toStringAsFixed(1)}°',
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            const SizedBox(width: 6),
            Text(
              env.weatherDescription,
              style: TextStyle(fontSize: 10, color: _weatherColor(env.weather)),
            ),
            const Spacer(),
            Icon(timeIcon, size: 12, color: Colors.white38),
            const SizedBox(width: 3),
            Text(
              env.lightPreset.toUpperCase(),
              style: const TextStyle(fontSize: 8, color: Colors.white38, letterSpacing: 0.5),
            ),
          ],
        ),
        const SizedBox(height: 4),
        // 상세 라인
        Row(
          children: [
            _miniInfo(Icons.wb_sunny_outlined, sunriseStr),
            const SizedBox(width: 8),
            _miniInfo(Icons.nights_stay_outlined, sunsetStr),
            const SizedBox(width: 8),
            _miniInfo(Icons.air, '${env.windSpeed.toStringAsFixed(0)}km/h'),
            const SizedBox(width: 8),
            _miniInfo(Icons.visibility, '${env.visibility.toStringAsFixed(0)}km'),
          ],
        ),
      ],
    );
  }

  Widget _miniInfo(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 9, color: Colors.white24),
        const SizedBox(width: 2),
        Text(text, style: const TextStyle(fontSize: 8, color: Colors.white38)),
      ],
    );
  }

  IconData _timeIcon(DayPhase tod) {
    switch (tod) {
      case DayPhase.dawn: return Icons.wb_twilight;
      case DayPhase.day: return Icons.wb_sunny;
      case DayPhase.dusk: return Icons.wb_twilight;
      case DayPhase.night: return Icons.nights_stay;
    }
  }

  Color _weatherColor(WeatherCondition w) {
    switch (w) {
      case WeatherCondition.clear: return Colors.amberAccent;
      case WeatherCondition.cloudy: return Colors.grey;
      case WeatherCondition.rain: return Colors.lightBlueAccent;
      case WeatherCondition.drizzle: return Colors.lightBlue;
      case WeatherCondition.snow: return Colors.white;
      case WeatherCondition.fog: return Colors.blueGrey;
      case WeatherCondition.thunderstorm: return Colors.deepPurpleAccent;
    }
  }

  Widget _buildStatusInfo() {
    if (!widget.controller.isActive) {
      return const Text(
        'OFF - 탭하여 시작',
        style: TextStyle(fontSize: 10, color: Colors.grey),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _infoRow('모드', widget.controller.mode == SubwayMode.demo
            ? '데모 (API 미사용)'
            : 'Live (API ${widget.controller.fetchIntervalSec}s)'),
        _infoRow('열차 수', '${widget.controller.currentTrains.length}대'),
        if (widget.controller.mode == SubwayMode.live)
          _infoRow('API', '${widget.controller.apiCallCount}/${SeoulSubwayService.dailyLimit}'),
        if (widget.controller.lastUpdate != null)
          _infoRow('갱신', _formatTime(widget.controller.lastUpdate!)),
        if (widget.controller.lastError != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              widget.controller.lastError!,
              style: const TextStyle(fontSize: 8, color: Colors.redAccent),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
      ],
    );
  }

  Widget _buildToggles() {
    return Column(
      children: [
        _toggleRow('노선 경로', widget.controller.showRoutes, (v) {
          widget.controller.toggleRoutes(v);
          widget.onRefresh();
        }),
        _toggleRow('열차 위치', widget.controller.showTrains, (v) {
          widget.controller.toggleTrains(v);
          widget.onRefresh();
        }),
        _toggleRow('역 표시', widget.controller.showStations, (v) {
          widget.controller.toggleStations(v);
          widget.onRefresh();
        }),
      ],
    );
  }

  Widget _buildLineFilter() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text('노선 필터', style: TextStyle(fontSize: 9, color: Colors.grey)),
            const Spacer(),
            GestureDetector(
              onTap: () {
                widget.controller.setLineFilter(null);
                widget.onRefresh();
              },
              child: const Text('전체', style: TextStyle(fontSize: 9, color: Colors.blueAccent)),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 4,
          runSpacing: 4,
          children: SubwayColors.lineColors.entries.map((entry) {
            final lineId = entry.key;
            final color = entry.value;
            final name = SubwayColors.lineNames[lineId] ?? lineId;
            final isSelected = widget.controller.selectedLines == null ||
                widget.controller.selectedLines!.contains(lineId);

            return GestureDetector(
              onTap: () {
                final current = widget.controller.selectedLines ??
                    Set<String>.from(SubwayColors.lineColors.keys);
                if (current.contains(lineId)) {
                  current.remove(lineId);
                } else {
                  current.add(lineId);
                }
                widget.controller.setLineFilter(current.isEmpty ? null : current);
                widget.onRefresh();
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: isSelected ? color.withValues(alpha: 0.3) : Colors.transparent,
                  border: Border.all(
                    color: isSelected ? color : Colors.white12,
                    width: 1,
                  ),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  name,
                  style: TextStyle(
                    fontSize: 8,
                    color: isSelected ? color : Colors.grey,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 9, color: Colors.grey)),
          Text(value, style: const TextStyle(fontSize: 9, color: Colors.white)),
        ],
      ),
    );
  }

  Widget _toggleRow(String label, bool value, ValueChanged<bool> onChanged) {
    return SizedBox(
      height: 28,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 10, color: Colors.white70)),
          Transform.scale(
            scale: 0.7,
            child: Switch.adaptive(
              value: value,
              onChanged: onChanged,
              activeColor: Colors.greenAccent,
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}:${time.second.toString().padLeft(2, '0')}';
  }
}

class _PowerButton extends StatelessWidget {
  final bool isActive;
  final VoidCallback onPressed;

  const _PowerButton({required this.isActive, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isActive ? Colors.greenAccent.withOpacity(0.2) : Colors.white10,
          border: Border.all(
            color: isActive ? Colors.greenAccent : Colors.grey,
            width: 1.5,
          ),
        ),
        child: Icon(
          Icons.power_settings_new,
          size: 14,
          color: isActive ? Colors.greenAccent : Colors.grey,
        ),
      ),
    );
  }
}

/// 역 도착정보 팝업 패널
class StationArrivalPanel extends StatelessWidget {
  final String stationName;
  final List<ArrivalInfo> arrivals;
  final VoidCallback onClose;

  const StationArrivalPanel({
    super.key,
    required this.stationName,
    required this.arrivals,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.black.withOpacity(0.95),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        width: 300,
        constraints: const BoxConstraints(maxHeight: 400),
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 헤더
            Row(
              children: [
                const Icon(Icons.info_outline, color: Colors.blueAccent, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    stationName,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: Colors.white,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 16, color: Colors.grey),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: onClose,
                ),
              ],
            ),
            const Divider(height: 12, color: Colors.white10),

            // 도착 정보 목록
            if (arrivals.isEmpty)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text('도착 정보 없음', style: TextStyle(color: Colors.grey, fontSize: 11)),
              )
            else
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: arrivals.length,
                  itemBuilder: (context, index) {
                    final info = arrivals[index];
                    final lineColor = SubwayColors.getColor(info.subwayId);
                    return _buildArrivalRow(info, lineColor);
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildArrivalRow(ArrivalInfo info, Color lineColor) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: lineColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border(left: BorderSide(color: lineColor, width: 3)),
      ),
      child: Row(
        children: [
          // 방면 정보
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  info.trainLineName,
                  style: const TextStyle(fontSize: 11, color: Colors.white),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  '${info.destinationName}행 ${info.trainType}',
                  style: const TextStyle(fontSize: 9, color: Colors.grey),
                ),
              ],
            ),
          ),
          // 도착 메시지
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                info.arrivalMsg,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: info.arrivalSeconds <= 60 ? Colors.redAccent : Colors.greenAccent,
                ),
              ),
              Text(
                info.arrivalCodeText,
                style: const TextStyle(fontSize: 8, color: Colors.grey),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 열차 정보 툴팁 (지도 위 열차 클릭 시) — 레거시, TrainDetailPanel로 대체
class TrainInfoTooltip extends StatelessWidget {
  final InterpolatedTrainPosition train;
  final VoidCallback? onClose;

  const TrainInfoTooltip({
    super.key,
    required this.train,
    this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return TrainDetailPanel(train: train, onClose: onClose);
  }
}

/// MiniTokyo3D 스타일 열차 상세 바텀 패널
/// 열차 클릭 시 하단에 슬라이드업으로 표시
class TrainDetailPanel extends StatelessWidget {
  final InterpolatedTrainPosition train;
  final VoidCallback? onClose;

  const TrainDetailPanel({
    super.key,
    required this.train,
    this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final lineColor = SubwayColors.getColor(train.subwayId);
    final lineName = SubwayColors.lineNames[train.subwayId] ?? train.subwayName;
    final directionText = _directionText(train.subwayId, train.direction);
    final trainTypeText = _trainTypeText(train.expressType);
    final prevStation = _getPrevStation();
    final nextStation = _getNextStation();
    final currentStation = train.stationName;
    final isMoving = train.trainStatus == 2 || train.trainStatus == 3;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: const Color(0xF01A1A2E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: lineColor.withOpacity(0.4), width: 1),
        boxShadow: [
          BoxShadow(
            color: lineColor.withOpacity(0.15),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── 헤더: 노선명 + 열차 종류 + 방향 ──
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: lineColor.withOpacity(0.15),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              children: [
                // 노선 아이콘
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: lineColor,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      _lineShortName(train.subwayId),
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // 노선 + 방향 정보
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        lineName,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: lineColor,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Text(
                            trainTypeText,
                            style: TextStyle(
                              fontSize: 12,
                              color: train.expressType == 1
                                  ? Colors.orangeAccent
                                  : Colors.white70,
                              fontWeight: train.expressType == 1
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '($directionText)',
                            style: const TextStyle(fontSize: 12, color: Colors.white54),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // 닫기 버튼
                GestureDetector(
                  onTap: onClose,
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: Colors.white10,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.close, size: 16, color: Colors.white54),
                  ),
                ),
              ],
            ),
          ),

          // ── 열차 번호 + 상태 태그 ──
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
            child: Row(
              children: [
                Icon(Icons.train, size: 14, color: lineColor),
                const SizedBox(width: 6),
                Text(
                  '열차 #${train.trainNo}',
                  style: const TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.w600),
                ),
                const SizedBox(width: 8),
                _statusChip(train.trainStatus, lineColor),
                if (train.isLastTrain) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.redAccent.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: Colors.redAccent.withOpacity(0.5)),
                    ),
                    child: const Text('막차', style: TextStyle(fontSize: 9, color: Colors.redAccent, fontWeight: FontWeight.bold)),
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 12),

          // ── 역 진행 표시 (이전역 → 현재역 → 다음역) ──
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _buildStationProgress(
              prevStation: prevStation,
              currentStation: currentStation,
              nextStation: nextStation,
              lineColor: lineColor,
              isMoving: isMoving,
            ),
          ),

          const SizedBox(height: 12),

          // ── 종착역 정보 ──
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
            child: Row(
              children: [
                Icon(Icons.flag, size: 12, color: Colors.white38),
                const SizedBox(width: 6),
                Text(
                  '${train.terminalName}행',
                  style: const TextStyle(fontSize: 11, color: Colors.white54),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 역 진행 위젯 (이전역 → 현재역 → 다음역)
  Widget _buildStationProgress({
    required String? prevStation,
    required String currentStation,
    required String? nextStation,
    required Color lineColor,
    required bool isMoving,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          // 이전역
          Expanded(
            child: _stationCell(
              label: '이전역',
              name: prevStation ?? '-',
              alignment: CrossAxisAlignment.start,
              isActive: false,
              color: Colors.white38,
            ),
          ),
          // 화살표 + 진행선
          _progressArrow(lineColor, isMoving, isLeft: true),
          // 현재역 (강조)
          Expanded(
            flex: 2,
            child: _stationCell(
              label: isMoving ? '출발역' : '현재역',
              name: currentStation,
              alignment: CrossAxisAlignment.center,
              isActive: true,
              color: lineColor,
            ),
          ),
          // 화살표 + 진행선
          _progressArrow(lineColor, isMoving, isLeft: false),
          // 다음역
          Expanded(
            child: _stationCell(
              label: '다음역',
              name: nextStation ?? '-',
              alignment: CrossAxisAlignment.end,
              isActive: false,
              color: Colors.white60,
            ),
          ),
        ],
      ),
    );
  }

  Widget _stationCell({
    required String label,
    required String name,
    required CrossAxisAlignment alignment,
    required bool isActive,
    required Color color,
  }) {
    return Column(
      crossAxisAlignment: alignment,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: TextStyle(fontSize: 9, color: color.withOpacity(0.7))),
        const SizedBox(height: 3),
        Text(
          name,
          style: TextStyle(
            fontSize: isActive ? 14 : 11,
            fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
            color: color,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  Widget _progressArrow(Color color, bool isMoving, {required bool isLeft}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 10), // label 높이 맞춤
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 12, height: 2, color: color.withOpacity(isMoving ? 0.6 : 0.2)),
              Icon(
                Icons.chevron_right,
                size: 14,
                color: color.withOpacity(isMoving && !isLeft ? 0.8 : 0.3),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statusChip(int status, Color lineColor) {
    String text;
    Color chipColor;
    switch (status) {
      case 0:
        text = '진입';
        chipColor = Colors.amber;
        break;
      case 1:
        text = '정차';
        chipColor = Colors.greenAccent;
        break;
      case 2:
        text = '출발';
        chipColor = lineColor;
        break;
      case 3:
        text = '운행';
        chipColor = lineColor;
        break;
      default:
        text = '운행';
        chipColor = lineColor;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: chipColor.withOpacity(0.15),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: chipColor.withOpacity(0.4)),
      ),
      child: Text(text, style: TextStyle(fontSize: 9, color: chipColor, fontWeight: FontWeight.bold)),
    );
  }

  /// 2호선 등 순환선 방향 텍스트
  String _directionText(String subwayId, int direction) {
    if (subwayId == '1002') {
      return direction == 0 ? '내선 순환' : '외선 순환';
    }
    return direction == 0 ? '상행' : '하행';
  }

  /// 열차 종류 텍스트
  String _trainTypeText(int expressType) {
    switch (expressType) {
      case 1: return '급행';
      case 7: return '특급';
      default: return '보통';
    }
  }

  /// 노선 원 안에 표시할 짧은 이름
  String _lineShortName(String subwayId) {
    switch (subwayId) {
      case '1001': return '1';
      case '1002': return '2';
      case '1003': return '3';
      case '1004': return '4';
      case '1005': return '5';
      case '1006': return '6';
      case '1007': return '7';
      case '1008': return '8';
      case '1009': return '9';
      case '1063': return '경의';
      case '1065': return '공항';
      case '1067': return '경춘';
      case '1075': return '수분';
      case '1077': return '신분';
      case '1092': return '우신';
      case '1032': return 'G';
      default: return '?';
    }
  }

  /// 이전역 찾기: 현재역 기준으로 반대 방향의 다음 역
  String? _getPrevStation() {
    final stations = _getLineStationNames();
    if (stations == null) return null;
    final idx = stations.indexOf(train.stationName);
    if (idx < 0) return null;

    // direction 0 = 상행(리스트 역순 진행) → 이전역은 idx+1
    // direction 1 = 하행(리스트 순서 진행) → 이전역은 idx-1
    final prevIdx = train.direction == 0 ? idx + 1 : idx - 1;
    if (prevIdx < 0 || prevIdx >= stations.length) return null;
    return stations[prevIdx];
  }

  /// 다음역 찾기: 현재역 기준으로 진행 방향의 다음 역
  String? _getNextStation() {
    final stations = _getLineStationNames();
    if (stations == null) return null;
    final idx = stations.indexOf(train.stationName);
    if (idx < 0) return null;

    // direction 0 = 상행(리스트 역순 진행) → 다음역은 idx-1
    // direction 1 = 하행(리스트 순서 진행) → 다음역은 idx+1
    final nextIdx = train.direction == 0 ? idx - 1 : idx + 1;
    if (nextIdx < 0 || nextIdx >= stations.length) return null;
    return stations[nextIdx];
  }

  /// 현재 노선의 역 이름 목록
  List<String>? _getLineStationNames() {
    final stations = SeoulSubwayData.getLineStations(train.subwayId);
    if (stations.isEmpty) return null;
    return stations.map((s) => s.name).toList();
  }
}

/// 역 상세 바텀 패널 (역 클릭 시)
class StationDetailPanel extends StatelessWidget {
  final String stationName;
  final StationInfo? stationInfo;
  final List<ArrivalInfo> arrivals;
  final bool isLoading;
  final VoidCallback? onClose;

  const StationDetailPanel({
    super.key,
    required this.stationName,
    this.stationInfo,
    required this.arrivals,
    required this.isLoading,
    this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    // 역이 속한 노선 색상들
    final lineColors = _getStationLineColors();
    final primaryColor = lineColors.isNotEmpty ? lineColors.first : Colors.blueAccent;
    final lat = stationInfo?.lat ?? 37.5665;
    final lng = stationInfo?.lng ?? 126.9780;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 12),
      constraints: const BoxConstraints(maxHeight: 420),
      decoration: BoxDecoration(
        color: const Color(0xF01A1A2E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: primaryColor.withOpacity(0.3), width: 1),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── 역 사진 (Mapbox Satellite) ──
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            child: Stack(
              children: [
                Image.network(
                  _satelliteImageUrl(lat, lng),
                  width: double.infinity,
                  height: 120,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    height: 120,
                    color: const Color(0xFF2a2a3e),
                    child: const Center(
                      child: Icon(Icons.train, size: 40, color: Colors.white12),
                    ),
                  ),
                  loadingBuilder: (_, child, progress) {
                    if (progress == null) return child;
                    return Container(
                      height: 120,
                      color: const Color(0xFF2a2a3e),
                      child: const Center(
                        child: SizedBox(
                          width: 20, height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white24),
                        ),
                      ),
                    );
                  },
                ),
                // 그라데이션 오버레이
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          const Color(0xF01A1A2E),
                        ],
                        stops: const [0.4, 1.0],
                      ),
                    ),
                  ),
                ),
                // 닫기 버튼
                Positioned(
                  top: 8,
                  right: 8,
                  child: GestureDetector(
                    onTap: onClose,
                    child: Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.close, size: 14, color: Colors.white70),
                    ),
                  ),
                ),
                // 역명 오버레이
                Positioned(
                  bottom: 8,
                  left: 12,
                  right: 48,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        stationName,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          shadows: [Shadow(blurRadius: 8, color: Colors.black)],
                        ),
                      ),
                      const SizedBox(height: 2),
                      // 노선 칩들
                      Wrap(
                        spacing: 4,
                        children: lineColors.map((color) {
                          final name = _lineNameForColor(color);
                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                            decoration: BoxDecoration(
                              color: color.withOpacity(0.8),
                              borderRadius: BorderRadius.circular(3),
                            ),
                            child: Text(
                              name,
                              style: const TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: Colors.white),
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ── 출발 정보 ──
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
            child: Row(
              children: [
                Icon(Icons.departure_board, size: 14, color: primaryColor),
                const SizedBox(width: 6),
                const Text(
                  '실시간 출발 정보',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white),
                ),
                const Spacer(),
                if (isLoading)
                  const SizedBox(
                    width: 12, height: 12,
                    child: CircularProgressIndicator(strokeWidth: 1.5, color: Colors.white38),
                  ),
              ],
            ),
          ),

          // 도착 정보 리스트
          if (isLoading && arrivals.isEmpty)
            const Padding(
              padding: EdgeInsets.all(20),
              child: Center(
                child: Text('조회 중...', style: TextStyle(fontSize: 11, color: Colors.grey)),
              ),
            )
          else if (arrivals.isEmpty)
            const Padding(
              padding: EdgeInsets.all(20),
              child: Center(
                child: Text('도착 정보 없음', style: TextStyle(fontSize: 11, color: Colors.grey)),
              ),
            )
          else
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
                itemCount: arrivals.length,
                itemBuilder: (context, index) {
                  final info = arrivals[index];
                  final lineColor = SubwayColors.getColor(info.subwayId);
                  return _buildArrivalRow(info, lineColor);
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildArrivalRow(ArrivalInfo info, Color lineColor) {
    final isUrgent = info.arrivalSeconds <= 60;
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: lineColor.withOpacity(0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border(left: BorderSide(color: lineColor, width: 3)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  info.trainLineName,
                  style: const TextStyle(fontSize: 11, color: Colors.white),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  '${info.destinationName}행 ${info.trainType}',
                  style: const TextStyle(fontSize: 9, color: Colors.grey),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                info.arrivalMsg,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: isUrgent ? Colors.redAccent : Colors.greenAccent,
                ),
              ),
              Text(
                info.arrivalCodeText,
                style: const TextStyle(fontSize: 8, color: Colors.grey),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Mapbox Satellite 정적 이미지 URL
  String _satelliteImageUrl(double lat, double lng) {
    final token = ApiKeys.mapboxAccessToken;
    return 'https://api.mapbox.com/styles/v1/mapbox/satellite-streets-v12/static/'
        '$lng,$lat,16.5,60/600x240@2x?access_token=$token';
  }

  /// 역이 속한 노선들의 색상 목록
  List<Color> _getStationLineColors() {
    final colors = <Color>[];
    for (final entry in SeoulSubwayData.lineIdToApiName.entries) {
      final stations = SeoulSubwayData.getLineStations(entry.key);
      for (final s in stations) {
        if (s.name == stationName) {
          colors.add(SubwayColors.getColor(entry.key));
          break;
        }
      }
    }
    if (colors.isEmpty) colors.add(Colors.blueAccent);
    return colors;
  }

  /// 색상으로 노선명 찾기
  String _lineNameForColor(Color color) {
    for (final entry in SubwayColors.lineColors.entries) {
      if (entry.value == color) {
        return SubwayColors.lineNames[entry.key] ?? entry.key;
      }
    }
    return '';
  }
}
