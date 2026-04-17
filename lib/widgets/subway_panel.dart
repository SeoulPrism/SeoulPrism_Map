import 'package:flutter/material.dart';
import '../models/subway_models.dart';
import '../services/seoul_subway_service.dart';
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

/// 열차 정보 툴팁 (지도 위 열차 클릭 시)
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
    final lineColor = SubwayColors.getColor(train.subwayId);

    return Card(
      color: Colors.black.withOpacity(0.95),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: lineColor, width: 1.5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: lineColor,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    train.subwayName,
                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '#${train.trainNo}',
                  style: const TextStyle(fontSize: 10, color: Colors.grey),
                ),
                if (onClose != null) ...[
                  const SizedBox(width: 16),
                  GestureDetector(
                    onTap: onClose,
                    child: const Icon(Icons.close, size: 14, color: Colors.grey),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 6),
            _row('현재역', train.stationName),
            _row('종착역', train.terminalName),
            _row('방향', train.direction == 0 ? '상행/내선' : '하행/외선'),
            _row('상태', _statusText(train.trainStatus)),
            if (train.expressType == 1)
              _row('유형', '급행', valueColor: Colors.orangeAccent),
            if (train.isLastTrain)
              _row('막차', '마지막 열차', valueColor: Colors.redAccent),
          ],
        ),
      ),
    );
  }

  Widget _row(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 45,
            child: Text(label, style: const TextStyle(fontSize: 9, color: Colors.grey)),
          ),
          Text(value, style: TextStyle(fontSize: 9, color: valueColor ?? Colors.white)),
        ],
      ),
    );
  }

  String _statusText(int status) {
    switch (status) {
      case 0: return '진입 중';
      case 1: return '도착';
      case 2: return '출발';
      case 3: return '전역 출발';
      default: return '운행 중';
    }
  }
}
