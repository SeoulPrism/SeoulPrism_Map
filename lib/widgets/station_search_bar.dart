import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:cupertino_native_better/cupertino_native.dart';
import '../data/seoul_subway_data.dart';
import '../models/subway_models.dart';

/// 초성 매핑 테이블
const List<String> _chosung = [
  'ㄱ', 'ㄲ', 'ㄴ', 'ㄷ', 'ㄸ', 'ㄹ', 'ㅁ', 'ㅂ', 'ㅃ',
  'ㅅ', 'ㅆ', 'ㅇ', 'ㅈ', 'ㅉ', 'ㅊ', 'ㅋ', 'ㅌ', 'ㅍ', 'ㅎ',
];

/// 한글 문자에서 초성 추출
String _getChosung(String text) {
  final buffer = StringBuffer();
  for (final c in text.runes) {
    if (c >= 0xAC00 && c <= 0xD7A3) {
      final index = ((c - 0xAC00) / 588).floor();
      buffer.write(_chosung[index]);
    } else {
      buffer.writeCharCode(c);
    }
  }
  return buffer.toString();
}

/// 초성 검색 포함 역명 매칭
bool _matchesQuery(String stationName, String query) {
  // 일반 매칭 (contains)
  if (stationName.contains(query)) return true;
  // 초성 매칭
  final chosung = _getChosung(stationName);
  if (chosung.contains(query)) return true;
  return false;
}

/// 역 검색 결과 아이템
class _SearchResult {
  final StationInfo station;
  final String lineId;
  final String lineName;
  final Color lineColor;

  const _SearchResult({
    required this.station,
    required this.lineId,
    required this.lineName,
    required this.lineColor,
  });
}

/// 지하철역 검색바 + 프로필 버튼 (리퀴드 글라스)
class StationSearchBar extends StatefulWidget {
  final void Function(String stationName) onStationSelected;
  final VoidCallback? onProfileTap;

  const StationSearchBar({
    super.key,
    required this.onStationSelected,
    this.onProfileTap,
  });

  @override
  State<StationSearchBar> createState() => _StationSearchBarState();
}

class _StationSearchBarState extends State<StationSearchBar> {
  final TextEditingController _textController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  List<_SearchResult> _results = [];
  bool _isSearching = false;

  // 전체 역 목록 캐시 (노선 정보 포함)
  late final List<_SearchResult> _allStations;

  @override
  void initState() {
    super.initState();
    _buildStationCache();
    _focusNode.addListener(() {
      if (!_focusNode.hasFocus && _textController.text.isEmpty) {
        setState(() {
          _isSearching = false;
          _results = [];
        });
      }
    });
  }

  void _buildStationCache() {
    final stations = <_SearchResult>[];
    final seen = <String>{};

    for (final entry in SubwayColors.lineColors.entries) {
      final lineId = entry.key;
      final color = entry.value;
      final lineName = SubwayColors.lineNames[lineId] ?? lineId;
      final lineStations = SeoulSubwayData.getLineStations(lineId);

      for (final station in lineStations) {
        // 중복 역명은 첫 번째만 (환승역)
        if (seen.contains(station.name)) continue;
        seen.add(station.name);
        stations.add(_SearchResult(
          station: station,
          lineId: lineId,
          lineName: lineName,
          lineColor: color,
        ));
      }
    }
    _allStations = stations;
  }

  void _onSearchChanged(String query) {
    if (query.isEmpty) {
      setState(() {
        _results = [];
        _isSearching = false;
      });
      return;
    }

    final trimmed = query.trim();
    final matches = _allStations
        .where((r) => _matchesQuery(r.station.name, trimmed))
        .take(20)
        .toList();

    setState(() {
      _results = matches;
      _isSearching = true;
    });
  }

  void _selectStation(_SearchResult result) {
    _textController.clear();
    _focusNode.unfocus();
    setState(() {
      _isSearching = false;
      _results = [];
    });
    widget.onStationSelected(result.station.name);
  }

  void _cancelSearch() {
    _textController.clear();
    _focusNode.unfocus();
    setState(() {
      _isSearching = false;
      _results = [];
    });
  }

