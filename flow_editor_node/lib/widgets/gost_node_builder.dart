import 'package:flutter/material.dart';
import '../factories/node_factory.dart';
import '../models/flow_models.dart';

class GostNodeBuilder {
  final Size nodeSize;
  final bool isSelected;
  final ValueChanged<Size> onResize;
  final void Function(String nodeName, Offset newPosition)? onPositionChange;
  final VoidCallback? onResizeStart;
  final VoidCallback? onResizeEnd;
  final String nodeName;

  const GostNodeBuilder({
    required this.nodeSize,
    required this.isSelected,
    required this.onResize,
    this.onPositionChange,
    this.onResizeStart,
    this.onResizeEnd,
    required this.nodeName,
  });

  Widget build(NodeModel node) {
    final data = node.data;
    final text = data.text;

    Widget shape;
    switch (data) {
      case TerminalBlock():
        shape = _RoundedRectNode(
          child: _NodeContent(text: text),
          radius: 40.0,
          size: nodeSize,
        );
        break;
      case ProcessBlock():
        shape = _RectNode(
          child: _NodeContent(text: text),
          size: nodeSize,
        );
        break;
      case LogicBlock():
        shape = _DiamondNode(
          child: _NodeContent(text: text),
          size: nodeSize,
        );
        break;
      case IOBlock():
        shape = _ParallelogramNode(
          child: _NodeContent(text: text),
          size: nodeSize,
        );
        break;
      case SubroutineBlock():
        shape = _SubroutineNode(
          child: _NodeContent(text: text),
          size: nodeSize,
        );
        break;
      case ForBlock():
        shape = _HexagonNode(
          child: _NodeContent(text: text),
          size: nodeSize,
        );
        break;
      default:
        shape = _RectNode(
          child: _NodeContent(text: text),
          size: nodeSize,
        );
    }

    if (isSelected) {
      return _ResizableWrapper(
        size: nodeSize,
        onResize: onResize,
        onPositionChange: (delta) {
          if (onPositionChange != null) {
            onPositionChange!(nodeName, node.position + delta);
          }
        },
        onResizeStart: onResizeStart,
        onResizeEnd: onResizeEnd,
        nodePosition: node.position,
        child: shape,
      );
    }

    return SizedBox(
      width: nodeSize.width,
      height: nodeSize.height,
      child: shape,
    );
  }
}


class _ResizableWrapper extends StatefulWidget {
  final Size size;
  final ValueChanged<Size> onResize;
  final ValueChanged<Offset> onPositionChange;
  final Widget child;
  final VoidCallback? onResizeStart;
  final VoidCallback? onResizeEnd;
  final Offset nodePosition;

  const _ResizableWrapper({
    required this.size,
    required this.onResize,
    required this.onPositionChange,
    required this.child,
    this.onResizeStart,
    this.onResizeEnd,
    required this.nodePosition,
  });

  @override
  State<_ResizableWrapper> createState() => _ResizableWrapperState();
}

class _ResizableWrapperState extends State<_ResizableWrapper> {
  late Size _size;
  Rect? _startRect;
  Offset? _startDragPosition;
  Alignment? _activeHandle;
  Offset? _startNodePosition;
  Offset _tempTranslation = Offset.zero;

  @override
  void initState() {
    super.initState();
    _size = widget.size;
  }

