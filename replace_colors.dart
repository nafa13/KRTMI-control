import 'dart:io';

void main() {
  final file = File('lib/screens/home_screen.dart');
  var content = file.readAsStringSync();
  
  // 1. Background gradient
  content = content.replaceAll(
    'colors: [\n              Color(0xFF0F2027),\n              Color(0xFF203A43),\n              Color(0xFF2C5364),\n            ]',
    'colors: [\n              Color(0xFFF5F7FA),\n              Color(0xFFE4E9F2),\n              Color(0xFFC3CFE2),\n            ]'
  );

  // 2. D-Pad center core gradient
  content = content.replaceAll(
    'colors: [Color(0xFF2C5364), Color(0xFF0F2027)]',
    'colors: [Color(0xFFE4E9F2), Color(0xFFC3CFE2)]'
  );
  
  // 3. Text & transparent backgrounds
  content = content.replaceAll('Colors.white70', 'Colors.black54');
  content = content.replaceAll('Colors.white60', 'Colors.black45');
  content = content.replaceAll('Colors.white54', 'Colors.black38');
  content = content.replaceAll('Colors.white38', 'Colors.black26');
  content = content.replaceAll('Colors.white24', 'Colors.black12');
  content = content.replaceAll('Colors.white12', 'Colors.black12');
  content = content.replaceAll('Colors.white', 'Colors.black87');
  
  // Fix button text colors back to white because gradients are dark
  content = content.replaceAll(
    'color: Colors.black87,\n                    fontSize: 14,\n                    fontWeight: FontWeight.bold,',
    'color: Colors.white,\n                    fontSize: 14,\n                    fontWeight: FontWeight.bold,'
  );
  content = content.replaceAll(
    'color: Colors.black87.withOpacity(0.85),\n                      fontSize: 11,\n                      fontWeight: FontWeight.w500,',
    'color: Colors.white.withOpacity(0.85),\n                      fontSize: 11,\n                      fontWeight: FontWeight.w500,'
  );
  content = content.replaceAll(
    'Icon(icon, color: Colors.black87, size: 24)',
    'Icon(icon, color: Colors.white, size: 24)'
  );
  
  // Fix play/stop button icon color
  content = content.replaceAll(
    'Icon(\n                          isCameraRunning\n                              ? Icons.stop_rounded\n                              : Icons.play_arrow_rounded,\n                          color: Colors.black87,\n                          size: 30,\n                        )',
    'Icon(\n                          isCameraRunning\n                              ? Icons.stop_rounded\n                              : Icons.play_arrow_rounded,\n                          color: Colors.white,\n                          size: 30,\n                        )'
  );

  // 4. Primary accent color
  content = content.replaceAll('Colors.cyanAccent', 'Colors.blueAccent');
  content = content.replaceAll('Colors.cyan', 'Colors.blue');

  file.writeAsStringSync(content);
  print('Done replacing colors.');
}
