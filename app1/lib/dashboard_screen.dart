import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'services/realtime_db_service.dart';
import 'services/cooking_history_service.dart';
import 'settings_screen.dart'; // <-- 1. IMPORT THE NEW SCREEN
import 'cooking_history_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  // --- State Variables ---
  String? _captureUrl;
  Uint8List? _capturedImage;
  bool _isPlaying = false;
  bool _isLoadingImage = false;
  bool _isLoadingConfig = true;

  bool _isCookerOn = false;
  double _flameLevel = 18; // Angle from 18-60 degrees
  bool _isFlameVerified = false;

  // Safety sensor states
  bool _smokeSensor = false;
  bool _gasSensor = false;
  bool _coSensor = false;

  Timer? _timer;
  Timer? _flameCheckTimer;
  int _secondsOn = 0;
  DateTime? _sessionStartTime;

  // Stream subscriptions for real-time updates
  StreamSubscription? _isFlameSubscription;
  StreamSubscription? _smokeSensorSubscription;
  StreamSubscription? _gasSensorSubscription;
  StreamSubscription? _coSensorSubscription;

  // --- Methods ---

  @override
  void initState() {
    super.initState();
    _fetchCameraConfig();
    // Setup sensor listeners asynchronously to avoid blocking UI
    Future.delayed(Duration.zero, () {
      _setupSensorListeners();
    });
  }

  void _setupSensorListeners() {
    try {
      final dbService = RealtimeDBService();

      // Listen to is_flame for real-time verification
      _isFlameSubscription = dbService.listenToIsFlame().listen(
        (isFlame) async {
          if (mounted) {
            final previousFlameState = _isFlameVerified;
            setState(() {
              _isFlameVerified = isFlame;
            });

            // If flame goes out unexpectedly while cooker was on - SAFETY SHUTOFF
            if (_isCookerOn &&
                !isFlame &&
                _flameLevel > 0 &&
                previousFlameState) {
              print(
                '🚨 Flame went out unexpectedly! Initiating safety shutoff...',
              );

              // Close the valve immediately for safety
              try {
                await dbService.setValveAngle(0);
                print('Valve closed for safety');
              } catch (e) {
                print('Error closing valve: $e');
              }

              // Update UI to show cooker is off
              setState(() {
                _isCookerOn = false;
                _flameLevel = 0;
              });
              _stopTimer();
              _flameCheckTimer?.cancel();

              // Notify user
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    '⚠️ Flame went out unexpectedly! Valve has been closed for safety.',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  backgroundColor: Colors.red,
                  duration: Duration(seconds: 7),
                ),
              );
            }

            // If flame is detected and cooker wasn't on, update state
            if (isFlame && !_isCookerOn) {
              setState(() {
                _isCookerOn = true;
                if (_timer == null || !_timer!.isActive) {
                  _startTimer();
                }
              });
            }
          }
        },
        onError: (error) {
          print('Error listening to is_flame: $error');
        },
      );

      // Listen to smoke sensor
      _smokeSensorSubscription = dbService.listenToSmokeSensor().listen(
        (value) {
          if (mounted) {
            setState(() {
              _smokeSensor = value;
            });
            if (value) {
              _showSafetyAlert(
                'Smoke Detected!',
                'High smoke levels detected. Please check the cooker.',
              );
            }
          }
        },
        onError: (error) {
          print('Error listening to smoke sensor: $error');
        },
      );

      // Listen to gas sensor
      _gasSensorSubscription = dbService.listenToGasSensor().listen(
        (value) {
          if (mounted) {
            setState(() {
              _gasSensor = value;
            });
            if (value) {
              _showSafetyAlert(
                'Gas Leak Detected!',
                'Gas leak detected. Please ventilate the area immediately.',
              );
            }
          }
        },
        onError: (error) {
          print('Error listening to gas sensor: $error');
        },
      );

      // Listen to CO sensor
      _coSensorSubscription = dbService.listenToCOSensor().listen(
        (value) {
          if (mounted) {
            setState(() {
              _coSensor = value;
            });
            if (value) {
              _showSafetyAlert(
                'Carbon Monoxide Detected!',
                'Dangerous CO levels detected. Leave the area and ventilate.',
              );
            }
          }
        },
        onError: (error) {
          print('Error listening to CO sensor: $error');
        },
      );
    } catch (e) {
      print('Error setting up sensor listeners: $e');
    }
  }

  void _showSafetyAlert(String title, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 4),
            Text(message),
          ],
        ),
        backgroundColor: Colors.red[700],
        duration: const Duration(seconds: 5),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _fetchCameraConfig() async {
    print("Dashboard: Starting _fetchCameraConfig");
    try {
      final config = await RealtimeDBService().getCameraConfig();
      print("Dashboard: Got config: $config");
      if (mounted) {
        setState(() {
          _captureUrl = config['capture_url'];
          _isLoadingConfig = false;
        });
        print("Dashboard: Set state - loading complete");
      }
    } catch (e) {
      print("Error in _fetchCameraConfig: $e");
      if (mounted) {
        setState(() {
          _isLoadingConfig = false;
        });
      }
    } finally {
      // Ensure loading is stopped even if something weird happens
      if (mounted && _isLoadingConfig) {
        print("Dashboard: Finally block - forcing loading to false");
        setState(() {
          _isLoadingConfig = false;
        });
      }
    }
  }

  void _startStream() {
    if (_captureUrl == null || _captureUrl!.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Camera URL not available")));
      return;
    }

    setState(() {
      _isPlaying = true;
      _capturedImage = null; // Clear captured image
    });

    // Use polling method: capture images repeatedly for smooth "streaming"
    _startPollingStream();
  }

  Timer? _pollingTimer;

  void _startPollingStream() {
    _pollingTimer?.cancel();
    _pollingTimer = Timer.periodic(const Duration(milliseconds: 200), (
      timer,
    ) async {
      if (!_isPlaying || !mounted) {
        timer.cancel();
        return;
      }

      try {
        final response = await http
            .get(Uri.parse(_captureUrl!))
            .timeout(const Duration(milliseconds: 150));

        if (response.statusCode == 200 && mounted && _isPlaying) {
          setState(() {
            _capturedImage = response.bodyBytes;
          });
        }
      } catch (e) {
        // Silently fail for polling errors to avoid spam
        // print("Polling error: $e");
      }
    });
  }

  Future<void> _stopStream() async {
    _pollingTimer?.cancel();
    _pollingTimer = null;

    if (mounted) {
      setState(() {
        _isPlaying = false;
      });
    }
  }

  Future<void> _captureImage() async {
    if (_captureUrl == null || _captureUrl!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Capture URL not available")),
      );
      return;
    }

    setState(() {
      _isLoadingImage = true;
      // _stopStream(); // Don't stop immediately, wait for success
    });

    try {
      final response = await http
          .get(Uri.parse(_captureUrl!))
          .timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        if (_isPlaying) {
          await _stopStream();
        }
        setState(() {
          _capturedImage = response.bodyBytes;
          _isLoadingImage = false;
        });
      } else {
        throw Exception('Failed to load image: ${response.statusCode}');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingImage = false;
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Error capturing image: $e")));
      }
    }
  }

  void _togglePower() async {
    final dbService = RealtimeDBService();
    final willTurnOn = !_isCookerOn;

    if (willTurnOn) {
      // Turn on = start with max valve (60) for ignition
      setState(() {
        _isCookerOn = true;
        _flameLevel = 23; // Set to medium level during ignition
      });

      try {
        // Start at 60 for max gas flow and ignition
        await dbService.setValveAngle(60);
        // Trigger ignition (will be true for 5 seconds, then auto false)
        dbService.triggerIgnition();
        _startTimer();

        // After 5 seconds, reduce to 30 (transition)
        Timer(const Duration(seconds: 5), () async {
          if (mounted && _isCookerOn) {
            await dbService.setValveAngle(30);
            print('Flame reduced to 30 after 5 seconds');
          }
        });

        // After 8 seconds total, set to HIGH (28)
        Timer(const Duration(seconds: 8), () async {
          if (mounted && _isCookerOn) {
            await dbService.setValveAngle(28);
            print('Flame set to HIGH (28) after 8 seconds');
          }
        });

        // After 10 seconds total, set to MEDIUM (23)
        Timer(const Duration(seconds: 10), () async {
          if (mounted && _isCookerOn) {
            await dbService.setValveAngle(23);
            print('Flame set to MEDIUM (23) after 10 seconds');
          }
        });

        // Check if flame ignites after 12 seconds
        _flameCheckTimer?.cancel();
        _flameCheckTimer = Timer(const Duration(seconds: 12), () async {
          final isFlame = await dbService.getIsFlame();
          if (!isFlame && mounted) {
            // Flame didn't ignite - turn off valve and notify user
            await dbService.setValveAngle(0);

            setState(() {
              _isCookerOn = false;
              _flameLevel = 18;
            });
            _stopTimer();

            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  '⚠️ Gas cooker did not ignite. Valve has been closed. Please check gas supply and ignition.',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                backgroundColor: Colors.red,
                duration: Duration(seconds: 7),
              ),
            );
          }
        });
      } catch (e) {
        print('Error turning on cooker: $e');
        if (mounted) {
          setState(() {
            _isCookerOn = false;
            _flameLevel = 18;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error turning on cooker: $e')),
          );
        }
      }
    } else {
      // Turn off
      setState(() {
        _isCookerOn = false;
        _flameLevel = 18;
      });

      try {
        await dbService.setValveAngle(0);
        _stopTimer();
        _flameCheckTimer?.cancel();
      } catch (e) {
        print('Error turning off cooker: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error turning off cooker: $e')),
          );
        }
      }
    }
  }

  void _setFlameLevel(double value) async {
    final dbService = RealtimeDBService();
    final turningOn = !_isCookerOn && value >= 18;

    setState(() {
      _flameLevel = value;
    });

    if (value < 18) {
      // User set below minimum - turn off
      setState(() {
        _isCookerOn = false;
        _flameLevel = 18;
      });
      await dbService.setValveAngle(0);
      _stopTimer();
      _flameCheckTimer?.cancel();
    } else {
      // Use the slider value directly as valve angle (18-60)
      int valveAngle = value.round();

      if (turningOn) {
        // Perform ignition sequence
        setState(() {
          _isCookerOn = true;
        });

        try {
          // Start with max valve (60) for ignition, then step down
          await dbService.setValveAngle(60);
          _startTimer();

          // Trigger ignition when turning on from off
          dbService.triggerIgnition();

          // After 5 seconds, reduce to 30
          Timer(const Duration(seconds: 5), () async {
            if (mounted && _isCookerOn) {
              await dbService.setValveAngle(30);
              print('Flame reduced to 30 after 5 seconds');
            }
          });

          // After 8 seconds, set to HIGH (28)
          Timer(const Duration(seconds: 8), () async {
            if (mounted && _isCookerOn) {
              await dbService.setValveAngle(28);
              print('Flame set to HIGH (28) after 8 seconds');
            }
          });

          // After 10 seconds, reduce to target level
          Timer(const Duration(seconds: 10), () async {
            if (mounted && _isCookerOn) {
              await dbService.setValveAngle(valveAngle);
              print('Flame set to target level ($valveAngle) after 10 seconds');
            }
          });

          _flameCheckTimer?.cancel();
          _flameCheckTimer = Timer(const Duration(seconds: 12), () async {
            final isFlame = await dbService.getIsFlame();
            if (!isFlame && mounted) {
              // Flame didn't ignite - turn off valve and notify user
              await dbService.setValveAngle(0);

              setState(() {
                _isCookerOn = false;
                _flameLevel = 18;
              });
              _stopTimer();

              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    '⚠️ Gas cooker did not ignite. Valve has been closed. Please check gas supply and ignition.',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  backgroundColor: Colors.red,
                  duration: Duration(seconds: 7),
                ),
              );
            }
          });
        } catch (e) {
          print('Error during ignition: $e');
          if (mounted) {
            setState(() {
              _isCookerOn = false;
              _flameLevel = 18;
            });
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Error during ignition: $e')),
            );
          }
        }
      } else {
        // Just change the flame level, cooker already on
        try {
          await dbService.setValveAngle(valveAngle);
          print('Flame level adjusted to $valveAngle');
        } catch (e) {
          print('Error adjusting flame: $e');
        }
      }
    }
  }

  // ... (All other methods: _startTimer, _stopTimer, _formatDuration, dispose) ...
  // (No changes needed to the timer methods or dispose)
  String _formatDuration(int seconds) {
    final duration = Duration(seconds: seconds);
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    String twoDigitHours = twoDigits(duration.inHours);
    return "$twoDigitHours:$twoDigitMinutes:$twoDigitSeconds";
  }

  void _startTimer() {
    _timer?.cancel();
    _sessionStartTime = DateTime.now();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _secondsOn++;
      });
    });
  }

  void _stopTimer() async {
    _timer?.cancel();

    // Save cooking session to history if it lasted more than 10 seconds
    if (_sessionStartTime != null && _secondsOn > 10) {
      final endTime = DateTime.now();
      final flameLabel = _getLevelLabel(_flameLevel.round());

      try {
        await CookingHistoryService().saveCookingSession(
          startTime: _sessionStartTime!,
          endTime: endTime,
          durationSeconds: _secondsOn,
          flameLevel: flameLabel,
        );
        print('Session saved: ${_secondsOn}s at $flameLabel');
      } catch (e) {
        print('Error saving session: $e');
      }
    }

    setState(() {
      _secondsOn = 0;
      _sessionStartTime = null;
    });
  }

  String _getLevelLabel(int level) {
    if (level < 18) return "Off";
    if (level < 28) return "Low";
    if (level < 40) return "Medium";
    return "High";
  }

  @override
  void dispose() {
    _timer?.cancel();
    _flameCheckTimer?.cancel();
    _pollingTimer?.cancel();
    _isFlameSubscription?.cancel();
    _smokeSensorSubscription?.cancel();
    _gasSensorSubscription?.cancel();
    _coSensorSubscription?.cancel();
    _stopStream();
    super.dispose();
  }

  // --- UI Build ---
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("ChefBot Dashboard"),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(Icons.history, color: Colors.grey[800]),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const CookingHistoryScreen(),
                ),
              );
            },
            tooltip: 'Cooking History',
          ),
          IconButton(
            icon: Icon(Icons.settings, color: Colors.grey[800]),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => SettingsScreen(isCookerOn: _isCookerOn),
                ),
              );
            },
          ),
        ],
      ),
      body: _isLoadingConfig
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildVideoPlayer(),
                    const SizedBox(height: 24),
                    _buildSafetyStatus(),
                    const SizedBox(height: 24),
                    _buildMainControls(),
                    const SizedBox(height: 24),
                    _buildFlameControl(),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
    );
  }

  // --- Helper Widgets ---

  Widget _buildVideoPlayer() {
    return Column(
      children: [
        AspectRatio(
          aspectRatio: 16 / 9,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(12),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: _capturedImage != null
                  ? Image.memory(
                      _capturedImage!,
                      fit: BoxFit.cover,
                      gaplessPlayback: true,
                    )
                  : _isLoadingImage
                  ? const Center(
                      child: CircularProgressIndicator(color: Colors.white),
                    )
                  : Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _isPlaying
                                ? Icons.hourglass_empty
                                : Icons.videocam_off,
                            color: Colors.white54,
                            size: 50,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _isPlaying ? "Loading stream..." : "Camera Off",
                            style: const TextStyle(color: Colors.white54),
                          ),
                        ],
                      ),
                    ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: ElevatedButton.icon(
                  onPressed: _isPlaying ? _stopStream : _startStream,
                  icon: Icon(_isPlaying ? Icons.stop : Icons.play_arrow),
                  label: Text(_isPlaying ? "Stop Live" : "Watch Live"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isPlaying ? Colors.red : Colors.blue,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(left: 8.0),
                child: ElevatedButton.icon(
                  onPressed: _captureImage,
                  icon: const Icon(Icons.camera_alt),
                  label: const Text("Capture Image"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSafetyStatus() {
    return Card(
      elevation: 2,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildStatusIndicator(
              Icons.gas_meter,
              "Gas",
              _gasSensor ? "ALERT" : "Safe",
              _gasSensor ? Colors.red : Colors.green,
            ),
            _buildStatusIndicator(
              Icons.smoke_free,
              "Smoke",
              _smokeSensor ? "ALERT" : "Safe",
              _smokeSensor ? Colors.red : Colors.green,
            ),
            _buildStatusIndicator(
              Icons.air,
              "CO",
              _coSensor ? "ALERT" : "Safe",
              _coSensor ? Colors.red : Colors.green,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusIndicator(
    IconData icon,
    String label,
    String status,
    Color color,
  ) {
    return Column(
      children: [
        Icon(icon, size: 30, color: color),
        const SizedBox(height: 8),
        Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
        Text(
          status,
          style: TextStyle(color: color, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Widget _buildMainControls() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          children: [
            const Text(
              "Cooker Power",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            InkWell(
              onTap: _togglePower,
              borderRadius: BorderRadius.circular(50),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: _isCookerOn ? Colors.red[100] : Colors.green[100],
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: _isCookerOn && !_isFlameVerified
                        ? Colors.orange
                        : Colors.transparent,
                    width: 3,
                  ),
                ),
                child: Icon(
                  Icons.power_settings_new,
                  size: 40,
                  color: _isCookerOn ? Colors.red : Colors.green,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _isCookerOn ? "ON" : "OFF",
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: _isCookerOn ? Colors.red : Colors.green,
              ),
            ),
            if (_isCookerOn)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _isFlameVerified ? Icons.check_circle : Icons.warning,
                      size: 16,
                      color: _isFlameVerified ? Colors.green : Colors.orange,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _isFlameVerified ? "Flame On" : "Igniting...",
                      style: TextStyle(
                        fontSize: 12,
                        color: _isFlameVerified ? Colors.green : Colors.orange,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
        Column(
          children: [
            const Text(
              "Time Elapsed",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              _formatDuration(_secondsOn),
              style: TextStyle(
                fontSize: 42,
                fontWeight: FontWeight.w300,
                color: Colors.grey[800],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildFlameControl() {
    String getFlameLabel(double value) {
      if (value < 18) return "Off";
      if (value < 28) return "Low";
      if (value < 40) return "Medium";
      return "High";
    }

    return Card(
      elevation: 2,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "Flame Intensity",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                Text(
                  getFlameLabel(_flameLevel),
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue[600],
                  ),
                ),
              ],
            ),
            Slider(
              value: _flameLevel,
              min: 18,
              max: 60,
              divisions: 42,
              label: getFlameLabel(_flameLevel),
              onChanged: (value) {
                _setFlameLevel(value);
              },
            ),
          ],
        ),
      ),
    );
  }
}