  @override
  void didUpdateWidget(covariant _ResizableWrapper oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.size != oldWidget.size) {
      _size = widget.size;
      _tempTranslation = Offset.zero;
    }
  }

  void _updateFromRect(Rect newRect) {
    _size = newRect.size;
    widget.onPositionChange(newRect.topLeft - Offset(_startRect!.left, _startRect!.top));
  }

  Widget _buildHandle(Alignment align) {
    final isActive = _activeHandle == align;

    double left, top;
    final effectiveWidth = _size.width;
    final effectiveHeight = _size.height;
    switch (align.x) {
      case -1: left = -14; break;
      case 0: left = effectiveWidth / 2 - 14; break;
      case 1: left = effectiveWidth - 12; break;
      default: left = -14;
    }
    switch (align.y) {
      case -1: top = -14; break;
      case 0: top = effectiveHeight / 2 - 14; break;
      case 1: top = effectiveHeight - 14; break;
      default: top = -14;
    }
    return Positioned(
      left: left,
      top: top,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onPanStart: (details) {
          widget.onResizeStart?.call();
          setState(() {
            _activeHandle = align;
          });
          _startDragPosition = details.localPosition;
          _startRect = Rect.fromLTWH(
            widget.nodePosition.dx,
            widget.nodePosition.dy,
            _size.width,
            _size.height,
          );
          _tempTranslation = Offset.zero;
        },
        onPanUpdate: (details) {
          if (_startRect == null || _startDragPosition == null) return;
          final delta = details.localPosition - _startDragPosition!;
          Rect newRect = _startRect!;

          if (align.x == -1) {
            newRect = Rect.fromLTRB(
              newRect.left + delta.dx,
              newRect.top,
              newRect.right,
              newRect.bottom,
            );
          } else if (align.x == 1) {
            newRect = Rect.fromLTRB(
              newRect.left,
              newRect.top,
              newRect.right + delta.dx,
              newRect.bottom,
            );
          }

          if (align.y == -1) {
            newRect = Rect.fromLTRB(
              newRect.left,
              newRect.top + delta.dy,
              newRect.right,
              newRect.bottom,
            );
          } else if (align.y == 1) {
            newRect = Rect.fromLTRB(
              newRect.left,
              newRect.top,
              newRect.right,
              newRect.bottom + delta.dy,
            );
          }

          if (newRect.width < 80) {
            if (align.x == -1) newRect = Rect.fromLTRB(newRect.right - 80, newRect.top, newRect.right, newRect.bottom);
            else newRect = Rect.fromLTRB(newRect.left, newRect.top, newRect.left + 80, newRect.bottom);
          }
          if (newRect.height < 40) {
            if (align.y == -1) newRect = Rect.fromLTRB(newRect.left, newRect.bottom - 40, newRect.right, newRect.bottom);
            else newRect = Rect.fromLTRB(newRect.left, newRect.top, newRect.right, newRect.top + 40);
          }

          setState(() {
            _size = newRect.size;
          });


          final deltaPos = Offset(newRect.left - _startRect!.left, newRect.top - _startRect!.top);
          if (deltaPos != Offset.zero) {
            setState(() {
              _tempTranslation = deltaPos;
            });
          }
        },
        onPanEnd: (details) {
          setState(() => _activeHandle = null);
          final finalDelta = _tempTranslation;
          widget.onPositionChange(finalDelta);
          widget.onResize(_size);
          widget.onResizeEnd?.call();
          // Сброс
          _startRect = null;
          _startDragPosition = null;
          _tempTranslation = Offset.zero;
        },
        child: SizedBox(
          width: 24,
          height: 24,
          child: Center(
            child: Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                color: isActive ? Colors.green : Colors.white,
                border: Border.all(color: isActive ? Colors.green : Colors.blue, width: isActive ? 3 : 2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Transform.translate(
      offset: _tempTranslation,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          SizedBox(
            width: _size.width,
            height: _size.height,
            child: widget.child,
          ),
          _buildHandle(Alignment.topLeft),
          _buildHandle(Alignment.topCenter),
          _buildHandle(Alignment.topRight),
          _buildHandle(Alignment.centerLeft),
          _buildHandle(Alignment.centerRight),
          _buildHandle(Alignment.bottomLeft),
          _buildHandle(Alignment.bottomCenter),
          _buildHandle(Alignment.bottomRight),
        ],
      ),
    );
  }
}

class _NodeContent extends StatelessWidget {
  final String text;
  const _NodeContent({required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Text(
        text,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        textAlign: TextAlign.center,
      ),
    );
  }
}

class _RectNode extends StatelessWidget {
  final Widget child;
  final Size size;
  const _RectNode({required this.child, required this.size});
  @override
  Widget build(BuildContext context) => Container(
    width: size.width,
    height: size.height,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: Colors.transparent,
      border: Border.all(color: Colors.black, width: 2),
    ),
    child: child,
  );
}

class _RoundedRectNode extends StatelessWidget {
  final Widget child;
  final double radius;
  final Size size;
  const _RoundedRectNode({required this.child, required this.radius, required this.size});
  @override
  Widget build(BuildContext context) => Container(
    width: size.width,
    height: size.height,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: Colors.transparent,
      border: Border.all(color: Colors.black, width: 2),
      borderRadius: BorderRadius.circular(radius),
    ),
    child: child,
  );
}

