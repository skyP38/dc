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

  const VerticalToolbar({
    super.key,
    required this.selectedPrototype,
    required this.onSelectPrototype,
    required this.onSetNodeSize,
    required this.isGridVisible,
    required this.onGridToggle,
    required this.onExport,
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
            shape: (size) => Container(color: Colors.grey.shade300),
          ),
          _buildButton(
            label: 'Logic',
            prototype: LogicBlock(''),
            shape: (size) => Transform.rotate(
              angle: 45 * math.pi / 180,
              child: Container(color: Colors.grey.shade300),
            ),
          ),
          _buildButton(
            label: 'IO',
            prototype: IOBlock(''),
            shape: (size) => ClipPath(
              clipper: _ParallelogramIconClipper(),
              child: Container(color: Colors.grey.shade300),
            ),
          ),
          _buildButton(
            label: 'Subroutine',
            prototype: SubroutineBlock(''),
            shape: (size) => CustomPaint(size: size, painter: _SubroutineIconPainter()),
          ),
          const Divider(),
          CheckboxListTile(
            title: const Text('Показать сетку'),
            value: isGridVisible,
            onChanged: (value) => onGridToggle(value ?? false),
            dense: true,
          ),
          ElevatedButton(
            onPressed: onExport,
            child: const Text('Экспорт в SVG'),
          ),
          const SizedBox(height: 8),
          ElevatedButton(
            onPressed: () => _showSetSizeDialog(context),
            child: const Text('Размер блоков'),
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
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.black, width: 1.5),
              ),
              child: shape(const Size(28, 28)),
            ),
          ),
          const SizedBox(width: 12),
          Text(label),
        ],
      ),
    );
  }
}

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
