import 'dart:io';
import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/hidden_files_service.dart';
import '../widgets/media_grid_item.dart';

class GalleryScreen extends StatefulWidget {
  const GalleryScreen({super.key});

  @override
  State<GalleryScreen> createState() => _GalleryScreenState();
}

class _GalleryScreenState extends State<GalleryScreen>
    with TickerProviderStateMixin {
  final HiddenFilesService _hiddenFilesService = HiddenFilesService();
  List<AssetEntity> _mediaList = [];
  List<AssetEntity> _selectedMedia = [];
  bool _isLoading = true;
  bool _hasPermission = false;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _requestPermissionAndLoadMedia();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _requestPermissionAndLoadMedia() async {
    final permission = await _requestPermission();
    if (permission) {
      await _loadMedia();
    }
    setState(() {
      _hasPermission = permission;
      _isLoading = false;
    });
  }

  Future<bool> _requestPermission() async {
    if (Platform.isAndroid) {
      // For Android 13+ (API 33+), we need specific media permissions
      final photos = await Permission.photos.request();
      final videos = await Permission.videos.request();
      return photos.isGranted && videos.isGranted;
    } else {
      final photos = await Permission.photos.request();
      return photos.isGranted;
    }
  }

  Future<void> _loadMedia() async {
    final albums = await PhotoManager.getAssetPathList(
      type: RequestType.common,
      onlyAll: true,
    );

    if (albums.isNotEmpty) {
      final recentAlbum = albums.first;
      final media = await recentAlbum.getAssetListRange(
        start: 0,
        end: 1000, // Load first 1000 items
      );

      setState(() {
        _mediaList = media;
      });
    }
  }

  void _toggleSelection(AssetEntity asset) {
    setState(() {
      if (_selectedMedia.contains(asset)) {
        _selectedMedia.remove(asset);
      } else {
        _selectedMedia.add(asset);
      }
    });
  }

  Future<void> _hideSelectedMedia() async {
    if (_selectedMedia.isEmpty) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text(
          'Hiding Files...',
          style: TextStyle(color: Colors.white),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(color: Colors.deepPurple),
            const SizedBox(height: 16),
            Text(
              'Hiding ${_selectedMedia.length} files',
              style: const TextStyle(color: Colors.grey),
            ),
          ],
        ),
      ),
    );

    int successCount = 0;
    for (final asset in _selectedMedia) {
      try {
        final file = await asset.file;
        if (file != null) {
          await _hiddenFilesService.hideFile(file);
          successCount++;
        }
      } catch (e) {
        // Handle individual file errors
      }
    }

    Navigator.of(context).pop(); // Close loading dialog

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Successfully hidden $successCount files'),
          backgroundColor: Colors.green,
        ),
      );
    }

    setState(() {
      _selectedMedia.clear();
    });
  }

  List<AssetEntity> _getFilteredMedia(AssetType type) {
    if (type == AssetType.other) return _mediaList; // All media
    return _mediaList.where((asset) => asset.type == type).toList();
  }

  Widget _buildMediaGrid(List<AssetEntity> media) {
    if (media.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.photo_library_outlined, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'No media found',
              style: TextStyle(color: Colors.grey, fontSize: 16),
            ),
          ],
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(8),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 4,
        mainAxisSpacing: 4,
      ),
      itemCount: media.length,
      itemBuilder: (context, index) {
        final asset = media[index];
        final isSelected = _selectedMedia.contains(asset);

        return MediaGridItem(
          asset: asset,
          isSelected: isSelected,
          onTap: () => _toggleSelection(asset),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.grey[900],
        title: Text(
          _selectedMedia.isEmpty
              ? 'Select Media to Hide'
              : '${_selectedMedia.length} selected',
          style: const TextStyle(color: Colors.white),
        ),
        leading: IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.arrow_back, color: Colors.white),
        ),
        actions: [
          if (_selectedMedia.isNotEmpty)
            IconButton(
              onPressed: _hideSelectedMedia,
              icon: const Icon(Icons.visibility_off, color: Colors.white),
              tooltip: 'Hide Selected',
            ),
          IconButton(
            onPressed: () {
              setState(() {
                _selectedMedia.clear();
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
          tabs: const [
            Tab(text: 'All', icon: Icon(Icons.photo_library)),
            Tab(text: 'Photos', icon: Icon(Icons.photo)),
            Tab(text: 'Videos', icon: Icon(Icons.videocam)),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Colors.deepPurple),
            )
          : !_hasPermission
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.block, size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  const Text(
                    'Permission Required',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Please grant gallery access to hide photos and videos',
                    style: TextStyle(color: Colors.grey),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: _requestPermissionAndLoadMedia,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.deepPurple,
                    ),
                    child: const Text('Grant Permission'),
                  ),
                ],
              ),
            )
          : TabBarView(
              controller: _tabController,
              children: [
                _buildMediaGrid(_getFilteredMedia(AssetType.other)),
                _buildMediaGrid(_getFilteredMedia(AssetType.image)),
                _buildMediaGrid(_getFilteredMedia(AssetType.video)),
              ],
            ),
      floatingActionButton: _selectedMedia.isNotEmpty
          ? FloatingActionButton.extended(
              onPressed: _hideSelectedMedia,
              backgroundColor: Colors.deepPurple,
              icon: const Icon(Icons.visibility_off),
              label: Text('Hide ${_selectedMedia.length}'),
            )
          : null,
    );
  }
}
