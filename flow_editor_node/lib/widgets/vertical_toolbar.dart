import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/flow_models.dart';

class VerticalToolbar extends StatelessWidget {
  final GostNodeData? selectedPrototype;
  final ValueChanged<GostNodeData?> onSelectPrototype;
  final ValueChanged<Size> onSetNodeSize;
  final bool isGridVisible;
  final ValueChanged<bool> onGridToggle;
  final VoidCallback onExport;

  final VoidCallback onUndo;
  final VoidCallback onRedo;
  final VoidCallback onSave;
  final VoidCallback onLoad;

  const VerticalToolbar({
    super.key,
    required this.selectedPrototype,
    required this.onSelectPrototype,
    required this.onSetNodeSize,
    required this.isGridVisible,
    required this.onGridToggle,
    required this.onExport,
    required this.onUndo,
    required this.onRedo,
    required this.onSave,
    required this.onLoad,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 200,
      child: Column(
        children: [
          const SizedBox(height: 16),
          _buildButton(
            label: 'Process',
            prototype: ProcessBlock(''),
            shape: (size) => CustomPaint(
              size: size,
              painter: _RectIconPainter(),
            ),
          ),
          _buildButton(
            label: 'Logic',
            prototype: LogicBlock(''),
            shape: (size) => CustomPaint(
              size: size,
              painter: _DiamondIconPainter(),
            ),
          ),
          _buildButton(
            label: 'IO',
            prototype: IOBlock(''),
            shape: (size) => CustomPaint(
              size: size,
              painter: _ParallelogramIconPainter(),
            ),
          ),
          _buildButton(
            label: 'Subroutine',
            prototype: SubroutineBlock(''),
            shape: (size) => CustomPaint(
              size: size,
              painter: _SubroutineIconPainter(),
            ),
          ),
          _buildButton(
            label: 'For',
            prototype: ForBlock(''),
            shape: (size) => CustomPaint(
              size: size,
              painter: _HexagonIconPainter(),
            ),
          ),
          const Divider(),
          GestureDetector(
            onTap: () => onGridToggle(!isGridVisible),
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
              child: Row(
                children: [
                  Checkbox(
                    value: isGridVisible,
                    onChanged: (value) => onGridToggle(value ?? false),
                  ),
                  const SizedBox(width: 8),
                  const Text('Показать сетку'),
                ],
              ),
            ),
          ),
          // CheckboxListTile(
          //   title: const Text('Показать сетку'),
          //   value: isGridVisible,
          //   onChanged: (value) => onGridToggle(value ?? false),
          //   dense: true,
          // ),
          ElevatedButton(
            onPressed: onExport,
            child: const Text('Экспорт в SVG'),
          ),
          const SizedBox(height: 8),
          ElevatedButton(
            onPressed: () => _showSetSizeDialog(context),
            child: const Text('Размер блоков'),
          ),

          const SizedBox(height: 8),
          ElevatedButton(
            onPressed: onUndo,
            child: const Text('Отменить (Ctrl+Z)'),
          ),
          const SizedBox(height: 8),
          ElevatedButton(
            onPressed: onRedo,
            child: const Text('Вернуть (Ctrl+Y)'),
          ),
          const SizedBox(height: 8),
          ElevatedButton(
            onPressed: onSave,
            child: const Text('Сохранить'),
          ),
          const SizedBox(height: 8),
          ElevatedButton(
            onPressed: onLoad,
            child: const Text('Загрузить'),
          ),
        ],
      ),
    );
  }

  void _showSetSizeDialog(BuildContext context) async {
    final widthController = TextEditingController(text: '160');
    final heightController = TextEditingController(text: '80');
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Задать размер блоков'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: widthController,
              decoration: const InputDecoration(labelText: 'Ширина'),
              keyboardType: TextInputType.number,
            ),
            TextField(
              controller: heightController,
              decoration: const InputDecoration(labelText: 'Высота'),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Отмена')),
          TextButton(
            onPressed: () {
              final width = double.tryParse(widthController.text) ?? 160;
              final height = double.tryParse(heightController.text) ?? 80;
              Navigator.pop(ctx);
              onSetNodeSize(Size(width, height));
            },
            child: const Text('Применить'),
          ),
        ],
      ),
    );
  }

  Widget _buildButton({
    required String label,
    required GostNodeData prototype,
    required Widget Function(Size) shape,
  }) {
    final isSelected = selectedPrototype?.runtimeType == prototype.runtimeType;
    return ElevatedButton(
      onPressed: () => onSelectPrototype(isSelected ? null : prototype),
      style: ElevatedButton.styleFrom(
        backgroundColor: isSelected ? Colors.blue.shade100 : null,
        minimumSize: const Size(160, 48),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          SizedBox(
            width: 28,
            height: 28,
            child: shape(const Size(28, 28)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}


class _RectIconPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
    ..color = Colors.black
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.5;
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), paint);
  }
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _DiamondIconPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final path = Path();
    path.moveTo(size.width / 2, 0);
    path.lineTo(size.width, size.height / 2);
    path.lineTo(size.width / 2, size.height);
    path.lineTo(0, size.height / 2);
    path.close();
    final paint = Paint()
    ..color = Colors.black
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.5;
    canvas.drawPath(path, paint);
  }
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _ParallelogramIconPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final path = Path();
    const skew = 6.0; // для размера 28x28
    path.moveTo(skew, 0);
    path.lineTo(size.width, 0);
    path.lineTo(size.width - skew, size.height);
    path.lineTo(0, size.height);
    path.close();
    final paint = Paint()
    ..color = Colors.black
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.5;
    canvas.drawPath(path, paint);
  }
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _SubroutineIconPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
    ..color = Colors.black
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.5;
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    canvas.drawRect(rect, paint);
    const double left = 5.0;
    canvas.drawLine(Offset(left, 0), Offset(left, size.height), paint);
    final double right = size.width - 5.0;
    canvas.drawLine(Offset(right, 0), Offset(right, size.height), paint);
  }
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _HexagonIconPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final h2 = h / 2;
    final w4 = w / 4;
    final path = Path()
    ..moveTo(w4, 0)
    ..lineTo(w * 3 / 4, 0)
    ..lineTo(w, h2)
    ..lineTo(w * 3 / 4, h)
    ..lineTo(w4, h)
    ..lineTo(0, h2)
    ..close();
    final paint = Paint()
    ..color = Colors.black
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.5;
    canvas.drawPath(path, paint);
  }
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/*
class _ParallelogramIconClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    path.moveTo(size.width * 0.2, 0);
    path.lineTo(size.width, 0);
    path.lineTo(size.width * 0.8, size.height);
    path.lineTo(0, size.height);
    path.close();
    return path;
  }
  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

class _SubroutineIconPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paintFill = Paint()..color = Colors.grey.shade300;
    final paintBorder = Paint()..color = Colors.black..strokeWidth = 1..style = PaintingStyle.stroke;
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    canvas.drawRect(rect, paintFill);
    canvas.drawRect(rect, paintBorder);
    double left = 5;
    canvas.drawLine(Offset(left, 0), Offset(left, size.height), paintBorder);
    double right = size.width - 5;
    canvas.drawLine(Offset(right, 0), Offset(right, size.height), paintBorder);
  }
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _HexagonIconPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
    ..color = Colors.grey.shade300
    ..style = PaintingStyle.fill;
    final borderPaint = Paint()
    ..color = Colors.black
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.5;

    final w = size.width;
    final h = size.height;
    final h2 = h / 2;
    final w4 = w / 4;
    final path = Path()
    ..moveTo(w4, 0)
    ..lineTo(w * 3 / 4, 0)
    ..lineTo(w, h2)
    ..lineTo(w * 3 / 4, h)
    ..lineTo(w4, h)
    ..lineTo(0, h2)
    ..close();

    canvas.drawPath(path, paint);
    canvas.drawPath(path, borderPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}*/
