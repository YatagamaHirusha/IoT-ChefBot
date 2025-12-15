import 'package:flutter/material.dart';
import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/realtime_db_service.dart';
import '../services/cooking_history_service.dart';

class HomeControlPanel extends StatefulWidget {
  const HomeControlPanel({super.key});

  @override
  State<HomeControlPanel> createState() => _HomeControlPanelState();
}

class _HomeControlPanelState extends State<HomeControlPanel> {
  // --- State Variables ---
  bool _isCookerOn = false;
  bool _childLockEnabled = false; // <--- NEW CHILD LOCK STATE
  double _flameLevel = 18;

  // Sensor States
  bool _smokeSensor = false;
  bool _gasSensor = false;
  bool _coSensor = false;

  // Track safety alerts during session
  List<SafetyAlert> _sessionSafetyAlerts = [];

  Timer? _timer;
  int _secondsOn = 0;
  DateTime? _sessionStartTime;

  // Stream Subscriptions
  StreamSubscription? _flameSub;
  StreamSubscription? _smokeSub;
  StreamSubscription? _gasSub;
  StreamSubscription? _coSub;

  @override
  void initState() {
    super.initState();
    _initSensors();
  }

  void _initSensors() {
    final db = RealtimeDBService();

    _flameSub = db.listenToIsFlame().listen((isFlame) {
      if (mounted) {
        // Safety check: if cooker is ON but flame goes out
        if (_isCookerOn && !isFlame && _flameLevel > 18) {
          // In a real scenario, you might add a delay here before shutting off
          // to account for sensor flickering, but for safety we warn immediately.
        }
      }
    });

    _smokeSub = db.listenToSmokeSensor().listen((val) {
      if (mounted) {
        if (val && !_smokeSensor) {
          // New alert
          _showSafetyAlert(
            'Smoke',
            'Smoke detected! Please check your cooker.',
          );
          _sessionSafetyAlerts.add(
            SafetyAlert(type: 'smoke', timestamp: DateTime.now()),
          );
        }
        setState(() => _smokeSensor = val);
      }
    });

    _gasSub = db.listenToGasSensor().listen((val) {
      if (mounted) {
        if (val && !_gasSensor) {
          // New alert
          _showSafetyAlert(
            'Gas Leak',
            'Gas leak detected! Turn off the cooker immediately.',
          );
          _sessionSafetyAlerts.add(
            SafetyAlert(type: 'gas', timestamp: DateTime.now()),
          );
        }
        setState(() => _gasSensor = val);
      }
    });

    _coSub = db.listenToCOSensor().listen((val) {
      if (mounted) {
        if (val && !_coSensor) {
          // New alert
          _showSafetyAlert(
            'Carbon Monoxide',
            'CO detected! Ventilate the area immediately.',
          );
          _sessionSafetyAlerts.add(
            SafetyAlert(type: 'co', timestamp: DateTime.now()),
          );
        }
        setState(() => _coSensor = val);
      }
    });
  }

