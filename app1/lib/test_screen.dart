// import 'package:flutter/material.dart';
// import 'dart:async';
// import 'settings_screen.dart';

// class DashboardScreen extends StatefulWidget {
//   const DashboardScreen({super.key});

//   @override
//   State<DashboardScreen> createState() => _DashboardScreenState();
// }

// class _DashboardScreenState extends State<DashboardScreen> {
//   bool _isCookerOn = false; // <-- This state will be passed
//   bool _isChildLockOn = false;
//   // ... (all other state variables)

//   // ... (all other methods: _togglePower, _toggleChildLock, _setFlameLevel, etc.)
//   // (No changes are needed to any of your existing methods)
//   // ... (methods code) ...
//   double _flameLevel = 0;
//   String _gasStatus = "Safe";
//   String _smokeStatus = "Safe";
//   String _coStatus = "Safe";
//   Timer? _timer;
//   int _secondsOn = 0;

//   void _togglePower() {
//     setState(() {
//       _isCookerOn = !_isCookerOn;
//       if (_isCookerOn) {
//         _flameLevel = 1;
//         _startTimer();
//       } else {
//         _flameLevel = 0;
//         _stopTimer();
//       }
//     });
//   }

//   void _toggleChildLock(bool value) {
//     setState(() {
//       _isChildLockOn = value;
//     });
//   }

//   void _setFlameLevel(double value) {
//     if (value == 0) {
//       _isCookerOn = false;
//       _stopTimer();
//     } else {
//       _isCookerOn = true;
//       if (_timer == null || !_timer!.isActive) {
//         _startTimer();
//       }
//     }
//     setState(() {
//       _flameLevel = value;
//     });
//   }

//   String _formatDuration(int seconds) {
//     final duration = Duration(seconds: seconds);
//     String twoDigits(int n) => n.toString().padLeft(2, '0');
//     String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
//     String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
//     String twoDigitHours = twoDigits(duration.inHours);
//     return "$twoDigitHours:$twoDigitMinutes:$twoDigitSeconds";
//   }

//   void _startTimer() {
//     _timer?.cancel();
//     _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
//       setState(() {
//         _secondsOn++;
//       });
//     });
//   }

//   void _stopTimer() {
//     _timer?.cancel();
//     setState(() {
//       _secondsOn = 0;
//     });
//   }

//   @override
//   void dispose() {
//     _timer?.cancel();
//     super.dispose();
//   }

//   @override
//   Widget build(BuildContext context) {
//     final bool controlsDisabled = _isChildLockOn;

//     return Scaffold(
//       appBar: AppBar(
//         title: const Text("ChefBot Dashboard"),
//         backgroundColor: Colors.transparent,
//         elevation: 0,
//         actions: [
//           IconButton(
//             icon: Icon(Icons.settings, color: Colors.grey[800]),
//             onPressed: () {
//               // --- UPDATE THE NAVIGATION CALL HERE ---
//               Navigator.push(
//                 context,
//                 MaterialPageRoute(
//                   builder: (context) => SettingsScreen(
//                     initialChildLockState: _isChildLockOn,
//                     onChildLockChanged: _toggleChildLock,
//                     isCookerOn: _isCookerOn, // <-- PASS THE STATE HERE
//                   ),
//                 ),
//               );
//             },
//           ),
//         ],
//       ),
//       // ... (The rest of your body and helper widgets are unchanged) ...
//       body: SingleChildScrollView(
//         child: Padding(
//           padding: const EdgeInsets.all(16.0),
//           child: Column(
//             crossAxisAlignment: CrossAxisAlignment.stretch,
//             children: [
//               _buildVideoPlayer(controlsDisabled),
//               const SizedBox(height: 24),
//               _buildSafetyStatus(controlsDisabled),
//               const SizedBox(height: 24),
//               _buildMainControls(controlsDisabled),
//               const SizedBox(height: 24),
//               _buildFlameControl(controlsDisabled),
//               const SizedBox(height: 16),
//             ],
//           ),
//         ),
//       ),
//     );
//   }

//   // ... (All _build... helper widgets are unchanged) ...
//   Widget _buildVideoPlayer(bool disabled) {
//     return Opacity(
//       opacity: disabled ? 0.5 : 1.0,
//       child: AspectRatio(
//         aspectRatio: 16 / 9,
//         child: Container(
//           decoration: BoxDecoration(
//             color: Colors.black,
//             borderRadius: BorderRadius.circular(12),
//           ),
//           child: const Center(
//             child: Icon(Icons.videocam, color: Colors.white, size: 50),
//           ),
//         ),
//       ),
//     );
//   }

