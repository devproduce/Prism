import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:prism/utils/constants.dart';

class CroppedFace extends StatefulWidget {
  final String imageId;
  final Map<String, dynamic>? bbox;
  final double size;

  const CroppedFace({
    super.key,
    required this.imageId,
    this.bbox,
    this.size = 48.0,
  });

  @override
  State<CroppedFace> createState() => _CroppedFaceState();
}

class _CroppedFaceState extends State<CroppedFace> {
  int? _naturalWidth;
  int? _naturalHeight;
  bool _resolved = false;
  ImageStreamListener? _listener;
  ImageStream? _imageStream;

  @override
  void initState() {
    super.initState();
    _resolveImageDimensions();
  }

  @override
  void didUpdateWidget(CroppedFace oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageId != widget.imageId) {
      _cleanupListener();
      _resolved = false;
      _resolveImageDimensions();
    }
  }

  @override
  void dispose() {
    _cleanupListener();
    super.dispose();
  }

  void _cleanupListener() {
    if (_listener != null && _imageStream != null) {
      _imageStream!.removeListener(_listener!);
    }
  }

  void _resolveImageDimensions() {
    final url = '${ApiConstants.baseUrl}/images/${widget.imageId}';
    final image = CachedNetworkImageProvider(url);
    _imageStream = image.resolve(const ImageConfiguration());
    _listener = ImageStreamListener(
      (ImageInfo info, bool _) {
        if (mounted) {
          setState(() {
            _naturalWidth = info.image.width;
            _naturalHeight = info.image.height;
            _resolved = true;
          });
        }
      },
      onError: (exception, stackTrace) {
        debugPrint('[CroppedFace] Error resolving image size: $exception');
      },
    );
    _imageStream!.addListener(_listener!);
  }

  @override
  Widget build(BuildContext context) {
    final url = '${ApiConstants.baseUrl}/images/${widget.imageId}';

    if (widget.bbox == null ||
        !_resolved ||
        _naturalWidth == null ||
        _naturalHeight == null) {
      return _fallbackCircle(url);
    }

    final bbox = widget.bbox!;
    final x1 = (bbox['x1'] ?? 0).toDouble();
    final y1 = (bbox['y1'] ?? 0).toDouble();
    final x2 = (bbox['x2'] ?? 0).toDouble();
    final y2 = (bbox['y2'] ?? 0).toDouble();
    final boxWidth = x2 - x1;
    final boxHeight = y2 - y1;

    if (boxWidth <= 0 || boxHeight <= 0) {
      return _fallbackCircle(url);
    }

    return Container(
      width: widget.size,
      height: widget.size,
      decoration: const BoxDecoration(shape: BoxShape.circle),
      child: ClipOval(
        child: CustomSingleChildLayout(
          delegate: _BBoxCroppingLayoutDelegate(
            naturalWidth: _naturalWidth!.toDouble(),
            naturalHeight: _naturalHeight!.toDouble(),
            x1: x1,
            y1: y1,
            boxWidth: boxWidth,
            boxHeight: boxHeight,
            targetSize: widget.size,
          ),
          child: CachedNetworkImage(imageUrl: url, fit: BoxFit.fill),
        ),
      ),
    );
  }

  Widget _fallbackCircle(String url) {
    return Container(
      width: widget.size,
      height: widget.size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withValues(alpha: 0.05),
      ),
      child: ClipOval(
        child: CachedNetworkImage(
          imageUrl: url,
          fit: BoxFit.cover,
          errorWidget: (_, __, ___) => Icon(
            Icons.person_rounded,
            color: Colors.white60,
            size: widget.size * 0.45,
          ),
        ),
      ),
    );
  }
}

class _BBoxCroppingLayoutDelegate extends SingleChildLayoutDelegate {
  final double naturalWidth;
  final double naturalHeight;
  final double x1;
  final double y1;
  final double boxWidth;
  final double boxHeight;
  final double targetSize;

  _BBoxCroppingLayoutDelegate({
    required this.naturalWidth,
    required this.naturalHeight,
    required this.x1,
    required this.y1,
    required this.boxWidth,
    required this.boxHeight,
    required this.targetSize,
  });

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) {
    final scaleX = targetSize / boxWidth;
    final scaleY = targetSize / boxHeight;
    return BoxConstraints.tightFor(
      width: naturalWidth * scaleX,
      height: naturalHeight * scaleY,
    );
  }

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    final scaleX = targetSize / boxWidth;
    final scaleY = targetSize / boxHeight;
    return Offset(-x1 * scaleX, -y1 * scaleY);
  }

  @override
  bool shouldRelayout(covariant _BBoxCroppingLayoutDelegate oldDelegate) {
    return oldDelegate.naturalWidth != naturalWidth ||
        oldDelegate.naturalHeight != naturalHeight ||
        oldDelegate.x1 != x1 ||
        oldDelegate.y1 != y1 ||
        oldDelegate.boxWidth != boxWidth ||
        oldDelegate.boxHeight != boxHeight ||
        oldDelegate.targetSize != targetSize;
  }
}
