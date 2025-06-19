import 'dart:async';
import 'package:flutter/material.dart';

class RefreshCountdown extends StatefulWidget {
  final int refreshIntervalSeconds;
  final VoidCallback onRefresh;
  final Function(int) onIntervalChanged;

  const RefreshCountdown({
    super.key,
    required this.refreshIntervalSeconds,
    required this.onRefresh,
    required this.onIntervalChanged,
  });

  @override
  State<RefreshCountdown> createState() => _RefreshCountdownState();
}

class _RefreshCountdownState extends State<RefreshCountdown> with TickerProviderStateMixin {
  late AnimationController _controller;
  Timer? _timer;
  int _remainingSeconds = 0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: Duration(seconds: widget.refreshIntervalSeconds),
      vsync: this,
    );
    _startCountdown();
  }

  @override
  void didUpdateWidget(RefreshCountdown oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshIntervalSeconds != widget.refreshIntervalSeconds) {
      _controller.dispose();
      _controller = AnimationController(
        duration: Duration(seconds: widget.refreshIntervalSeconds),
        vsync: this,
      );
      _startCountdown();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _timer?.cancel();
    super.dispose();
  }

  void _startCountdown() {
    _timer?.cancel();
    _remainingSeconds = widget.refreshIntervalSeconds;
    _controller.reset();
    _controller.forward();

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _remainingSeconds--;
      });

      if (_remainingSeconds <= 0) {
        timer.cancel();
        widget.onRefresh();
        _startCountdown();
      }
    });
  }

  void _refreshNow() {
    _timer?.cancel();
    _controller.reset();
    widget.onRefresh();
    _startCountdown();
  }

  void _showIntervalMenu() {
    final RenderBox renderBox = context.findRenderObject() as RenderBox;
    final position = renderBox.localToGlobal(Offset.zero);

    showMenu<int>(
      context: context,
      position: RelativeRect.fromLTRB(
        position.dx - 100,
        position.dy - 200,
        position.dx + 100,
        position.dy,
      ),
      items: [
        const PopupMenuItem(value: 5, child: Text('5 seconds')),
        const PopupMenuItem(value: 10, child: Text('10 seconds')),
        const PopupMenuItem(value: 15, child: Text('15 seconds')),
        const PopupMenuItem(value: 30, child: Text('30 seconds')),
        const PopupMenuItem(value: 60, child: Text('1 minute')),
      ],
    ).then((value) {
      if (value != null) {
        widget.onIntervalChanged(value);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _refreshNow,
      onLongPress: _showIntervalMenu,
      child: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.9),
          boxShadow: [
            BoxShadow(
              color: Theme.of(context).shadowColor.withValues(alpha: 0.2),
              blurRadius: 6,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                return CircularProgressIndicator(
                  value: _controller.value,
                  strokeWidth: 3,
                  backgroundColor: Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.3),
                  valueColor: AlwaysStoppedAnimation<Color>(Theme.of(context).colorScheme.onPrimary),
                );
              },
            ),
            Text(
              '$_remainingSeconds',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onPrimary,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
