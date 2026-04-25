import 'package:flutter/material.dart';
import '../models/subway_models.dart';
import '../data/seoul_subway_data.dart';
import '../core/api_keys.dart';
import '../services/seoul_subway_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import '../theme/app_spacing.dart';
import 'app_badge.dart';
import 'subway_overlay.dart';
import '../services/congestion_service.dart';
import '../services/closure_service.dart';

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
      color: AppColors.surface.withValues(alpha: 0.9),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSpacing.md)),
      child: Container(
        width: 220,
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildHeader(),
            if (!_isCollapsed) ...[
              if (widget.controller.trainDelays.isNotEmpty) ...[
                Divider(height: AppSpacing.lg, color: AppColors.divider),
                _buildDelayAlertBanner(),
              ],
              Divider(height: AppSpacing.lg, color: AppColors.divider),
              _buildStatusInfo(),
              Divider(height: AppSpacing.lg, color: AppColors.divider),
              _buildToggles(),
              Divider(height: AppSpacing.lg, color: AppColors.divider),
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
          color: widget.controller.isActive ? AppColors.success : Colors.grey,
          size: 18,
        ),
        const SizedBox(width: AppSpacing.sm),
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
            style: AppTypography.bodySm.copyWith(
              fontWeight: FontWeight.bold,
              color: widget.controller.mode == SubwayMode.demo
                  ? AppColors.warning
                  : AppColors.textPrimary,
              letterSpacing: 1.2,
            ),
          ),
        ),
        const Spacer(),
        Semantics(
          label: _isCollapsed ? '패널 펼치기' : '패널 접기',
          button: true,
          child: GestureDetector(
            onTap: () => setState(() => _isCollapsed = !_isCollapsed),
            child: Icon(
              _isCollapsed ? Icons.expand_more : Icons.expand_less,
              color: AppColors.textTertiary,
              size: AppSpacing.xl,
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.xs),
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

  Widget _buildDelayAlertBanner() {
    final delays = widget.controller.trainDelays;
    // 지연 시간순 정렬
    final sorted = delays.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 6, height: 6,
              decoration: BoxDecoration(
                color: AppColors.danger,
                shape: BoxShape.circle,
                boxShadow: [BoxShadow(color: AppColors.danger, blurRadius: 4)],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Text(
              '지연 열차 ${delays.length}대',
              style: AppTypography.caption.copyWith(
                fontWeight: FontWeight.bold,
                color: AppColors.danger,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        ...sorted.take(4).map((entry) {
          final train = widget.controller.currentTrains
              .where((t) => t.trainNo == entry.key)
              .firstOrNull;
          final lineColor = train != null
              ? SubwayColors.getColor(train.subwayId)
              : Colors.grey;
          final lineName = train != null
              ? (SubwayColors.lineNames[train.subwayId] ?? '')
              : '';

          return Padding(
            padding: const EdgeInsets.only(bottom: 3),
            child: Row(
              children: [
                if (lineName.isNotEmpty) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs, vertical: 1),
                    decoration: BoxDecoration(
                      color: lineColor.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(3),
                      border: Border.all(color: lineColor, width: 0.5),
                    ),
                    child: Text(lineName,
                      style: AppTypography.caption.copyWith(color: AppColors.textPrimary)),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                ],
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs, vertical: 1),
                  decoration: BoxDecoration(
                    color: AppColors.danger.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(3),
                    border: Border.all(color: AppColors.danger, width: 0.5),
                  ),
                  child: Text('${entry.value}분',
                    style: AppTypography.caption.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppColors.danger)),
                ),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: Text(
                    '${entry.key}${train != null ? ' · ${train.stationName}' : ''}',
                    style: AppTypography.caption.copyWith(color: AppColors.textSecondary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          );
        }),
        if (sorted.length > 4)
          Text(
            '외 ${sorted.length - 4}대...',
            style: AppTypography.caption.copyWith(color: AppColors.textDisabled),
          ),
      ],
    );
  }

  Widget _buildStatusInfo() {
    if (!widget.controller.isActive) {
      return Text(
        'OFF - 탭하여 시작',
        style: AppTypography.caption.copyWith(color: Colors.grey),
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
            padding: const EdgeInsets.only(top: AppSpacing.xs),
            child: Text(
              widget.controller.lastError!,
              style: AppTypography.caption.copyWith(color: AppColors.danger),
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
        _toggleRow('혼잡도', widget.controller.showCongestion, (v) {
          widget.controller.setCongestionVisible(v);
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
            Text('노선 필터', style: AppTypography.caption.copyWith(color: Colors.grey)),
            const Spacer(),
            GestureDetector(
              onTap: () {
                widget.controller.setLineFilter(null);
                widget.onRefresh();
              },
              child: Text('전체', style: AppTypography.caption.copyWith(color: AppColors.accent)),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: AppSpacing.xs,
          runSpacing: AppSpacing.xs,
          children: SubwayColors.lineColors.entries.map((entry) {
            final lineId = entry.key;
            final color = entry.value;
            final name = SubwayColors.lineNames[lineId] ?? lineId;
            final isSelected = widget.controller.selectedLines == null ||
                widget.controller.selectedLines!.contains(lineId);

            return AppFilterChip(
              label: name,
              color: color,
              isSelected: isSelected,
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
          Text(label, style: AppTypography.caption.copyWith(color: Colors.grey)),
          Text(value, style: AppTypography.caption.copyWith(color: AppColors.textPrimary)),
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
          Text(label, style: AppTypography.caption.copyWith(color: AppColors.textSecondary)),
          Transform.scale(
            scale: 0.7,
            child: Switch.adaptive(
              value: value,
              onChanged: onChanged,
              activeColor: AppColors.success,
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
    return AppCircleButton(
      icon: Icons.power_settings_new,
      onTap: onPressed,
      semanticLabel: isActive ? '지하철 시각화 끄기' : '지하철 시각화 켜기',
      size: AppSpacing.buttonSm,
      iconSize: 14,
      color: isActive ? AppColors.success.withValues(alpha: 0.2) : AppColors.surfaceOverlay,
      borderColor: isActive ? AppColors.success : Colors.grey,
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
      color: AppColors.surface.withValues(alpha: 0.95),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSpacing.md)),
      child: Container(
        width: 300,
        constraints: const BoxConstraints(maxHeight: 400),
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 헤더
            Row(
              children: [
                Icon(Icons.info_outline, color: AppColors.accent, size: AppSpacing.lg),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    stationName,
                    style: AppTypography.bodyMd.copyWith(fontWeight: FontWeight.bold),
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
            Divider(height: AppSpacing.md, color: AppColors.divider),

            // 도착 정보 목록
            if (arrivals.isEmpty)
              Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Text('도착 정보 없음', style: AppTypography.bodySm.copyWith(color: Colors.grey)),
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
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: lineColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppSpacing.sm),
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
                  style: AppTypography.bodySm.copyWith(color: AppColors.textPrimary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  '${info.destinationName}행 ${info.trainType}',
                  style: AppTypography.caption.copyWith(color: Colors.grey),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                info.arrivalMsg,
                style: AppTypography.bodySm.copyWith(
                  fontWeight: FontWeight.bold,
                  color: info.arrivalSeconds <= 60 ? AppColors.danger : AppColors.success,
                ),
              ),
              Text(
                info.arrivalCodeText,
                style: AppTypography.caption.copyWith(color: Colors.grey),
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
  final int delayMinutes;

  const TrainDetailPanel({
    super.key,
    required this.train,
    this.onClose,
    this.delayMinutes = 0,
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
      margin: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(AppSpacing.xl),
        border: Border.all(color: lineColor.withValues(alpha: 0.4), width: 1),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
        children: [
          // ── 헤더: 노선명 + 열차 종류 + 방향 ──
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
            decoration: BoxDecoration(
              color: lineColor.withValues(alpha: 0.15),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(AppSpacing.xl)),
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
                      style: AppTypography.bodySm.copyWith(
                        fontWeight: FontWeight.w900,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                // 노선 + 방향 정보
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        lineName,
                        style: AppTypography.titleMd.copyWith(color: lineColor),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Text(
                            trainTypeText,
                            style: AppTypography.bodySm.copyWith(
                              color: train.expressType == 1
                                  ? AppColors.warning
                                  : AppColors.textSecondary,
                              fontWeight: train.expressType == 1
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Text(
                            '($directionText)',
                            style: AppTypography.bodySm.copyWith(color: AppColors.textTertiary),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // 닫기 버튼
                AppCircleButton(
                  icon: Icons.close,
                  onTap: onClose ?? () {},
                  semanticLabel: '열차 상세 닫기',
                ),
              ],
            ),
          ),

          // ── 열차 번호 + 상태 태그 ──
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.md, AppSpacing.lg, 0),
            child: Row(
              children: [
                Icon(Icons.train, size: 14, color: lineColor),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  '열차 #${train.trainNo}',
                  style: AppTypography.bodySm.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(width: AppSpacing.sm),
                _statusChip(train.trainStatus, lineColor),
                if (delayMinutes >= 2) ...[
                  const SizedBox(width: AppSpacing.sm),
                  AppBadge(text: '$delayMinutes분 지연', color: AppColors.danger),
                ],
                if (train.isLastTrain) ...[
                  const SizedBox(width: AppSpacing.sm),
                  AppBadge(text: '막차', color: AppColors.danger),
                ],
              ],
            ),
          ),

          const SizedBox(height: AppSpacing.md),

          // ── 역 진행 표시 (이전역 → 현재역 → 다음역) ──
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: _buildStationProgress(
              prevStation: prevStation,
              currentStation: currentStation,
              nextStation: nextStation,
              lineColor: lineColor,
              isMoving: isMoving,
            ),
          ),

          const SizedBox(height: AppSpacing.md),

          // ── 종착역 정보 ──
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.lg),
            child: Row(
              children: [
                Icon(Icons.flag, size: AppSpacing.md, color: AppColors.textDisabled),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  '${train.terminalName}행',
                  style: AppTypography.bodySm.copyWith(color: AppColors.textTertiary),
                ),
              ],
            ),
          ),
        ],
      ),
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
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(AppSpacing.md),
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
        Text(label, style: AppTypography.caption.copyWith(color: color.withValues(alpha: 0.7))),
        const SizedBox(height: AppSpacing.xs),
        Text(
          name,
          style: (isActive ? AppTypography.bodyMd : AppTypography.bodySm).copyWith(
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
              Container(width: AppSpacing.md, height: 2, color: color.withValues(alpha: isMoving ? 0.6 : 0.2)),
              Icon(
                Icons.chevron_right,
                size: 14,
                color: color.withValues(alpha: isMoving && !isLeft ? 0.8 : 0.3),
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
        text = '곧 도착';
        chipColor = Colors.amber;
        break;
      case 1:
        text = '정차중';
        chipColor = AppColors.success;
        break;
      case 2:
        text = '출발';
        chipColor = lineColor;
        break;
      case 3:
        text = '이동중';
        chipColor = lineColor;
        break;
      default:
        text = '운행';
        chipColor = lineColor;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 2),
      decoration: BoxDecoration(
        color: chipColor.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(AppSpacing.xs),
        border: Border.all(color: chipColor.withValues(alpha: 0.4)),
      ),
      child: Text(text, style: AppTypography.caption.copyWith(color: chipColor, fontWeight: FontWeight.bold)),
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

    // 노선 그라데이션 (환승역은 여러 색 그라데이션)
    final gradientColors = lineColors.length >= 2
        ? lineColors.map((c) => c.withValues(alpha: 0.2)).toList()
        : [primaryColor.withValues(alpha: 0.2), primaryColor.withValues(alpha: 0.05)];

    final panelHeight = MediaQuery.of(context).size.height * 0.30;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: SizedBox(
        width: double.infinity,
        height: panelHeight,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: AppColors.surfaceCard.withValues(alpha: 0.94),
            borderRadius: BorderRadius.circular(AppSpacing.xl),
            border: Border.all(color: primaryColor.withValues(alpha: 0.3), width: 1),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppSpacing.xl),
            child: Column(
              children: [
              // ── 헤더: 노선 그라데이션 + 역명 (열차 패널 스타일) ──
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: gradientColors),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(AppSpacing.xl)),
                ),
                child: Row(
                  children: [
                    // 노선 아이콘(들)
                    if (lineColors.length == 1)
                      Container(
                        width: 36, height: 36,
                        decoration: BoxDecoration(color: primaryColor, shape: BoxShape.circle),
                        child: Center(
                          child: Text(
                            _lineShortName(primaryColor),
                            style: AppTypography.bodySm.copyWith(fontWeight: FontWeight.w900, color: AppColors.textPrimary),
                          ),
                        ),
                      )
                    else
                      // 환승역: 최대 4개까지, 겹쳐서 표시
                      SizedBox(
                        width: 24.0 + (lineColors.take(4).length - 1) * 10.0,
                        height: 28,
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            for (int i = 0; i < lineColors.take(4).length; i++)
                              Positioned(
                                left: i * 10.0,
                                child: Container(
                                  width: 24, height: 24,
                                  decoration: BoxDecoration(
                                    color: lineColors[i],
                                    shape: BoxShape.circle,
                                    border: Border.all(color: Colors.white24, width: 1.5),
                                  ),
                                  child: Center(
                                    child: Text(
                                      _lineShortName(lineColors[i]),
                                      style: AppTypography.caption.copyWith(fontWeight: FontWeight.w900, color: AppColors.textPrimary),
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    const SizedBox(width: AppSpacing.md),
                    // 역명 + 노선 칩
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            stationName,
                            style: AppTypography.titleMd.copyWith(color: primaryColor),
                          ),
                          const SizedBox(height: 2),
                          Wrap(
                            spacing: AppSpacing.xs,
                            children: lineColors.map((color) {
                              final name = _lineNameForColor(color);
                              return Text(name, style: AppTypography.bodySm.copyWith(color: color.withValues(alpha: 0.8)));
                            }).toList(),
                          ),
                        ],
                      ),
                    ),
                    // 닫기
                    AppCircleButton(
                      icon: Icons.close,
                      onTap: onClose ?? () {},
                      semanticLabel: '역 상세 닫기',
                    ),
                  ],
                ),
              ),

              // ── 혼잡도 정보 ──
              _buildCongestionRow(primaryColor),

              // ── 시설 폐쇄 안내 ──
              _buildClosureSection(),

              // ── 출발 정보 라벨 ──
              Padding(
                padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.xs),
                child: Row(
                  children: [
                    Icon(Icons.departure_board, size: 14, color: primaryColor),
                    const SizedBox(width: AppSpacing.sm),
                    Text('실시간 출발 정보', style: AppTypography.bodySm.copyWith(fontWeight: FontWeight.w600)),
                    const Spacer(),
                    if (isLoading)
                      SizedBox(width: AppSpacing.md, height: AppSpacing.md, child: CircularProgressIndicator(strokeWidth: 1.5, color: AppColors.textDisabled)),
                  ],
                ),
              ),

              // ── 도착 정보 리스트 ──
              if (isLoading && arrivals.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(AppSpacing.xl),
                  child: Center(child: Text('조회 중...', style: AppTypography.bodySm.copyWith(color: Colors.grey))),
                )
              else if (arrivals.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(AppSpacing.xl),
                  child: Center(child: Text('도착 정보 없음', style: AppTypography.bodySm.copyWith(color: Colors.grey))),
                )
              else
                Builder(builder: (context) {
                  final filtered = _filterNearestArrivals(arrivals);
                  return Expanded(
                    child: ListView.builder(
                      clipBehavior: Clip.hardEdge,
                      padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.xs, AppSpacing.md, AppSpacing.md),
                      itemCount: filtered.length,
                      itemBuilder: (context, index) {
                        final info = filtered[index];
                        final lineColor = SubwayColors.getColor(info.subwayId);
                        return _buildArrivalRow(info, lineColor);
                      },
                    ),
                  );
                }),


              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildArrivalRow(ArrivalInfo info, Color lineColor) {
    final isUrgent = info.arrivalSeconds <= 60;
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: lineColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppSpacing.sm),
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
                  style: AppTypography.bodySm.copyWith(color: AppColors.textPrimary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  '${info.destinationName}행 ${info.trainType}',
                  style: AppTypography.caption.copyWith(color: Colors.grey),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                info.arrivalMsg,
                style: AppTypography.bodySm.copyWith(
                  fontWeight: FontWeight.bold,
                  color: isUrgent ? AppColors.danger : AppColors.success,
                ),
              ),
              Text(
                info.arrivalCodeText,
                style: AppTypography.caption.copyWith(color: Colors.grey),
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

  /// 방면별 가장 빨리 도착하는 열차 1개씩만 필터
  List<ArrivalInfo> _filterNearestArrivals(List<ArrivalInfo> all) {
    final seen = <String>{};
    final result = <ArrivalInfo>[];
    for (final info in all) {
      // 방면 정보 (예: "성수행 - 신도림방면")를 키로 사용
      final key = info.trainLineName;
      if (key.isNotEmpty && seen.add(key)) {
        result.add(info);
      } else if (key.isEmpty) {
        // trainLineName이 비어있으면 방향+종착역으로 폴백
        final fallbackKey = '${info.direction}_${info.destinationName}';
        if (seen.add(fallbackKey)) {
          result.add(info);
        }
      }
    }
    return result;
  }

  /// 색상으로 노선 짧은 이름 (원 안 표시용)
  String _lineShortName(Color color) {
    for (final entry in SubwayColors.lineColors.entries) {
      if (entry.value == color) {
        final name = SubwayColors.lineNames[entry.key] ?? '';
        if (name.endsWith('호선')) return name.replaceAll('호선', '');
        if (name.length > 2) return name.substring(0, 2);
        return name;
      }
    }
    return '?';
  }

  /// 혼잡도 정보 행
  Widget _buildCongestionRow(Color primaryColor) {
    final service = CongestionService.instance;
    if (!service.isLoaded) return const SizedBox.shrink();

    final congestion = service.data[stationName];
    if (congestion == null) return const SizedBox.shrink();

    final crowding = service.getCrowding(stationName);
    final Color crowdColor;
    final String crowdLabel;
    if (crowding > 0.7) {
      crowdColor = Colors.red;
      crowdLabel = '매우 혼잡';
    } else if (crowding > 0.4) {
      crowdColor = Colors.orange;
      crowdLabel = '혼잡';
    } else if (crowding > 0.2) {
      crowdColor = Colors.amber;
      crowdLabel = '보통';
    } else {
      crowdColor = Colors.green;
      crowdLabel = '여유';
    }

    final formatter = RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))');
    String fmt(int n) => n.toString().replaceAllMapped(formatter, (m) => '${m[1]},');

    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, 0),
      child: Row(
        children: [
          Icon(Icons.people, size: 14, color: crowdColor),
          const SizedBox(width: AppSpacing.sm),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: crowdColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(crowdLabel, style: AppTypography.caption.copyWith(color: crowdColor, fontWeight: FontWeight.w700)),
          ),
          const SizedBox(width: AppSpacing.sm),
          Text(
            '승차 ${fmt(congestion.boarding)}명',
            style: AppTypography.caption.copyWith(color: Colors.blue.shade300),
          ),
          const SizedBox(width: AppSpacing.sm),
          Text(
            '하차 ${fmt(congestion.alighting)}명',
            style: AppTypography.caption.copyWith(color: Colors.orange.shade300),
          ),
        ],
      ),
    );
  }

  /// 시설 임시폐쇄 정보 섹션
  Widget _buildClosureSection() {
    final closures = ClosureService.instance.getClosures(stationName);
    if (closures.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, 0),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpacing.sm),
        decoration: BoxDecoration(
          color: Colors.orange.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(AppSpacing.sm),
          border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.construction, size: 14, color: Colors.orange),
                const SizedBox(width: AppSpacing.xs),
                Text(
                  '시설 폐쇄 ${closures.length}건',
                  style: AppTypography.bodySm.copyWith(
                    fontWeight: FontWeight.w700,
                    color: Colors.orange,
                  ),
                ),
              ],
            ),
            for (final c in closures) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(
                '${c.closurePlace} (~${c.endDate})',
                style: AppTypography.caption.copyWith(fontWeight: FontWeight.w600),
              ),
              if (c.altRoute.isNotEmpty)
                Text(
                  c.altRoute,
                  style: AppTypography.caption.copyWith(color: Colors.grey),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
            ],
          ],
        ),
      ),
    );
  }
}
