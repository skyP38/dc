import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';
import '../controllers/flow_controller.dart';
import '../factories/node_factory.dart';
import '../models/flow_models.dart';
import '../utils/connection_path_utils.dart';
import '../widgets/gost_node_builder.dart';
import '../widgets/vertical_toolbar.dart';

class EditorScreen extends StatefulWidget {
  @override
  State<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends State<EditorScreen> {
  final FlowController _controller = FlowController();
  final Uuid _uuid = const Uuid();
  final FocusNode _focusNode = FocusNode();

  static const Size _defaultNodeSize = Size(160, 80);
  late Size _nodeSize;
  String? _selectedNodeName;
  GostNodeData? _selectedPrototype;
  bool _isApplyingLayout = false;
  String? _selectedConnectionId;
  bool _isResizing = false;

  Map<String, NodeModel> _nodes = {};


  @override
  void initState() {
    super.initState();
    _controller.addListener(() => setState(() {}));
    _nodeSize = _defaultNodeSize;
    _setupNodes();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _setupNodes() {
    final startNode = NodeFactory.createNode(
      id: _uuid.v4(),
      data: TerminalBlock('Start'),
      position: const Offset(200, 50),
    );
    _controller.addNode(startNode);

    final endNode = NodeFactory.createNode(
      id: _uuid.v4(),
      data: TerminalBlock('End'),
      position: const Offset(200, 200),
    );
    _controller.addNode(endNode);

    _controller.addConnection(Connection(
      id: _uuid.v4(),
      sourceNodeName: startNode.name,
      sourcePort: 'out',
      targetNodeName: endNode.name,
      targetPort: 'in',
    ));
    setState(() {});
  }

  void _removeNode(String nodeName) {
    final success = _controller.removeNode(nodeName, nodeSize: _nodeSize);
    if (!success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Нельзя удалить блок Start или End')),
      );
    } else {
      if (_selectedNodeName == nodeName) _selectedNodeName = null;
      _applyAutoLayout();
    }
  }


  void _applyAutoLayout() {
    if (_isApplyingLayout || _isResizing) return;
    _isApplyingLayout = true;
    _controller.performAutoLayout(_nodeSize);
    _isApplyingLayout = false;
  }

  void _handleCanvasTapDown(TapDownDetails details) {
    final localPos = details.localPosition;
    Connection? tappedConnection;
    double minDistance = 15.0;

    for (final conn in _controller.connections) {
      final path = buildConnectionPath(conn: conn, nodes: _controller.nodes, nodeSize: _nodeSize);

      // разделение пути на сегменты и поиск минимальное расстояние
      double minDistForConn = double.infinity;
      final metrics = path.computeMetrics();
      for (final metric in metrics) {
        const double step = 2.0; // шаг для дискретизации
        for (double dist = 0; dist <= metric.length; dist += step) {
          final tangent = metric.getTangentForOffset(dist);
          if (tangent != null) {
            final point = tangent.position;
            final distance = (localPos - point).distance;
            if (distance < minDistForConn) {
              minDistForConn = distance;
            }
          }
        }
        final endPoint = metric.getTangentForOffset(metric.length)?.position;
        if (endPoint != null) {
          final distance = (localPos - endPoint).distance;
          if (distance < minDistForConn) minDistForConn = distance;
        }
      }
      if (minDistForConn < minDistance) {
        minDistance = minDistForConn;
        tappedConnection = conn;
      }
    }

    if (tappedConnection != null) {
      setState(() {
        _selectedConnectionId = tappedConnection?.id;
        _selectedNodeName = null;
      });

      if (_selectedPrototype != null) {
        _controller.insertNodeOnConnection(tappedConnection, _selectedPrototype!, _nodeSize);
        _applyAutoLayout();
        setState(() => _selectedPrototype = null);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Выберите тип блока на панели слева')),
        );
      }
    }
  }


