import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'services/esp32_service.dart';
import 'services/firestore_service.dart';
import 'services/network_info_service.dart';

class WifiSetupScreen extends StatefulWidget {
  const WifiSetupScreen({super.key});

  @override
  State<WifiSetupScreen> createState() => _WifiSetupScreenState();
}

class _WifiSetupScreenState extends State<WifiSetupScreen> {
  final ESP32Service _esp32Service = ESP32Service();
  final FirestoreService _firestoreService = FirestoreService();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final NetworkInfoService _networkInfoService = NetworkInfoService();

  final TextEditingController _ssidController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _isLoading = false;
  bool _obscurePassword = true;
  String _statusMessage = '';
  String _errorMessage = '';
  String? _macAddress;

  @override
  void initState() {
    super.initState();
    _getMacAddress();
  }

  // Get MAC address from ESP32
  Future<void> _getMacAddress() async {
    setState(() {
      _isLoading = true;
      _statusMessage = 'Connecting to ChefBot...';
    });

    // Ensure we are connected to ChefBot AP
    final onChefBotAp = await _networkInfoService.isChefBotAp();
    if (!onChefBotAp) {
      final currentSsid = await _networkInfoService.getCurrentSsid();
      setState(() {
        _errorMessage = currentSsid == null
            ? 'Not connected to any Wi-Fi network. Connect to ChefBot-XXXX first.'
            : 'Connected to "$currentSsid". Please switch to ChefBot-XXXX Wi-Fi before continuing.';
        _isLoading = false;
        _statusMessage = '';
      });
      return;
    }

    String? macAddress = await _esp32Service.getMacAddress();

    if (macAddress != null) {
      setState(() {
        _macAddress = macAddress;
        _statusMessage = 'Connected! Cooker ID: $macAddress';
        _isLoading = false;
      });
    } else {
      setState(() {
        _errorMessage =
            'Could not connect to ChefBot. Please ensure you are connected to the ChefBot-XXXX Wi-Fi network.';
        _isLoading = false;
      });
    }
  }

