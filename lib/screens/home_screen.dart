import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Untuk Haptic Feedback
import 'package:provider/provider.dart';
import 'package:flutter_mjpeg/flutter_mjpeg.dart';
import '../mqtt_service.dart';

class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _ipController =
      TextEditingController(text: 'http://192.168.1.100:81/stream');
  bool isCameraRunning = false;

  @override
  Widget build(BuildContext context) {
    final mqttService = Provider.of<MqttService>(context);

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'KRTMI Robot Controller',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 20,
            letterSpacing: 1.2,
            color: Colors.black87,
          ),
        ),
        centerTitle: true,
        actions: [],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFFF5F7FA),
              Color(0xFFE4E9F2),
              Color(0xFFD1DBE8),
            ],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            physics: BouncingScrollPhysics(),
            child: Column(
              children: [
                // Camera Section
                _buildCameraSection(),

                SizedBox(height: 20),

                // Sensor & Status Section
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0),
                  child: Row(
                    children: [
                      Expanded(
                          child: _buildGlassCard(
                              'Jarak Depan',
                              '${mqttService.distanceFront} cm',
                              Icons.radar,
                              _getSensorColor(mqttService.distanceFront))),
                      SizedBox(width: 16),
                      Expanded(
                          child: _buildGlassCard(
                              'Jarak Belakang',
                              '${mqttService.distanceRear} cm',
                              Icons.sensors,
                              _getSensorColor(mqttService.distanceRear))),
                    ],
                  ),
                ),

                SizedBox(height: 16),

                // Auto LED Status Indicator
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0),
                  child: _buildStatusIndicator(mqttService),
                ),

                SizedBox(height: 30),

                // Speed Control
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'KECEPATAN ROBOT',
                        style: TextStyle(
                          color: Colors.black54,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 1.5,
                        ),
                      ),
                      Row(
                        children: [
                          Icon(Icons.speed, color: Colors.blueAccent, size: 20),
                          Expanded(
                            child: SliderTheme(
                              data: SliderTheme.of(context).copyWith(
                                activeTrackColor: Colors.blueAccent,
                                inactiveTrackColor: Colors.black12,
                                thumbColor: Colors.blueAccent,
                                overlayColor:
                                    Colors.blueAccent.withOpacity(0.2),
                              ),
                              child: Slider(
                                value: mqttService.speed.toDouble(),
                                min: 0,
                                max: 100,
                                divisions: 10,
                                label: '${mqttService.speed}%',
                                onChanged: (value) {
                                  mqttService.setSpeed(value);
                                },
                              ),
                            ),
                          ),
                          Text('${mqttService.speed}%',
                              style: TextStyle(
                                  color: Colors.black87,
                                  fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ],
                  ),
                ),

                SizedBox(height: 20),

                // Control Section Title
                Text(
                  'KONTROL GERAK',
                  style: TextStyle(
                    color: Colors.black54,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 2.0,
                  ),
                ),
                SizedBox(height: 20),

                // Modern D-Pad
                _buildModernDPad(mqttService),

                SizedBox(height: 40),

                // Actions Section
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: _buildGradientButton(
                              icon: Icons.back_hand,
                              label: 'Ambil Barang',
                              subtitle: 'Payload: krtmi/robot/gripper -> close',
                              gradient: LinearGradient(colors: [
                                Color(0xFF11998E),
                                Color(0xFF38EF7D)
                              ]),
                              onPressed: () {
                                HapticFeedback.mediumImpact();
                                mqttService.closeGripper();
                              },
                            ),
                          ),
                          SizedBox(width: 16),
                          Expanded(
                            child: _buildGradientButton(
                              icon: Icons.pan_tool_outlined,
                              label: 'Letakkan',
                              subtitle: 'Payload: krtmi/robot/gripper -> open',
                              gradient: LinearGradient(colors: [
                                Color(0xFFF2994A),
                                Color(0xFFF2C94C)
                              ]),
                              onPressed: () {
                                HapticFeedback.mediumImpact();
                                mqttService.openGripper();
                              },
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 20),
                      // Emergency Stop
                      _buildGradientButton(
                        icon: Icons.warning_rounded,
                        label: 'BERHENTI DARURAT',
                        gradient: LinearGradient(colors: [
                          Colors.red.shade900,
                          Colors.redAccent.shade700
                        ]),
                        isFullWidth: true,
                        onPressed: () {
                          HapticFeedback.vibrate(); // Getar panjang/kuat
                          mqttService.emergencyStop();
                        },
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 24),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0),
                  child: _buildMqttStatusFooter(mqttService),
                ),
                SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0),
                  child: _buildMqttLogPanel(mqttService),
                ),
                SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Color _getSensorColor(int distance) {
    if (distance <= 0) return Colors.blueAccent; // Default/No data
    if (distance < 15) return Colors.redAccent; // Bahaya
    if (distance < 30) return Colors.orangeAccent; // Awas
    return Colors.greenAccent; // Aman
  }

  Widget _buildStatusIndicator(MqttService mqttService) {
    final ledMode = mqttService.ledMode;
    final isFastBlink = ledMode == 'fast_blink';
    final isSolidOn = ledMode == 'solid_on';
    final isSlowBlink = ledMode == 'slow_blink';

    final Color accentColor = isSolidOn
        ? Colors.greenAccent
        : isSlowBlink
            ? Colors.orangeAccent
            : Colors.blueAccent;

    final String statusText = isFastBlink
        ? 'FAST BLINK: ESP32 sedang mencari WiFi / MQTT'
        : isSolidOn
            ? 'SOLID ON: Robot online dan siap menerima perintah'
            : isSlowBlink
                ? 'SLOW BLINK: Koneksi putus / connection lost'
                : 'LED status belum terbaca';

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: accentColor.withOpacity(0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accentColor.withOpacity(0.35)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            isSolidOn ? Icons.check_circle_outline : Icons.graphic_eq,
            color: accentColor,
          ),
          SizedBox(width: 8),
          Text(
            statusText,
            style: TextStyle(
              color: accentColor,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCameraSection() {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.blueAccent.withOpacity(0.15),
            blurRadius: 20,
            spreadRadius: 2,
            offset: Offset(0, 10),
          )
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.black87.withOpacity(0.05),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.black87.withOpacity(0.1)),
            ),
            child: Column(
              children: [
                // Stream display
                Container(
                  height: 220,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.black87,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                        color: isCameraRunning
                            ? Colors.blueAccent.withOpacity(0.5)
                            : Colors.black12,
                        width: 2),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: isCameraRunning
                        ? Mjpeg(
                            isLive: true,
                            stream: _ipController.text,
                            error: (context, error, stack) => Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.error_outline,
                                      color: Colors.redAccent, size: 40),
                                  SizedBox(height: 8),
                                  Text('Koneksi Gagal',
                                      style: TextStyle(
                                          color: Colors.redAccent,
                                          fontWeight: FontWeight.bold)),
                                ],
                              ),
                            ),
                          )
                        : Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.videocam_off,
                                    color: Colors.black26, size: 48),
                                SizedBox(height: 12),
                                Text(
                                  'Kamera Tidak Aktif\nTekan tombol Play',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                      color: Colors.black38, fontSize: 14),
                                ),
                              ],
                            ),
                          ),
                  ),
                ),
                SizedBox(height: 16),
                // URL input & play btn
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        height: 50,
                        decoration: BoxDecoration(
                          color: Colors.black26,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.black12),
                        ),
                        child: TextField(
                          controller: _ipController,
                          style: TextStyle(color: Colors.black87, fontSize: 14),
                          decoration: InputDecoration(
                            contentPadding:
                                EdgeInsets.symmetric(horizontal: 16),
                            hintText: 'Masukkan URL Kamera',
                            hintStyle: TextStyle(color: Colors.black26),
                            border: InputBorder.none,
                            icon: Padding(
                              padding: const EdgeInsets.only(left: 12.0),
                              child: Icon(Icons.link,
                                  color: Colors.blueAccent, size: 20),
                            ),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: 12),
                    GestureDetector(
                      onTap: () {
                        HapticFeedback.lightImpact();
                        setState(() {
                          isCameraRunning = !isCameraRunning;
                        });
                      },
                      child: Container(
                        height: 50,
                        width: 50,
                        decoration: BoxDecoration(
                          gradient: isCameraRunning
                              ? LinearGradient(
                                  colors: [Colors.redAccent, Colors.deepOrange])
                              : LinearGradient(
                                  colors: [Colors.blue, Colors.blueAccent]),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: isCameraRunning
                                  ? Colors.redAccent.withOpacity(0.4)
                                  : Colors.blue.withOpacity(0.4),
                              blurRadius: 10,
                              offset: Offset(0, 4),
                            )
                          ],
                        ),
                        child: Icon(
                          isCameraRunning
                              ? Icons.stop_rounded
                              : Icons.play_arrow_rounded,
                          color: Colors.white,
                          size: 30,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGlassCard(
      String title, String value, IconData icon, Color iconColor) {
    // Membuat animasi perubahan warna lebih smooth
    return AnimatedContainer(
      duration: Duration(milliseconds: 300),
      decoration: BoxDecoration(
        color: Colors.black87.withOpacity(0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: iconColor.withOpacity(0.5)),
        boxShadow: [
          BoxShadow(
            color: iconColor.withOpacity(0.1),
            blurRadius: 10,
            spreadRadius: 1,
          )
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Padding(
            padding: EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: iconColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: iconColor, size: 24),
                ),
                SizedBox(height: 16),
                Text(title,
                    style: TextStyle(
                        color: Colors.black45,
                        fontSize: 12,
                        fontWeight: FontWeight.w500)),
                SizedBox(height: 4),
                Text(value,
                    style: TextStyle(
                        color: Colors.black87,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.0)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildModernDPad(MqttService mqttService) {
    final isDisabled = mqttService.isArmBusy;

    return AnimatedOpacity(
      duration: Duration(milliseconds: 200),
      opacity: isDisabled ? 0.35 : 1,
      child: IgnorePointer(
        ignoring: isDisabled,
        child: Container(
          width: 220,
          height: 220,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.black87.withOpacity(0.03),
            border: Border.all(color: Colors.black87.withOpacity(0.05), width: 1),
            boxShadow: [
              BoxShadow(color: Colors.black26, blurRadius: 20),
            ],
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Center core
              Container(
                width: 70,
                height: 70,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [Color(0xFFD1DBE8), Color(0xFFF5F7FA)],
                  ),
                  border: Border.all(
                      color: Colors.blueAccent.withOpacity(0.3), width: 2),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.blueAccent.withOpacity(0.2),
                        blurRadius: 15,
                        spreadRadius: 1),
                  ],
                ),
                child: Icon(Icons.circle,
                    color: Colors.blueAccent.withOpacity(0.8), size: 24),
              ),
              // Arrows
              Positioned(
                  top: 10,
                  child: _buildDirBtn(
                      Icons.keyboard_arrow_up_rounded,
                      () => mqttService.moveCommand('forward'),
                      () => mqttService.moveCommand('stop'))),
              Positioned(
                  bottom: 10,
                  child: _buildDirBtn(
                      Icons.keyboard_arrow_down_rounded,
                      () => mqttService.moveCommand('backward'),
                      () => mqttService.moveCommand('stop'))),
              Positioned(
                  left: 10,
                  child: _buildDirBtn(
                      Icons.keyboard_arrow_left_rounded,
                      () => mqttService.moveCommand('left'),
                      () => mqttService.moveCommand('stop'))),
              Positioned(
                  right: 10,
                  child: _buildDirBtn(
                      Icons.keyboard_arrow_right_rounded,
                      () => mqttService.moveCommand('right'),
                      () => mqttService.moveCommand('stop'))),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDirBtn(
      IconData icon, VoidCallback onPointerDown, VoidCallback onPointerUp) {
    return Listener(
      onPointerDown: (event) {
        HapticFeedback.lightImpact();
        onPointerDown();
      },
      onPointerUp: (event) => onPointerUp(),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {},
          customBorder: CircleBorder(),
          splashColor: Colors.blueAccent.withOpacity(0.3),
          highlightColor: Colors.blueAccent.withOpacity(0.1),
          child: Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.black87.withOpacity(0.05),
            ),
            child: Icon(icon, color: Colors.black87, size: 40),
          ),
        ),
      ),
    );
  }

  Widget _buildGradientButton({
    required IconData icon,
    required String label,
    String? subtitle,
    required Gradient gradient,
    required VoidCallback onPressed,
    bool isFullWidth = false,
  }) {
    final buttonContent = Container(
      padding: EdgeInsets.symmetric(vertical: 16, horizontal: 20),
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: gradient.colors.first.withOpacity(0.4),
            blurRadius: 12,
            offset: Offset(0, 6),
          )
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: Colors.white, size: 24),
          SizedBox(width: 8),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
                if (subtitle != null) ...[
                  SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.85),
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(16),
        child: isFullWidth ? buttonContent : buttonContent,
      ),
    );
  }

  Widget _buildMqttStatusFooter(MqttService mqttService) {
    final isConnected = mqttService.isConnected;
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black87.withOpacity(0.05),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.black87.withOpacity(0.08)),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isConnected
                  ? Colors.greenAccent.withOpacity(0.15)
                  : Colors.redAccent.withOpacity(0.15),
            ),
            child: Icon(
              isConnected ? Icons.wifi : Icons.wifi_off,
              color: isConnected ? Colors.greenAccent : Colors.redAccent,
            ),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'MQTT Connection',
                  style: TextStyle(
                    color: Colors.black87,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  isConnected
                      ? 'Connected to ${mqttService.broker}:${mqttService.port}'
                      : 'Disconnected from broker',
                  style: TextStyle(
                    color: Colors.black54,
                    fontSize: 12,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'LED mode: ${mqttService.ledMode}',
                  style: TextStyle(
                    color: Colors.black38,
                    fontSize: 11,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Robot LWT: ${mqttService.robotOnline ? 'online' : 'offline'}',
                  style: TextStyle(
                    color: mqttService.robotOnline
                        ? Colors.greenAccent
                        : Colors.orangeAccent,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () {
              HapticFeedback.lightImpact();
              if (isConnected) {
                mqttService.disconnect();
              } else {
                mqttService.connect(
                    'flutter_client_${DateTime.now().millisecondsSinceEpoch}');
              }
            },
            child: Text(isConnected ? 'Disconnect' : 'Connect'),
          ),
        ],
      ),
    );
  }

  Widget _buildMqttLogPanel(MqttService mqttService) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black87.withOpacity(0.05),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.black87.withOpacity(0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.receipt_long, color: Colors.blueAccent, size: 20),
              SizedBox(width: 8),
              Text(
                'MQTT LOG',
                style: TextStyle(
                  color: Colors.black87,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  letterSpacing: 1.0,
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          Container(
            constraints: BoxConstraints(maxHeight: 280),
            child: mqttService.logs.isEmpty
                ? Container(
                    width: double.infinity,
                    padding: EdgeInsets.symmetric(vertical: 24),
                    alignment: Alignment.center,
                    child: Text(
                      'Belum ada log MQTT',
                      style: TextStyle(color: Colors.black38, fontSize: 12),
                    ),
                  )
                : ListView.separated(
                    shrinkWrap: true,
                    physics: NeverScrollableScrollPhysics(),
                    itemCount: mqttService.logs.length,
                    separatorBuilder: (_, __) =>
                        Divider(color: Colors.black12, height: 12),
                    itemBuilder: (context, index) {
                      final entry = mqttService.logs[index];
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            entry.formattedTime,
                            style: TextStyle(
                              color: Colors.blueAccent,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              entry.message,
                              style: TextStyle(
                                color: Colors.black87,
                                fontSize: 12,
                                height: 1.3,
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
