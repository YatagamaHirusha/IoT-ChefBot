import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:http/http.dart' show ClientException;

/// Result model for attempting to configure WiFi on the ESP32.
class WifiConfigResult {
  final bool success;
  final int? statusCode;
  final String? responseBody;
  final String? errorMessage;
  final bool isTimeout;
  final bool isUnreachable;

  const WifiConfigResult({
    required this.success,
    this.statusCode,
    this.responseBody,
    this.errorMessage,
    this.isTimeout = false,
    this.isUnreachable = false,
  });
}

class ESP32Service {
  // Default IP when connected to ESP32's AP mode
  static const String esp32BaseUrl = 'http://192.168.4.1';

  // Get MAC address from ESP32
  Future<String?> getMacAddress() async {
    try {
      final response = await http
          .get(Uri.parse('$esp32BaseUrl/mac'))
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        String macAddress = data['mac'];
        print('Received MAC address: $macAddress');
        return macAddress;
      } else {
        print('Failed to get MAC address: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('Error getting MAC address: $e');
      return null;
    }
  }

  // Send WiFi credentials to ESP32
  Future<bool> sendWifiCredentials({
    required String ssid,
    required String password,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse('$esp32BaseUrl/config'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'ssid': ssid, 'password': password}),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        print('WiFi credentials sent successfully');
        return true;
      } else {
        print('Failed to send WiFi credentials: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      print('Error sending WiFi credentials: $e');
      return false;
    }
  }

  /// Detailed version of [sendWifiCredentials] that returns richer diagnostics.
  Future<WifiConfigResult> configureWifi({
    required String ssid,
    required String password,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse('$esp32BaseUrl/config'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'ssid': ssid, 'password': password}),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        return WifiConfigResult(
          success: true,
          statusCode: response.statusCode,
          responseBody: response.body,
        );
      }

      return WifiConfigResult(
        success: false,
        statusCode: response.statusCode,
        responseBody: response.body,
        errorMessage: 'Non-200 status code',
      );
    } on ClientException catch (e) {
      return WifiConfigResult(
        success: false,
        errorMessage: 'ClientException: $e',
        isUnreachable: true,
      );
    } on SocketException catch (e) {
      return WifiConfigResult(
        success: false,
        errorMessage: 'SocketException: $e',
        isUnreachable: true,
      );
    } on HttpException catch (e) {
      return WifiConfigResult(
        success: false,
        errorMessage: 'HttpException: $e',
      );
    } on FormatException catch (e) {
      return WifiConfigResult(
        success: false,
        errorMessage: 'Bad response format: $e',
      );
    } on TimeoutException catch (e) {
      return WifiConfigResult(
        success: false,
        errorMessage: 'Timeout: $e',
        isTimeout: true,
      );
    } catch (e) {
      return WifiConfigResult(
        success: false,
        errorMessage: 'Unexpected error: $e',
      );
    }
  }

  // Check if ESP32 is reachable (to verify connection to ChefBot AP)
  Future<bool> checkConnection() async {
    try {
      final response = await http
          .get(Uri.parse('$esp32BaseUrl/ping'))
          .timeout(const Duration(seconds: 5));

      return response.statusCode == 200;
    } catch (e) {
      print('ESP32 not reachable: $e');
      return false;
    }
  }

  // Get current status from ESP32
  Future<Map<String, dynamic>?> getStatus() async {
    try {
      final response = await http
          .get(Uri.parse('$esp32BaseUrl/status'))
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        print('Failed to get status: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('Error getting status: $e');
      return null;
    }
  }
}