  // Send WiFi credentials to ESP32 and save to Firestore
  Future<void> _setupWifi() async {
    if (_ssidController.text.trim().isEmpty ||
        _passwordController.text.trim().isEmpty) {
      setState(() {
        _errorMessage = 'Please enter both WiFi name and password.';
      });
      return;
    }

    if (_macAddress == null) {
      setState(() {
        _errorMessage =
            'MAC address not available. Please reconnect to ChefBot.';
      });
      return;
    }

    // Verify still on ChefBot AP prior to provisioning
    final onChefBotAp = await _networkInfoService.isChefBotAp();
    if (!onChefBotAp) {
      final currentSsid = await _networkInfoService.getCurrentSsid();
      setState(() {
        _errorMessage = currentSsid == null
            ? 'Wi-Fi disconnected. Reconnect to ChefBot-XXXX.'
            : 'Currently on "$currentSsid". Reconnect to ChefBot-XXXX to send credentials.';
      });
      return;
    }

    // Pre-check HTTP reachability to esp32 AP
    final reachable = await _esp32Service.checkConnection();
    if (!reachable) {
      setState(() {
        _errorMessage =
            'ChefBot not reachable at 192.168.4.1. Ensure the cooker is in setup mode (Wi-Fi light blinking) and your phone is connected to ChefBot-XXXX. If already configured, perform a factory reset or long press the reset button to re-enter provisioning.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = '';
      _statusMessage = 'Sending Wi-Fi credentials to ChefBot...';
    });

    try {
      // Send WiFi credentials with detailed diagnostics
      final result = await _esp32Service.configureWifi(
        ssid: _ssidController.text.trim(),
        password: _passwordController.text.trim(),
      );

      if (!result.success) {
        String reason;
        if (result.isUnreachable) {
          reason =
              'ChefBot unreachable. It may have already switched off AP mode. Reset it to re-enter provisioning.';
        } else if (result.isTimeout) {
          reason =
              'Timed out waiting for response. Wi-Fi signal weak or device exited setup mode.';
        } else if (result.statusCode != null) {
          reason =
              'Cooker responded with HTTP ${result.statusCode}. Body: ${result.responseBody ?? 'No body'}';
        } else {
          reason = result.errorMessage ?? 'Unknown error';
        }
        setState(() {
          _errorMessage = 'Failed to configure ChefBot. $reason';
          _isLoading = false;
          _statusMessage = '';
        });
        return;
      }

      // Save cooker data to Firestore
      User? currentUser = _auth.currentUser;
      if (currentUser != null) {
        await _firestoreService.saveCookerData(
          uid: currentUser.uid,
          macAddress: _macAddress!,
          cookerName:
              'ChefBot ${_macAddress!.substring(_macAddress!.length - 4)}',
        );

        // Optionally query status endpoint to confirm connection
        final status = await _esp32Service.getStatus();
        setState(() {
          _statusMessage = status == null
              ? 'ChefBot configured successfully! (Status unavailable)'
              : 'ChefBot configured! Connected: ${status['connected']} | IP: ${status['ip'] ?? 'N/A'}';
        });

        // Wait a moment to show success message
        await Future.delayed(const Duration(seconds: 2));

        if (mounted) {
          // Navigate to dashboard
          Navigator.pushReplacementNamed(context, '/dashboard');
        }
      } else {
        setState(() {
          _errorMessage = 'User not logged in. Please log in again.';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'An error occurred: $e';
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _ssidController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Configure Wi-Fi"),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 20),
            Icon(Icons.wifi, size: 80, color: Colors.blue[600]),
            const SizedBox(height: 24),
            Text(
              "Connect ChefBot to Your Home Wi-Fi",
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),

            // Status message
            if (_statusMessage.isNotEmpty)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.blue[600]),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _statusMessage,
                        style: TextStyle(color: Colors.blue[900]),
                      ),
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 24),

            // WiFi SSID field
            TextFormField(
              controller: _ssidController,
              decoration: const InputDecoration(
                labelText: "Home Wi-Fi Name (SSID)",
                prefixIcon: Icon(Icons.wifi),
                hintText: "Enter your Wi-Fi network name",
              ),
            ),

            const SizedBox(height: 16),

            // WiFi password field
            TextFormField(
              controller: _passwordController,
              obscureText: _obscurePassword,
              decoration: InputDecoration(
                labelText: "Wi-Fi Password",
                prefixIcon: const Icon(Icons.lock_outline),
                hintText: "Enter your Wi-Fi password",
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscurePassword ? Icons.visibility_off : Icons.visibility,
                  ),
                  onPressed: () {
                    setState(() {
                      _obscurePassword = !_obscurePassword;
                    });
                  },
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Error message
            if (_errorMessage.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red[50],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline, color: Colors.red[600]),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _errorMessage,
                          style: TextStyle(color: Colors.red[900]),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // Configure button
            ElevatedButton(
              onPressed: (_isLoading || _macAddress == null)
                  ? null
                  : _setupWifi,
              child: _isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Text("Configure ChefBot"),
            ),

            const SizedBox(height: 16),

            // Retry connection button
            if (_macAddress == null && !_isLoading)
              TextButton(
                onPressed: _getMacAddress,
                child: const Text("Retry Connection"),
              ),

            const SizedBox(height: 24),

            // Instructions
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Instructions:",
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _buildInstruction(
                    "1. Make sure you're connected to ChefBot-XXXX Wi-Fi",
                  ),
                  _buildInstruction(
                    "2. Enter your home Wi-Fi credentials above",
                  ),
                  _buildInstruction(
                    "3. ChefBot will connect to your home network",
                  ),
                  _buildInstruction(
                    "4. You can reconnect your phone to your home Wi-Fi",
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInstruction(String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.circle, size: 6, color: Colors.grey),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text, style: TextStyle(color: Colors.grey[700])),
          ),
        ],
      ),
    );
  }
}