class _DiamondNode extends StatelessWidget {
  final Widget child;
  final Size size;
  const _DiamondNode({required this.child, required this.size});
  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        SizedBox(
          width: size.width,
          height: size.height,
          child: CustomPaint(
            painter: _DiamondPainter(size: size),
          ),
        ),
        Center(child: child),
        Positioned(
          bottom: -20,
          left: size.width / 2 - 25,
          child: const Text('Да', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
        ),
        Positioned(
          right: -25,
          top: size.height / 2 - 20,
          child: const Text('Нет', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }
}

class _DiamondPainter extends CustomPainter {
  final Size size;
  _DiamondPainter({required this.size});
  @override
  void paint(Canvas canvas, Size _) {
    final path = Path();
    path.moveTo(size.width / 2, 0);
    path.lineTo(size.width, size.height / 2);
    path.lineTo(size.width / 2, size.height);
    path.lineTo(0, size.height / 2);
    path.close();
    final borderPaint = Paint()..color = Colors.black..style = PaintingStyle.stroke..strokeWidth = 2;
    canvas.drawPath(path, borderPaint);
  }
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _ParallelogramNode extends StatelessWidget {
  final Widget child;
  final Size size;
  const _ParallelogramNode({required this.child, required this.size});
  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        SizedBox(
          width: size.width,
          height: size.height,
          child: CustomPaint(painter: _ParallelogramPainter(size: size)),
        ),
        Center(child: child),
      ],
    );
  }
}

class _ParallelogramPainter extends CustomPainter {
  final Size size;
  _ParallelogramPainter({required this.size});
  @override
  void paint(Canvas canvas, Size _) {
    final path = Path();
    const skew = 20.0;
    path.moveTo(skew, 0);
    path.lineTo(size.width, 0);
    path.lineTo(size.width - skew, size.height);
    path.lineTo(0, size.height);
    path.close();
    final borderPaint = Paint()..color = Colors.black..style = PaintingStyle.stroke..strokeWidth = 2;
    canvas.drawPath(path, borderPaint);
  }
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _SubroutineNode extends StatelessWidget {
  final Widget child;
  final Size size;
  const _SubroutineNode({required this.child, required this.size});
  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        SizedBox(
          width: size.width,
          height: size.height,
          child: CustomPaint(painter: _SubroutineNodePainter(size: size)),
        ),
        Center(child: child),
      ],
    );
  }
}

class _SubroutineNodePainter extends CustomPainter {
  final Size size;
  _SubroutineNodePainter({required this.size});
  @override
  void paint(Canvas canvas, Size _) {
    final borderPaint = Paint()..color = Colors.black..strokeWidth = 2.0..style = PaintingStyle.stroke;
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    canvas.drawRect(rect, borderPaint);
    const double left = 10.0;
    canvas.drawLine(Offset(left, 0), Offset(left, size.height), borderPaint);
    final double right = size.width - 10.0;
    canvas.drawLine(Offset(right, 0), Offset(right, size.height), borderPaint);
  }
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _HexagonNode extends StatelessWidget {
  final Widget child;
  final Size size;
  const _HexagonNode({required this.child, required this.size});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size.width,
      height: size.height,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          SizedBox(
            width: size.width,
            height: size.height,
            child: CustomPaint(painter: _HexagonPainter(size: size)),
          ),
          Center(child: child),
          // Positioned(
          //   right: -25,
          //   top: size.height / 2 - 20,
          //   child: const Text('exit', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
          // ),
          // Positioned(
          //   bottom: -25,
          //   left: size.width / 2 - 25,
          //   child: const Text('body', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
          // ),
        ],
      ),
    );
  }
}

class _HexagonPainter extends CustomPainter {
  final Size size;
  _HexagonPainter({required this.size});

  @override
  void paint(Canvas canvas, Size _) {
    final path = Path();
    final w = size.width;
    final h = size.height;
    final h2 = h / 2;
    final w4 = w / 4;
    path.moveTo(w4, 0);
    path.lineTo(w * 3 / 4, 0);
    path.lineTo(w, h2);
    path.lineTo(w * 3 / 4, h);
    path.lineTo(w4, h);
    path.lineTo(0, h2);
    path.close();
    final paint = Paint()
    ..color = Colors.transparent
    ..style = PaintingStyle.fill;
    canvas.drawPath(path, paint);
    final borderPaint = Paint()
    ..color = Colors.black
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2;
    canvas.drawPath(path, borderPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
