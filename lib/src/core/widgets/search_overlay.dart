import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:logger/logger.dart';

import '../../app/theme/app_colors.dart';

final _logger = Logger();

class SearchOverlay extends StatefulWidget {
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
  State<SearchOverlay> createState() => _SearchOverlayState();
}

class _SearchOverlayState extends State<SearchOverlay>
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

  void _onSearchChanged() {
    setState(() {
      _suggestions.clear();
    });

    _debounceTimer?.cancel();

    final query = _searchController.text.trim();
    if (query.isEmpty) {
      return;
    }

    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      _fetchSuggestions(query);
    });
  }

  Future<void> _fetchSuggestions(String query) async {
    _logger.i('Fetching suggestions for query: $query');

    if (!mounted || query != _searchController.text.trim()) return;

    if (_lastRequestQuery == query) {
      _logger.d('Skipping duplicate request for query: $query');
      return;
    }
    _lastRequestQuery = query;

    try {
      _logger.d('Making API request to Google Suggestions API');

      final response = await _dio.get(
        'https://suggestqueries.google.com/complete/search',
        queryParameters: {'client': 'firefox', 'q': query, 'hl': 'en'},
        options: Options(responseType: ResponseType.plain),
      );

      _logger.d('API Response status: ${response.statusCode}');
      _logger.d('API Response data: ${response.data}');

      if (!mounted || query != _searchController.text.trim()) return;

      final jsonpString = response.data as String;
      final suggestions = _parseSuggestions(jsonpString);

      _logger.i('Parsed ${suggestions.length} suggestions from API');

      if (mounted && query == _searchController.text.trim()) {
        setState(() {
          _suggestions = suggestions.take(5).toList();
        });
        _logger.i('Set ${_suggestions.length} suggestions in UI');
      }
    } catch (e, stackTrace) {
      _logger.e('Error fetching suggestions', error: e, stackTrace: stackTrace);
    }
  }

  List<String> _parseSuggestions(String jsonpString) {
    _logger.d('Parsing suggestions from JSONP response');
    _logger.d('JSONP string length: ${jsonpString.length}');

    try {
      final startIndex = jsonpString.indexOf('[');
      final endIndex = jsonpString.lastIndexOf(']');

      if (startIndex == -1 || endIndex == -1 || startIndex >= endIndex) {
        _logger.w('Invalid JSON array boundaries');
        return [];
      }

      final jsonString = jsonpString.substring(startIndex, endIndex + 1);
      _logger.d(
        'Extracted JSON: ${jsonString.substring(0, jsonString.length > 100 ? 100 : jsonString.length)}...',
      );

      // Structure: ["query", ["suggestion1", "suggestion2", ...], [], {...}]
      // Find the second array (suggestions array)
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
        _logger.w('Could not find suggestions array');
        return [];
      }

      _logger.d('Found suggestions array starting at index: $secondArrayStart');

      // Find the end of the suggestions array
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
        _logger.w('Could not find end of suggestions array');
        return [];
      }

      final suggestionsStr = jsonString.substring(
        secondArrayStart + 1,
        suggestionsEnd,
      );
      _logger.d(
        'Suggestions substring: ${suggestionsStr.substring(0, suggestionsStr.length > 100 ? 100 : suggestionsStr.length)}...',
      );

      final suggestions = <String>[];

      // Extract all quoted strings
      RegExp regExp = RegExp(r'"([^"]*)"');
      final matches = regExp.allMatches(suggestionsStr);

      _logger.d('Found ${matches.length} regex matches');

      for (final match in matches) {
        var suggestion = match.group(1) ?? '';
        if (suggestion.isNotEmpty &&
            suggestion != _searchController.text.trim()) {
          // Decode Unicode escape sequences
          try {
            suggestion = json.decode('"$suggestion"') as String;
          } catch (_) {
            // If decoding fails, use the original string
          }
          suggestions.add(suggestion);
          _logger.d('Added suggestion: $suggestion');
        }
      }

      _logger.i('Successfully parsed ${suggestions.length} valid suggestions');
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
    widget.onSearch?.call(suggestion.trim());
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
                            padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: AppColors.cardSurface,
                                      borderRadius: BorderRadius.circular(14),
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
                                                    horizontal: 16,
                                                    vertical: 16,
                                                  ),
                                              isDense: false,
                                              filled: false,
                                            ),
                                            textInputAction:
                                                TextInputAction.search,
                                            onSubmitted: (value) {
                                              if (value.trim().isNotEmpty) {
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
                                              size: 20,
                                            ),
                                            color: AppColors.textMid,
                                            padding: const EdgeInsets.all(8),
                                            constraints: const BoxConstraints(
                                              minWidth: 36,
                                              minHeight: 36,
                                            ),
                                            onPressed: () {
                                              _searchController.clear();
                                            },
                                          ),
                                        const SizedBox(width: 4),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Container(
                                  decoration: BoxDecoration(
                                    color: AppColors.primary,
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: IconButton(
                                    icon: const Icon(Icons.search, size: 24),
                                    color: AppColors.black,
                                    padding: const EdgeInsets.all(12),
                                    constraints: const BoxConstraints(
                                      minWidth: 48,
                                      minHeight: 48,
                                    ),
                                    onPressed: () {
                                      final value = _searchController.text
                                          .trim();
                                      if (value.isNotEmpty) {
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
    return Container(
      color: AppColors.black,
      child: Column(
        children: [
          ...(_suggestions.asMap().entries.map((entry) {
            final isLast = entry.key == _suggestions.length - 1;
            return Column(
              children: [
                _buildSuggestionItem(entry.value),
                if (!isLast) Container(height: 1, color: AppColors.outline),
              ],
            );
          }).toList()),
          Container(height: 1, color: AppColors.outline),
        ],
      ),
    );
  }

  Widget _buildSuggestionItem(String suggestion) {
    return GestureDetector(
      onTap: () => _selectSuggestion(suggestion),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
        child: Row(
          children: [
            const Icon(Icons.search, size: 16, color: AppColors.textMid),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
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
          ],
        ),
      ),
    );
  }
}
