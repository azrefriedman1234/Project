import 'package:flutter/material.dart';

class RectSel {
  Rect rect;
  RectSel(this.rect);
}

class BlurOverlay extends StatefulWidget {
  final Widget child;
  final void Function(List<RectSel> rects) onChanged;

  const BlurOverlay({super.key, required this.child, required this.onChanged});

  @override
  State<BlurOverlay> createState() => _BlurOverlayState();
}

class _BlurOverlayState extends State<BlurOverlay> {
  Offset? start;
  Rect? current;
  final rects = <RectSel>[];

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onPanStart: (d) {
        start = d.localPosition;
        setState(() => current = Rect.fromPoints(start!, start!));
      },
      onPanUpdate: (d) {
        if (start == null) return;
        setState(() => current = Rect.fromPoints(start!, d.localPosition));
      },
      onPanEnd: (_) {
        if (current != null && current!.width.abs() > 8 && current!.height.abs() > 8) {
          rects.add(RectSel(current!));
          widget.onChanged(rects);
        }
        setState(() { start = null; current = null; });
      },
      child: Stack(
        children: [
          widget.child,
          CustomPaint(
            painter: _RectPainter(rects, current),
            size: Size.infinite,
          ),
        ],
      ),
    );
  }
}

class _RectPainter extends CustomPainter {
  final List<RectSel> rects;
  final Rect? current;
  _RectPainter(this.rects, this.current);

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    for (final r in rects) {
      canvas.drawRect(r.rect, p);
    }
    if (current != null) {
      canvas.drawRect(current!, p);
    }
  }

  @override
  bool shouldRepaint(covariant _RectPainter oldDelegate) => true;
}
