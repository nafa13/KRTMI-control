import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_mjpeg/flutter_mjpeg.dart';
import '../mqtt_service.dart';

class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _ipController = TextEditingController(text: 'http://192.168.1.100:81/stream');
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
            color: Colors.white,
          ),
        ),
        centerTitle: true,
        actions: [
          Container(
            margin: EdgeInsets.only(right: 16),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: mqttService.isConnected ? Colors.green.withOpacity(0.2) : Colors.red.withOpacity(0.2),
            ),
            child: IconButton(
              icon: Icon(mqttService.isConnected ? Icons.wifi : Icons.wifi_off),
              color: mqttService.isConnected ? Colors.greenAccent : Colors.redAccent,
              onPressed: () {
                if (mqttService.isConnected) {
                  mqttService.disconnect();
                } else {
                  mqttService.connect('flutter_client_${DateTime.now().millisecondsSinceEpoch}');
                }
              },
            ),
          )
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF0F2027),
              Color(0xFF203A43),
              Color(0xFF2C5364),
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
                
                // Sensor Section
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0),
                  child: Row(
                    children: [
                      Expanded(child: _buildGlassCard('Jarak Depan', '${mqttService.distanceFront} cm', Icons.radar, Colors.cyanAccent)),
                      SizedBox(width: 16),
                      Expanded(child: _buildGlassCard('Jarak Belakang', '${mqttService.distanceRear} cm', Icons.sensors, Colors.purpleAccent)),
                    ],
                  ),
                ),
                
                SizedBox(height: 30),
                
                // Control Section Title
                Text(
                  'KONTROL GERAK',
                  style: TextStyle(
                    color: Colors.white70,
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
                              gradient: LinearGradient(colors: [Color(0xFF11998E), Color(0xFF38EF7D)]),
                              onPressed: () => mqttService.closeGripper(),
                            ),
                          ),
                          SizedBox(width: 16),
                          Expanded(
                            child: _buildGradientButton(
                              icon: Icons.pan_tool_outlined,
                              label: 'Letakkan',
                              gradient: LinearGradient(colors: [Color(0xFFF2994A), Color(0xFFF2C94C)]),
                              onPressed: () => mqttService.openGripper(),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 16),
                      _buildGradientButton(
                        icon: mqttService.ledStatus ? Icons.lightbulb : Icons.lightbulb_outline,
                        label: mqttService.ledStatus ? 'LED Menyala' : 'LED Mati',
                        gradient: mqttService.ledStatus 
                            ? LinearGradient(colors: [Colors.yellow.shade700, Colors.orange.shade500])
                            : LinearGradient(colors: [Colors.grey.shade700, Colors.grey.shade800]),
                        onPressed: () => mqttService.toggleLed(),
                        isFullWidth: true,
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 40),
              ],
            ),
          ),
        ),
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
            color: Colors.cyanAccent.withOpacity(0.15),
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
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white.withOpacity(0.1)),
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
                    border: Border.all(color: isCameraRunning ? Colors.cyanAccent.withOpacity(0.5) : Colors.white24, width: 2),
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
                                  Icon(Icons.error_outline, color: Colors.redAccent, size: 40),
                                  SizedBox(height: 8),
                                  Text('Koneksi Gagal', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
                                ],
                              ),
                            ),
                          )
                        : Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.videocam_off, color: Colors.white38, size: 48),
                                SizedBox(height: 12),
                                Text(
                                  'Kamera Tidak Aktif\nTekan tombol Play',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: Colors.white54, fontSize: 14),
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
                          border: Border.all(color: Colors.white12),
                        ),
                        child: TextField(
                          controller: _ipController,
                          style: TextStyle(color: Colors.white, fontSize: 14),
                          decoration: InputDecoration(
                            contentPadding: EdgeInsets.symmetric(horizontal: 16),
                            hintText: 'Masukkan URL Kamera',
                            hintStyle: TextStyle(color: Colors.white38),
                            border: InputBorder.none,
                            icon: Padding(
                              padding: const EdgeInsets.only(left: 12.0),
                              child: Icon(Icons.link, color: Colors.cyanAccent, size: 20),
                            ),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: 12),
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          isCameraRunning = !isCameraRunning;
                        });
                      },
                      child: Container(
                        height: 50,
                        width: 50,
                        decoration: BoxDecoration(
                          gradient: isCameraRunning 
                              ? LinearGradient(colors: [Colors.redAccent, Colors.deepOrange])
                              : LinearGradient(colors: [Colors.cyan, Colors.blueAccent]),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: isCameraRunning ? Colors.redAccent.withOpacity(0.4) : Colors.cyan.withOpacity(0.4),
                              blurRadius: 10,
                              offset: Offset(0, 4),
                            )
                          ],
                        ),
                        child: Icon(
                          isCameraRunning ? Icons.stop_rounded : Icons.play_arrow_rounded,
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

  Widget _buildGlassCard(String title, String value, IconData icon, Color iconColor) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withOpacity(0.1)),
          ),
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
              Text(title, style: TextStyle(color: Colors.white60, fontSize: 12, fontWeight: FontWeight.w500)),
              SizedBox(height: 4),
              Text(value, style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold, letterSpacing: 1.0)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModernDPad(MqttService mqttService) {
    return Container(
      width: 220,
      height: 220,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withOpacity(0.03),
        border: Border.all(color: Colors.white.withOpacity(0.05), width: 1),
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
                colors: [Color(0xFF2C5364), Color(0xFF0F2027)],
              ),
              border: Border.all(color: Colors.cyanAccent.withOpacity(0.3), width: 2),
              boxShadow: [
                BoxShadow(color: Colors.cyanAccent.withOpacity(0.2), blurRadius: 15, spreadRadius: 1),
              ],
            ),
            child: Icon(Icons.circle, color: Colors.cyanAccent.withOpacity(0.8), size: 24),
          ),
          // Arrows
          Positioned(top: 10, child: _buildDirBtn(Icons.keyboard_arrow_up_rounded, () => mqttService.moveCommand('forward'), () => mqttService.moveCommand('stop'))),
          Positioned(bottom: 10, child: _buildDirBtn(Icons.keyboard_arrow_down_rounded, () => mqttService.moveCommand('backward'), () => mqttService.moveCommand('stop'))),
          Positioned(left: 10, child: _buildDirBtn(Icons.keyboard_arrow_left_rounded, () => mqttService.moveCommand('left'), () => mqttService.moveCommand('stop'))),
          Positioned(right: 10, child: _buildDirBtn(Icons.keyboard_arrow_right_rounded, () => mqttService.moveCommand('right'), () => mqttService.moveCommand('stop'))),
        ],
      ),
    );
  }

  Widget _buildDirBtn(IconData icon, VoidCallback onPointerDown, VoidCallback onPointerUp) {
    return Listener(
      onPointerDown: (event) => onPointerDown(),
      onPointerUp: (event) => onPointerUp(),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {}, 
          customBorder: CircleBorder(),
          splashColor: Colors.cyanAccent.withOpacity(0.3),
          highlightColor: Colors.cyanAccent.withOpacity(0.1),
          child: Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withOpacity(0.05),
            ),
            child: Icon(icon, color: Colors.white, size: 40),
          ),
        ),
      ),
    );
  }

  Widget _buildGradientButton({
    required IconData icon,
    required String label,
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
          Text(
            label,
            style: TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
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
}
