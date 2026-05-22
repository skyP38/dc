import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'package:collection/collection.dart';
import '../models/flow_models.dart';
import '../factories/node_factory.dart';
import '../widgets/gost_node_builder.dart';
import '../widgets/vertical_toolbar.dart';
import 'package:flutter/services.dart';
import 'dart:ui';
import 'dart:convert';
import 'dart:typed_data';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

String numberToLetter(int n) {
  const alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
  String result = '';
  while (n >= 0) {
    result = alphabet[n % 26] + result;
    n = (n / 26).floor() - 1;
    if (n < 0) break;
  }
  return result;
}

class EditorScreen extends StatefulWidget {
  @override
  State<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends State<EditorScreen> {
  static const Size _defaultNodeSize = Size(160, 80);
  late Size _nodeSize;
  final Map<String, _NodeWidgetData> _nodes = {};
  final List<_ConnectionData> _connections = [];
  String? _selectedNodeName;
  GostNodeData? _selectedPrototype;
  bool _isApplyingLayout = false;
  String? _selectedConnectionId;
  bool _isResizing = false;
  final FocusNode _focusNode = FocusNode();
  bool _showGrid = true;

  final Uuid _uuid = const Uuid();

  @override
  void initState() {
    super.initState();
    _nodeSize = _defaultNodeSize;
    _setupNodes();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  void _setupNodes() {
    final startPos = Offset(_nodeSize.height, _nodeSize.height);
    final startNode = NodeFactory.createNode(
      id: _uuid.v4(),
      data: TerminalBlock('Start'),
      position: startPos,
      // position: const Offset(200, 50),
    );
    _addNode(startNode);

    final endPos = Offset(startPos.dx, startPos.dy + _nodeSize.height + 50);
    final endNode = NodeFactory.createNode(
      id: _uuid.v4(),
      data: TerminalBlock('End'),
      position: endPos
      // position: const Offset(200, 200),
    );
    _addNode(endNode);

    _connections.add(_ConnectionData(
      id: _uuid.v4(),
      sourceNodeName: startNode.name,
      sourcePort: 'out',
      targetNodeName: endNode.name,
      targetPort: 'in',
    ));
    setState(() {});
  }

  void _addNode(NodeModel node) {
    _nodes[node.name] = _NodeWidgetData(
      node: node,
      position: node.position,
    );
  }

  void _removeNode(String nodeName) {
    final removedNode = _nodes[nodeName]?.node;
    if (removedNode == null) return;

    if (removedNode.data is TerminalBlock) {
      final text = removedNode.data.text;
      if (text == 'Start' || text == 'End') {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Нельзя удалить блок Start или End')),
        );
        return;
      }
    }

    final incoming = _connections.where((c) => c.targetNodeName == nodeName).toList();
    final outgoing = _connections.where((c) => c.sourceNodeName == nodeName).toList();
    final bool isLogic = removedNode.data is LogicBlock;

    if (isLogic) {
      // Сбор узлов на ветке "Нет", исключая End
      final Set<String> nodesToRemove = {nodeName};
      final noOutgoing = outgoing.where((c) => c.sourcePort == 'no').toList();
      for (final conn in noOutgoing) {
        _collectSubtreeExcludingEnd(conn.targetNodeName, nodesToRemove);
      }

      // Удаление собранных узлов (кроме самого логического и End)
      for (final n in nodesToRemove) {
        if (n == nodeName) continue;
        final node = _nodes[n]?.node;
        if (node != null && node.data is TerminalBlock && node.data.text == 'End') continue;
        _nodes.remove(n);
      }

      // Формирование финального множества для удаления связей (исключая End)
      final nodesToRemoveFinal = nodesToRemove.where((n) {
        final nd = _nodes[n]?.node;
        return !(nd != null && nd.data is TerminalBlock && nd.data.text == 'End');
      }).toSet();
      nodesToRemoveFinal.add(nodeName); // сам логический блок

      // Удаление связей, где источник или цель входит в nodesToRemoveFinal
      _connections.removeWhere((c) =>
      nodesToRemoveFinal.contains(c.sourceNodeName) ||
      nodesToRemoveFinal.contains(c.targetNodeName));

      // Переподключение входа к выходу 'yes'
      final incomingConn = incoming.isNotEmpty ? incoming.first : null;
      final outgoingYes = outgoing.firstWhereOrNull((c) => c.sourcePort == 'yes');
      if (incomingConn != null && outgoingYes != null && _nodes.containsKey(outgoingYes.targetNodeName)) {
        _connections.add(_ConnectionData(
          id: _uuid.v4(),
          sourceNodeName: incomingConn.sourceNodeName,
          sourcePort: incomingConn.sourcePort,
          targetNodeName: outgoingYes.targetNodeName,
          targetPort: outgoingYes.targetPort,
        ));
      }

      // Удаление логического блока
      _nodes.remove(nodeName);
    } else {
      // Обычный блок – без изменений
      if (incoming.length == 1 && outgoing.length == 1) {
        final inConn = incoming.first;
        final outConn = outgoing.first;
        _connections.add(_ConnectionData(
          id: _uuid.v4(),
          sourceNodeName: inConn.sourceNodeName,
          sourcePort: inConn.sourcePort,
          targetNodeName: outConn.targetNodeName,
          targetPort: outConn.targetPort,
        ));
      }
      _connections.removeWhere((c) => c.sourceNodeName == nodeName || c.targetNodeName == nodeName);
      _nodes.remove(nodeName);
    }

    if (_selectedNodeName == nodeName) _selectedNodeName = null;
    if (_selectedConnectionId != null) _selectedConnectionId = null;

    setState(() {});
    _applyAutoLayout();
  }



  /// Рекурсивно собирает узлы, достижимые из startNode, но не включает блок End
  void _collectSubtreeExcludingEnd(String startNode, Set<String> collected) {
    if (collected.contains(startNode)) return;
    final node = _nodes[startNode]?.node;
    if (node != null && node.data is TerminalBlock && node.data.text == 'End') return;
    collected.add(startNode);
    final children = _connections.where((c) => c.sourceNodeName == startNode).toList();
    for (final child in children) {
      _collectSubtreeExcludingEnd(child.targetNodeName, collected);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Создание контроллера для вертикальной прокрутки
    final verticalScrollController = ScrollController();
    // Для горизонтальной прокрутки
    final horizontalScrollController = ScrollController();

    return Scaffold(
      body: Row(
        children: [
          VerticalToolbar(
            selectedPrototype: _selectedPrototype,
            onSelectPrototype: (p) => setState(() => _selectedPrototype = p),
            onSetNodeSize: _setNodeSize,
            isGridVisible: _showGrid,
            onGridToggle: (value) => setState(() => _showGrid = value),
            onExport: _exportToSvg,
          ),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final contentSize = _getContentSize();
                Widget gridWidget = const SizedBox.shrink();
                if (_showGrid) {
                  final startNodeEntry = _nodes.entries.firstWhereOrNull(
                    (e) => e.value.node.data is TerminalBlock && e.value.node.data.text == 'Start',
                  );
                  if (startNodeEntry != null) {
                    gridWidget = GridWithLabels(
                      canvasSize: contentSize,
                      stepX: _nodeSize.width,
                      stepY: _nodeSize.height,
                      startPosition: startNodeEntry.value.position,
                    );
                  }
                }
                return Scrollbar(
                  thumbVisibility: true,
                  trackVisibility: true,   // всегда показывать дорожку полосы
                  controller: verticalScrollController,
                  child: SingleChildScrollView(
                    controller: verticalScrollController,
                    scrollDirection: Axis.vertical,
                    child: Scrollbar(
                      thumbVisibility: true,
                      trackVisibility: true,   // дорожка для горизонтальной полосы
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
                                onKey: _handleKeyEvent,
                                child: CustomPaint(
                                  painter: _ConnectionPainter(
                                    connections: _connections,
                                    nodes: _nodes,
                                    nodeSize: _nodeSize,
                                    selectedConnectionId: _selectedConnectionId,
                                  ),
                                  child: Stack(
                                    children: [
                                        if (_showGrid) gridWidget,
                                        // Линии соединений
                                        CustomPaint(
                                          painter: _ConnectionPainter(
                                            connections: _connections,
                                            nodes: _nodes,
                                            nodeSize: _nodeSize,
                                            selectedConnectionId: _selectedConnectionId,
                                          ),
                                          child: Stack(
                                            children: _nodes.entries
                                            .map((entry) => _buildNodeWidget(entry.key, entry.value))
                                            .toList(),
                                          ),
                                        ),
                                    ],
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

  // Обработка удаления блока
  void _handleKeyEvent(RawKeyEvent event) {
    if (event is RawKeyDownEvent) {
      if (event.logicalKey == LogicalKeyboardKey.delete ||
        event.logicalKey == LogicalKeyboardKey.backspace) {
        if (_selectedNodeName != null) {
          final node = _nodes[_selectedNodeName!]?.node;
          final isProtected = node?.data is TerminalBlock &&
          (node!.data.text == 'Start' || node.data.text == 'End');
          if (!isProtected) {
            _removeNode(_selectedNodeName!);
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Нельзя удалить блок Start или End')),
            );
          }
        }
        }
    }
  }

  Widget _buildNodeWidget(String nodeName, _NodeWidgetData data) {
    final node = data.node;
    final position = data.position;
    final isSelected = _selectedNodeName == nodeName;

    return Positioned(
      left: position.dx,
      top: position.dy,
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
            setState(() {
              if (_nodes.containsKey(nodeName)) {
                _nodes[nodeName]!.position = newPosition;
              }
            });
          },
          onResizeStart: () => setState(() => _isResizing = true),
          onResizeEnd: () {
            setState(() => _isResizing = false);
            _applyAutoLayout();
          },
          nodeName: nodeName,
        ).build(data.node),
      ),
    );
  }

  void _showNodeContextMenu(TapDownDetails details, String nodeName) {
    final node = _nodes[nodeName]?.node;
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

  void _handleCanvasTapDown(TapDownDetails details) {
    final localPos = details.localPosition;

    _ConnectionData? tappedConnection;
    double minDistance = 15.0;

    for (final conn in _connections) {
      final sourceNode = _nodes[conn.sourceNodeName];
      final targetNode = _nodes[conn.targetNodeName];
      if (sourceNode == null || targetNode == null) continue;

      final path = _getConnectionPath(conn);

      // Разбиение пути на сегменты и поиск минимальное расстояние
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
        // Проверка конечной точки
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
        _insertNodeOnConnection(tappedConnection);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Выберите тип блока на панели слева')),
        );
      }
    }
  }

  double _distanceToLineSegment(Offset point, Offset start, Offset end) {
    final dx = end.dx - start.dx;
    final dy = end.dy - start.dy;
    final lengthSquared = dx * dx + dy * dy;
    if (lengthSquared == 0) return (point - start).distance;

    double t = ((point.dx - start.dx) * dx + (point.dy - start.dy) * dy) / lengthSquared;
    t = t.clamp(0.0, 1.0);
    final projection = Offset(start.dx + t * dx, start.dy + t * dy);
    return (point - projection).distance;
  }

  Path _getConnectionPath(_ConnectionData conn) {
    final source = _nodes[conn.sourceNodeName];
    final target = _nodes[conn.targetNodeName];
    if (source == null || target == null) return Path();

    // Вычисление нижней границы
    double maxBottomY = 0;
    for (final entry in _nodes.entries) {
      final bottom = entry.value.position.dy + _nodeSize.height;
      if (bottom > maxBottomY) maxBottomY = bottom;
    }
    maxBottomY = maxBottomY - _nodeSize.height - 10;
    const double endOffset = 0.0;
    final double endLineY = maxBottomY + endOffset;

    final startPos = source.position;
    final targetPos = target.position;
    final path = Path();

    if (conn.sourcePort == 'no') {
      final start = startPos + Offset(_nodeSize.width, _nodeSize.height / 2);
      final end = targetPos + Offset(_nodeSize.width / 2, 0);
      final targetNode = target.node;
      final isEnd = targetNode.data is TerminalBlock && targetNode.data.text == 'End';

      if (isEnd) {
        // Горизонтальный обход всех блоков между startX+30 и endX
        final sourceRect = Rect.fromLTWH(startPos.dx, startPos.dy, _nodeSize.width, _nodeSize.height);
        double maxObstacleBottom = sourceRect.bottom;
        final double startX = start.dx;
        final double endX = end.dx;
        final double minX = startX + 30;
        final double maxX = endX;

        for (final entry in _nodes.entries) {
          if (entry.key == conn.sourceNodeName || entry.key == conn.targetNodeName) continue;
          final nodeWidget = entry.value;
          final nodeRect = Rect.fromLTWH(
            nodeWidget.position.dx, nodeWidget.position.dy,
            _nodeSize.width, _nodeSize.height,
          );
          final bool overlapX = nodeRect.right >= minX && nodeRect.left <= maxX;
          if (overlapX && nodeRect.top > sourceRect.bottom) {
            if (nodeRect.bottom > maxObstacleBottom) maxObstacleBottom = nodeRect.bottom;
          }
        }
        final double horizontalY = maxObstacleBottom > startPos.dy + _nodeSize.height
        ? maxObstacleBottom + 20
        : startPos.dy + _nodeSize.height + 60;

        final mid1 = Offset(start.dx + 30, start.dy);
        // final mid2 = Offset(mid1.dx, horizontalY);
        final mid2 = Offset(mid1.dx, endLineY);
        final mid3 = Offset(end.dx, mid2.dy);
        path.moveTo(start.dx, start.dy);
        path.lineTo(mid1.dx, mid1.dy);
        path.lineTo(mid2.dx, mid2.dy);
        path.lineTo(mid3.dx, mid3.dy);
        path.lineTo(end.dx, end.dy);
      } else {
        final mid1 = Offset(end.dx, start.dy);
        final mid2 = Offset(mid1.dx, end.dy);
        path.moveTo(start.dx, start.dy);
        path.lineTo(mid1.dx, mid1.dy);
        path.lineTo(mid2.dx, mid2.dy);
        path.lineTo(end.dx, end.dy);
      }
    } else if (conn.sourcePort == 'yes') {
      final start = startPos + Offset(_nodeSize.width / 2, _nodeSize.height);
      final end = targetPos + Offset(_nodeSize.width / 2, 0);
      final targetNode = target.node;
      final isEnd = targetNode.data is TerminalBlock && targetNode.data.text == 'End';

      if (isEnd) {
        // Обход блоков на ветке "Да"
        final sourceRect = Rect.fromLTWH(startPos.dx, startPos.dy, _nodeSize.width, _nodeSize.height);
        double maxObstacleBottom = sourceRect.bottom;
        final double startX = start.dx;
        final double endX = end.dx;
        final double minX = startX;
        final double maxX = endX;

        for (final entry in _nodes.entries) {
          if (entry.key == conn.sourceNodeName || entry.key == conn.targetNodeName) continue;
          final nodeWidget = entry.value;
          final nodeRect = Rect.fromLTWH(
            nodeWidget.position.dx, nodeWidget.position.dy,
            _nodeSize.width, _nodeSize.height,
          );
          final bool overlapX = nodeRect.right >= minX && nodeRect.left <= maxX;
          if (overlapX && nodeRect.top > sourceRect.bottom) {
            if (nodeRect.bottom > maxObstacleBottom) maxObstacleBottom = nodeRect.bottom;
          }
        }
        const double verticalStep = 30.0;
        final double horizontalY = maxObstacleBottom > startPos.dy + _nodeSize.height
        ? maxObstacleBottom + 20
        : startPos.dy + _nodeSize.height + verticalStep;
        // final mid1 = Offset(start.dx, start.dy + verticalStep);
        final mid1 = Offset(start.dx, endLineY);
        // final mid2 = Offset(end.dx, mid1.dy);
        final mid2 = Offset(end.dx, endLineY);
        // final mid2 = Offset(end.dx, endLineY);
        path.moveTo(start.dx, start.dy);
        path.lineTo(mid1.dx, mid1.dy);
        path.lineTo(mid2.dx, mid2.dy);
        path.lineTo(end.dx, end.dy);
      } else {
        path.moveTo(start.dx, start.dy);
        path.lineTo(end.dx, end.dy);
      }
    } else {
      // Обычная связь
      final start = startPos + Offset(_nodeSize.width / 2, _nodeSize.height);
      final end = targetPos + Offset(_nodeSize.width / 2, 0);
      final targetNode = target.node;
      final isEnd = targetNode.data is TerminalBlock && targetNode.data.text == 'End';

      if (isEnd && end.dx != start.dx) {
        final mid1 = Offset(start.dx, start.dy + 20);
        // final mid2 = Offset(end.dx, mid1.dy);
        final mid2 = Offset(mid1.dx, endLineY);
        final mid3 = Offset(end.dx, mid2.dy);
        path.moveTo(start.dx, start.dy);
        path.lineTo(mid1.dx, mid1.dy);
        path.lineTo(mid2.dx, mid2.dy);
        path.lineTo(mid3.dx, mid3.dy);
        path.lineTo(end.dx, end.dy);
      } else {
        path.moveTo(start.dx, start.dy);
        path.lineTo(end.dx, end.dy);
      }
    }
    return path;
  }

  void _insertNodeOnConnection(_ConnectionData connection) {
    final sourceNode = _nodes[connection.sourceNodeName]?.node;
    final targetNode = _nodes[connection.targetNodeName]?.node;
    if (sourceNode == null || targetNode == null) return;

    final prototype = _selectedPrototype!;

    final sourcePos = _nodes[connection.sourceNodeName]!.position;
    final targetPos = _nodes[connection.targetNodeName]!.position;
    final midpoint = Offset(
      (sourcePos.dx + targetPos.dx) / 2,
      (sourcePos.dy + targetPos.dy) / 2,
    );
    final newPos = Offset(midpoint.dx, midpoint.dy);

    final newNode = NodeFactory.createNode(
      id: _uuid.v4(),
      data: prototype,
      position: newPos,
    );
    _addNode(newNode);

    final newSourcePortName = (prototype is LogicBlock) ? 'yes' : 'out';
    _connections.removeWhere((c) => c.id == connection.id);

    // Add connections: source -> newNode, newNode -> target
    _connections.add(_ConnectionData(
      id: _uuid.v4(),
      sourceNodeName: connection.sourceNodeName,
      sourcePort: connection.sourcePort,
      targetNodeName: newNode.name,
      targetPort: 'in',
    ));

    if (prototype is LogicBlock) {
      // Ветка "Да" идёт к исходному целевому узлу
      _connections.add(_ConnectionData(
        id: _uuid.v4(),
        sourceNodeName: newNode.name,
        sourcePort: 'yes',
        targetNodeName: connection.targetNodeName,
        targetPort: connection.targetPort,
      ));

      NodeModel? endNode = _nodes.values
      .map((d) => d.node)
      .firstWhereOrNull((n) => n.data is TerminalBlock && n.data.text == 'End');
      if (endNode == null) {
        final endPos = Offset(newPos.dx + _nodeSize.width + 80, newPos.dy + _nodeSize.height + 30);
        endNode = NodeFactory.createNode(
          id: _uuid.v4(),
          data: TerminalBlock('End'),
          position: endPos,
        );
        _addNode(endNode);
      }

      _connections.add(_ConnectionData(
        id: _uuid.v4(),
        sourceNodeName: newNode.name,
        sourcePort: 'no',
        targetNodeName: connection.targetNodeName,
        targetPort: connection.targetPort,
      ));

    } else {
      // Обычный блок – одна исходящая связь
      _connections.add(_ConnectionData(
        id: _uuid.v4(),
        sourceNodeName: newNode.name,
        sourcePort: (prototype is LogicBlock) ? 'yes' : 'out',
        targetNodeName: connection.targetNodeName,
        targetPort: connection.targetPort,
      ));
    }

    _selectedPrototype = null;
    _selectedConnectionId = null;
    _applyAutoLayout();
  }

  Widget _buildNodeShape(NodeModel node, bool isSelected) {
    return GostNodeBuilder(
      nodeSize: _nodeSize,
      isSelected: isSelected,
      onResize: (newSize) {
        setState(() => _nodeSize = newSize);
        _applyAutoLayout();
      },
      onPositionChange: (nodeName, newPosition) {
        setState(() {
          if (_nodes.containsKey(nodeName)) {
            _nodes[nodeName]!.position = newPosition;
          }
        });
      },
      nodeName: node.name,
    ).build(node);
  }

  void _createConnection(String srcNode, String srcPort, String tgtNode, String tgtPort) {
    if (_connections.any((c) =>
      c.sourceNodeName == srcNode &&
      c.sourcePort == srcPort &&
      c.targetNodeName == tgtNode &&
      c.targetPort == tgtPort)) return;

    setState(() {
      _connections.add(_ConnectionData(
        id: _uuid.v4(),
        sourceNodeName: srcNode,
        sourcePort: srcPort,
        targetNodeName: tgtNode,
        targetPort: tgtPort,
      ));
    });
    _applyAutoLayout();
  }

  void _editNodeText(String nodeName) async {
    final nodeData = _nodes[nodeName];
    if (nodeData == null) return;
    final currentText = nodeData.node.data.text;
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
      setState(() {
        _nodes[nodeName]!.node.data = nodeData.node.data.copyWith(text: newText);
      });
      _applyAutoLayout();
    }
  }

  void _applyAutoLayout() {
    if (_isApplyingLayout || _isResizing) return;
    _isApplyingLayout = true;

    // Поиск стартового узла
    final startNodeEntry = _nodes.entries.firstWhereOrNull(
      (e) => e.value.node.data is TerminalBlock && e.value.node.data.text == 'Start',
    );
    if (startNodeEntry == null) {
      _isApplyingLayout = false;
      return;
    }
    final startName = startNodeEntry.key;
    final startPos = startNodeEntry.value.position;
    const double xOffsetStart = 0;

    // Построение исходящих связей для каждого узла
    final Map<String, List<_ConnectionData>> outgoing = {};
    for (final conn in _connections) {
      outgoing.putIfAbsent(conn.sourceNodeName, () => []).add(conn);
    }

    // Вычисление рангов (BFS с накоплением максимальной глубины)
    final Map<String, int> ranks = {};
    final queue = <String>[];
    ranks[startName] = 0;
    queue.add(startName);
    while (queue.isNotEmpty) {
      final current = queue.removeAt(0);
      final currentRank = ranks[current]!;
      for (final conn in outgoing[current] ?? []) {
        final target = conn.targetNodeName;
        final newRank = currentRank + 1;
        if ((ranks[target] ?? -1) < newRank) {
          ranks[target] = newRank;
          queue.add(target);
        }
      }
    }

    // Рекурсивное определение X-координат
    final Map<String, double> xPositions = {};
    double _layoutX(String nodeName, double currentX, Set<String> visited) {
      if (visited.contains(nodeName)) return currentX;
      visited.add(nodeName);
      if (!xPositions.containsKey(nodeName)) {
        xPositions[nodeName] = currentX;
      } else {
        currentX = xPositions[nodeName]!;
      }

      final children = outgoing[nodeName] ?? [];
      if (children.isEmpty) return currentX;

      final node = _nodes[nodeName]?.node;
      final isLogic = node?.data is LogicBlock;

      if (isLogic && children.length >= 2) {
        _ConnectionData? yesConn, noConn;
        for (final c in children) {
          if (c.sourcePort == 'yes') yesConn = c;
          if (c.sourcePort == 'no') noConn = c;
        }
        if (yesConn != null) {
          _layoutX(yesConn.targetNodeName, currentX, visited);
        }
        if (noConn != null) {
          // Сдвиг для ветки "Нет"
          final targetNode = _nodes[noConn.targetNodeName]?.node;
          final isEnd = targetNode != null && targetNode.data is TerminalBlock && targetNode.data.text == 'End';
          const double noOffset = 300;
          final offset = isEnd ? 0 : noOffset;
          _layoutX(noConn.targetNodeName, currentX + offset, visited);
        }
      } else {
        // Обычный блок – все дети на той же X
        for (final conn in children) {
          _layoutX(conn.targetNodeName, currentX, visited);
        }
      }
      return currentX;
    }

    final visited = <String>{};
    _layoutX(startName, startPos.dx + xOffsetStart, visited);

    // Коррекция перекрытий на каждом уровне
    final Map<int, List<String>> nodesByRank = {};
    for (final entry in ranks.entries) {
      nodesByRank.putIfAbsent(entry.value, () => []).add(entry.key);
    }
    const double gap = 50.0;
    for (final rank in nodesByRank.keys) {
      final nodeNames = nodesByRank[rank]!;
      nodeNames.sort((a, b) => xPositions[a]!.compareTo(xPositions[b]!));
      double nextMinX = startPos.dx;
      for (final name in nodeNames) {
        double currentX = xPositions[name]!;
        if (currentX < nextMinX) {
          currentX = nextMinX;
          xPositions[name] = currentX;
        }
        nextMinX = currentX + _nodeSize.width + gap;
      }
    }

    // Вычисление Y-координат
    final stepY = _nodeSize.height + 40.0;
    final double startY = startPos.dy;
    // final stepY = _nodeSize.height + 30.0;
    final Map<String, Offset> newPositions = {};
    for (final entry in ranks.entries) {
      final name = entry.key;
      final rank = entry.value;
      final x = xPositions[name] ?? startPos.dx;
      final y = startY + rank * stepY;
      // final y = startPos.dy + rank * stepY;
      newPositions[name] = Offset(x, y);
    }

    // Обработка конечного блока End
    final endNodeEntry = _nodes.entries.firstWhereOrNull(
      (e) => e.value.node.data is TerminalBlock && e.value.node.data.text == 'End',
    );
    if (endNodeEntry != null) {
      final endName = endNodeEntry.key;
      final maxRank = ranks.values.isEmpty ? 0 : ranks.values.reduce((a, b) => a > b ? a : b);
      final endY = startPos.dy + maxRank * stepY;
      // final endY = startPos.dy + (maxRank + 1) * stepY;
      newPositions[endName] = Offset(startPos.dx, endY);
    }

    setState(() {
      for (final entry in newPositions.entries) {
        if (_nodes.containsKey(entry.key)) {
          _nodes[entry.key]!.position = entry.value;
        }
      }
    });

    _isApplyingLayout = false;
  }

  void _setNodeSize(Size newSize) {
    if (_nodeSize == newSize) return;
    _nodeSize = newSize;
    _applyAutoLayout();
  }

  Size _getContentSize() {
    if (_nodes.isEmpty) return const Size(1500, 1000);
    double minX = double.infinity, minY = double.infinity;
    double maxX = -double.infinity, maxY = -double.infinity;
    for (final data in _nodes.values) {
      final pos = data.position;
      minX = minX < pos.dx ? minX : pos.dx;
      minY = minY < pos.dy ? minY : pos.dy;
      maxX = maxX > pos.dx + _nodeSize.width ? maxX : pos.dx + _nodeSize.width;
      maxY = maxY > pos.dy + _nodeSize.height ? maxY : pos.dy + _nodeSize.height;
    }
    const padding = 400.0;
    double width = maxX - minX + padding;
    double height = maxY - minY + padding;
    // Минимальные размеры, чтобы полосы прокрутки точно появились
    width = width < 1200 ? 1200 : width;
    height = height < 800 ? 800 : height;
    return Size(width, height);
  }


  Future<void> _exportToSvg() async {
    if (_nodes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Нет элементов для экспорта')),
      );
      return;
    }

    // Генерация SVG строки
    final buffer = StringBuffer();
    buffer.writeln('<?xml version="1.0" encoding="utf-8"?>');
    buffer.writeln('<svg xmlns="http://www.w3.org/2000/svg" '
    'width="${_getContentSize().width}" height="${_getContentSize().height}">');

    // Фон
    buffer.writeln('<rect width="100%" height="100%" fill="white"/>');

    // Сетка, если включена
    if (_showGrid) {
      final startNodeEntry = _nodes.entries.firstWhereOrNull(
        (e) => e.value.node.data is TerminalBlock && e.value.node.data.text == 'Start',
      );
      if (startNodeEntry != null) {
        final startPos = startNodeEntry.value.position;
        final stepX = _nodeSize.width;
        final stepY = _nodeSize.height;
        final contentSize = _getContentSize();
        final gridSvg = _buildGridSvg(contentSize, startPos, stepX, stepY);
        buffer.write(gridSvg);
      }
    }

    // Рисовка связей
    for (final conn in _connections) {
      final source = _nodes[conn.sourceNodeName];
      final target = _nodes[conn.targetNodeName];
      if (source == null || target == null) continue;

      final path = _getConnectionPath(conn);
      // Преобразоваение Path в строку SVG d
      final d = _pathToSvgPath(path);
      if (d.isNotEmpty) {
        buffer.writeln('<path d="$d" stroke="black" stroke-width="2" fill="none" />');
      }
    }

    // Рисовка узлов
    for (final entry in _nodes.entries) {
      final node = entry.value.node;
      final pos = entry.value.position;
      final nodeSvg = _buildNodeSvg(node, pos, _nodeSize);
      buffer.writeln(nodeSvg);
    }

    buffer.writeln('</svg>');

    try {
      // Директория для сохранения
      final directory = await getDownloadsDirectory();
      if (directory == null) {
        throw Exception('Не удалось получить директорию для сохранения');
      }
      final fileName = 'diagram_${DateTime.now().millisecondsSinceEpoch}.svg';
      final file = File('${directory.path}/$fileName');
      await file.writeAsString(buffer.toString());

      // Показываем сообщение об успешном сохранении
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Схема сохранена: ${file.path}')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка экспорта: $e')),
      );
    }
  }

  // Path в строку SVG
  String _pathToSvgPath(Path path) {
    final List<String> parts = [];
    for (final metric in path.computeMetrics()) {
      for (double dist = 0; dist <= metric.length; dist += 1) {
        final tangent = metric.getTangentForOffset(dist);
        if (tangent != null) {
          final point = tangent.position;
          if (dist == 0) {
            parts.add('M ${point.dx} ${point.dy}');
          } else {
            parts.add('L ${point.dx} ${point.dy}');
          }
        }
      }
    }
    return parts.join(' ');
  }

  String _buildNodeSvg(NodeModel node, Offset pos, Size size) {
    final x = pos.dx;
    final y = pos.dy;
    final w = size.width;
    final h = size.height;
    final text = node.data.text;

    String shapeSvg;
    switch (node.data) {
      case TerminalBlock():
        // Терминальный блок
        final rx = 40.0;
        shapeSvg = '<rect x="$x" y="$y" width="$w" height="$h" rx="$rx" ry="$rx" stroke="black" stroke-width="2" fill="white"/>';
        break;
      case ProcessBlock():
        shapeSvg = '<rect x="$x" y="$y" width="$w" height="$h" stroke="black" stroke-width="2" fill="white"/>';
        break;
      case LogicBlock():
        // Ромб
        final cx = x + w/2;
        final cy = y + h/2;
        final points = '${cx},${y} ${x+w},${cy} ${cx},${y+h} ${x},${cy}';
        shapeSvg = '<polygon points="$points" stroke="black" stroke-width="2" fill="white"/>';
        break;
      case IOBlock():
        // Параллелограмм
        final skew = 20.0;
        final points = '${x+skew},${y} ${x+w},${y} ${x+w-skew},${y+h} ${x},${y+h}';
        shapeSvg = '<polygon points="$points" stroke="black" stroke-width="2" fill="white"/>';
        break;
      case SubroutineBlock():
        // 2 вертикальные линии внутри прямоугольника
        shapeSvg = '<rect x="$x" y="$y" width="$w" height="$h" stroke="black" stroke-width="2" fill="white"/>'
        '<line x1="${x+10}" y1="$y" x2="${x+10}" y2="${y+h}" stroke="black" stroke-width="2"/>'
        '<line x1="${x+w-10}" y1="$y" x2="${x+w-10}" y2="${y+h}" stroke="black" stroke-width="2"/>';
        break;
      default:
        shapeSvg = '<rect x="$x" y="$y" width="$w" height="$h" stroke="black" stroke-width="2" fill="white"/>';
    }

    // Текст
    final textSvg = '<text x="${x + w/2}" y="${y + h/2}" text-anchor="middle" dominant-baseline="middle" '
    'font-family="Arial" font-size="14" fill="black">${_escapeXml(text)}</text>';

    return shapeSvg + textSvg;
  }

  String _escapeXml(String text) {
    return text.replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;')
    .replaceAll("'", '&apos;');
  }

  String _buildGridSvg(Size canvasSize, Offset startPosition, double stepX, double stepY) {
    final buffer = StringBuffer();
    const textStyle = 'font-family="Arial" font-size="18" fill="#666666"';

    // Подписи столбцов (цифры) сверху
    int firstCol = ((startPosition.dx) / stepX).floor();
    int lastCol = ((canvasSize.width - startPosition.dx) / stepX).ceil();
    for (int col = firstCol; col <= lastCol; col++) {
      double x = (col + 1) * stepX;
      if (x < 0 || x > canvasSize.width) continue;
      final number = col + 1;
      buffer.writeln('<text x="$x" y="20" text-anchor="middle" $textStyle>$number</text>');
    }

    // Подписи строк (буквы) слева
    final double stepYgrid = stepY! + 40.0;
    final double startCenterY = startPosition.dy + stepY! / 2;
    int firstRow = ((0 - startCenterY) / stepY).floor();
    int lastRow = ((canvasSize.height - startCenterY) / stepY).ceil();
    for (int row = firstRow; row <= lastRow; row++) {
      double y = startCenterY + row * stepYgrid;
      if (y < 0 || y > canvasSize.height) continue;
      String letter = numberToLetter(row);
      buffer.writeln('<text x="20" y="$y" text-anchor="middle" dominant-baseline="middle" $textStyle>$letter</text>');
    }

    return buffer.toString();
  }



}

class _NodeWidgetData {
  NodeModel node;
  Offset position;
  _NodeWidgetData({required this.node, required this.position});
}

class _ConnectionData {
  final String? id;
  final String sourceNodeName;
  final String sourcePort;
  final String targetNodeName;
  final String targetPort;
  _ConnectionData({
    this.id,
    required this.sourceNodeName,
    required this.sourcePort,
    required this.targetNodeName,
    required this.targetPort,
  });
}

class _ConnectionDragData {
  final String sourceNodeName;
  final String sourcePort;
  _ConnectionDragData({required this.sourceNodeName, required this.sourcePort});
}

class _ConnectionPainter extends CustomPainter {
  final List<_ConnectionData> connections;
  final Map<String, _NodeWidgetData> nodes;
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
    // Поиск нижней границы всех блоков
    double maxBottomY = 0;
    for (final entry in nodes.entries) {
      final bottom = entry.value.position.dy + nodeSize.height;
      if (bottom > maxBottomY) maxBottomY = bottom;
    }
    maxBottomY = maxBottomY - nodeSize.height - 10;
    const double endOffset = 0.0;
    final double endLineY = maxBottomY + endOffset;