  void _editNodeText(String nodeName) async {
    final node = _controller.nodes[nodeName];
    if (node == null) return;
    final currentText = node.data.text;
    final controller = TextEditingController(text: currentText);
    final newText = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Редактировать текст блока'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: null,
          decoration: const InputDecoration(hintText: 'Введите текст'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Отмена')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, controller.text),
            child: const Text('Сохранить'),
          ),
        ],
      ),
    );
    if (newText != null && newText.isNotEmpty && newText != currentText) {
      _controller.updateNodeText(nodeName, newText);
      _applyAutoLayout();
    }
  }

  void _showNodeContextMenu(TapDownDetails details, String nodeName) {
    final node = _nodes[nodeName];
    final bool isProtected = node?.data is TerminalBlock &&
    (node!.data.text == 'Start' || node.data.text == 'End');

    showMenu(
      context: context,
      position: RelativeRect.fromLTRB(
        details.globalPosition.dx,
        details.globalPosition.dy,
        details.globalPosition.dx,
        details.globalPosition.dy,
      ),
      items: [
        if (!isProtected)
          PopupMenuItem(
            value: 'delete',
            child: const Text('Удалить блок'),
          ),
      ],
    ).then((value) {
      if (value == 'delete') {
        _removeNode(nodeName);
      }
    });
  }


  void _setNodeSize(Size newSize) {
    if (_nodeSize == newSize) return;
    _nodeSize = newSize;
    _applyAutoLayout();
  }


  Size _getContentSize() {
    final nodes = _controller.nodes;
    if (nodes.isEmpty) return const Size(1500, 1000);
    double minX = double.infinity, minY = double.infinity;
    double maxX = -double.infinity, maxY = -double.infinity;
    for (final data in nodes.values) {
      final pos = data.position;
      minX = minX < pos.dx ? minX : pos.dx;
      minY = minY < pos.dy ? minY : pos.dy;
      maxX = maxX > pos.dx + _nodeSize.width ? maxX : pos.dx + _nodeSize.width;
      maxY = maxY > pos.dy + _nodeSize.height ? maxY : pos.dy + _nodeSize.height;
    }
    const padding = 400.0;
    double width = maxX - minX + padding;
    double height = maxY - minY + padding;
    width = width < 1200 ? 1200 : width;
    height = height < 800 ? 800 : height;
    return Size(width, height);
  }


  @override
  Widget build(BuildContext context) {
    final nodes = _controller.nodes;
    final connections = _controller.connections;

    // контроллер для вертикальной прокрутки
    final verticalScrollController = ScrollController();
    // контроллер для горизонтальной прокрутки
    final horizontalScrollController = ScrollController();

    return Scaffold(
      body: Row(
        children: [
          VerticalToolbar(
            selectedPrototype: _selectedPrototype,
            onSelectPrototype: (p) => setState(() => _selectedPrototype = p),
            onSetNodeSize: _setNodeSize,
          ),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final contentSize = _getContentSize();
                return Scrollbar(
                  thumbVisibility: true,
                  trackVisibility: true,
                  controller: verticalScrollController,
                  child: SingleChildScrollView(
                    controller: verticalScrollController,
                    scrollDirection: Axis.vertical,
                    child: Scrollbar(
                      thumbVisibility: true,
                      trackVisibility: true,
                      controller: horizontalScrollController,
                      child: SingleChildScrollView(
                        controller: horizontalScrollController,
                        scrollDirection: Axis.horizontal,
                        child: Container(
                          width: contentSize.width,
                          height: contentSize.height,
                          child: GestureDetector(
                            onTapDown: _handleCanvasTapDown,
                            onTap: () {
                              setState(() {
                                _selectedNodeName = null;
                                _selectedConnectionId = null;
                              });
                              _focusNode.requestFocus();
                            },
                            child: RawKeyboardListener(
                                focusNode: _focusNode,
                                autofocus: true,
                                onKey: (event) {
                                  if (event is RawKeyDownEvent && (event.logicalKey == LogicalKeyboardKey.delete ||
                                      event.logicalKey == LogicalKeyboardKey.backspace)) {
                                    if (_selectedNodeName != null) {
                                      _removeNode(_selectedNodeName!);
                                    }
                                  }
                                },
                                child: CustomPaint(
                                  painter: _ConnectionPainter(
                                    connections: connections,
                                    nodes: nodes,
                                    nodeSize: _nodeSize,
                                    selectedConnectionId: _selectedConnectionId,
                                  ),
                                  child: Stack(
                                    children: nodes.entries.map((entry) {
                                      final nodeName = entry.key;
                                      final node = entry.value;
                                      final isSelected = _selectedNodeName == nodeName;
                                      return Positioned(
                                        left: node.position.dx,
                                        top: node.position.dy,
                                        child: GestureDetector(
                                          onTap: () {
                                            setState(() {
                                              _selectedNodeName = nodeName;
                                              _selectedConnectionId = null;
                                            });
                                            _focusNode.requestFocus();
                                          },
                                          onDoubleTap: () => _editNodeText(nodeName),
                                          onSecondaryTapDown: (details) => _showNodeContextMenu(details, nodeName),
                                          child: GostNodeBuilder(
                                            nodeSize: _nodeSize,
                                            isSelected: isSelected,
                                            onResize: (newSize) {
                                              setState(() => _nodeSize = newSize);
                                            },
                                            onPositionChange: (nodeName, newPosition) {
                                              _controller.updateNodePosition(nodeName, newPosition);
                                            },
                                            onResizeStart: () => setState(() => _isResizing = true),
                                            onResizeEnd: () {
                                              setState(() => _isResizing = false);
                                              _applyAutoLayout();
                                            },
                                            nodeName: nodeName,
                                          ).build(node),
                                        ),
                                      );
                                    }).toList(),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ConnectionPainter extends CustomPainter {
  final List<Connection> connections;
  final Map<String, NodeModel> nodes;
  final Size nodeSize;
  final String? selectedConnectionId;

  _ConnectionPainter({
    required this.connections,
    required this.nodes,
    required this.nodeSize,
    this.selectedConnectionId,
  });

  @override
  void paint(Canvas canvas, Size size) {
    for (final conn in connections) {
      final path = buildConnectionPath(conn: conn, nodes: nodes, nodeSize: nodeSize);
      final isSelected = conn.id == selectedConnectionId;
      final paint = Paint()
      ..color = isSelected ? Colors.blue : Colors.black
      ..strokeWidth = isSelected ? 4 : 2
      ..style = PaintingStyle.stroke;
      canvas.drawPath(path, paint);
    }
  }


  @override
  bool shouldRepaint(covariant _ConnectionPainter oldDelegate) {
    return oldDelegate.connections != connections ||
    oldDelegate.nodes != nodes ||
    oldDelegate.nodeSize != nodeSize ||
    oldDelegate.selectedConnectionId != selectedConnectionId;
  }
}
