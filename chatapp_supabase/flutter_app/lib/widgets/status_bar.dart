import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/connection_service.dart';

class StatusBar extends StatelessWidget {
  final bool showIcon;
  final TextStyle? textStyle;
  final double? height;

  const StatusBar({
    super.key,
    this.showIcon = true,
    this.textStyle,
    this.height = 32,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<ConnectionService>(
      builder: (context, connectionService, _) {
        final status = connectionService.status;
        final isConnected = connectionService.isConnected;
        final statusMessage = connectionService.getStatusMessage();

        // Determine colors based on status
        Color bgColor;
        Color textColor;
        Color iconColor;

        switch (status) {
          case ConnectionStatus.connected:
            bgColor = const Color(0xFF4CAF50).withOpacity(0.1);
            textColor = const Color(0xFF2E7D32);
            iconColor = const Color(0xFF4CAF50);
            break;
          case ConnectionStatus.disconnected:
            bgColor = const Color(0xFFF44336).withOpacity(0.1);
            textColor = const Color(0xFFC62828);
            iconColor = const Color(0xFFF44336);
            break;
          case ConnectionStatus.reconnecting:
            bgColor = const Color(0xFFFFC107).withOpacity(0.1);
            textColor = const Color(0xFFF57F17);
            iconColor = const Color(0xFFFFC107);
            break;
        }

        return Container(
          height: height,
          color: bgColor,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (showIcon) ...[
                Icon(
                  isConnected ? Icons.cloud_done : Icons.cloud_off,
                  size: 14,
                  color: iconColor,
                ),
                const SizedBox(width: 6),
              ],
              Text(
                statusMessage,
                style: textStyle ??
                    GoogleFonts.nunito(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: textColor,
                    ),
              ),
            ],
          ),
        );
      },
    );
  }
}
