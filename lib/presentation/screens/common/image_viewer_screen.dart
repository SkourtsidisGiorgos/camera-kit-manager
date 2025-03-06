// lib/presentation/screens/common/image_viewer_screen.dart

import 'dart:io';
import 'package:camera_kit_manager/domain/entities/item_photo.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';

class ImageViewerScreen extends StatefulWidget {
  final List<ItemPhoto> photos;
  final int initialIndex;
  final String title;

  const ImageViewerScreen({
    super.key,
    required this.photos,
    this.initialIndex = 0,
    this.title = 'Item Photos',
  });

  @override
  State<ImageViewerScreen> createState() => _ImageViewerScreenState();
}

class _ImageViewerScreenState extends State<ImageViewerScreen> {
  late PageController _pageController;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: _currentIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(widget.title),
        elevation: 0,
        actions: [
          if (widget.photos.length > 1)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Center(
                child: Text(
                  '${_currentIndex + 1}/${widget.photos.length}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
        ],
      ),
      body: PhotoViewGallery.builder(
        scrollPhysics: const BouncingScrollPhysics(),
        builder: _buildItem,
        itemCount: widget.photos.length,
        loadingBuilder: (context, event) => Center(
          child: SizedBox(
            width: 20.0,
            height: 20.0,
            child: CircularProgressIndicator(
              value: event == null
                  ? 0
                  : event.cumulativeBytesLoaded / event.expectedTotalBytes!,
            ),
          ),
        ),
        backgroundDecoration: const BoxDecoration(color: Colors.black),
        pageController: _pageController,
        onPageChanged: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
      ),
      bottomNavigationBar: widget.photos.length > 1
          ? _buildThumbnailBar()
          : const SizedBox.shrink(),
    );
  }

  PhotoViewGalleryPageOptions _buildItem(BuildContext context, int index) {
    final photo = widget.photos[index];
    ImageProvider imageProvider;

    if (kIsWeb && photo.imageDataUrl != null) {
      imageProvider = NetworkImage(photo.imageDataUrl!);
    } else if (!kIsWeb && photo.imagePath != null) {
      imageProvider = FileImage(File(photo.imagePath!));
    } else {
      // Fallback for missing images
      imageProvider = const AssetImage('assets/placeholder.png');
    }

    return PhotoViewGalleryPageOptions(
      imageProvider: imageProvider,
      initialScale: PhotoViewComputedScale.contained,
      minScale: PhotoViewComputedScale.contained * 0.8,
      maxScale: PhotoViewComputedScale.covered * 2,
      heroAttributes: PhotoViewHeroAttributes(tag: 'photo_${photo.id}'),
      errorBuilder: (context, error, stackTrace) {
        return Container(
          color: Colors.black,
          child: const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.broken_image, color: Colors.white, size: 64),
                SizedBox(height: 16),
                Text(
                  'Could not load image',
                  style: TextStyle(color: Colors.white),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildThumbnailBar() {
    return Container(
      height: 80,
      color: Colors.black,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        itemCount: widget.photos.length,
        itemBuilder: (context, index) {
          return _buildThumbnail(index);
        },
      ),
    );
  }

  Widget _buildThumbnail(int index) {
    final photo = widget.photos[index];
    final isSelected = index == _currentIndex;

    return GestureDetector(
      onTap: () {
        _pageController.animateToPage(
          index,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      },
      child: Container(
        width: 60,
        height: 60,
        margin: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
          border: Border.all(
            color: isSelected ? Colors.blue : Colors.transparent,
            width: 2,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: Builder(
            builder: (context) {
              try {
                if (kIsWeb && photo.imageDataUrl != null) {
                  return Image.network(
                    photo.imageDataUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) =>
                        const Icon(Icons.broken_image, color: Colors.white),
                  );
                } else if (!kIsWeb && photo.imagePath != null) {
                  return Image.file(
                    File(photo.imagePath!),
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) =>
                        const Icon(Icons.broken_image, color: Colors.white),
                  );
                } else {
                  return const Icon(Icons.image_not_supported,
                      color: Colors.white);
                }
              } catch (e) {
                return const Icon(Icons.error, color: Colors.white);
              }
            },
          ),
        ),
      ),
    );
  }
}
