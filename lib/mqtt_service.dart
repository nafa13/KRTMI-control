import 'package:flutter/foundation.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';

class MqttService extends ChangeNotifier {
  MqttServerClient? _client;
  bool isConnected = false;
  
  // Sensor data state
  int distanceFront = 0;
  int distanceRear = 0;
  bool ledStatus = false;
  bool gripperStatus = false;

  final String broker = 'broker.hivemq.com';
  final int port = 1883;

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
        .withWillMessage('Robot App Disconnected')
        .startClean()
        .withWillQos(MqttQos.atLeastOnce);
    
    _client!.connectionMessage = connMess;

    try {
      print('Connecting to MQTT Broker $broker...');
      await _client!.connect();
    } catch (e) {
      print('Exception: $e');
      _client!.disconnect();
    }

    if (_client!.connectionStatus!.state == MqttConnectionState.connected) {
      isConnected = true;
      print('MQTT Connected');
      notifyListeners();
      
      // Subscribe to topics
      subscribeToTopics();
      
      _client!.updates!.listen((List<MqttReceivedMessage<MqttMessage?>>? c) {
        final recMess = c![0].payload as MqttPublishMessage;
        final pt = MqttPublishPayload.bytesToStringAsString(recMess.payload.message);

        print('Received message: topic is ${c[0].topic}, payload is $pt');
        
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
      _client!.disconnect();
    }
  }

  void subscribeToTopics() {
    _client!.subscribe('krtmi/robot/sensor/distance_front', MqttQos.atMostOnce);
    _client!.subscribe('krtmi/robot/sensor/distance_rear', MqttQos.atMostOnce);
  }

  void disconnect() {
    _client?.disconnect();
  }

  void onConnected() {
    print('Connected to MQTT Broker.');
  }

  void onDisconnected() {
    print('Disconnected from MQTT Broker.');
    isConnected = false;
    notifyListeners();
  }

  void onSubscribed(String topic) {
    print('Subscribed to $topic');
  }

  // Publisher methods
  void publishMessage(String topic, String message) {
    if (_client != null && _client!.connectionStatus!.state == MqttConnectionState.connected) {
      final builder = MqttClientPayloadBuilder();
      builder.addString(message);
      _client!.publishMessage(topic, MqttQos.atMostOnce, builder.payload!);
    } else {
      print('Cannot publish, client not connected.');
    }
  }

  void moveCommand(String direction) {
    publishMessage('krtmi/robot/move', direction); // forward, backward, left, right, stop
  }

  void toggleGripper() {
    gripperStatus = !gripperStatus;
    publishMessage('krtmi/robot/gripper', gripperStatus ? 'open' : 'close');
    notifyListeners();
  }

  void openGripper() {
    gripperStatus = true;
    publishMessage('krtmi/robot/gripper', 'open');
    notifyListeners();
  }

  void closeGripper() {
    gripperStatus = false;
    publishMessage('krtmi/robot/gripper', 'close');
    notifyListeners();
  }

  void toggleLed() {
    ledStatus = !ledStatus;
    publishMessage('krtmi/robot/led', ledStatus ? 'on' : 'off');
    notifyListeners();
  }
}
