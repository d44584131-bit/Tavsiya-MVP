import 'package:flutter/material.dart';

/// Полноэкранный просмотр фото (фото места, фото в отзыве) — свайп между
/// фото + пинч-зум на каждом.
class PhotoViewerScreen extends StatefulWidget {
  final List<String> photos;
  final int initialIndex;
  const PhotoViewerScreen(
      {super.key, required this.photos, required this.initialIndex});

  @override
  State<PhotoViewerScreen> createState() => _PhotoViewerScreenState();
}

class _PhotoViewerScreenState extends State<PhotoViewerScreen> {
  late final _controller = PageController(initialPage: widget.initialIndex);
  late int _index = widget.initialIndex;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          PageView.builder(
            controller: _controller,
            onPageChanged: (i) => setState(() => _index = i),
            itemCount: widget.photos.length,
            itemBuilder: (context, i) => InteractiveViewer(
              child: Center(
                  child: Image.network(widget.photos[i], fit: BoxFit.contain)),
            ),
          ),
          Positioned(
            top: 8,
            left: 8,
            child: SafeArea(
              child: IconButton(
                onPressed: () => Navigator.maybePop(context),
                icon: const Icon(Icons.close_rounded, color: Colors.white),
              ),
            ),
          ),
          if (widget.photos.length > 1)
            Positioned(
              bottom: 24,
              left: 0,
              right: 0,
              child: SafeArea(
                child: Center(
                  child: Text(
                    '${_index + 1} / ${widget.photos.length}',
                    style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
