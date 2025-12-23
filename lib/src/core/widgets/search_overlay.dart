import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';

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

  @override
  void initState() {
    super.initState();
    _searchController.text = widget.initialQuery;
    _searchController.addListener(() {
      setState(() {});
    });
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
    super.dispose();
  }

  Future<void> _close() async {
    _focusNode.unfocus();
    await _animationController.reverse();
    final currentText = _searchController.text;
    if (widget.onClose != null) {
      widget.onClose!(currentText);
    }
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
                          Container(height: 1, color: AppColors.outline),
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
}