  void _showSafetyAlert(String title, String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF7F1D1D),
        title: Row(
          children: [
            const Icon(Icons.warning, color: Colors.redAccent),
            const SizedBox(width: 8),
            Text(title, style: const TextStyle(color: Colors.white)),
          ],
        ),
        content: Text(message, style: const TextStyle(color: Colors.white)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // --- Logic Methods ---

  void _togglePower() async {
    if (_childLockEnabled) return; // Block if child lock is on

    final db = RealtimeDBService();

    if (!_isCookerOn) {
      // TURN ON SEQUENCE
      setState(() {
        _isCookerOn = true;
        _flameLevel = 60; // Start high for ignition
      });

      try {
        await db.setValveAngle(60);
        await db.triggerIgnition();
        _startTimer();

        // Simulate the automatic reduction after ignition (same as App 1)
        Future.delayed(const Duration(seconds: 5), () {
          if (mounted && _isCookerOn) _setFlameLevel(30);
        });
      } catch (e) {
        print("Error starting cooker: $e");
      }
    } else {
      // TURN OFF
      _turnOffCooker();
    }
  }

  void _turnOffCooker() async {
    if (_childLockEnabled) return;

    setState(() {
      _isCookerOn = false;
      _flameLevel = 18;
    });

    RealtimeDBService().setValveAngle(0);
    _stopTimer();
  }

  void _setFlameLevel(double value) {
    if (_childLockEnabled) return;

    if (value < 18) {
      _turnOffCooker();
      return;
    }

    setState(() => _flameLevel = value);
    RealtimeDBService().setValveAngle(value.round());
  }

  void _startTimer() {
    _stopTimer();
    _sessionStartTime = DateTime.now();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (mounted) setState(() => _secondsOn++);
    });
  }

  void _stopTimer() {
    _timer?.cancel();
    if (_sessionStartTime != null && _secondsOn > 10) {
      // Save history logic with safety alerts
      CookingHistoryService().saveCookingSession(
        startTime: _sessionStartTime!,
        endTime: DateTime.now(),
        durationSeconds: _secondsOn,
        flameLevel: _flameLevel > 40 ? "High" : "Medium",
        safetyAlerts: _sessionSafetyAlerts.isNotEmpty
            ? _sessionSafetyAlerts
            : null,
      );
      _sessionSafetyAlerts.clear();
    }
    _secondsOn = 0;
    _sessionStartTime = null;
  }

  @override
  void dispose() {
    _timer?.cancel();
    _flameSub?.cancel();
    _smokeSub?.cancel();
    _gasSub?.cancel();
    _coSub?.cancel();
    super.dispose();
  }

  // --- UI Helpers ---

  String _formatTime(int totalSeconds) {
    final m = (totalSeconds ~/ 60).toString().padLeft(2, '0');
    final s = (totalSeconds % 60).toString().padLeft(2, '0');
    return "$m:$s";
  }

  String _getFlameLabel(double level) {
    if (level < 30) return 'Low';
    if (level < 45) return 'Medium';
    return 'High';
  }

  double _getIncrementAmount() {
    // In Low range (18-29): increment by 3 to stay in low or move to medium
    if (_flameLevel < 30) return 3;
    // In Medium/High range (30-60): increment by 10
    return 10;
  }

  double _getDecrementAmount() {
    // Above 30: decrement by 10 until we reach 30
    if (_flameLevel > 30) return 10;
    // At or below 30 (in Low range): decrement by 3
    return 3;
  }

  @override
  Widget build(BuildContext context) {
    // We use this opacity to visually indicate disabled state
    final double controlOpacity = _childLockEnabled ? 0.3 : 1.0;

    return Scaffold(
      appBar: AppBar(
        title: const Text("ChefBot Control"),
        actions: [
          // Child Lock Switch in AppBar
          Row(
            children: [
              Icon(
                _childLockEnabled ? Icons.lock : Icons.lock_open,
                color: _childLockEnabled ? Colors.redAccent : Colors.grey,
              ),
              Switch(
                value: _childLockEnabled,
                activeColor: Colors.redAccent,
                onChanged: (val) {
                  setState(() => _childLockEnabled = val);
                  if (val) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text("Child Lock Enabled. Controls disabled."),
                      ),
                    );
                  }
                },
              ),
            ],
          ),
          const SizedBox(width: 8),
          // Logout Button
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              if (context.mounted) {
                Navigator.pushReplacementNamed(context, '/signin');
              }
            },
            tooltip: 'Logout',
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // MAIN CONTROLS (Wrapped in Opacity/IgnorePointer for Child Lock)
            IgnorePointer(
              ignoring: _childLockEnabled,
              child: Opacity(
                opacity: controlOpacity,
                child: Column(
                  children: [
                    const SizedBox(height: 20),
                    // Power Button Area
                    GestureDetector(
                      onTap: _togglePower,
                      child: Container(
                        width: 180,
                        height: 180,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _isCookerOn
                              ? const Color(0xFFEF4444).withOpacity(
                                  0.2,
                                ) // Red glow
                              : const Color(0xFF1E293B),
                          border: Border.all(
                            color: _isCookerOn
                                ? const Color(0xFFEF4444)
                                : const Color(0xFF475569),
                            width: 4,
                          ),
                          boxShadow: _isCookerOn
                              ? [
                                  BoxShadow(
                                    color: Colors.red.withOpacity(0.4),
                                    blurRadius: 30,
                                  ),
                                ]
                              : [],
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.power_settings_new,
                              size: 48,
                              color: _isCookerOn
                                  ? Colors.redAccent
                                  : Colors.grey,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _isCookerOn ? "ON" : "OFF",
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Timer Display
                    Text(
                      _isCookerOn ? _formatTime(_secondsOn) : "00:00",
                      style: const TextStyle(
                        fontSize: 48,
                        fontWeight: FontWeight.w200, // Thin font
                        color: Colors.white,
                        fontFeatures: [
                          FontFeature.tabularFigures(),
                        ], // Monospace numbers
                      ),
                    ),

                    const SizedBox(height: 40),

                    // Flame Control with Plus/Minus buttons
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E293B),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        children: [
                          const Text(
                            "FLAME INTENSITY",
                            style: TextStyle(
                              color: Colors.grey,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.5,
                            ),
                          ),
                          const SizedBox(height: 20),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              // Minus Button
                              IconButton(
                                onPressed: () {
                                  if (!_childLockEnabled && _flameLevel > 18) {
                                    _setFlameLevel(
                                      _flameLevel - _getDecrementAmount(),
                                    );
                                  }
                                },
                                icon: const Icon(Icons.remove, size: 28),
                                style: IconButton.styleFrom(
                                  backgroundColor: const Color(0xFF334155),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.all(16),
                                ),
                              ),
                              const SizedBox(width: 30),
                              // Flame Level Display
                              Column(
                                children: [
                                  Text(
                                    _flameLevel.round().toString(),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 42,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    _getFlameLabel(_flameLevel),
                                    style: const TextStyle(
                                      color: Color(0xFF6366F1),
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(width: 30),
                              // Plus Button
                              IconButton(
                                onPressed: () {
                                  if (!_childLockEnabled && _flameLevel < 60) {
                                    _setFlameLevel(
                                      _flameLevel + _getIncrementAmount(),
                                    );
                                  }
                                },
                                icon: const Icon(Icons.add, size: 28),
                                style: IconButton.styleFrom(
                                  backgroundColor: const Color(0xFF334155),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.all(16),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 50),

            // BOTTOM BUTTONS SECTION
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pushNamed(context, '/camera');
                    },
                    icon: const Icon(Icons.videocam_outlined, size: 20),
                    label: const Text("Live Feed"),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF6366F1),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      side: const BorderSide(
                        color: Color(0xFF6366F1),
                        width: 2,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pushNamed(context, '/history');
                    },
                    icon: const Icon(Icons.history, size: 20),
                    label: const Text("History"),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF6366F1),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      side: const BorderSide(
                        color: Color(0xFF6366F1),
                        width: 2,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
