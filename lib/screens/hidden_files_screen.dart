import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../services/hidden_files_service.dart';
import '../widgets/hidden_file_item.dart';

class HiddenFilesScreen extends StatefulWidget {
  const HiddenFilesScreen({super.key});

  @override
  State<HiddenFilesScreen> createState() => _HiddenFilesScreenState();
}

class _HiddenFilesScreenState extends State<HiddenFilesScreen>
    with TickerProviderStateMixin {
  final HiddenFilesService _hiddenFilesService = HiddenFilesService();
  List<HiddenFile> _hiddenFiles = [];
  List<HiddenFile> _selectedFiles = [];
  bool _isLoading = true;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadHiddenFiles();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadHiddenFiles() async {
    final files = await _hiddenFilesService.getHiddenFiles();
    setState(() {
      _hiddenFiles = files;
      _isLoading = false;
    });
  }

  void _toggleSelection(HiddenFile file) {
    setState(() {
      if (_selectedFiles.contains(file)) {
        _selectedFiles.remove(file);
      } else {
        _selectedFiles.add(file);
      }
    });
  }

  Future<void> _deleteSelectedFiles() async {
    if (_selectedFiles.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text(
          'Delete Files',
          style: TextStyle(color: Colors.white),
        ),
        content: Text(
          'Are you sure you want to permanently delete ${_selectedFiles.length} files? This action cannot be undone.',
          style: const TextStyle(color: Colors.grey),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text(
          'Deleting Files...',
          style: TextStyle(color: Colors.white),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(color: Colors.deepPurple),
            const SizedBox(height: 16),
            Text(
              'Deleting ${_selectedFiles.length} files',
              style: const TextStyle(color: Colors.grey),
            ),
          ],
        ),
      ),
    );

    int successCount = 0;
    for (final file in _selectedFiles) {
      final success = await _hiddenFilesService.deleteHiddenFile(file);
      if (success) successCount++;
    }

    Navigator.of(context).pop(); // Close loading dialog

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Successfully deleted $successCount files'),
        backgroundColor: Colors.green,
      ),
    );

    setState(() {
      _selectedFiles.clear();
    });

    await _loadHiddenFiles(); // Reload the list
  }

  List<HiddenFile> _getFilteredFiles(String type) {
    if (type == 'all') return _hiddenFiles;
    return _hiddenFiles.where((file) => file.type == type).toList();
  }

  Widget _buildFileGrid(List<HiddenFile> files) {
    if (files.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.folder_outlined, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'No hidden files',
              style: TextStyle(color: Colors.grey, fontSize: 16),
            ),
            SizedBox(height: 8),
            Text(
              'Files you hide will appear here',
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ],
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(8),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        childAspectRatio: 0.8,
      ),
      itemCount: files.length,
      itemBuilder: (context, index) {
        final file = files[index];
        final isSelected = _selectedFiles.contains(file);

        return HiddenFileItem(
          hiddenFile: file,
          isSelected: isSelected,
          onTap: () => _toggleSelection(file),
          onLongPress: () => _viewFile(file),
        );
      },
    );
  }

  void _viewFile(HiddenFile file) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => FileViewerScreen(hiddenFile: file),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.grey[900],
        title: Text(
          _selectedFiles.isEmpty
              ? 'Hidden Files (${_hiddenFiles.length})'
              : '${_selectedFiles.length} selected',
          style: const TextStyle(color: Colors.white),
        ),
        leading: IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.arrow_back, color: Colors.white),
        ),
        actions: [
          if (_selectedFiles.isNotEmpty)
            IconButton(
              onPressed: _deleteSelectedFiles,
              icon: const Icon(Icons.delete, color: Colors.red),
              tooltip: 'Delete Selected',
            ),
          IconButton(
            onPressed: () {
              setState(() {
                _selectedFiles.clear();
              });
            },
            icon: const Icon(Icons.clear, color: Colors.white),
            tooltip: 'Clear Selection',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.deepPurple,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.grey,
          tabs: [
            Tab(
              text: 'All (${_hiddenFiles.length})',
              icon: const Icon(Icons.folder),
            ),
            Tab(
              text: 'Photos (${_getFilteredFiles('image').length})',
              icon: const Icon(Icons.photo),
            ),
            Tab(
              text: 'Videos (${_getFilteredFiles('video').length})',
              icon: const Icon(Icons.videocam),
            ),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Colors.deepPurple),
            )
          : TabBarView(
              controller: _tabController,
              children: [
                _buildFileGrid(_getFilteredFiles('all')),
                _buildFileGrid(_getFilteredFiles('image')),
                _buildFileGrid(_getFilteredFiles('video')),
              ],
            ),
      floatingActionButton: _selectedFiles.isNotEmpty
          ? FloatingActionButton.extended(
              onPressed: _deleteSelectedFiles,
              backgroundColor: Colors.red,
              icon: const Icon(Icons.delete),
              label: Text('Delete ${_selectedFiles.length}'),
            )
          : null,
    );
  }
}

class FileViewerScreen extends StatefulWidget {
  final HiddenFile hiddenFile;

  const FileViewerScreen({super.key, required this.hiddenFile});

  @override
  State<FileViewerScreen> createState() => _FileViewerScreenState();
}

class _FileViewerScreenState extends State<FileViewerScreen> {
  final HiddenFilesService _hiddenFilesService = HiddenFilesService();
  Uint8List? _fileBytes;
  VideoPlayerController? _videoController;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadFile();
  }

  @override
  void dispose() {
    _videoController?.dispose();
    super.dispose();
  }

  Future<void> _loadFile() async {
    final bytes = await _hiddenFilesService.getFileBytes(widget.hiddenFile);

    if (widget.hiddenFile.type == 'video' && bytes != null) {
      // For video files, we need to use the file path
      _videoController = VideoPlayerController.file(
        File(widget.hiddenFile.hiddenPath),
      );
      await _videoController!.initialize();
    }

    setState(() {
      _fileBytes = bytes;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: Text(
          widget.hiddenFile.originalName,
          style: const TextStyle(color: Colors.white),
        ),
        leading: IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.arrow_back, color: Colors.white),
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Colors.deepPurple),
            )
          : _fileBytes == null
          ? const Center(
              child: Text(
                'Failed to load file',
                style: TextStyle(color: Colors.white),
              ),
            )
          : widget.hiddenFile.type == 'video'
          ? _videoController != null
                ? Center(
                    child: AspectRatio(
                      aspectRatio: _videoController!.value.aspectRatio,
                      child: VideoPlayer(_videoController!),
                    ),
                  )
                : const Center(
                    child: Text(
                      'Failed to load video',
                      style: TextStyle(color: Colors.white),
                    ),
                  )
          : Center(
              child: InteractiveViewer(
                child: Image.memory(_fileBytes!, fit: BoxFit.contain),
              ),
            ),
      floatingActionButton:
          widget.hiddenFile.type == 'video' && _videoController != null
          ? FloatingActionButton(
              onPressed: () {
                setState(() {
                  if (_videoController!.value.isPlaying) {
                    _videoController!.pause();
                  } else {
                    _videoController!.play();
                  }
                });
              },
              backgroundColor: Colors.deepPurple,
              child: Icon(
                _videoController!.value.isPlaying
                    ? Icons.pause
                    : Icons.play_arrow,
              ),
            )
          : null,
    );
  }
}
