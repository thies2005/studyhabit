import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/models/enums.dart';
import '../../../../core/models/source.dart';
import '../../subject_providers.dart';
import '../topics/chapter_providers.dart';
import '../topics/topic_providers.dart';
import 'source_providers.dart';

class SourcesTab extends ConsumerWidget {
  const SourcesTab({super.key, required this.subjectId});

  final String subjectId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sourcesAsync = ref.watch(sourceListProvider(subjectId));

    return sourcesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(
        child: Text(
          'Failed to load sources',
          style: Theme.of(context).textTheme.bodyLarge,
        ),
      ),
      data: (sources) {
        if (sources.isEmpty) {
          return _EmptySources(onAdd: () => _showAddSheet(context, ref));
        }

        final subjectAsync = ref.watch(subjectByIdProvider(subjectId));
        HierarchyMode hierarchyMode = HierarchyMode.flat;
        subjectAsync.whenData((s) {
          if (s != null) hierarchyMode = s.hierarchyMode;
        });

        return _SourcesGrid(
          sources: sources,
          subjectId: subjectId,
          hierarchyMode: hierarchyMode,
        );
      },
    );
  }

  void _showAddSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => AddSourceBottomSheet(subjectId: subjectId),
    );
  }
}

class _EmptySources extends StatelessWidget {
  const _EmptySources({required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.source_outlined,
            size: 48,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 12),
          Text(
            'No sources yet',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Add PDFs, links, or videos',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.tonal(onPressed: onAdd, child: const Text('Add Source')),
        ],
      ),
    );
  }
}

class _SourcesGrid extends StatelessWidget {
  const _SourcesGrid({
    required this.sources,
    required this.subjectId,
    required this.hierarchyMode,
  });

  final List<Source> sources;
  final String subjectId;
  final HierarchyMode hierarchyMode;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: () => showModalBottomSheet<void>(
          context: context,
          isScrollControlled: true,
          useSafeArea: true,
          builder: (_) => AddSourceBottomSheet(subjectId: subjectId),
        ),
        child: const Icon(Icons.add),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final crossAxisCount = constraints.maxWidth >= 600 ? 3 : 2;

          return GridView.builder(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossAxisCount,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: 0.85,
            ),
            itemCount: sources.length,
            itemBuilder: (context, index) {
              final source = sources[index];
              return switch (source.type) {
                SourceType.pdf => _PdfSourceCard(
                  source: source,
                  subjectId: subjectId,
                ),
                SourceType.url => _UrlSourceCard(
                  source: source,
                  subjectId: subjectId,
                ),
                SourceType.videoUrl => _UrlSourceCard(
                  source: source,
                  subjectId: subjectId,
                ),
              };
            },
          );
        },
      ),
    );
  }
}

class _PdfSourceCard extends StatelessWidget {
  const _PdfSourceCard({required this.source, required this.subjectId});

