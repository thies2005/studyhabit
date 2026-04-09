import 'dart:async';
import 'dart:io';

import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';

import '../../../core/database/app_database.dart';
import '../../../core/providers/database_provider.dart';
import '../subjects/detail/sources/source_providers.dart';

class PdfViewerScreen extends ConsumerStatefulWidget {
  const PdfViewerScreen({
    super.key,
    required this.subjectId,
    required this.sourceId,
  });

  final String subjectId;
  final String sourceId;

  @override
  ConsumerState<PdfViewerScreen> createState() => _PdfViewerScreenState();
}

class _PdfViewerScreenState extends ConsumerState<PdfViewerScreen> {
  late final PdfViewerController _controller;
  Timer? _debounce;
  bool _isLoading = true;
  int? _startPage;

  @override
  void initState() {
    super.initState();
    _controller = PdfViewerController();
  }

  @override
  void dispose() {
    _savePagePosition();
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _savePagePosition() {
    try {
      final page = _controller.pageNumber;
      if (page > 0) {
        final endPage = page;
        ref
            .read(sourceProvider(widget.subjectId).notifier)
            .updateProgress(
              widget.sourceId,
              currentPage: page,
              progressPercent: null,
            );

        // Update session page range if startPage was recorded
        if (_startPage != null && _startPage != endPage) {
          // TODO: Update session with startPage and endPage when session tracking is implemented
          debugPrint('Page range: $_startPage - $endPage');
        }
      }
    } catch (e) {
      debugPrint('Error saving page position: $e');
    }
  }

  void _onPageChanged(PdfPageChangedDetails details) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(seconds: 3), () {
      try {
        ref
            .read(sourceProvider(widget.subjectId).notifier)
            .updateProgress(
              widget.sourceId,
              currentPage: details.newPageNumber,
              progressPercent: null,
            );
      } catch (e) {
        debugPrint('Error updating progress: $e');
      }
    });
  }

  void _onDocumentLoaded(PdfDocumentLoadedDetails details) {
    if (!mounted) return;
    setState(() => _isLoading = false);

    try {
      final totalPages = details.document.pages.count;
      if (totalPages > 0) {
        final db = ref.read(appDatabaseProvider);
        (db.update(db.sources)..where((t) => t.id.equals(widget.sourceId)))
            .write(SourcesCompanion(totalPages: Value(totalPages)));
      }
    } catch (e) {
      debugPrint('Error updating total pages: $e');
    }
  }

  void _goToPreviousPage() {
    final currentPage = _controller.pageNumber;
    if (currentPage > 1) {
      _controller.previousPage();
    }
  }

  void _goToNextPage(int? totalPages) {
    if (totalPages != null && _controller.pageNumber < totalPages) {
      _controller.nextPage();
    }
  }

  @override
  Widget build(BuildContext context) {
    final sourceAsync = ref.watch(sourceByIdProvider(widget.sourceId));
    final colorScheme = Theme.of(context).colorScheme;

    return sourceAsync.when(
      loading: () => Scaffold(
        appBar: AppBar(title: const Text('Loading PDF...')),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (error, _) => Scaffold(
        appBar: AppBar(title: const Text('Error')),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, size: 48, color: colorScheme.error),
              const SizedBox(height: 12),
              Text(
                'Failed to load source',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            ],
          ),
        ),
      ),
      data: (source) {
        final filePath = source.filePath;
        if (filePath == null) {
          return Scaffold(
            appBar: AppBar(title: Text(source.title)),
            body: Center(
              child: Text(
                'File path not available',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            ),
          );
        }

        final currentPage = source.currentPage ?? 1;
        final totalPages = source.totalPages;

        // Initialize startPage tracking
        _startPage ??= currentPage;

        return Scaffold(
          appBar: AppBar(
            title: Text(source.title),
          ),
          body: Stack(
            children: [
              SfPdfViewer.file(
                File(filePath),
                controller: _controller,
                initialPageNumber: currentPage,
                onPageChanged: _onPageChanged,
                onDocumentLoaded: _onDocumentLoaded,
              ),
              if (_isLoading)
                const Positioned.fill(
                  child: Center(child: CircularProgressIndicator()),
                ),
            ],
          ),
          bottomNavigationBar: BottomAppBar(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: _goToPreviousPage,
                  tooltip: 'Previous page',
                ),
                Text(
                  totalPages != null
                      ? '$currentPage / $totalPages'
                      : 'Page $currentPage',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                IconButton(
                  icon: const Icon(Icons.arrow_forward),
                  onPressed: () => _goToNextPage(totalPages),
                  tooltip: 'Next page',
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
