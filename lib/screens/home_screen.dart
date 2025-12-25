import 'dart:io';
import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/hidden_files_service.dart';
import 'lock_screen.dart';
import 'gallery_screen.dart';
import 'hidden_files_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  final AuthService _authService = AuthService();
  final HiddenFilesService _hiddenFilesService = HiddenFilesService();
  bool _isAppInBackground = false;
  int _hiddenFilesCount = 0;
  int _totalHiddenSize = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadStats();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _loadStats() async {
    final count = await _hiddenFilesService.getHiddenFilesCount();
    final size = await _hiddenFilesService.getTotalHiddenSize();
    setState(() {
      _hiddenFilesCount = count;
      _totalHiddenSize = size;
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
        _isAppInBackground = true;
        break;
      case AppLifecycleState.resumed:
        if (_isAppInBackground) {
          _isAppInBackground = false;
          _lockApp();
        }
        break;
      default:
        break;
    }
  }

  void _lockApp() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (context) => const LockScreen()),
    );
  }

  void _openGallery() {
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (context) => const GalleryScreen()))
        .then((_) => _loadStats()); // Refresh stats when returning
  }

  void _openHiddenFiles() {
    Navigator.of(context)
        .push(
          MaterialPageRoute(builder: (context) => const HiddenFilesScreen()),
        )
        .then((_) => _loadStats()); // Refresh stats when returning
  }

  void _showSettingsDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text(
          'Security Settings',
          style: TextStyle(color: Colors.white),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.lock_reset, color: Colors.orange),
              title: const Text(
                'Reset PIN',
                style: TextStyle(color: Colors.white),
              ),
              subtitle: const Text(
                'Change your current PIN',
                style: TextStyle(color: Colors.grey),
              ),
              onTap: () {
                Navigator.of(context).pop();
                _showResetPinDialog();
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_forever, color: Colors.red),
              title: const Text(
                'Clear All Hidden Files',
                style: TextStyle(color: Colors.white),
              ),
              subtitle: const Text(
                'Permanently delete all hidden files',
                style: TextStyle(color: Colors.grey),
              ),
              onTap: () {
                Navigator.of(context).pop();
                _showClearAllDialog();
              },
            ),
            ListTile(
              leading: const Icon(Icons.restore, color: Colors.red),
              title: const Text(
                'Reset All',
                style: TextStyle(color: Colors.white),
              ),
              subtitle: const Text(
                'Clear all data and reset app',
                style: TextStyle(color: Colors.grey),
              ),
              onTap: () {
                Navigator.of(context).pop();
                _showResetAllDialog();
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  void _showResetPinDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text('Reset PIN', style: TextStyle(color: Colors.white)),
        content: const Text(
          'This will require you to set up a new PIN. Continue?',
          style: TextStyle(color: Colors.grey),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              await _authService.resetAuth();
              if (mounted) {
                Navigator.of(context).pop();
                _lockApp();
              }
            },
            child: const Text('Reset', style: TextStyle(color: Colors.orange)),
          ),
        ],
      ),
    );
  }

  void _showClearAllDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text(
          'Clear All Hidden Files',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'This will permanently delete all hidden files. This action cannot be undone. Continue?',
          style: TextStyle(color: Colors.grey),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              await _hiddenFilesService.clearAllHiddenFiles();
              await _loadStats();
              if (mounted) {
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('All hidden files cleared'),
                    backgroundColor: Colors.green,
                  ),
                );
              }
            },
            child: const Text('Clear All', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showResetAllDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text(
          'Reset All Data',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'This will clear all authentication data and hidden files, then reset the app. This action cannot be undone. Continue?',
          style: TextStyle(color: Colors.grey),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              await _authService.resetAuth();
              await _hiddenFilesService.clearAllHiddenFiles();
              if (mounted) {
                Navigator.of(context).pop();
                _lockApp();
              }
            },
            child: const Text('Reset All', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024)
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.grey[900],
        title: const Text(
          'HideHub',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            onPressed: _lockApp,
            icon: const Icon(Icons.lock, color: Colors.white),
            tooltip: 'Lock App',
          ),
          IconButton(
            onPressed: _showSettingsDialog,
            icon: const Icon(Icons.settings, color: Colors.white),
            tooltip: 'Settings',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadStats,
        color: Colors.deepPurple,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Welcome section
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.deepPurple, Colors.deepPurple.shade800],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.security, color: Colors.white, size: 32),
                        SizedBox(width: 12),
                        Text(
                          'Welcome to HideHub!',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Your secure vault for photos and videos',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.9),
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Stats section
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[900],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Storage Stats',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _buildStatItem(
                            Icons.folder,
                            'Hidden Files',
                            '$_hiddenFilesCount',
                            Colors.blue,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildStatItem(
                            Icons.storage,
                            'Total Size',
                            _formatFileSize(_totalHiddenSize),
                            Colors.green,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Main actions
              const Text(
                'Quick Actions',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 16),

              // Action buttons
              Row(
                children: [
                  Expanded(
                    child: _buildActionCard(
                      icon: Icons.photo_library,
                      title: 'Hide Files',
                      subtitle: 'Select from gallery',
                      color: Colors.deepPurple,
                      onTap: _openGallery,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildActionCard(
                      icon: Icons.folder_special,
                      title: 'Hidden Files',
                      subtitle: '$_hiddenFilesCount files',
                      color: Colors.orange,
                      onTap: _openHiddenFiles,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Security features
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[900],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Security Features',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildFeatureItem(Icons.pin, 'PIN Protection'),
                    _buildFeatureItem(
                      Icons.fingerprint,
                      'Biometric Authentication',
                    ),
                    _buildFeatureItem(
                      Icons.security,
                      'Auto-lock on Background',
                    ),
                    _buildFeatureItem(Icons.block, 'Failed Attempt Protection'),
                    _buildFeatureItem(Icons.encrypted, 'Secure File Storage'),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatItem(
    IconData icon,
    String label,
    String value,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(label, style: TextStyle(color: Colors.grey[400], fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildActionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey[900],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 32),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(color: Colors.grey[400], fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureItem(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, color: Colors.deepPurple, size: 20),
          const SizedBox(width: 12),
          Text(text, style: TextStyle(color: Colors.grey[300], fontSize: 14)),
        ],
      ),
    );
  }
}