  final Source source;
  final String subjectId;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final currentPage = source.currentPage ?? 1;
    final totalPages = source.totalPages;
    final progress = (totalPages != null && totalPages > 0)
        ? currentPage / totalPages
        : 0.0;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.pushNamed(
          'pdf-viewer',
          pathParameters: {'subjectId': subjectId, 'sourceId': source.id},
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 4),
              Icon(Icons.picture_as_pdf, size: 32, color: colorScheme.error),
              const SizedBox(height: 8),
              Text(
                source.title,
                style: textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const Spacer(),
              LinearProgressIndicator(value: progress.clamp(0.0, 1.0)),
              const SizedBox(height: 4),
              Text(
                totalPages != null
                    ? '$currentPage / $totalPages'
                    : 'Page $currentPage',
                style: textTheme.labelSmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _UrlSourceCard extends ConsumerStatefulWidget {
  const _UrlSourceCard({required this.source, required this.subjectId});

  final Source source;
  final String subjectId;

  @override
  ConsumerState<_UrlSourceCard> createState() => _UrlSourceCardState();
}

class _UrlSourceCardState extends ConsumerState<_UrlSourceCard> {
  double _progress = 0.0;

  @override
  void initState() {
    super.initState();
    _progress = widget.source.progressPercent ?? 0.0;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final isVideo = widget.source.type == SourceType.videoUrl;

    final domain = _extractDomain(widget.source.url ?? '');
    final firstLetter = domain.isNotEmpty ? domain[0].toUpperCase() : '?';

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: colorScheme.primaryContainer,
                  child: Text(
                    firstLetter,
                    style: TextStyle(
                      color: colorScheme.onPrimaryContainer,
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                ),
                const Spacer(),
                if (widget.source.url != null)
                  IconButton(
                    icon: Icon(
                      Icons.open_in_new,
                      size: 16,
                      color: colorScheme.outline,
                    ),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: () => _launchUrl(widget.source.url!),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              widget.source.title,
              style: textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            if (domain.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(
                domain,
                style: textTheme.labelSmall?.copyWith(
                  color: colorScheme.outline,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            const Spacer(),
            Text(
              isVideo ? 'Progress' : 'Progress',
              style: textTheme.labelSmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                activeTrackColor: colorScheme.primary,
                thumbColor: colorScheme.primary,
                inactiveTrackColor: colorScheme.surfaceContainerHighest,
                trackHeight: 4,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
              ),
              child: Slider(
                value: _progress,
                min: 0,
                max: 100,
                divisions: 100,
                label: '${_progress.round()}%',
                onChanged: (v) => setState(() => _progress = v),
                onChangeEnd: (v) {
                  ref
                      .read(sourceProvider(widget.subjectId).notifier)
                      .updateProgress(widget.source.id, progressPercent: v);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _extractDomain(String url) {
    try {
      final uri = Uri.parse(url);
      return uri.host.replaceFirst('www.', '');
    } catch (_) {
      return '';
    }
  }

  Future<void> _launchUrl(String url) async {
    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      debugPrint('Error launching URL: $e');
    }
  }
}

class AddSourceBottomSheet extends ConsumerStatefulWidget {
  const AddSourceBottomSheet({super.key, required this.subjectId});

  final String subjectId;

  @override
  ConsumerState<AddSourceBottomSheet> createState() =>
      _AddSourceBottomSheetState();
}

class _AddSourceBottomSheetState extends ConsumerState<AddSourceBottomSheet> {
  SourceType _selectedType = SourceType.pdf;
  final _titleController = TextEditingController();
  final _urlController = TextEditingController();
  String? _pickedFilePath;
  String? _pickedFileName;
  int? _totalPages;
  String? _selectedTopicId;
  String? _selectedChapterId;
  bool _isLoading = false;

  @override
  void dispose() {
    _titleController.dispose();
    _urlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final subjectAsync = ref.watch(subjectByIdProvider(widget.subjectId));
    HierarchyMode hierarchyMode = HierarchyMode.flat;
    subjectAsync.whenData((s) {
      if (s != null) hierarchyMode = s.hierarchyMode;
    });

    final showTopicPicker = hierarchyMode != HierarchyMode.flat;
    final showChapterPicker = hierarchyMode == HierarchyMode.threeLevel;

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.5,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, scrollController) {
        return SingleChildScrollView(
          controller: scrollController,
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Add Source', style: textTheme.titleLarge),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              SegmentedButton<SourceType>(
                segments: const [
                  ButtonSegment(
                    value: SourceType.pdf,
                    icon: Icon(Icons.picture_as_pdf, size: 18),
                    label: Text('PDF'),
                  ),
                  ButtonSegment(
                    value: SourceType.url,
                    icon: Icon(Icons.link, size: 18),
                    label: Text('URL'),
                  ),
                  ButtonSegment(
                    value: SourceType.videoUrl,
                    icon: Icon(Icons.videocam, size: 18),
                    label: Text('Video'),
                  ),
                ],
                selected: {_selectedType},
                onSelectionChanged: (v) {
                  setState(() {
                    _selectedType = v.first;
                    _pickedFilePath = null;
                    _pickedFileName = null;
                    _totalPages = null;
                  });
                },
              ),
              const SizedBox(height: 20),
              if (_selectedType == SourceType.pdf) ...[
                if (_pickedFilePath == null)
                  FilledButton.tonal(
                    onPressed: _isLoading ? null : _pickPdf,
                    child: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Select PDF File'),
                  )
                else
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          Icon(Icons.picture_as_pdf, color: colorScheme.error),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _pickedFileName ?? 'PDF',
                                  style: textTheme.bodySmall?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                if (_totalPages != null)
                                  Text(
                                    '$_totalPages pages',
                                    style: textTheme.labelSmall?.copyWith(
                                      color: colorScheme.outline,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, size: 18),
                            onPressed: () => setState(() {
                              _pickedFilePath = null;
                              _pickedFileName = null;
                              _totalPages = null;
                            }),
                          ),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: 12),
                TextField(
                  controller: _titleController,
                  decoration: const InputDecoration(
                    labelText: 'Title',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.title),
                  ),
                ),
              ] else ...[
                TextField(
                  controller: _urlController,
                  decoration: InputDecoration(
                    labelText: _selectedType == SourceType.videoUrl
                        ? 'Video URL'
                        : 'URL',
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.link),
                    hintText: _selectedType == SourceType.videoUrl
                        ? 'https://youtube.com/...'
                        : 'https://...',
                  ),
                  keyboardType: TextInputType.url,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _titleController,
                  decoration: const InputDecoration(
                    labelText: 'Title',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.title),
                  ),
                ),
              ],
              if (showTopicPicker) ...[
                const SizedBox(height: 12),
                _TopicPicker(
                  subjectId: widget.subjectId,
                  selectedTopicId: _selectedTopicId,
                  onChanged: (v) {
                    setState(() {
                      _selectedTopicId = v;
                      _selectedChapterId = null;
                    });
                  },
                ),
              ],
              if (showChapterPicker && _selectedTopicId != null) ...[
                const SizedBox(height: 12),
                _ChapterPicker(
                  topicId: _selectedTopicId!,
                  selectedChapterId: _selectedChapterId,
                  onChanged: (v) => setState(() => _selectedChapterId = v),
                ),
              ],
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _canSubmit ? _submit : null,
                  child: const Text('Add Source'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  bool get _canSubmit {
    if (_selectedType == SourceType.pdf) {
      return _pickedFilePath != null && _titleController.text.trim().isNotEmpty;
    }
    return _urlController.text.trim().isNotEmpty &&
        _titleController.text.trim().isNotEmpty;
  }

  Future<void> _pickPdf() async {
    setState(() => _isLoading = true);

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        if (file.path != null) {
          setState(() {
            _pickedFilePath = file.path;
            _pickedFileName = file.name;
            if (_titleController.text.isEmpty) {
              _titleController.text = file.name.replaceAll('.pdf', '');
            }
          });

          await _detectPageCount(file.path!);
        }
      }
    } catch (e) {
      debugPrint('Error picking PDF: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _detectPageCount(String path) async {
    // Page count will be automatically detected when the PDF is first opened
    // in PdfViewerScreen via the onDocumentLoaded callback.
    // Setting totalPages to null here; PdfViewerScreen will update it.
    if (mounted) {
      setState(() {
        _totalPages = null;
      });
    }
  }

  Future<void> _submit() async {
    final notifier = ref.read(sourceProvider(widget.subjectId).notifier);

    try {
      if (_selectedType == SourceType.pdf) {
        await notifier.addPdf(
          subjectId: widget.subjectId,
          topicId: _selectedTopicId,
          chapterId: _selectedChapterId,
          title: _titleController.text.trim(),
          filePath: _pickedFilePath!,
          totalPages: _totalPages,
        );
      } else {
        await notifier.addUrl(
          subjectId: widget.subjectId,
          topicId: _selectedTopicId,
          chapterId: _selectedChapterId,
          type: _selectedType,
          title: _titleController.text.trim(),
          url: _urlController.text.trim(),
        );
      }

      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      debugPrint('Error adding source: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to add source: $e')));
      }
    }
  }
}

class _TopicPicker extends ConsumerWidget {
  const _TopicPicker({
    required this.subjectId,
    required this.selectedTopicId,
    required this.onChanged,
  });

  final String subjectId;
  final String? selectedTopicId;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final topicsAsync = ref.watch(topicListProvider(subjectId));

    return topicsAsync.when(
      loading: () => const SizedBox(
        height: 48,
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (_, __) => const SizedBox.shrink(),
      data: (topics) {
        if (topics.isEmpty) return const SizedBox.shrink();

        return DropdownButtonFormField<String?>(
          initialValue: selectedTopicId,
          decoration: const InputDecoration(
            labelText: 'Topic',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.folder_outlined),
          ),
          items: [
            const DropdownMenuItem<String?>(value: null, child: Text('None')),
            ...topics.map(
              (t) => DropdownMenuItem<String?>(
                value: t.id,
                child: Text(t.name, overflow: TextOverflow.ellipsis),
              ),
            ),
          ],
          onChanged: onChanged,
        );
      },
    );
  }
}

class _ChapterPicker extends ConsumerWidget {
  const _ChapterPicker({
    required this.topicId,
    required this.selectedChapterId,
    required this.onChanged,
  });

  final String topicId;
  final String? selectedChapterId;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chaptersAsync = ref.watch(chapterListProvider(topicId));

    return chaptersAsync.when(
      loading: () => const SizedBox(
        height: 48,
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (_, __) => const SizedBox.shrink(),
      data: (chapters) {
        if (chapters.isEmpty) return const SizedBox.shrink();

        return DropdownButtonFormField<String?>(
          initialValue: selectedChapterId,
          decoration: const InputDecoration(
            labelText: 'Chapter',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.article_outlined),
          ),
          items: [
            const DropdownMenuItem<String?>(value: null, child: Text('None')),
            ...chapters.map(
              (ch) => DropdownMenuItem<String?>(
                value: ch.id,
                child: Text(ch.name, overflow: TextOverflow.ellipsis),
              ),
            ),
          ],
          onChanged: onChanged,
        );
      },
    );
  }
}