    for (final conn in connections) {
      final source = nodes[conn.sourceNodeName];
      final target = nodes[conn.targetNodeName];
      if (source == null || target == null) continue;

      final isSelected = conn.id != null && conn.id == selectedConnectionId;
      final paint = Paint()
      ..color = isSelected ? Colors.blue : Colors.black
      ..strokeWidth = isSelected ? 4 : 2
      ..style = PaintingStyle.stroke;

      if (conn.sourcePort == 'no') {
        final start = source.position + Offset(nodeSize.width, nodeSize.height / 2);
        final end = target.position + Offset(nodeSize.width / 2, 0);
        final targetNode = nodes[conn.targetNodeName]?.node;
        final isEnd = targetNode != null && targetNode.data is TerminalBlock && targetNode.data.text == 'End';

        if (isEnd) {

          final mid1 = Offset(start.dx + 30, start.dy);
          final mid2 = Offset(mid1.dx, endLineY);
          final mid3 = Offset(end.dx, mid2.dy);
          final path = Path()
          ..moveTo(start.dx, start.dy)
          ..lineTo(mid1.dx, mid1.dy)
          ..lineTo(mid2.dx, mid2.dy)
          ..lineTo(mid3.dx, mid3.dy)
          ..lineTo(end.dx, end.dy);
          canvas.drawPath(path, paint);
        } else {
          // вправо → вниз → влево
          final mid1 = Offset(end.dx, start.dy);
          final mid2 = Offset(mid1.dx, end.dy);
          final path = Path()
          ..moveTo(start.dx, start.dy)
          ..lineTo(mid1.dx, mid1.dy)
          ..lineTo(mid2.dx, mid2.dy)
          ..lineTo(end.dx, end.dy);
          canvas.drawPath(path, paint);
          print("no noend");
        }
      } else if (conn.sourcePort == 'yes') {
        final start = source.position + Offset(nodeSize.width / 2, nodeSize.height);
        final end = target.position + Offset(nodeSize.width / 2, 0);
        final targetNode = nodes[conn.targetNodeName]?.node;
        final isEnd = targetNode != null && targetNode.data is TerminalBlock && targetNode.data.text == 'End';
        print(end.dx);
        print(start.dx);
        if (isEnd && end.dx != start.dx) {
          const double verticalStep = 20.0;
          // final mid1 = Offset(start.dx, start.dy + verticalStep);
          final mid1 = Offset(start.dx, endLineY);
          // final mid2 = Offset(end.dx, endLineY);
          final mid2 = Offset(end.dx, endLineY);
          // final mid2 = Offset(end.dx, mid1.dy);

          final path = Path()
          ..moveTo(start.dx, start.dy)
          ..lineTo(mid1.dx, mid1.dy)
          ..lineTo(mid2.dx, mid2.dy)
          ..lineTo(end.dx, end.dy);
          canvas.drawPath(path, paint);
          print("yes");
        } else if (isEnd) {
          canvas.drawLine(start, end, paint);
        } else {
          // вправо -> вниз -> влево
          final sourcePos = source.position + Offset(nodeSize.width / 2, nodeSize.height);
          final targetPos = target.position + Offset(nodeSize.width / 2, 0);
          canvas.drawLine(sourcePos, targetPos, paint);
        }
      } else {
        final start = source.position + Offset(nodeSize.width / 2, nodeSize.height);
        final end = target.position + Offset(nodeSize.width / 2, 0);
        final targetNode = nodes[conn.targetNodeName]?.node;
        final isEnd = targetNode != null && targetNode.data is TerminalBlock && targetNode.data.text == 'End';

        if (isEnd && end.dx != start.dx) {
          // Путь для End: вниз -> влево -> вниз
          final mid1 = Offset(start.dx, start.dy + 20);
          final mid2 = Offset(mid1.dx, endLineY);
          final mid3 = Offset(end.dx, mid2.dy);
          // final mid2 = Offset(end.dx, mid1.dy);
          final path = Path()
          ..moveTo(start.dx, start.dy)
          ..lineTo(mid1.dx, mid1.dy)
          ..lineTo(mid2.dx, mid2.dy)
          ..lineTo(mid3.dx, mid3.dy)
          ..lineTo(end.dx, end.dy);
          canvas.drawPath(path, paint);
        } else {
          final sourcePos = source.position + Offset(nodeSize.width / 2, nodeSize.height);
          final targetPos = target.position + Offset(nodeSize.width / 2, 0);
          canvas.drawLine(sourcePos, targetPos, paint);
        }
      }
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

// Виджет, рисующий буквы строк (слева) и цифры столбцов (сверху)
class GridWithLabels extends StatelessWidget {
  final Size canvasSize;
  final double stepX;
  final double stepY;
  final Offset? startPosition; // позиция блока Start

  const GridWithLabels({
    super.key,
    required this.canvasSize,
    required this.stepX,
    required this.stepY,
    required this.startPosition,
  });

  @override
  Widget build(BuildContext context) {
    if (startPosition == null) return const SizedBox.shrink();
    return CustomPaint(
      size: canvasSize,
      painter: _GridLabelsPainter(
        stepX: stepX,
        stepY: stepY,
        startPosition: startPosition!,
      ),
    );
  }
}

class _GridLabelsPainter extends CustomPainter {
  final double? stepX;
  final double? stepY;
  final Offset startPosition;

  _GridLabelsPainter({
    required this.stepX,
    required this.stepY,
    required this.startPosition,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (stepX == null || stepY == null) return;

    final textStyle = TextStyle(
      color: Colors.grey.shade700,
      fontSize: 18,
      fontWeight: FontWeight.w500,
    );

    // Подписи столбцов (цифры) сверху
    int firstCol = ((startPosition.dx) / stepX!).floor();
    int lastCol = ((size.width - startPosition.dx) / stepX!).ceil();
    for (int col = firstCol; col <= lastCol; col++) {

      double x = (col + 1) * stepX!;

      if (x < 0 || x > size.width) continue;
      final number = col + 1;
      final textSpan = TextSpan(text: '$number', style: textStyle);
      final textPainter = TextPainter(text: textSpan, textDirection: TextDirection.ltr);
      textPainter.layout();
      textPainter.paint(canvas, Offset(x, 2));
    }

    // Подписи строк (буквы) слева
    final double stepYgrid = stepY! + 40.0;
    final double startCenterY = startPosition.dy + stepY! / 2;
    int firstRow = ((0 - startCenterY) / stepY!).floor();
    int lastRow = ((size.height - startCenterY) / stepY!).ceil();
    for (int row = firstRow; row <= lastRow; row++) {
      // double y = startPosition.dy + row * stepY! + stepY! / 2;
      // double y = (row * 1.5) * stepY!;
      double y = startCenterY + row * stepYgrid;
      print(y);
      if (y < 0 || y > size.height) continue;
      String letter = numberToLetter(row);
      final textSpan = TextSpan(text: letter, style: textStyle);
      final textPainter = TextPainter(text: textSpan, textDirection: TextDirection.ltr);
      textPainter.layout();
      // textPainter.paint(canvas, Offset(2, y));
      textPainter.paint(canvas, Offset(2, y - textPainter.height / 2));

    }
  }



  @override
  bool shouldRepaint(covariant _GridLabelsPainter oldDelegate) {
    return oldDelegate.stepX != stepX || oldDelegate.stepY != stepY || oldDelegate.startPosition != startPosition;
  }
}
