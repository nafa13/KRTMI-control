import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';

class MqttLogEntry {
  MqttLogEntry({
    required this.time,
    required this.message,
  });

  final DateTime time;
  final String message;

  String get formattedTime =>
      '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}:${time.second.toString().padLeft(2, '0')}';
}

class MqttService extends ChangeNotifier {
  MqttServerClient? _client;
  bool isConnected = false;
  final List<MqttLogEntry> _logs = [];
  String ledMode = 'fast_blink';
  bool robotOnline = false;
  bool isArmBusy = false;

  // Sensor data state
  int distanceFront = 0;
  int distanceRear = 0;
  bool ledStatus = false;
  bool gripperStatus = false;
  int speed = 50; // Kecepatan default

  Timer? _speedDebounceTimer;
  double? _pendingSpeed;
  Timer? _armBusyTimer;

  final String broker = '10.99.235.199';
  final int port = 1883;

  List<MqttLogEntry> get logs => List.unmodifiable(_logs);

  void _addLog(String message) {
    _logs.insert(0, MqttLogEntry(time: DateTime.now(), message: message));
    if (_logs.length > 100) {
      _logs.removeLast();
    }
    notifyListeners();
  }

  Future<void> connect(String clientId) async {
    _client = MqttServerClient(broker, clientId);
    _client!.port = port;
    _client!.logging(on: false);
    _client!.keepAlivePeriod = 60;
    _client!.onDisconnected = onDisconnected;
    _client!.onConnected = onConnected;
    _client!.onSubscribed = onSubscribed;

    final connMess = MqttConnectMessage()
        .withClientIdentifier(clientId)
        .withWillTopic('krtmi/robot/will')
        .withWillMessage('offline')
        .startClean()
        .withWillQos(MqttQos.atLeastOnce);

    _client!.connectionMessage = connMess;

    try {
      print('Connecting to MQTT Broker $broker...');
      ledMode = 'fast_blink';
      _addLog('CONNECT -> broker $broker:$port, clientId=$clientId');
      _addLog('LED MODE -> fast_blink (connecting)');
      await _client!.connect();
    } catch (e) {
      print('Exception: $e');
      _addLog('CONNECT ERROR -> $e');
      _client!.disconnect();
    }

    if (_client!.connectionStatus!.state == MqttConnectionState.connected) {
      isConnected = true;
      ledMode = 'solid_on';
      print('MQTT Connected');
      _addLog('STATUS -> connected');
      _addLog('LED MODE -> solid_on (online)');
      publishMessage('krtmi/robot/led', 'solid_on', qos: MqttQos.atMostOnce);
      notifyListeners();

      // Subscribe to topics
      subscribeToTopics();

      _client!.updates!.listen((List<MqttReceivedMessage<MqttMessage?>>? c) {
        final recMess = c![0].payload as MqttPublishMessage;
        final pt =
            MqttPublishPayload.bytesToStringAsString(recMess.payload.message);

        print('Received message: topic is ${c[0].topic}, payload is $pt');
        _addLog('RECV ${c[0].topic} -> $pt');

        if (c[0].topic == 'krtmi/robot/will') {
          robotOnline = pt == 'online';
          _addLog('ROBOT STATUS -> ${robotOnline ? 'online' : 'offline'}');
          notifyListeners();
        }

        // Handle incoming sensor data
        if (c[0].topic == 'krtmi/robot/sensor/distance_front') {
          distanceFront = int.tryParse(pt) ?? distanceFront;
          notifyListeners();
        } else if (c[0].topic == 'krtmi/robot/sensor/distance_rear') {
          distanceRear = int.tryParse(pt) ?? distanceRear;
          notifyListeners();
        }
      });
    } else {
      print('MQTT connection failed - status is ${_client!.connectionStatus}');
      _addLog('STATUS -> connection failed (${_client!.connectionStatus})');
      _client!.disconnect();
    }
  }

  void subscribeToTopics() {
    _client!.subscribe('krtmi/robot/sensor/distance_front', MqttQos.atMostOnce);
    _client!.subscribe('krtmi/robot/sensor/distance_rear', MqttQos.atMostOnce);
    _client!.subscribe('krtmi/robot/will', MqttQos.atMostOnce);
    _addLog('SUBSCRIBE -> krtmi/robot/sensor/distance_front');
    _addLog('SUBSCRIBE -> krtmi/robot/sensor/distance_rear');
    _addLog('SUBSCRIBE -> krtmi/robot/will');
  }

  Future<void> disconnect() async {
    ledMode = 'slow_blink';
    publishMessage('krtmi/robot/led', 'slow_blink', qos: MqttQos.atMostOnce);
    _addLog('STATUS -> disconnected');
    _addLog('LED MODE -> slow_blink (connection lost)');
    notifyListeners();
    await Future.delayed(const Duration(milliseconds: 150));
    _client?.disconnect();
  }

  void onConnected() {
    print('Connected to MQTT Broker.');
    _addLog('STATUS CALLBACK -> connected');
  }

  void onDisconnected() {
    print('Disconnected from MQTT Broker.');
    isConnected = false;
    ledMode = 'slow_blink';
    _addLog('STATUS CALLBACK -> disconnected');
    _addLog('LED MODE -> slow_blink (connection lost)');
    notifyListeners();
  }

  void onSubscribed(String topic) {
    print('Subscribed to $topic');
    _addLog('SUBSCRIBED -> $topic');
  }

  // Publisher methods
  void publishMessage(String topic, String message,
      {MqttQos qos = MqttQos.atMostOnce}) {
    if (_client != null &&
        _client!.connectionStatus!.state == MqttConnectionState.connected) {
      final builder = MqttClientPayloadBuilder();
      builder.addString(message);
      _client!.publishMessage(topic, qos, builder.payload!);
      _addLog('SEND [$qos] $topic -> $message');
    } else {
      print('Cannot publish, client not connected.');
      _addLog('SEND FAILED $topic -> $message (client not connected)');
    }
  }

  void moveCommand(String direction) {
    publishMessage('krtmi/robot/move', direction, qos: MqttQos.atMostOnce);
  }

  void toggleGripper() {
    gripperStatus = !gripperStatus;
    _sendGripperCommand(gripperStatus ? 'open' : 'close');
  }

  void openGripper() {
    gripperStatus = true;
    _sendGripperCommand('open');
  }

  void closeGripper() {
    gripperStatus = false;
    _sendGripperCommand('close');
  }

  void setSpeed(double newSpeed) {
    speed = newSpeed.toInt();
    notifyListeners();

    _pendingSpeed = newSpeed;
    _speedDebounceTimer?.cancel();
    _speedDebounceTimer = Timer(const Duration(milliseconds: 150), () {
      final pending = _pendingSpeed;
      if (pending == null) {
        return;
      }
      publishMessage('krtmi/robot/speed', pending.toInt().toString(),
          qos: MqttQos.atMostOnce);
    });
  }

  void emergencyStop() {
    publishMessage('krtmi/robot/move', 'stop', qos: MqttQos.atMostOnce);
    notifyListeners();
  }

  void _sendGripperCommand(String payload) {
    isArmBusy = true;
    _armBusyTimer?.cancel();
    publishMessage('krtmi/robot/gripper', payload, qos: MqttQos.atLeastOnce);
    _addLog('ARM STATE -> busy/mute');
    notifyListeners();

    _armBusyTimer = Timer(const Duration(seconds: 5), () {
      isArmBusy = false;
      _addLog('ARM STATE -> ready');
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _speedDebounceTimer?.cancel();
    _armBusyTimer?.cancel();
    _client?.disconnect();
    super.dispose();
  }
}
