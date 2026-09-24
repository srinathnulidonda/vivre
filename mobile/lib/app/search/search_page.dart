// lib/app/search/search_page.dart
import 'dart:async';

import 'package:flutter/material.dart';

import '../../api/shared/shared_api.dart';
import '../../themes/color-palette.dart';
import '../../widgets/skeleton_loader.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  Timer? _debounce;
  List<SearchResult> _results = const [];
  bool _isLoading = false;
  bool _hasSearched = false;
  int _requestId = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    final String query = value.trim();
    if (query.isEmpty) {
      setState(() {
        _results = const [];
        _isLoading = false;
        _hasSearched = false;
      });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 300), () {
      _performSearch(query);
    });
  }

  Future<void> _performSearch(String query) async {
    final int id = ++_requestId;
    setState(() {
      _isLoading = true;
      _hasSearched = true;
    });

    try {
      final List<SearchResult> results =
          await SharedApi().search(query, limit: 50);
      if (!mounted || id != _requestId) return;
      setState(() {
        _results = results;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted || id != _requestId) return;
      setState(() {
        _results = const [];
        _isLoading = false;
      });
    }
  }

  void _clear() {
    _controller.clear();
    _debounce?.cancel();
    setState(() {
      _results = const [];
      _isLoading = false;
      _hasSearched = false;
    });
    _focusNode.requestFocus();
  }

  Map<String, List<SearchResult>> get _grouped {
    const List<String> order = [
      'note',
      'task',
      'project',
      'goal',
      'habit',
      'journal_entry',
      'event',
      'client',
    ];
    final Map<String, List<SearchResult>> groups =
        <String, List<SearchResult>>{};
    for (final String key in order) {
      final List<SearchResult> matching = _results
          .where((SearchResult r) => r.resultType == key)
          .toList();
      if (matching.isNotEmpty) groups[key] = matching;
    }
    return groups;
  }

  @override
  Widget build(BuildContext context) {
    final VivreColors colors = context.colors;
    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          color: colors.textPrimary,
        ),
        titleSpacing: 0,
        title: Container(
          height: 44,
          decoration: BoxDecoration(
            color: colors.surfaceSoft,
            borderRadius: BorderRadius.circular(22),
          ),
          child: TextField(
            controller: _controller,
            focusNode: _focusNode,
            onChanged: _onChanged,
            textInputAction: TextInputAction.search,
            onSubmitted: (String value) {
              final String query = value.trim();
              if (query.isEmpty) return;
              _debounce?.cancel();
              _performSearch(query);
            },
            style: TextStyle(
              fontSize: 15,
              color: colors.textPrimary,
            ),
            decoration: InputDecoration(
              hintText: 'Search notes, tasks, goals…',
              hintStyle: TextStyle(
                fontSize: 15,
                color: colors.textMuted,
              ),
              prefixIcon: Icon(
                Icons.search_rounded,
                size: 20,
                color: colors.textMuted,
              ),
              suffixIcon: _controller.text.isEmpty
                  ? null
                  : GestureDetector(
                      onTap: _clear,
                      child: Icon(
                        Icons.close_rounded,
                        size: 18,
                        color: colors.textMuted,
                      ),
                    ),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),
        actions: const [SizedBox(width: 16)],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (!_hasSearched && _controller.text.isEmpty) {
      return const _SearchHint();
    }
    if (_isLoading && _results.isEmpty) {
      return const _SearchSkeleton();
    }
    if (_results.isEmpty) {
      return _NoResults(query: _controller.text.trim());
    }

    final Map<String, List<SearchResult>> groups = _grouped;
    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        for (final MapEntry<String, List<SearchResult>> entry in groups.entries)
          _GroupSection(
            type: entry.key,
            results: entry.value,
          ),
      ],
    );
  }
}

class _GroupSection extends StatelessWidget {
  final String type;
  final List<SearchResult> results;

  const _GroupSection({required this.type, required this.results});

  static const Map<String, (String, IconData)> _labels = {
    'note': ('Notes', Icons.description_outlined),
    'project': ('Projects', Icons.folder_outlined),
    'task': ('Tasks', Icons.check_circle_outline_rounded),
    'goal': ('Goals', Icons.flag_outlined),
    'habit': ('Habits', Icons.eco_outlined),
    'journal_entry': ('Journal', Icons.menu_book_outlined),
    'event': ('Events', Icons.calendar_today_outlined),
    'client': ('Clients', Icons.business_outlined),
  };

  @override
  Widget build(BuildContext context) {
    final VivreColors colors = context.colors;
    final (String label, IconData icon) =
        _labels[type] ?? ('Results', Icons.search_rounded);

    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 10),
            child: Row(
              children: [
                Icon(icon, size: 14, color: colors.textMuted),
                const SizedBox(width: 6),
                Text(
                  label.toUpperCase(),
                  style: TextStyle(
                    color: colors.textMuted,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${results.length}',
                  style: TextStyle(
                    color: colors.textMuted,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: colors.border, width: 1),
            ),
            child: Column(
              children: [
                for (int i = 0; i < results.length; i++)
                  _ResultRow(
                    result: results[i],
                    showDivider: i < results.length - 1,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ResultRow extends StatelessWidget {
  final SearchResult result;
  final bool showDivider;

  const _ResultRow({required this.result, required this.showDivider});

  @override
  Widget build(BuildContext context) {
    final VivreColors colors = context.colors;
    return Column(
      children: [
        InkWell(
          onTap: () {},
          borderRadius: BorderRadius.circular(18),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        result.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: colors.textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          height: 1.3,
                        ),
                      ),
                      if (result.snippet != null &&
                          result.snippet!.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          result.snippet!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: colors.textSecondary,
                            fontSize: 12.5,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  Icons.chevron_right_rounded,
                  size: 20,
                  color: colors.textMuted,
                ),
              ],
            ),
          ),
        ),
        if (showDivider)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Divider(color: colors.border, height: 1, thickness: 0.6),
          ),
      ],
    );
  }
}

class _SearchHint extends StatelessWidget {
  const _SearchHint();

  @override
  Widget build(BuildContext context) {
    final VivreColors colors = context.colors;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: colors.primarySoft,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.search_rounded,
                color: colors.primary,
                size: 30,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'Search everything',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: colors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Find notes, tasks, projects, goals, habits, journal entries, events, and clients — all in one place.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13.5,
                color: colors.textSecondary,
                height: 1.45,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NoResults extends StatelessWidget {
  final String query;

  const _NoResults({required this.query});

  @override
  Widget build(BuildContext context) {
    final VivreColors colors = context.colors;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.search_off_rounded,
              size: 44,
              color: colors.textMuted,
            ),
            const SizedBox(height: 14),
            Text(
              'No matches for \u201C$query\u201D',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: colors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Try a different word or check your spelling.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13.5,
                color: colors.textSecondary,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SearchSkeleton extends StatelessWidget {
  const _SearchSkeleton();

  @override
  Widget build(BuildContext context) {
    return SkeletonLoader(
      isLoading: true,
      child: ListView(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: const [
          SkeletonBox(width: 90, height: 12, borderRadius: 6),
          SizedBox(height: 12),
          SkeletonBox(height: 56, borderRadius: 14),
          SizedBox(height: 10),
          SkeletonBox(height: 56, borderRadius: 14),
          SizedBox(height: 24),
          SkeletonBox(width: 90, height: 12, borderRadius: 6),
          SizedBox(height: 12),
          SkeletonBox(height: 56, borderRadius: 14),
        ],
      ),
    );
  }
}