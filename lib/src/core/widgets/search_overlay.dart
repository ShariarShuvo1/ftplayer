import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:logger/logger.dart';

import '../../app/theme/app_colors.dart';
import '../../core/utils/vibration_helper.dart';
import '../../state/settings/vibration_settings_provider.dart';
import '../storage/search_history_storage.dart';

final _logger = Logger();

class SearchOverlay extends ConsumerStatefulWidget {
  final ValueChanged<String>? onClose;
  final ValueChanged<String>? onSearch;
  final String initialQuery;

  const SearchOverlay({
    super.key,
    required this.onClose,
    this.onSearch,
    this.initialQuery = '',
  });

  @override
  ConsumerState<SearchOverlay> createState() => _SearchOverlayState();
}

class _SearchOverlayState extends ConsumerState<SearchOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _slideAnimation;
  late Animation<double> _fadeAnimation;
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  List<String> _suggestions = [];
  Timer? _debounceTimer;
  String? _lastRequestQuery;
  final Dio _dio = Dio();
  final SearchHistoryStorage _searchHistory = SearchHistoryStorage();

  @override
  void initState() {
    super.initState();
    _searchController.text = widget.initialQuery;
    _searchController.addListener(_onSearchChanged);
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _slideAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
      ),
    );
    _animationController.forward();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
      _initSearchHistory();
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    _searchController.dispose();
    _focusNode.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  Future<void> _initSearchHistory() async {
    await _searchHistory.init();
    if (mounted && _searchController.text.trim().isEmpty) {
      setState(() {
        _suggestions = _searchHistory.getSearchHistory();
      });
    }
  }

  void _onSearchChanged() {
    setState(() {
      _suggestions.clear();
    });

    _debounceTimer?.cancel();

    final query = _searchController.text.trim();
    if (query.isEmpty) {
      setState(() {
        _suggestions = _searchHistory.getSearchHistory();
      });
      return;
    }

    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      _fetchSuggestions(query);
    });
  }

  Future<void> _fetchSuggestions(String query) async {
    if (!mounted || query != _searchController.text.trim()) return;

    if (_lastRequestQuery == query) {
      return;
    }
    _lastRequestQuery = query;

    try {
      final response = await _dio.get(
        'https://suggestqueries.google.com/complete/search',
        queryParameters: {'client': 'firefox', 'q': query, 'hl': 'en'},
        options: Options(responseType: ResponseType.plain),
      );

      if (!mounted || query != _searchController.text.trim()) return;

      final jsonpString = response.data as String;
      final googleSuggestions = _parseSuggestions(jsonpString);
      final matchingHistory = _searchHistory.getMatchingHistory(query);

      final mergedSuggestions = <String>[
        ...matchingHistory,
        ...googleSuggestions.where((s) => !matchingHistory.contains(s)),
      ];

      if (mounted && query == _searchController.text.trim()) {
        setState(() {
          _suggestions = mergedSuggestions.take(5).toList();
        });
      }
    } catch (e, stackTrace) {
      _logger.e('Error fetching suggestions', error: e, stackTrace: stackTrace);
    }
  }

  List<String> _parseSuggestions(String jsonpString) {
    try {
      final startIndex = jsonpString.indexOf('[');
      final endIndex = jsonpString.lastIndexOf(']');

      if (startIndex == -1 || endIndex == -1 || startIndex >= endIndex) {
        return [];
      }

      final jsonString = jsonpString.substring(startIndex, endIndex + 1);

      int firstArrayStart = jsonString.indexOf('[');
      int depth = 0;
      int secondArrayStart = -1;

      for (int i = firstArrayStart; i < jsonString.length; i++) {
        if (jsonString[i] == '[') {
          depth++;
          if (depth == 2) {
            secondArrayStart = i;
            break;
          }
        } else if (jsonString[i] == ']') {
          depth--;
        }
      }

      if (secondArrayStart == -1) {
        return [];
      }

      int suggestionsEnd = -1;
      depth = 0;
      for (int i = secondArrayStart; i < jsonString.length; i++) {
        if (jsonString[i] == '[') {
          depth++;
        } else if (jsonString[i] == ']') {
          depth--;
          if (depth == 0) {
            suggestionsEnd = i;
            break;
          }
        }
      }

      if (suggestionsEnd == -1) {
        return [];
      }

      final suggestionsStr = jsonString.substring(
        secondArrayStart + 1,
        suggestionsEnd,
      );

      final suggestions = <String>[];

      RegExp regExp = RegExp(r'"([^"]*)"');
      final matches = regExp.allMatches(suggestionsStr);

      for (final match in matches) {
        var suggestion = match.group(1) ?? '';
        if (suggestion.isNotEmpty &&
            suggestion != _searchController.text.trim()) {
          try {
            suggestion = json.decode('"$suggestion"') as String;
          } catch (e) {
            _logger.e('Error decoding suggestion: $e');
          }
          suggestions.add(suggestion);
        }
      }

      return suggestions;
    } catch (e, stackTrace) {
      _logger.e('Error parsing suggestions', error: e, stackTrace: stackTrace);
    }

    return [];
  }

  Future<void> _close() async {
    _focusNode.unfocus();
    await _animationController.reverse();
    final currentText = _searchController.text;
    if (widget.onClose != null) {
      widget.onClose!(currentText);
    }
  }

  void _selectSuggestion(String suggestion) {
    _searchController.text = suggestion;
    _suggestions.clear();
    setState(() {});
    _searchHistory.addSearchKeyword(suggestion.trim());
    widget.onSearch?.call(suggestion.trim());
  }

  Widget _buildHighlightedText(String text, String query) {
    if (query.isEmpty) {
      return Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: AppColors.textHigh,
          fontSize: 14,
          fontWeight: FontWeight.w400,
        ),
      );
    }

    final lowerText = text.toLowerCase();
    final lowerQuery = query.toLowerCase();
    final startIndex = lowerText.indexOf(lowerQuery);

    if (startIndex == -1) {
      return Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: AppColors.textHigh,
          fontSize: 14,
          fontWeight: FontWeight.w400,
        ),
      );
    }

    final endIndex = startIndex + query.length;

    return RichText(
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      text: TextSpan(
        children: [
          TextSpan(
            text: text.substring(0, startIndex),
            style: const TextStyle(
              color: AppColors.textHigh,
              fontSize: 14,
              fontWeight: FontWeight.w400,
            ),
          ),
          TextSpan(
            text: text.substring(startIndex, endIndex),
            style: const TextStyle(
              color: AppColors.primary,
              fontSize: 14,
              fontWeight: FontWeight.w400,
            ),
          ),
          TextSpan(
            text: text.substring(endIndex),
            style: const TextStyle(
              color: AppColors.textHigh,
              fontSize: 14,
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _close,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: Container(
          color: Colors.black.withValues(alpha: 0.85),
          child: Column(
            children: [
              GestureDetector(
                onTap: () {},
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0, -1),
                    end: Offset.zero,
                  ).animate(_slideAnimation),
                  child: Container(
                    decoration: const BoxDecoration(color: AppColors.black),
                    child: SafeArea(
                      bottom: false,
                      child: Column(
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(8, 8, 8, 12),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: AppColors.cardSurface,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: AppColors.outline,
                                        width: 1,
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: TextField(
                                            controller: _searchController,
                                            focusNode: _focusNode,
                                            style: const TextStyle(
                                              color: AppColors.textHigh,
                                              fontSize: 15,
                                              fontWeight: FontWeight.w500,
                                            ),
                                            decoration: const InputDecoration(
                                              hintText:
                                                  'Search movies, series...',
                                              hintStyle: TextStyle(
                                                color: AppColors.textLow,
                                                fontSize: 15,
                                                fontWeight: FontWeight.w400,
                                              ),
                                              border: InputBorder.none,
                                              enabledBorder: InputBorder.none,
                                              focusedBorder: InputBorder.none,
                                              contentPadding:
                                                  EdgeInsets.symmetric(
                                                    horizontal: 14,
                                                    vertical: 12,
                                                  ),
                                              isDense: true,
                                              filled: false,
                                            ),
                                            textInputAction:
                                                TextInputAction.search,
                                            onSubmitted: (value) {
                                              if (value.trim().isNotEmpty) {
                                                _searchHistory.addSearchKeyword(
                                                  value.trim(),
                                                );
                                                widget.onSearch?.call(
                                                  value.trim(),
                                                );
                                              }
                                            },
                                          ),
                                        ),
                                        if (_searchController.text.isNotEmpty)
                                          IconButton(
                                            icon: const Icon(
                                              Icons.close,
                                              size: 18,
                                            ),
                                            color: AppColors.textMid,
                                            padding: const EdgeInsets.all(6),
                                            constraints: const BoxConstraints(
                                              minWidth: 32,
                                              minHeight: 32,
                                            ),
                                            onPressed: () {
                                              final vibrationSettings = ref
                                                  .read(
                                                    vibrationSettingsProvider,
                                                  );
                                              if (vibrationSettings.enabled &&
                                                  vibrationSettings
                                                      .vibrateOnAppbar) {
                                                VibrationHelper.vibrate(
                                                  vibrationSettings.strength,
                                                );
                                              }
                                              _searchController.clear();
                                            },
                                          ),
                                        const SizedBox(width: 4),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Container(
                                  decoration: BoxDecoration(
                                    color: AppColors.primary,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: IconButton(
                                    icon: const Icon(Icons.search, size: 22),
                                    color: AppColors.black,
                                    padding: const EdgeInsets.all(10),
                                    constraints: const BoxConstraints(
                                      minWidth: 44,
                                      minHeight: 44,
                                    ),
                                    onPressed: () {
                                      final value = _searchController.text
                                          .trim();
                                      if (value.isNotEmpty) {
                                        final vibrationSettings = ref.read(
                                          vibrationSettingsProvider,
                                        );
                                        if (vibrationSettings.enabled &&
                                            vibrationSettings.vibrateOnAppbar) {
                                          VibrationHelper.vibrate(
                                            vibrationSettings.strength,
                                          );
                                        }
                                        _searchHistory.addSearchKeyword(value);
                                        widget.onSearch?.call(value);
                                      }
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (_suggestions.isNotEmpty) _buildSuggestionsPanel(),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSuggestionsPanel() {
    final query = _searchController.text.trim();
    final matchingHistory = query.isEmpty
        ? _searchHistory.getSearchHistory()
        : _searchHistory.getMatchingHistory(query);

    return Container(
      color: AppColors.black,
      child: Column(
        children: [
          ...(_suggestions.asMap().entries.map((entry) {
            final isLast = entry.key == _suggestions.length - 1;
            final isFromHistory = matchingHistory.contains(entry.value);
            return Column(
              children: [
                _buildSuggestionItem(entry.value, isFromHistory, query),
                if (!isLast) Container(height: 1, color: AppColors.outline),
              ],
            );
          }).toList()),
          Container(height: 1, color: AppColors.outline),
        ],
      ),
    );
  }

  Widget _buildSuggestionItem(
    String suggestion,
    bool isFromHistory,
    String query,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
      child: Row(
        children: [
          Icon(
            isFromHistory ? Icons.history : Icons.search,
            size: 16,
            color: AppColors.textMid,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: GestureDetector(
              onTap: () {
                final vibrationSettings = ref.read(vibrationSettingsProvider);
                if (vibrationSettings.enabled &&
                    vibrationSettings.vibrateOnAppbar) {
                  VibrationHelper.vibrate(vibrationSettings.strength);
                }
                _selectSuggestion(suggestion);
              },
              child: isFromHistory && query.isNotEmpty
                  ? _buildHighlightedText(suggestion, query)
                  : Text(
                      suggestion,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.textHigh,
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () {
              final vibrationSettings = ref.read(vibrationSettingsProvider);
              if (vibrationSettings.enabled &&
                  vibrationSettings.vibrateOnAppbar) {
                VibrationHelper.vibrate(vibrationSettings.strength);
              }
              _searchController.text = suggestion;
              setState(() {});
            },
            child: Icon(Icons.edit, size: 16, color: AppColors.textMid),
          ),
        ],
      ),
    );
  }
}
