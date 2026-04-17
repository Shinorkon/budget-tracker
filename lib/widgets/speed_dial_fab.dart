import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class SpeedDialFab extends StatefulWidget {
  final VoidCallback onAddTransaction;
  final VoidCallback onScanReceipt;
  final VoidCallback? onTransfer;

  const SpeedDialFab({
    super.key,
    required this.onAddTransaction,
    required this.onScanReceipt,
    this.onTransfer,
  });

  @override
  State<SpeedDialFab> createState() => _SpeedDialFabState();
}

class _SpeedDialFabState extends State<SpeedDialFab>
    with SingleTickerProviderStateMixin {
  bool _isOpen = false;
  late final AnimationController _controller;
  late final Animation<double> _expandAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _expandAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
      reverseCurve: Curves.easeIn,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toggle() {
    setState(() => _isOpen = !_isOpen);
    if (_isOpen) {
      _controller.forward();
    } else {
      _controller.reverse();
    }
  }

  void _close() {
    if (_isOpen) _toggle();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      // Tall enough to contain the expanded options above the FAB
      height: 200,
      child: Stack(
        alignment: Alignment.bottomCenter,
        clipBehavior: Clip.none,
        children: [
          // Transparent backdrop to close dial on outside tap
          if (_isOpen)
            Positioned.fill(
              child: GestureDetector(
                onTap: _close,
                behavior: HitTestBehavior.translucent,
                child: const SizedBox.expand(),
              ),
            ),

          // Transfer option (only when a handler is provided)
          if (widget.onTransfer != null)
            _buildOption(
              animation: _expandAnimation,
              offsetFactor: 1.5,
              icon: Icons.swap_horiz_rounded,
              label: 'Transfer',
              color: AppColors.primary,
              onTap: () {
                _close();
                widget.onTransfer!.call();
              },
            ),

          // Scan Receipt option
          _buildOption(
            animation: _expandAnimation,
            offsetFactor: 1.0,
            icon: Icons.document_scanner_rounded,
            label: 'Scan Receipt',
            color: AppColors.primary,
            onTap: () {
              _close();
              widget.onScanReceipt();
            },
          ),

          // Add Transaction option
          _buildOption(
            animation: _expandAnimation,
            offsetFactor: 0.48,
            icon: Icons.add_rounded,
            label: 'Add Transaction',
            color: AppColors.income,
            onTap: () {
              _close();
              widget.onAddTransaction();
            },
          ),

          // Main FAB
          _buildMainFab(),
        ],
      ),
    );
  }

  Widget _buildMainFab() {
    return AnimatedRotation(
      turns: _isOpen ? 0.125 : 0.0,
      duration: const Duration(milliseconds: 250),
      child: Container(
        height: 60,
        width: 60,
        decoration: BoxDecoration(
          gradient: AppColors.primaryGradient,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.4),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: _toggle,
            child: const Icon(Icons.add_rounded, color: Colors.white, size: 30),
          ),
        ),
      ),
    );
  }

  Widget _buildOption({
    required Animation<double> animation,
    required double offsetFactor,
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        final value = animation.value;
        return Positioned(
          bottom: 60 + (offsetFactor * 76 * value),
          child: Opacity(
            opacity: value,
            child: child!,
          ),
        );
      },
      child: GestureDetector(
        onTap: onTap,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Label
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.surfaceLight,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.border),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Text(
                label,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: 10),
            // Icon button
            Container(
              height: 48,
              width: 48,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: color.withValues(alpha: 0.4)),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
          ],
        ),
      ),
    );
  }
}
