import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class MjpegViewer extends StatefulWidget {
  final String streamUrl;
  final BoxFit fit;
  final Widget? placeholder;
  final Widget? errorBuilder;
  final Map<String, String>? headers;

  const MjpegViewer({
    super.key,
    required this.streamUrl,
    this.fit = BoxFit.contain,
    this.placeholder,
    this.errorBuilder,
    this.headers,
  });

  @override
  State<MjpegViewer> createState() => _MjpegViewerState();
}

class _MjpegViewerState extends State<MjpegViewer> {
  StreamSubscription? _subscription;
  http.Client? _client;
  Uint8List? _currentFrame;
  String? _error;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _startStream();
  }

  @override
  void didUpdateWidget(MjpegViewer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.streamUrl != widget.streamUrl) {
      _stopStream();
      _startStream();
    }
  }

  @override
  void dispose() {
    _stopStream();
    super.dispose();
  }

  void _stopStream() {
    _subscription?.cancel();
    _subscription = null;
    _client?.close();
    _client = null;
  }

  Future<void> _startStream() async {
    if (widget.streamUrl.isEmpty) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    print("MjpegViewer: Connecting to ${widget.streamUrl}");

    try {
      _client = http.Client();
      final request = http.Request('GET', Uri.parse(widget.streamUrl));
      if (widget.headers != null) {
        request.headers.addAll(widget.headers!);
      }

      print("MjpegViewer: Sending request...");

      // Add timeout for connection - increased to 30 seconds
      final response = await _client!
          .send(request)
          .timeout(
            const Duration(seconds: 30),
            onTimeout: () {
              throw TimeoutException(
                'Connection timeout - cannot reach camera',
              );
            },
          );

      print("MjpegViewer: Response received!");
      print("MjpegViewer: Status code: ${response.statusCode}");
      print("MjpegViewer: Content-Type: ${response.headers['content-type']}");
      print("MjpegViewer: Headers: ${response.headers}");

      if (response.statusCode != 200) {
        throw Exception('Stream returned status code ${response.statusCode}');
      }

      // Successfully connected - clear loading state
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }

      final stream = response.stream;
      List<int> buffer = [];
      int chunkCount = 0;
      int totalBytes = 0;

      _subscription = stream.listen(
        (chunk) {
          if (chunk.isEmpty) return;
          chunkCount++;
          totalBytes += chunk.length;
          if (chunkCount <= 5) {
            print(
              "MjpegViewer: Received chunk #$chunkCount of size ${chunk.length} bytes (total: $totalBytes)",
            );
          }
          buffer.addAll(chunk);
          _processBuffer(buffer);
        },
        onError: (error) {
          print("MjpegViewer: Stream error: $error");
          if (mounted) {
            setState(() {
              _error = "Stream error: $error";
              _isLoading = false;
            });
          }
        },
        onDone: () {
          print(
            "MjpegViewer: Stream closed (received $chunkCount chunks, $totalBytes total bytes)",
          );
          if (mounted) {
            setState(() {
              _error = "Stream connection closed";
              _isLoading = false;
            });
          }
        },
        cancelOnError: true,
      );
    } catch (e, stackTrace) {
      print("MjpegViewer: Connection error: $e");
      print("MjpegViewer: Stack trace: $stackTrace");
      if (mounted) {
        setState(() {
          _error = "Connection error: ${e.toString()}";
          _isLoading = false;
        });
      }
    }
  }

  void _processBuffer(List<int> buffer) {
    // Simple parser looking for JPEG SOI (FF D8) and EOI (FF D9)

    // Optimization: Only search if buffer is large enough
    if (buffer.length < 100) return;

    int start = -1;
    int end = -1;

    // Search for SOI
    for (int i = 0; i < buffer.length - 1; i++) {
      if (buffer[i] == 0xFF && buffer[i + 1] == 0xD8) {
        start = i;
        break;
      }
    }

    if (start != -1) {
      // Search for EOI after SOI
      for (int i = start + 2; i < buffer.length - 1; i++) {
        if (buffer[i] == 0xFF && buffer[i + 1] == 0xD9) {
          end = i + 2; // Include the EOI bytes
          break;
        }
      }
    }

    if (start != -1 && end != -1) {
      // We found a full frame
      final frameData = Uint8List.fromList(buffer.sublist(start, end));
      final frameSize = frameData.length;

      // Remove processed data from buffer
      buffer.removeRange(0, end);

      if (mounted) {
        setState(() {
          _currentFrame = frameData;
          _isLoading = false;
        });
      }

      // Log first few frames
      if (_currentFrame != null && frameSize > 0) {
        print(
          "MjpegViewer: Frame decoded successfully! Size: ${frameSize} bytes, Buffer remaining: ${buffer.length}",
        );
      }

      // Recursively check if we have another frame in the remaining buffer
      if (buffer.length > 100) {
        _processBuffer(buffer);
      }
    } else if (start == -1 && buffer.length > 5 * 1024 * 1024) {
      // Safety: if buffer gets too huge (5MB) without finding a frame, clear it
      print("MjpegViewer: Buffer too large (${buffer.length}), clearing");
      buffer.clear();
    } else if (start != -1 && buffer.length - start > 5 * 1024 * 1024) {
      // Found start but no end for 5MB?
      print("MjpegViewer: Frame too large or no EOI, clearing");
      buffer.clear();
    } else {
      // Waiting for more data
      if (start != -1) {
        print(
          "MjpegViewer: Found SOI at $start, waiting for EOI... Buffer size: ${buffer.length}",
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return widget.errorBuilder ??
          Container(
            color: Colors.black,
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error, color: Colors.red),
                  const SizedBox(height: 8),
                  Text(_error!, style: const TextStyle(color: Colors.white)),
                ],
              ),
            ),
          );
    }

    if (_currentFrame == null) {
      return widget.placeholder ??
          Container(
            color: Colors.black,
            child: const Center(child: CircularProgressIndicator()),
          );
    }

    return Image.memory(
      _currentFrame!,
      fit: widget.fit,
      gaplessPlayback: true, // Important for smooth video
    );
  }
}