//   Widget _buildSafetyStatus(bool disabled) {
//     return Opacity(
//       opacity: disabled ? 0.5 : 1.0,
//       child: Card(
//         elevation: 2,
//         color: Colors.white,
//         shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
//         child: Padding(
//           padding: const EdgeInsets.symmetric(vertical: 16.0),
//           child: Row(
//             mainAxisAlignment: MainAxisAlignment.spaceAround,
//             children: [
//               _buildStatusIndicator(
//                 Icons.gas_meter,
//                 "Gas",
//                 _gasStatus,
//                 Colors.green,
//               ),
//               _buildStatusIndicator(
//                 Icons.smoke_free,
//                 "Smoke",
//                 _smokeStatus,
//                 Colors.green,
//               ),
//               _buildStatusIndicator(Icons.air, "CO", _coStatus, Colors.green),
//             ],
//           ),
//         ),
//       ),
//     );
//   }

//   Widget _buildStatusIndicator(
//     IconData icon,
//     String label,
//     String status,
//     Color color,
//   ) {
//     return Column(
//       children: [
//         Icon(icon, size: 30, color: color),
//         const SizedBox(height: 8),
//         Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
//         Text(
//           status,
//           style: TextStyle(color: color, fontWeight: FontWeight.bold),
//         ),
//       ],
//     );
//   }

//   Widget _buildMainControls(bool disabled) {
//     return Opacity(
//       opacity: disabled ? 0.5 : 1.0,
//       child: Row(
//         mainAxisAlignment: MainAxisAlignment.spaceBetween,
//         children: [
//           Column(
//             children: [
//               const Text(
//                 "Cooker Power",
//                 style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
//               ),
//               const SizedBox(height: 8),
//               InkWell(
//                 onTap: disabled ? null : _togglePower,
//                 borderRadius: BorderRadius.circular(50),
//                 child: Container(
//                   padding: const EdgeInsets.all(20),
//                   decoration: BoxDecoration(
//                     color: _isCookerOn ? Colors.red[100] : Colors.green[100],
//                     shape: BoxShape.circle,
//                   ),
//                   child: Icon(
//                     Icons.power_settings_new,
//                     size: 40,
//                     color: _isCookerOn ? Colors.red : Colors.green,
//                   ),
//                 ),
//               ),
//               const SizedBox(height: 8),
//               Text(
//                 _isCookerOn ? "ON" : "OFF",
//                 style: TextStyle(
//                   fontSize: 16,
//                   fontWeight: FontWeight.bold,
//                   color: _isCookerOn ? Colors.red : Colors.green,
//                 ),
//               ),
//             ],
//           ),
//           Column(
//             children: [
//               const Text(
//                 "Time Elapsed",
//                 style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
//               ),
//               const SizedBox(height: 8),
//               Text(
//                 _formatDuration(_secondsOn),
//                 style: TextStyle(
//                   fontSize: 42,
//                   fontWeight: FgWeight.w300,
//                   color: Colors.grey[800],
//                 ),
//               ),
//             ],
//           ),
//         ],
//       ),
//     );
//   }

//   Widget _buildFlameControl(bool disabled) {
//     String getFlameLabel(double value) {
//       if (value == 0) return "Off";
//       if (value == 1) return "Low";
//       if (value == 2) return "Medium";
//       if (value == 3) return "High";
//       return "";
//     }

//     return Opacity(
//       opacity: disabled ? 0.5 : 1.0,
//       child: Card(
//         elevation: 2,
//         color: Colors.white,
//         shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
//         child: Padding(
//           padding: const EdgeInsets.all(20.0),
//           child: Column(
//             children: [
//               Row(
//                 mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                 children: [
//                   const Text(
//                     "Flame Intensity",
//                     style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
//                   ),
//                   Text(
//                     getFlameLabel(_flameLevel),
//                     style: TextStyle(
//                       fontSize: 16,
//                       fontWeight: FontWeight.bold,
//                       color: Colors.blue[600],
//                     ),
//                   ),
//                 ],
//               ),
//               Slider(
//                 value: _flameLevel,
//                 min: 0,
//                 max: 3,
//                 divisions: 3,
//                 label: getFlameLabel(_flameLevel),
//                 onChanged: disabled
//                     ? null
//                     : (value) {
//                         _setFlameLevel(value);
//                       },
//               ),
//             ],
//           ),
//         ),
//       ),
//     );
//   }
// }
