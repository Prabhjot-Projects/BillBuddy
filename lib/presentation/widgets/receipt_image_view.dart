import 'dart:io';
import 'package:flutter/material.dart';

/// Displays a receipt's saved photo, read directly from disk via
/// [imagePath]. Kept as its own widget (rather than inlined in
/// ReviewScreen) because this same "show the receipt photo" need will
/// recur on bill_detail_screen later — extracting it now avoids
/// duplicating the missing-file handling twice.
class ReceiptImageView extends StatelessWidget {
  final String? imagePath;
  final List<String> imagePaths;

  const ReceiptImageView({
    super.key,
    required this.imagePath,
    this.imagePaths = const [],
  });

  @override
  Widget build(BuildContext context) {
    final path = imagePath;

    if (path == null) {
      return _placeholder(context, 'No photo available');
    }

    final file = File(path);

    // File.existsSync is fine here (small, local check on a UI build) —
    // this avoids a FutureBuilder just to answer "does this file exist".
    if (!file.existsSync()) {
      return _placeholder(context, 'Photo could not be found');
    }

    final files = [
      file,
      ...imagePaths.where((path) => path != imagePath).map(File.new),
    ];

    return GestureDetector(
      onTap: () => _openFullScreen(context, files),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Stack(
          alignment: Alignment.bottomRight,
          children: [
            Image.file(
              file,
              height: 220,
              width: double.infinity,
              fit: BoxFit.cover,
              // The compact preview remains cropped, but tapping it shows
              // the complete receipt without losing any content.
              errorBuilder: (context, error, stackTrace) =>
                  _placeholder(context, 'Photo could not be displayed'),
            ),
            Container(
              margin: const EdgeInsets.all(10),
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: .65),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.open_in_full,
                color: Colors.white,
                size: 18,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openFullScreen(BuildContext context, List<File> files) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => _FullScreenReceiptImage(files: files)),
    );
  }

  Widget _placeholder(BuildContext context, String message) {
    return Container(
      height: 220,
      width: double.infinity,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.receipt_long,
              color: Theme.of(context).colorScheme.outline,
              size: 40,
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: TextStyle(color: Theme.of(context).colorScheme.outline),
            ),
          ],
        ),
      ),
    );
  }
}

class _FullScreenReceiptImage extends StatelessWidget {
  const _FullScreenReceiptImage({required this.files});

  final List<File> files;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('Receipt photo'),
      ),
      body: PageView.builder(
        itemCount: files.length,
        itemBuilder: (context, index) => InteractiveViewer(
          minScale: 1,
          maxScale: 5,
          child: Center(
            child: Image.file(
              files[index],
              fit: BoxFit.contain,
              width: double.infinity,
              height: double.infinity,
              errorBuilder: (context, error, stackTrace) => const Center(
                child: Text(
                  'Photo could not be displayed',
                  style: TextStyle(color: Colors.white70),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
