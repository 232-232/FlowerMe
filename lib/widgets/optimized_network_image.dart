import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../debug/perf_logger.dart';

class OptimizedNetworkImage extends StatefulWidget {
  // Global cache of URLs that have been successfully loaded at least once
  // in this session. This prevents showing the jarring placeholder again
  // when recreating the widget for an image we already have on disk/memory.
  static final Set<String> _loadedUrls = {};

  final String imageUrl;
  final double? width;
  final double? height;
  final BoxFit fit;
  final double borderRadius;
  final Duration fadeInDuration;
  final Widget? placeholder;
  final Widget? errorWidget;
  final String? trackLogLabel;
  final String? trackLogName;

  const OptimizedNetworkImage({
    super.key,
    required this.imageUrl,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius = 0.0,
    this.fadeInDuration = const Duration(milliseconds: 50),
    this.placeholder,
    this.errorWidget,
    this.trackLogLabel,
    this.trackLogName,
  });

  @override
  State<OptimizedNetworkImage> createState() => _OptimizedNetworkImageState();
}

class _OptimizedNetworkImageState extends State<OptimizedNetworkImage> {
  late final Stopwatch _stopwatch;
  bool _logged = false;
  late bool _wasAlreadyLoaded;

  @override
  void initState() {
    super.initState();
    _stopwatch = Stopwatch()..start();
    // Check if we've already loaded this image in the current session
    _wasAlreadyLoaded = OptimizedNetworkImage._loadedUrls.contains(widget.imageUrl);
  }

  void _logTime(String status) {
    if (status == 'loaded' && !OptimizedNetworkImage._loadedUrls.contains(widget.imageUrl)) {
      OptimizedNetworkImage._loadedUrls.add(widget.imageUrl);
    }
    
    if (!_logged && widget.trackLogLabel != null) {
      _logged = true;
      _stopwatch.stop();
      final identifier = widget.trackLogName ?? widget.imageUrl;
      if (status == 'loaded') {
        Perf.logImageLoad(widget.trackLogLabel!, _stopwatch.elapsedMilliseconds, identifier);
      } else {
        Perf.log(widget.trackLogLabel!, 'Image $status in ${_stopwatch.elapsedMilliseconds}ms: $identifier');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.imageUrl.isEmpty) {
      return _buildErrorWidget(context, 'Empty URL');
    }

    // 1. Calculate ideal memory cache boundaries using Device Pixel Ratio
    //    to strictly limit decode memory size. Apply on all platforms.
    final displayW = widget.width ?? 300.0;
    final displayH = widget.height;
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final memCacheW = (displayW * dpr).toInt().clamp(1, 600);
    final memCacheH = displayH != null
        ? (displayH * dpr).toInt().clamp(1, 600)
        : null;

    // 2. Hardware acceleration: isolate the image into its own RepaintBoundary
    return RepaintBoundary(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(widget.borderRadius),
        child: CachedNetworkImage(
          imageUrl: widget.imageUrl,
          width: widget.width,
          height: widget.height,
          fit: widget.fit,
          memCacheWidth: memCacheW,
          memCacheHeight: memCacheH,
          fadeInDuration: _wasAlreadyLoaded ? Duration.zero : widget.fadeInDuration,
          imageBuilder: (context, imageProvider) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) _logTime('loaded');
            });
            return Image(
              image: imageProvider,
              width: widget.width,
              height: widget.height,
              fit: widget.fit,
              filterQuality: FilterQuality.low,
            );
          },
          placeholder: (context, url) {
            // If already loaded before, return a blank box instead of the full shimmer
            // to avoid flashing when switching tabs.
            if (_wasAlreadyLoaded) {
              return SizedBox(width: widget.width, height: widget.height);
            }
            return widget.placeholder ?? _buildShimmerPlaceholder(context);
          },
          errorWidget: (context, url, err) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) _logTime('failed');
            });
            return widget.errorWidget ?? _buildErrorWidget(context, err);
          },
        ),
      ),
    );
  }

  Widget _buildShimmerPlaceholder(BuildContext context) {
    return Container(
      width: widget.width ?? double.infinity,
      height: widget.height ?? double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(widget.borderRadius),
      ),
      // Wait for true Shimmer library or simple pulsing animation for advanced users.
      // We will use a gentle fade/pulse loop built natively.
      child: const Center(
        child: Icon(
          Icons.image_outlined,
          color: Color(0xff9CA3AF),
          size: 24,
        ),
      ),
    );
  }

  Widget _buildErrorWidget(BuildContext context, dynamic error) {
    return Container(
      width: widget.width ?? double.infinity,
      height: widget.height ?? double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(widget.borderRadius),
      ),
      child: const Center(
        child: Icon(
          Icons.broken_image_rounded,
          color: Color(0xff9CA3AF),
          size: 32,
        ),
      ),
    );
  }
}
