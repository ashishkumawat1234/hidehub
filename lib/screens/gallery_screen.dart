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
  final List<AssetEntity> _selectedMedia = [];
  List<HiddenFile> _hiddenFiles = []; // Store hidden files for comparison
  bool _isLoading = true;
  bool _hasPermission = false;
  late TabController _tabController;

  // Sorting options
  String _sortBy = 'newest'; // newest, oldest, name, size
  bool _showSortPanel = false;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _requestPermissionAndLoadMedia();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
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

      // Load hidden files to filter them out
      final hiddenFiles = await _hiddenFilesService.getHiddenFiles();

      setState(() {
        _mediaList = media;
        _hiddenFiles = hiddenFiles;
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

    // Reload hidden files to update the filter
    final hiddenFiles = await _hiddenFilesService.getHiddenFiles();
    setState(() {
      _hiddenFiles = hiddenFiles;
    });
  }

  Future<List<AssetEntity>> _getSortedMedia(AssetType type) async {
    List<AssetEntity> filtered = _mediaList;

    // Filter by type
    if (type != AssetType.other) {
      filtered = filtered.where((asset) => asset.type == type).toList();
    }

    // Filter out already hidden files (check by filename and size)
    List<AssetEntity> notHiddenFiles = [];
    for (final asset in filtered) {
      final file = await asset.file;
      if (file != null) {
        final fileName = file.path.split('/').last;
        final fileSize = await file.length();

        // Check if this file is already hidden by comparing name and size
        bool isAlreadyHidden = _hiddenFiles.any(
          (hiddenFile) =>
              hiddenFile.originalName == fileName &&
              hiddenFile.size == fileSize,
        );

        if (!isAlreadyHidden) {
          notHiddenFiles.add(asset);
        }
      }
    }
    filtered = notHiddenFiles;

    // Filter by search query
    if (_searchQuery.isNotEmpty) {
      filtered = filtered
          .where(
            (asset) => (asset.title ?? '').toLowerCase().contains(
              _searchQuery.toLowerCase(),
            ),
          )
          .toList();
    }

    // Sort media
    switch (_sortBy) {
      case 'newest':
        filtered.sort((a, b) => b.createDateTime.compareTo(a.createDateTime));
        break;
      case 'oldest':
        filtered.sort((a, b) => a.createDateTime.compareTo(b.createDateTime));
        break;
      case 'name':
        filtered.sort((a, b) => (a.title ?? '').compareTo(b.title ?? ''));
        break;
      case 'size':
        // Sort by file size - we need to get the actual file size
        filtered.sort((a, b) {
          // For AssetEntity, we can use width * height as a proxy for size
          // or we could load the file and get actual byte size, but that's expensive
          final aSize = (a.width * a.height);
          final bSize = (b.width * b.height);
          return bSize.compareTo(aSize);
        });
        break;
    }

    return filtered;
  }

  Widget _buildSortPanel() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(16),
          bottomRight: Radius.circular(16),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Search bar
          TextField(
            controller: _searchController,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Search by filename...',
              hintStyle: const TextStyle(color: Colors.grey),
              prefixIcon: const Icon(Icons.search, color: Colors.grey),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, color: Colors.grey),
                      onPressed: () {
                        _searchController.clear();
                        setState(() {
                          _searchQuery = '';
                        });
                      },
                    )
                  : null,
              filled: true,
              fillColor: Colors.grey[800],
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide.none,
              ),
            ),
            onChanged: (value) {
              setState(() {
                _searchQuery = value;
              });
            },
          ),
          const SizedBox(height: 16),

          // Sort options
          const Text(
            'Sort by',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              _buildSortChip('Newest', 'newest'),
              _buildSortChip('Oldest', 'oldest'),
              _buildSortChip('Name', 'name'),
              _buildSortChip('Size', 'size'),
            ],
          ),
          const SizedBox(height: 16),

          // Action buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TextButton(
                onPressed: () {
                  setState(() {
                    _sortBy = 'newest';
                    _searchQuery = '';
                    _searchController.clear();
                  });
                },
                child: const Text(
                  'Reset',
                  style: TextStyle(color: Colors.grey),
                ),
              ),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    _showSortPanel = false;
                  });
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurple,
                ),
                child: const Text('Apply'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSortChip(String label, String value) {
    final isSelected = _sortBy == value;
    return FilterChip(
      label: Text(
        label,
        style: TextStyle(
          color: isSelected ? Colors.white : Colors.grey,
          fontSize: 12,
        ),
      ),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          _sortBy = value;
        });
      },
      backgroundColor: Colors.grey[800],
      selectedColor: Colors.deepPurple,
      checkmarkColor: Colors.white,
    );
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

  Widget _buildAsyncMediaGrid(AssetType type) {
    return FutureBuilder<List<AssetEntity>>(
      future: _getSortedMedia(type),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: Colors.deepPurple),
          );
        }

        if (snapshot.hasError) {
          return const Center(
            child: Text(
              'Error loading media',
              style: TextStyle(color: Colors.red),
            ),
          );
        }

        final media = snapshot.data ?? [];
        return _buildMediaGrid(media);
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
          IconButton(
            onPressed: () {
              setState(() {
                _showSortPanel = !_showSortPanel;
              });
            },
            icon: Icon(
              Icons.sort,
              color: _showSortPanel ? Colors.deepPurple : Colors.white,
            ),
            tooltip: 'Sort',
          ),
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
          : Column(
              children: [
                // Sort panel
                if (_showSortPanel) _buildSortPanel(),

                // Media count and info
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  color: Colors.grey[850],
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      FutureBuilder<List<AssetEntity>>(
                        future: _getSortedMedia(AssetType.other),
                        builder: (context, snapshot) {
                          final count = snapshot.data?.length ?? 0;
                          return Text(
                            '$count items',
                            style: const TextStyle(
                              color: Colors.grey,
                              fontSize: 12,
                            ),
                          );
                        },
                      ),
                      if (_sortBy != 'newest' || _searchQuery.isNotEmpty)
                        const Text(
                          'Sorted',
                          style: TextStyle(
                            color: Colors.deepPurple,
                            fontSize: 12,
                          ),
                        ),
                    ],
                  ),
                ),

                // Tab content
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildAsyncMediaGrid(AssetType.other),
                      _buildAsyncMediaGrid(AssetType.image),
                      _buildAsyncMediaGrid(AssetType.video),
                    ],
                  ),
                ),
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
