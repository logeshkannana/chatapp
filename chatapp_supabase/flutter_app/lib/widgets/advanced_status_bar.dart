import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/connection_service.dart';

class AdvancedStatusBar extends StatefulWidget {
  final String? userStatus;
  final bool isTyping;
  final Widget? trailing;

  const AdvancedStatusBar({
    super.key,
    this.userStatus,
    this.isTyping = false,
    this.trailing,
  });

  @override
  State<AdvancedStatusBar> createState() => _AdvancedStatusBarState();
}

class _AdvancedStatusBarState extends State<AdvancedStatusBar>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    if (widget.isTyping) {
      _animationController.repeat();
    }
  }

  @override
  void didUpdateWidget(AdvancedStatusBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isTyping && !oldWidget.isTyping) {
      _animationController.repeat();
    } else if (!widget.isTyping && oldWidget.isTyping) {
      _animationController.stop();
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ConnectionService>(
      builder: (context, connectionService, _) {
        final isConnected = connectionService.isConnected;

        if (widget.isTyping) {
          return Container(
            height: 36,
            color: const Color(0xFF00897B).withOpacity(0.05),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Row(
              children: [
                SizedBox(
                  width: 24,
                  height: 24,
                  child: _TypingIndicator(animation: _animationController),
                ),
                const SizedBox(width: 8),
                Text(
                  widget.userStatus ?? 'typing',
                  style: GoogleFonts.nunito(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF00897B),
                    fontStyle: FontStyle.italic,
                  ),
                ),
                if (widget.trailing != null) ...[
                  const Spacer(),
                  widget.trailing!,
                ],
              ],
            ),
          );
        }

        return const SizedBox.shrink();
      },
    );
  }
}

class _TypingIndicator extends StatelessWidget {
  final Animation<double> animation;

  const _TypingIndicator({required this.animation});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(3, (index) {
            final offset = (animation.value - (index * 0.15)) % 1.0;
            final scale = (sin(offset * 3.14159) * 0.5 + 0.5).clamp(0.5, 1.0);
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Transform.scale(
                scale: scale,
                child: Container(
                  width: 4,
                  height: 4,
                  decoration: const BoxDecoration(
                    color: Color(0xFF00897B),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            );
          }),
        );
      },
    );
  }
}
