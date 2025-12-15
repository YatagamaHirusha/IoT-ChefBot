import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class MjpegViewer extends StatefulWidget {
  final String streamUrl;
  final BoxFit? fit;
  final Widget? placeholder;
  final Widget? errorBuilder;
  final Map<String, String>? headers;

  const MjpegViewer({
    super.key,
    required this.streamUrl,
    this.fit,
    this.placeholder,
    this.errorBuilder,
    this.headers,
  });

  @override
  State<MjpegViewer> createState() => _MjpegViewerState();
}

class _MjpegViewerState extends State<MjpegViewer> {
  // Use a ValueNotifier to update the image efficiently without rebuilding the whole widget tree
  final ValueNotifier<MemoryImage?> _imageNotifier =
      ValueNotifier<MemoryImage?>(null);

  // To control the stream subscription
  StreamSubscription? _subscription;
  http.Client? _client;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _startStream();
  }

  @override
  void didUpdateWidget(MjpegViewer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.streamUrl != oldWidget.streamUrl) {
      _stopStream();
      _startStream();
    }
  }

  void _startStream() {
    setState(() {
      _hasError = false;
    });

    _client = http.Client();
    final request = http.Request("GET", Uri.parse(widget.streamUrl));

    // Add headers optimized for ESP32 MJPEG streams
    request.headers.addAll({
      'Accept': '*/*',
      'Connection': 'keep-alive',
      'User-Agent': 'Flutter',
    });

    if (widget.headers != null) {
      request.headers.addAll(widget.headers!);
    }

    // Send the request asynchronously
    _client!
        .send(request)
        .timeout(
          const Duration(seconds: 10),
          onTimeout: () {
            throw TimeoutException('Stream connection timeout');
          },
        )
        .then((response) {
          if (response.statusCode >= 200 && response.statusCode < 300) {
            _subscription = response.stream.listen(
              _onData,
              onError: _onError,
              onDone: _onDone,
              cancelOnError: true,
            );
          } else {
            _onError("Stream returned status code: ${response.statusCode}");
          }
        })
        .catchError((e) {
          _onError(e);
        });
  }

  // Buffer to accumulate incoming bytes
  final List<int> _buffer = [];

  void _onData(List<int> chunk) {
    _buffer.addAll(chunk);

    // Look for the JPEG start (0xFF 0xD8) and end (0xFF 0xD9) markers
    // This is a simplified MJPEG parser

    int startIndex = -1;
    int endIndex = -1;

    // We scan the buffer to find the start and end of a frame
    // Note: A more robust parser would handle boundary strings properly,
    // but looking for JPEG magic numbers usually works for ESP32 cameras.

    // Find Start of Image (SOI): FF D8
    for (int i = 0; i < _buffer.length - 1; i++) {
      if (_buffer[i] == 0xFF && _buffer[i + 1] == 0xD8) {
        startIndex = i;
        break;
      }
    }

    if (startIndex != -1) {
      // Find End of Image (EOI): FF D9
      // We start searching after the start index
      for (int i = startIndex; i < _buffer.length - 1; i++) {
        if (_buffer[i] == 0xFF && _buffer[i + 1] == 0xD9) {
          endIndex = i + 2; // Include the bytes
          break;
        }
      }

      if (endIndex != -1) {
        // We found a complete frame!
        final jpgBytes = Uint8List.fromList(
          _buffer.sublist(startIndex, endIndex),
        );

        // Update the image
        _imageNotifier.value = MemoryImage(jpgBytes);

        // Remove the processed frame from buffer, keep the rest (if any)
        _buffer.removeRange(0, endIndex);
      }
    } else {
      // If the buffer gets too large without finding a start marker, clear it to prevent memory leaks
      if (_buffer.length > 1024 * 1024) {
        // 1MB limit
        _buffer.clear();
      }
    }
  }

  void _onError(dynamic error) {
    print("MJPEG Error: $error");
    if (mounted) {
      setState(() {
        _hasError = true;
      });
    }
    _stopStream();
  }

  void _onDone() {
    // Stream closed by server
    _stopStream();
  }

  void _stopStream() {
    _subscription?.cancel();
    _subscription = null;
    _client?.close();
    _client = null;
    _buffer.clear();
  }

  @override
  void dispose() {
    _stopStream();
    _imageNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_hasError) {
      return widget.errorBuilder ??
          Container(
            color: Colors.grey[900],
            child: const Center(
              child: Icon(Icons.broken_image, color: Colors.white54),
            ),
          );
    }

    return ValueListenableBuilder<MemoryImage?>(
      valueListenable: _imageNotifier,
      builder: (context, imageProvider, child) {
        if (imageProvider == null) {
          return widget.placeholder ??
              Container(
                color: Colors.black,
                child: const Center(child: CircularProgressIndicator()),
              );
        }

        return Image(
          image: imageProvider,
          fit: widget.fit ?? BoxFit.contain,
          gaplessPlayback: true, // Prevents flickering when image updates
        );
      },
    );
  }
}