  @override
  void dispose() {
    _textController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;

    return Stack(
      children: [
        // 검색바 + 프로필 버튼
        Positioned(
          top: topPadding + 8,
          left: 12,
          right: 12,
          child: Row(
            children: [
              // 검색 바 (리퀴드 글라스)
              Expanded(child: _buildSearchField()),
              const SizedBox(width: 8),
              // 프로필 버튼 (리퀴드 글라스)
              _buildProfileButton(),
            ],
          ),
        ),
        // 검색 결과 드롭다운
        if (_isSearching && _results.isNotEmpty)
          Positioned(
            top: topPadding + 56,
            left: 12,
            right: 12,
            child: _buildSearchResults(),
          ),
      ],
    );
  }

  Widget _buildSearchField() {
    return LiquidGlassContainer(
      config: const LiquidGlassConfig(
        effect: CNGlassEffect.regular,
        shape: CNGlassEffectShape.capsule,
        interactive: true,
      ),
      child: SizedBox(
        height: 40,
        child: CupertinoTextField(
          controller: _textController,
          focusNode: _focusNode,
          placeholder: '역명 검색',
          placeholderStyle: const TextStyle(
            color: CupertinoColors.systemGrey,
            fontSize: 15,
          ),
          style: const TextStyle(color: Colors.white, fontSize: 15),
          decoration: null,
          padding: const EdgeInsets.symmetric(horizontal: 4),
          prefix: const Padding(
            padding: EdgeInsets.only(left: 12),
            child: Icon(CupertinoIcons.search, size: 18, color: CupertinoColors.systemGrey),
          ),
          suffix: _textController.text.isNotEmpty
              ? GestureDetector(
                  onTap: _cancelSearch,
                  child: const Padding(
                    padding: EdgeInsets.only(right: 8),
                    child: Icon(CupertinoIcons.xmark_circle_fill, size: 18, color: CupertinoColors.systemGrey),
                  ),
                )
              : null,
          onChanged: _onSearchChanged,
          onSubmitted: (text) {
            if (_results.isNotEmpty) {
              _selectStation(_results.first);
            }
          },
        ),
      ),
    );
  }

  Widget _buildProfileButton() {
    return CNButton.icon(
      customIcon: CupertinoIcons.person_fill,
      onPressed: widget.onProfileTap ?? () {},
      config: const CNButtonConfig(
        style: CNButtonStyle.glass,
        minHeight: 40,
        width: 40,
        customIconSize: 18,
      ),
    );
  }

  Widget _buildSearchResults() {
    return Container(
      constraints: const BoxConstraints(maxHeight: 280),
      decoration: BoxDecoration(
        color: const Color(0xE6101020),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: ListView.separated(
          padding: const EdgeInsets.symmetric(vertical: 4),
          shrinkWrap: true,
          itemCount: _results.length,
          separatorBuilder: (_, __) => const Divider(
            height: 1,
            indent: 44,
            color: Colors.white10,
          ),
          itemBuilder: (context, index) {
            final r = _results[index];
            return _buildResultTile(r);
          },
        ),
      ),
    );
  }

  Widget _buildResultTile(_SearchResult result) {
    final hasTransfer = result.station.transferLines.isNotEmpty;

    return GestureDetector(
      onTap: () => _selectStation(result),
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            // 노선 색상 인디케이터
            Container(
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                color: result.lineColor,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  _lineShortName(result.lineName),
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            // 역명 + 부가정보
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    result.station.name,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  if (hasTransfer)
                    Text(
                      '환승: ${result.station.transferLines.map((id) => SubwayColors.lineNames[id] ?? id).join(', ')}',
                      style: const TextStyle(fontSize: 10, color: Colors.white38),
                    ),
                ],
              ),
            ),
            // 노선명
            Text(
              result.lineName,
              style: TextStyle(fontSize: 11, color: result.lineColor),
            ),
          ],
        ),
      ),
    );
  }

  String _lineShortName(String lineName) {
    // "1호선" → "1", "경의중앙" → "경의"
    if (lineName.endsWith('호선')) {
      return lineName.replaceAll('호선', '');
    }
    if (lineName.length > 2) return lineName.substring(0, 2);
    return lineName;
  }
}
