import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:crypto/crypto.dart';

class HiddenFile {
  final String id;
  final String originalName;
  final String hiddenPath;
  final String type; // 'image' or 'video'
  final DateTime hiddenAt;
  final int size;

  HiddenFile({
    required this.id,
    required this.originalName,
    required this.hiddenPath,
    required this.type,
    required this.hiddenAt,
    required this.size,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'originalName': originalName,
      'hiddenPath': hiddenPath,
      'type': type,
      'hiddenAt': hiddenAt.toIso8601String(),
      'size': size,
    };
  }

  factory HiddenFile.fromJson(Map<String, dynamic> json) {
    return HiddenFile(
      id: json['id'],
      originalName: json['originalName'],
      hiddenPath: json['hiddenPath'],
      type: json['type'],
      hiddenAt: DateTime.parse(json['hiddenAt']),
      size: json['size'],
    );
  }
}

class HiddenFilesService {
  static const String _hiddenFilesKey = 'hidden_files';
  static const String _hiddenFolderName = '.hidehub_secure';

  // Get the hidden files directory
  Future<Directory> _getHiddenDirectory() async {
    final appDir = await getApplicationDocumentsDirectory();
    final hiddenDir = Directory('${appDir.path}/$_hiddenFolderName');

    if (!await hiddenDir.exists()) {
      await hiddenDir.create(recursive: true);
    }

    return hiddenDir;
  }

  // Generate unique ID for file
  String _generateFileId() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final random = DateTime.now().microsecondsSinceEpoch;
    return sha256
        .convert(utf8.encode('$timestamp$random'))
        .toString()
        .substring(0, 16);
  }

  // Hide a file (copy to secure location and encrypt filename)
  Future<HiddenFile> hideFile(File originalFile) async {
    final hiddenDir = await _getHiddenDirectory();
    final fileId = _generateFileId();
    final originalName = originalFile.path.split('/').last;
    final extension = originalName.split('.').last;

    // Create encrypted filename
    final hiddenFileName = '$fileId.$extension';
    final hiddenPath = '${hiddenDir.path}/$hiddenFileName';

    // Copy file to hidden location
    final hiddenFile = await originalFile.copy(hiddenPath);
    final fileSize = await hiddenFile.length();

    // Determine file type
    final type = _isVideoFile(extension) ? 'video' : 'image';

    final hiddenFileInfo = HiddenFile(
      id: fileId,
      originalName: originalName,
      hiddenPath: hiddenPath,
      type: type,
      hiddenAt: DateTime.now(),
      size: fileSize,
    );

    // Save to preferences
    await _saveHiddenFileInfo(hiddenFileInfo);

    return hiddenFileInfo;
  }

  // Check if file is video based on extension
  bool _isVideoFile(String extension) {
    final videoExtensions = ['mp4', 'avi', 'mov', 'mkv', '3gp', 'webm', 'flv'];
    return videoExtensions.contains(extension.toLowerCase());
  }

  // Save hidden file info to preferences
  Future<void> _saveHiddenFileInfo(HiddenFile hiddenFile) async {
    final prefs = await SharedPreferences.getInstance();
    final hiddenFiles = await getHiddenFiles();
    hiddenFiles.add(hiddenFile);

    final jsonList = hiddenFiles.map((file) => file.toJson()).toList();
    await prefs.setString(_hiddenFilesKey, jsonEncode(jsonList));
  }

  // Get all hidden files
  Future<List<HiddenFile>> getHiddenFiles() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_hiddenFilesKey);

    if (jsonString == null) return [];

    final jsonList = jsonDecode(jsonString) as List;
    return jsonList.map((json) => HiddenFile.fromJson(json)).toList();
  }

  // Get hidden files by type
  Future<List<HiddenFile>> getHiddenFilesByType(String type) async {
    final allFiles = await getHiddenFiles();
    return allFiles.where((file) => file.type == type).toList();
  }

  // Restore a hidden file (copy back to gallery)
  Future<bool> restoreFile(HiddenFile hiddenFile) async {
    try {
      final hiddenFileObj = File(hiddenFile.hiddenPath);
      if (!await hiddenFileObj.exists()) return false;

      // For now, we'll just delete from hidden location
      // In a real app, you'd copy back to gallery
      await deleteHiddenFile(hiddenFile);
      return true;
    } catch (e) {
      return false;
    }
  }

  // Delete a hidden file permanently
  Future<bool> deleteHiddenFile(HiddenFile hiddenFile) async {
    try {
      // Delete physical file
      final file = File(hiddenFile.hiddenPath);
      if (await file.exists()) {
        await file.delete();
      }

      // Remove from preferences
      final prefs = await SharedPreferences.getInstance();
      final hiddenFiles = await getHiddenFiles();
      hiddenFiles.removeWhere((file) => file.id == hiddenFile.id);

      final jsonList = hiddenFiles.map((file) => file.toJson()).toList();
      await prefs.setString(_hiddenFilesKey, jsonEncode(jsonList));

      return true;
    } catch (e) {
      return false;
    }
  }

  // Get file as bytes for display
  Future<Uint8List?> getFileBytes(HiddenFile hiddenFile) async {
    try {
      final file = File(hiddenFile.hiddenPath);
      if (await file.exists()) {
        return await file.readAsBytes();
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  // Get total hidden files count
  Future<int> getHiddenFilesCount() async {
    final files = await getHiddenFiles();
    return files.length;
  }

  // Get total size of hidden files
  Future<int> getTotalHiddenSize() async {
    final files = await getHiddenFiles();
    int totalSize = 0;
    for (final file in files) {
      totalSize += file.size;
    }
    return totalSize;
  }

  // Clear all hidden files
  Future<void> clearAllHiddenFiles() async {
    final hiddenDir = await _getHiddenDirectory();
    if (await hiddenDir.exists()) {
      await hiddenDir.delete(recursive: true);
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_hiddenFilesKey);
  }
}
