import 'package:flutter/material.dart';
import '../services/realtime_db_service.dart';
// Ensure this import path matches where your MjpegViewer is located
import '../widgets/mjpeg_viewer.dart';

class CameraFeedView extends StatefulWidget {
  const CameraFeedView({super.key});

  @override
  State<CameraFeedView> createState() => _CameraFeedViewState();
}

class _CameraFeedViewState extends State<CameraFeedView> {
  String? _streamUrl;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadConfig();
  }

  Future<void> _loadConfig() async {
    final config = await RealtimeDBService().getCameraConfig();
    if (mounted) {
      setState(() {
        _streamUrl = config['stream_url'];
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black, // Immersive feel
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Text("Live Feed"),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Center(
        child: _isLoading
            ? const CircularProgressIndicator(color: Colors.white)
            : _streamUrl == null
            ? const Text(
                "Stream URL not found",
                style: TextStyle(color: Colors.white),
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Expanded(
                    child: MjpegViewer(
                      streamUrl: _streamUrl!,
                      fit: BoxFit.contain,
                      placeholder: const Center(
                        child: CircularProgressIndicator(color: Colors.white),
                      ),
                      errorBuilder: const Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.videocam_off,
                              color: Colors.white54,
                              size: 50,
                            ),
                            SizedBox(height: 16),
                            Text(
                              "Camera Offline",
                              style: TextStyle(color: Colors.white54),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
