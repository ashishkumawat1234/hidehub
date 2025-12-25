import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';

class MediaGridItem extends StatelessWidget {
  final AssetEntity asset;
  final bool isSelected;
  final VoidCallback onTap;

  const MediaGridItem({
    super.key,
    required this.asset,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        children: [
          // Media thumbnail
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: isSelected
                  ? Border.all(color: Colors.deepPurple, width: 3)
                  : null,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: AssetEntityImage(
                asset,
                isOriginal: false,
                thumbnailSize: const ThumbnailSize.square(200),
                fit: BoxFit.cover,
                width: double.infinity,
                height: double.infinity,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    color: Colors.grey[800],
                    child: const Center(
                      child: Icon(
                        Icons.broken_image,
                        color: Colors.grey,
                        size: 32,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),

          // Video duration indicator
          if (asset.type == AssetType.video)
            Positioned(
              bottom: 4,
              right: 4,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.play_arrow, color: Colors.white, size: 12),
                    const SizedBox(width: 2),
                    Text(
                      _formatDuration(asset.duration),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Selection indicator
          if (isSelected)
            Positioned(
              top: 4,
              right: 4,
              child: Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: Colors.deepPurple,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: const Icon(Icons.check, color: Colors.white, size: 14),
              ),
            ),

          // Selection overlay
          if (isSelected)
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                color: Colors.deepPurple.withOpacity(0.3),
              ),
            ),
        ],
      ),
    );
  }

  String _formatDuration(int seconds) {
    final duration = Duration(seconds: seconds);
    final minutes = duration.inMinutes;
    final remainingSeconds = duration.inSeconds % 60;

    if (minutes > 0) {
      return '${minutes}:${remainingSeconds.toString().padLeft(2, '0')}';
    } else {
      return '0:${remainingSeconds.toString().padLeft(2, '0')}';
    }
  }
}
