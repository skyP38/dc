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
import 'dart:math' as math;


import '../models/editor_models.dart';
import '../painters/connection_painter.dart';
import '../painters/selection_painter.dart';
import '../painters/grid_labels_painter.dart';


import 'dart:convert';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

import '../models/editor_state.dart';


class EditorScreen extends StatefulWidget {
  @override
  State<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends State<EditorScreen> {
  static const Size _defaultNodeSize = Size(160, 80);
  late Size _nodeSize;


  final Map<String, NodeWidgetData> _nodes = {};
  final List<ConnectionData> _connections = [];

  Set<String> _selectedNodeNames = {};
  Offset? _selectionStart;
  Offset? _selectionEnd;
  bool _isSelecting = false;
  bool _isSelectingFromEmpty = false;
  List<InsertionPoint> _insertionPoints = [];

  GostNodeData? _selectedPrototype;
  bool _isApplyingLayout = false;
  String? _selectedConnectionId;
  bool _isResizing = false;
  final FocusNode _focusNode = FocusNode();
  bool _showGrid = true;

  double _scale = 1.0;
  static const double _minScale = 0.5;
  static const double _maxScale = 3.0;

  bool _isToolbarVisible = true;

  final Uuid _uuid = const Uuid();


  static const int _maxHistorySize = 50;
  final List<EditorSnapshot> _undoStack = [];
  final List<EditorSnapshot> _redoStack = [];
  int _currentSnapshotIndex = -1; // -1 значит не синхронизировано с текущим состоянием
  bool _isUndoRedoOperation = false;

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

    _connections.add(ConnectionData(
      id: _uuid.v4(),
      sourceNodeName: startNode.name,
      sourcePort: 'out',
      targetNodeName: endNode.name,
      targetPort: 'in',
    ));
    setState(() {});


    _updateInsertionPoints();
  }

  void _addNode(NodeModel node) {
     // _pushState();

    _nodes[node.name] = NodeWidgetData(
      node: node,
      position: node.position,
    );

    _updateInsertionPoints();
  }

  void _removeNode(String nodeName) {
    _pushState();


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
    final bool isFor = removedNode.data is ForBlock;

    if (isLogic) {
      // Найти входную связь
      final incomingConn = incoming.isNotEmpty ? incoming.first : null;
      // Найти выходную связь 'yes'
      final outgoingYes = outgoing.firstWhereOrNull((c) => c.sourcePort == 'yes');
      // Найти выходную связь 'no'
      final outgoingNo = outgoing.firstWhereOrNull((c) => c.sourcePort == 'no');

      // Сбор узлов на ветке "Нет", исключая End
      final Set<String> nodesToRemove = {};
      if (outgoingNo != null) {
        _collectSubtreeExcludingEnd(outgoingNo.targetNodeName, nodesToRemove);
      }

      // Удаление собранных узлов (кроме самого логического и End)
      for (final n in nodesToRemove) {
        if (n == nodeName) continue;
        final node = _nodes[n]?.node;
        if (node != null && node.data is TerminalBlock && node.data.text == 'End') continue;
        _nodes.remove(n);
      }

      // Удалить все связи, где источник или цель входит в удаляемое поддерево
      _connections.removeWhere((c) =>
      nodesToRemove.contains(c.sourceNodeName) ||
      nodesToRemove.contains(c.targetNodeName));

      // Удалить связи, связанные с текущим логическим блоком
      _connections.removeWhere((c) =>
      c.sourceNodeName == nodeName || c.targetNodeName == nodeName);

      if (incomingConn != null && outgoingYes != null && _nodes.containsKey(outgoingYes.targetNodeName)) {
        _connections.add(ConnectionData(
          id: _uuid.v4(),
          sourceNodeName: incomingConn.sourceNodeName,
          sourcePort: incomingConn.sourcePort,
          targetNodeName: outgoingYes.targetNodeName,
          targetPort: outgoingYes.targetPort,
        ));
      }

      // Удаление логического блока
      _nodes.remove(nodeName);
    } else if (isFor) {
      final incomingConn = incoming.isNotEmpty ? incoming.first : null;
      final outgoingExit = outgoing.firstWhereOrNull((c) => c.sourcePort == 'exit');
      final outgoingBody = outgoing.firstWhereOrNull((c) => c.sourcePort == 'body');

      final Set<String> nodesToRemove = {};
      if (outgoingBody != null) {
        _collectSubtreeExcludingEnd(outgoingBody.targetNodeName, nodesToRemove);
      }

      // Удаляем узлы поддерева body (кроме End)
      for (final n in nodesToRemove) {
        if (n == nodeName) continue;
        final node = _nodes[n]?.node;
        if (node != null && node.data is TerminalBlock && node.data.text == 'End') continue;
        _nodes.remove(n);
      }

      // Удаляем все связи, где источник или цель входят в nodesToRemove
      _connections.removeWhere((c) =>
      nodesToRemove.contains(c.sourceNodeName) ||
      nodesToRemove.contains(c.targetNodeName));

      // Удаляем связи, связанные с текущим блоком For
      _connections.removeWhere((c) =>
      c.sourceNodeName == nodeName || c.targetNodeName == nodeName);

      // Переподключаем вход к выходу exit
      if (incomingConn != null && outgoingExit != null && _nodes.containsKey(outgoingExit.targetNodeName)) {
        _connections.add(ConnectionData(
          id: _uuid.v4(),
          sourceNodeName: incomingConn.sourceNodeName,
          sourcePort: incomingConn.sourcePort,
          targetNodeName: outgoingExit.targetNodeName,
          targetPort: outgoingExit.targetPort,
        ));
      }

      _nodes.remove(nodeName);
    } else {
      // Обычный блок – без изменений
      if (incoming.length == 1 && outgoing.length == 1) {
        final inConn = incoming.first;
        final outConn = outgoing.first;
        _connections.add(ConnectionData(
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

    // if (_selectedNodeName == nodeName) _selectedNodeName = null;
    if (_selectedNodeNames.contains(nodeName)) _selectedNodeNames.remove(nodeName);
    if (_selectedConnectionId != null) _selectedConnectionId = null;

    setState(() {});
    _applyAutoLayout();

    _updateInsertionPoints();
  }

  EditorSnapshot _captureSnapshot() {
    final nodesList = _nodes.entries.map((e) => SerializableNode.fromNode(e.value.node)).toList();
    final connectionsList = _connections.map((c) => SerializableConnection.fromConnection(c)).toList();
    return EditorSnapshot(
      nodes: nodesList,
      connections: connectionsList,
      nodeWidth: _nodeSize.width,
      nodeHeight: _nodeSize.height,
      showGrid: _showGrid,
      scale: _scale,
      isToolbarVisible: _isToolbarVisible,
    );
  }

  void _restoreSnapshot(EditorSnapshot snapshot) {
    _isUndoRedoOperation = true;

    // Восстановление узлов
    final newNodes = <String, NodeWidgetData>{};
    for (final sn in snapshot.nodes) {
      final node = sn.toNode();
      newNodes[node.name] = NodeWidgetData(node: node, position: node.position);
    }
    _nodes.clear();
    _nodes.addAll(newNodes);

    // Восстановление связей
    _connections.clear();
    _connections.addAll(snapshot.connections.map((c) => c.toConnection()));

    // Восстановление настроек
    _nodeSize = Size(snapshot.nodeWidth, snapshot.nodeHeight);
    _showGrid = snapshot.showGrid;
    _scale = snapshot.scale;
    _isToolbarVisible = snapshot.isToolbarVisible;

    // Сброс выделений
    _selectedNodeNames.clear();
    _selectedConnectionId = null;
    _selectionStart = null;
    _selectionEnd = null;
    _isSelecting = false;

    setState(() {
      // принудительная перерисовка
    });

    _applyAutoLayout();
    _updateInsertionPoints();
    _isUndoRedoOperation = false;
  }

  void _pushState() {
    if (_isUndoRedoOperation) return;
    final snapshot = _captureSnapshot();
    _undoStack.add(snapshot);
    if (_undoStack.length > _maxHistorySize) _undoStack.removeAt(0);
    _redoStack.clear();
  }

  void _undo() {
    if (_undoStack.isEmpty) return;
    final previous = _undoStack.removeLast();
    // сохранить текущее состояние в redo
    _redoStack.add(_captureSnapshot());
    if (_redoStack.length > _maxHistorySize) _redoStack.removeAt(0);
    _restoreSnapshot(previous);
  }

  void _redo() {
    if (_redoStack.isEmpty) return;
    final next = _redoStack.removeLast();
    _undoStack.add(_captureSnapshot());
    if (_undoStack.length > _maxHistorySize) _undoStack.removeAt(0);
    _restoreSnapshot(next);
  }


  double _getMaxBottomOfBodySubtree(String forNodeName) {
    // Найти корень тела (узел, подключённый к порту 'body')
    String? bodyRoot;
    for (final conn in _connections) {
      if (conn.sourceNodeName == forNodeName && conn.sourcePort == 'body') {
        bodyRoot = conn.targetNodeName;
        break;
      }
    }
    if (bodyRoot == null) return double.negativeInfinity;

    final Set<String> subtree = {};
    _collectSubtreeExcludingEnd(bodyRoot, subtree);
    double maxBottom = 0;
    for (final nodeName in subtree) {
      final nodeData = _nodes[nodeName];
      if (nodeData != null) {
        final bottom = nodeData.position.dy + _nodeSize.height;
        if (bottom > maxBottom) maxBottom = bottom;
      }
    }
    return maxBottom;
  }

  Future<void> _saveToJson() async {
    final snapshot = _captureSnapshot();
    final json = jsonEncode(snapshot.toJson());
    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/diagram.json');
    await file.writeAsString(json);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Схема сохранена: ${file.path}')),
    );
  }

  Future<void> _loadFromJson() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/diagram.json');
      if (!await file.exists()) throw Exception('Файл не найден');
      final jsonString = await file.readAsString();
      final Map<String, dynamic> jsonMap = jsonDecode(jsonString);
      final snapshot = EditorSnapshot.fromJson(jsonMap);
      _restoreSnapshot(snapshot);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Схема загружена')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка загрузки: $e')),
      );
    }
  }



  // Рекурсивно собирает узлы, достижимые из startNode, но не включает блок End
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
      body: Stack(
        children: [
          if (_isToolbarVisible)
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              child: RepaintBoundary(
                child: SizedBox(
                  width: 200,
                  child: VerticalToolbar(
                    selectedPrototype: _selectedPrototype,
                    onSelectPrototype: (p) => setState(() => _selectedPrototype = p),
                    onSetNodeSize: _setNodeSize,
                    isGridVisible: _showGrid,
                    onGridToggle: (value) => setState(() => _showGrid = value),
                    onExport: _exportToSvg,
                    onUndo: _undo,
                    onRedo: _redo,
                    onSave: _saveToJson,
                    onLoad: _loadFromJson,
                  ),
                ),
              ),
            ),

            Positioned(
              top: 18,
              left: _isToolbarVisible ? 200 - 40 : 8,
              child: FloatingActionButton.small(
                heroTag: null,
                onPressed: () {
                  setState(() {
                    _isToolbarVisible = !_isToolbarVisible;
                  });
                },
                child: Icon(_isToolbarVisible ? Icons.chevron_left : Icons.chevron_right),
              ),
            ),

          Row(
            children: [
              SizedBox(width: _isToolbarVisible ? 200 : 40),
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
                                  child: Listener(
                                    onPointerSignal: (event) {
                                      final isCtrl = RawKeyboard.instance.keysPressed.contains(LogicalKeyboardKey.controlLeft) ||
                                        RawKeyboard.instance.keysPressed.contains(LogicalKeyboardKey.controlRight);
                                      if (isCtrl) {
                                        try {
                                          final scrollDelta = (event as dynamic).scrollDelta.dy;
                                          if (scrollDelta != null) {
                                            setState(() {
                                              _scale = (_scale + scrollDelta * -0.01).clamp(_minScale, _maxScale);
                                            });
                                          }
                                        } catch (e) {
                                          // Игноририрование событий, не являющихся прокруткой
                                        }
                                      }
                                    },
                                  // width: contentSize.width,
                                  // height: contentSize.height,
                                  child: Transform(
                                    transform: Matrix4.diagonal3Values(_scale, _scale, 1.0),
                                    child: GestureDetector(
                                      onTapDown: _handleCanvasTapDown,
                                      onTap: () {
                                        setState(() {
                                          // _selectedNodeName = null;
                                          _selectedNodeNames.clear();
                                          _selectedConnectionId = null;
                                          _selectionStart = null;
                                          _selectionEnd = null;
                                          _isSelecting = false;
                                        });
                                        _focusNode.requestFocus();
                                      },
                                      onPanStart: (details) {
                                        // Начинаем выделение, только если касание было по пустой области
                                        if (!_isSelectingFromEmpty) return;
                                        setState(() {
                                          _isSelecting = true;
                                          _selectionStart = details.localPosition;
                                          _selectionEnd = details.localPosition;
                                        });
                                      },
                                      onPanUpdate: (details) {
                                        if (!_isSelecting) return;
                                        setState(() {
                                          _selectionEnd = details.localPosition;
                                        });
                                      },
                                      onPanEnd: (details) {
                                        if (!_isSelecting) return;
                                        final rect = Rect.fromPoints(_selectionStart!, _selectionEnd!);
                                        // Выделить все блоки, пересекающиеся с rect
                                        final newSelection = <String>{};
                                        for (final entry in _nodes.entries) {
                                          final nodePos = entry.value.position;
                                          final nodeRect = Rect.fromLTWH(nodePos.dx, nodePos.dy, _nodeSize.width, _nodeSize.height);
                                          if (rect.overlaps(nodeRect)) {
                                            newSelection.add(entry.key);
                                          }
                                        }
                                        setState(() {
                                          _selectedNodeNames = newSelection;
                                          _selectionStart = null;
                                          _selectionEnd = null;
                                          _isSelecting = false;
                                        });
                                        _focusNode.requestFocus();
                                      },
                                      child: RawKeyboardListener(
                                          focusNode: _focusNode,
                                          autofocus: true,
                                          onKey: _handleKeyEvent,
                                          child: CustomPaint(
                                            painter: ConnectionPainter(
                                              connections: _connections,
                                              nodes: _nodes,
                                              nodeSize: _nodeSize,
                                              selectedConnectionId: _selectedConnectionId,
                                              insertionPoints: _insertionPoints,
                                            ),
                                            child: Stack(
                                              children: [
                                                  if (_showGrid) gridWidget,
                                                  // Линии соединений
                                                  CustomPaint(
                                                    painter: ConnectionPainter(
                                                      connections: _connections,
                                                      nodes: _nodes,
                                                      nodeSize: _nodeSize,
                                                      selectedConnectionId: _selectedConnectionId,
                                                      insertionPoints: _insertionPoints,
                                                    ),
                                                    child: Stack(
                                                      children: _nodes.entries
                                                      .map((entry) => _buildNodeWidget(entry.key, entry.value))
                                                      .toList(),
                                                    ),
                                                  ),
                                                  if (_isSelecting && _selectionStart != null && _selectionEnd != null)
                                                    CustomPaint(
                                                      painter: SelectionRectPainter(
                                                        start: _selectionStart!,
                                                        end: _selectionEnd!,
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
                            ),
                          ),
                        );
                      },
                    ),
                      ),
                      ],
              ),
          ],
       ),
    );
  }

  bool _isPointOverAnyNode(Offset point) {
    for (final entry in _nodes.entries) {
      final pos = entry.value.position;
      final nodeRect = Rect.fromLTWH(pos.dx, pos.dy, _nodeSize.width, _nodeSize.height);
      if (nodeRect.contains(point)) return true;
    }
    return false;
  }

  // Обработка удаления блока
  void _handleKeyEvent(RawKeyEvent event) {
     _pushState();

    if (event is RawKeyDownEvent) {
      // Ctrl+Z (отмена)
      if (event.logicalKey == LogicalKeyboardKey.keyZ &&
        (event.isControlPressed || event.isMetaPressed) &&
        !event.isShiftPressed) {
        _undo();
      return;
        }
        // Ctrl+Y или Ctrl+Shift+Z (повтор)
        if (event.logicalKey == LogicalKeyboardKey.keyZ &&
          (event.isControlPressed || event.isMetaPressed) &&
          event.isShiftPressed) {
          _redo();
        return;
          }
          // Ctrl+Y (альтернатива)
          if (event.logicalKey == LogicalKeyboardKey.keyY &&
            (event.isControlPressed || event.isMetaPressed)) {
            _redo();
          return;
            }



      if (event.logicalKey == LogicalKeyboardKey.delete ||
        event.logicalKey == LogicalKeyboardKey.backspace) {
        if (_selectedNodeNames.isNotEmpty) {
          final toDelete = List.of(_selectedNodeNames);
          for (final nodeName in toDelete) {
            final node = _nodes[nodeName]?.node;
            final isProtected = node?.data is TerminalBlock &&
            (node!.data.text == 'Start' || node.data.text == 'End');
            if (!isProtected) {
              _removeNode(nodeName);
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Нельзя удалить блок Start или End')),
              );
            }
          }
          setState(() {
            _selectedNodeNames.clear();
          });
        } else if (_selectedConnectionId != null) {
          _connections.removeWhere((c) => c.id == _selectedConnectionId);
          _selectedConnectionId = null;
          setState(() {});
          _applyAutoLayout();
          _updateInsertionPoints();

        }
      }
    }
  }

  Widget _buildNodeWidget(String nodeName, NodeWidgetData data) {
    final node = data.node;
    final position = data.position;
    final isSelected = _selectedNodeNames.contains(nodeName);

    return Positioned(
      left: position.dx,
      top: position.dy,
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedNodeNames = {nodeName};
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

    // Проверка точки вставки
    for (final point in _insertionPoints) {
      if ((localPos - point.position).distance <= 12.0) {
        if (_selectedPrototype != null) {
          // _insertNodeOnConnection(point.connection);
          _insertNodeOnConnection(point.connection, insertPosition: point.position);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Выберите тип блока на панели слева')),
          );
        }
        _isSelectingFromEmpty = false;
        return;
      }
    }

    ConnectionData? tappedConnection;
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
        _selectedNodeNames.clear();
      });
      _isSelectingFromEmpty = false;
      return;
    }

    // Если не попали ни в блок, ни в точку, ни в линию
    final isOverNode = _isPointOverAnyNode(localPos);
    _isSelectingFromEmpty = !isOverNode;

    if (!isOverNode) {
      setState(() {
        _selectedNodeNames.clear();
        _selectedConnectionId = null;
      });
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

  Path _getConnectionPath(ConnectionData conn) {
    final source = _nodes[conn.sourceNodeName];
    final target = _nodes[conn.targetNodeName];
    if (source == null || target == null) return Path();

    // Обратная связь от заглушки к For
    if (conn.targetPort == 'loopback') {
      final start = source.position + Offset(_nodeSize.width / 2, _nodeSize.height); // из нижней грани заглушки
      final end = target.position + Offset(0, _nodeSize.height / 2); // в левую грань For
      const double up = 20.0;
      final mid1 = Offset(start.dx, start.dy + up);
      final mid2 = Offset(end.dx - 20, mid1.dy);
      final mid3 = Offset(end.dx, end.dy);
      final path = Path()
      ..moveTo(start.dx, start.dy)
      ..lineTo(mid1.dx, mid1.dy)
      ..lineTo(mid2.dx, mid2.dy)
      ..lineTo(mid3.dx, mid3.dy)
      ..lineTo(end.dx, end.dy);
      return path;
    }

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
    } else if (conn.sourcePort == 'body') {
      final start = source.position + Offset(_nodeSize.width / 2, _nodeSize.height);
      final end = target.position + Offset(_nodeSize.width / 2, 0);
      final path = Path()
      ..moveTo(start.dx, start.dy)
      ..lineTo(end.dx, end.dy);
      return path;
    } else if (conn.sourcePort == 'exit') {
      final start = source.position + Offset(_nodeSize.width, _nodeSize.height / 2);
      final end = target.position + Offset(_nodeSize.width / 2, 0);
      final targetNode = target.node;
      final isEnd = targetNode.data is TerminalBlock && targetNode.data.text == 'End';

      final double maxBodyBottom = _getMaxBottomOfBodySubtree(conn.sourceNodeName);
      double down = 30.0;
      double turnY = start.dy;
      if (maxBodyBottom > start.dy + _nodeSize.height) {
        down = (maxBodyBottom - start.dy - _nodeSize.height) + 30.0;
        turnY = start.dy + _nodeSize.height + down;
      } else {
        turnY = start.dy + 30.0;
      }



      if (isEnd) {
        // Для End – уходим на общую нижнюю линию
        final mid1 = Offset(start.dx, turnY);
        final mid2 = Offset(end.dx, turnY);
        final mid3 = Offset(end.dx, mid2.dy);
        final path = Path()
        ..moveTo(start.dx, start.dy)
        ..lineTo(mid1.dx, mid1.dy)
        ..lineTo(mid2.dx, mid2.dy)
        ..lineTo(mid3.dx, mid3.dy)
        ..lineTo(end.dx, end.dy);
        return path;
      } else {
        // Обычный путь: вправо - вниз
        final mid1 = Offset(end.dx, start.dy);
        // final mid2 = Offset(end.dx, mid1.dy);
        final path = Path()
        ..moveTo(start.dx, start.dy)
        ..lineTo(mid1.dx, mid1.dy)
        // ..lineTo(mid2.dx, mid2.dy)
        ..lineTo(end.dx, end.dy);
        return path;
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

  // void _insertNodeOnConnection(ConnectionData connection) {
  void _insertNodeOnConnection(ConnectionData connection, {Offset? insertPosition}) {
    _pushState();


    final sourceNode = _nodes[connection.sourceNodeName]?.node;
    final targetNode = _nodes[connection.targetNodeName]?.node;
    if (sourceNode == null || targetNode == null) return;

    final prototype = _selectedPrototype!;

    Offset newPos;
    if (connection.sourcePort == 'exit') {
      // Размещаем новый блок справа от блока For
      final sourceWidget = _nodes[connection.sourceNodeName]!;
      newPos = Offset(
        sourceWidget.position.dx + _nodeSize.width + 40,
        sourceWidget.position.dy + _nodeSize.height / 2 - _nodeSize.height / 2,
      );
    } else if (insertPosition != null) {
      newPos = insertPosition;
    } else {
      final sourcePos = _nodes[connection.sourceNodeName]!.position;
      final targetPos = _nodes[connection.targetNodeName]!.position;
      newPos = Offset(
        (sourcePos.dx + targetPos.dx) / 2,
        (sourcePos.dy + targetPos.dy) / 2,
      );
    }

    final sourcePos = _nodes[connection.sourceNodeName]!.position;
    final targetPos = _nodes[connection.targetNodeName]!.position;
    final midpoint = Offset(
      (sourcePos.dx + targetPos.dx) / 2,
      (sourcePos.dy + targetPos.dy) / 2,
    );
    // final newPos = Offset(midpoint.dx, midpoint.dy);

    final newNode = NodeFactory.createNode(
      id: _uuid.v4(),
      data: prototype,
      position: newPos,
    );
    _addNode(newNode);

    final newSourcePortName = (prototype is LogicBlock) ? 'yes' : 'out';
    _connections.removeWhere((c) => c.id == connection.id);

    // Add connections: source -> newNode, newNode -> target
    _connections.add(ConnectionData(
      id: _uuid.v4(),
      sourceNodeName: connection.sourceNodeName,
      sourcePort: connection.sourcePort,
      targetNodeName: newNode.name,
      targetPort: 'in',
    ));

    if (prototype is LogicBlock) {
      // Ветка "Да" идёт к исходному целевому узлу
      _connections.add(ConnectionData(
        id: _uuid.v4(),
        sourceNodeName: newNode.name,
        sourcePort: 'yes',
        targetNodeName: connection.targetNodeName,
        targetPort: connection.targetPort,
      ));

      // Поиск существующего End
      NodeWidgetData? endWidget = _nodes.values.firstWhereOrNull(
        (w) => w.node.data is TerminalBlock && w.node.data.text == 'End'
      );
      NodeModel? endNode = endWidget?.node;

      if (endNode == null) {
        final endPos = Offset(newPos.dx + _nodeSize.width + 80, newPos.dy + _nodeSize.height + 30);
        endNode = NodeFactory.createNode(
          id: _uuid.v4(),
          data: TerminalBlock('End'),
          position: endPos,
        );
        _addNode(endNode);
      }

      _connections.add(ConnectionData(
        id: _uuid.v4(),
        sourceNodeName: newNode.name,
        sourcePort: 'no',
        targetNodeName: endNode.name,
        targetPort: 'in'
        // targetNodeName: connection.targetNodeName,
        // targetPort: connection.targetPort,
      ));

    } else if (prototype is ForBlock) {
      // Ветка "exit" идёт к исходному целевому узлу
      _connections.add(ConnectionData(
        id: _uuid.v4(),
        sourceNodeName: newNode.name,
        sourcePort: 'exit',
        targetNodeName: connection.targetNodeName,
        targetPort: connection.targetPort,
      ));

      // узел-заглушка для тела цикла
      final bodyPos = Offset(
        newPos.dx,
        newPos.dy + _nodeSize.height + 30,
      );
      final bodyNode = NodeFactory.createNode(
        id: _uuid.v4(),
        data: ProcessBlock('Тело цикла'),
        position: bodyPos,
      );
      _addNode(bodyNode);

      // Обратная связь body - сам блок
      _connections.add(ConnectionData(
        id: _uuid.v4(),
        sourceNodeName: newNode.name,
        sourcePort: 'body',
        targetNodeName: bodyNode.name,
        targetPort: 'in',
      ));

      _connections.add(ConnectionData(
        id: _uuid.v4(),
        sourceNodeName: bodyNode.name,
        sourcePort: 'out',
        targetNodeName: newNode.name,
        targetPort: 'loopback', // специальный порт для возврата
      ));


    } else {
      // Обычный блок – одна исходящая связь
      _connections.add(ConnectionData(
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

    _updateInsertionPoints();
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
    _pushState();

    if (_connections.any((c) =>
      c.sourceNodeName == srcNode &&
      c.sourcePort == srcPort &&
      c.targetNodeName == tgtNode &&
      c.targetPort == tgtPort)) return;

    setState(() {
      _connections.add(ConnectionData(
        id: _uuid.v4(),
        sourceNodeName: srcNode,
        sourcePort: srcPort,
        targetNodeName: tgtNode,
        targetPort: tgtPort,
      ));
    });
    _applyAutoLayout();

    _updateInsertionPoints();
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
      _pushState();

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
    final Map<String, List<ConnectionData>> outgoing = {};
    for (final conn in _connections) {
      // if (conn.sourceNodeName == conn.targetNodeName) continue;
      if (conn.targetPort == 'loopback') continue;

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
      final isFor = node?.data is ForBlock;

      if ((isLogic || isFor) && children.length >= 2) {
        ConnectionData? mainBranch, secondaryBranch;
        for (final c in children) {
          if (c.sourcePort == 'yes' || c.sourcePort == 'exit') mainBranch = c;
          if (c.sourcePort == 'no' || c.sourcePort == 'body') secondaryBranch = c;
        }
        if (mainBranch != null) {
          _layoutX(mainBranch.targetNodeName, currentX, visited);
        }
        if (secondaryBranch != null) {
          // Сдвиг для вторичной ветки (например, "нет" или "тело")
          final targetNode = _nodes[secondaryBranch.targetNodeName]?.node;
          final isEnd = targetNode != null && targetNode.data is TerminalBlock && targetNode.data.text == 'End';
          double offset = 300;
          if (secondaryBranch.sourcePort == 'body') offset = 0;
          _layoutX(secondaryBranch.targetNodeName, currentX + (isEnd ? 0 : offset), visited);

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

    for (final conn in _connections) {
      if (conn.sourcePort == 'body') {
        final forX = xPositions[conn.sourceNodeName];
        if (forX != null && xPositions.containsKey(conn.targetNodeName)) {
          xPositions[conn.targetNodeName] = forX;
        }
      }
    }






    // Выравнивание поддеревьев тела цикла
    final Map<String, String> bodyRoots = {}; // узел For -> корень тела
    for (final conn in _connections) {
      if (conn.sourcePort == 'body') {
        bodyRoots[conn.targetNodeName] = conn.sourceNodeName;
      }
    }
    // Для каждого корня тела цикла собрать все достижимые узлы (кроме End)
    for (final entry in bodyRoots.entries) {
      final bodyRoot = entry.key;
      final forNode = entry.value;
      final forX = xPositions[forNode];
      if (forX == null) continue;
      final Set<String> bodySubtree = {};
      _collectSubtreeExcludingEnd(bodyRoot, bodySubtree);
      for (final node in bodySubtree) {
        if (xPositions.containsKey(node)) {
          xPositions[node] = forX;
        }
      }
    }

    // Смещение для поддеревьев exit (ветка "выход" цикла)
    const double exitOffset = 200.0;
    final Map<String, Set<String>> exitSubtrees = {};
    for (final conn in _connections) {
      if (conn.sourcePort == 'exit') {
        final Set<String> subtree = {};
        _collectSubtreeExcludingEnd(conn.targetNodeName, subtree);
        exitSubtrees[conn.sourceNodeName] = subtree;
      }
    }
    for (final entry in exitSubtrees.entries) {
      final forNode = entry.key;
      final subtree = entry.value;
      final forX = xPositions[forNode];
      if (forX == null) continue;
      for (final node in subtree) {
        if (xPositions.containsKey(node)) {
          xPositions[node] = forX + exitOffset;
        }
      }
      print('=== Exit subtree for ${forNode} ===');
      for (final node in subtree) {
        print('$node: x = ${xPositions[node]}');
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

    print('=== newPositions ===');
    for (final entry in newPositions.entries) {
      print('${entry.key}: ${entry.value}');
    }

    // Обработка конечного блока End
    final endNodeEntry = _nodes.entries.firstWhereOrNull(
      (e) => e.value.node.data is TerminalBlock && e.value.node.data.text == 'End',
    );

    if (endNodeEntry != null) {
      final endName = endNodeEntry.key;

      double maxY = startPos.dy;
      for (final entry in newPositions.entries) {
        if (entry.key == endName) continue;
        final y = entry.value.dy;
        if (y > maxY) maxY = y;
      }
      // Ставим End ниже самого нижнего узла на расстояние шага
      final endY = maxY + stepY;
      newPositions[endName] = Offset(startPos.dx, endY);

    }

    setState(() {
      for (final entry in newPositions.entries) {
        if (_nodes.containsKey(entry.key)) {
          _nodes[entry.key]!.position = entry.value;
        }
      }
    });

    _updateInsertionPoints();

    _isApplyingLayout = false;
  }

  void _updateInsertionPoints() {
    final points = <InsertionPoint>[];
    for (final conn in _connections) {
      if (conn.targetPort == 'loopback') continue;

      // Специальная обработка для ветки exit – ставим кружок на середине горизонтального участка
      if (conn.sourcePort == 'exit') {
        final source = _nodes[conn.sourceNodeName];
        final target = _nodes[conn.targetNodeName];
        if (source == null || target == null) continue;

        final isEnd = target.node.data is TerminalBlock && target.node.data.text == 'End';

        // Базовые координаты порта exit (середина правой грани For)
        final startX = source.position.dx + _nodeSize.width;
        final startY = source.position.dy + _nodeSize.height / 2;

        if (isEnd) {
          // Находим нижнюю границу тела цикла (через связь body)
          final double maxBodyBottom = _getMaxBottomOfBodySubtree(conn.sourceNodeName);
          double turnY = source.position.dy + _nodeSize.height + 30; // значение по умолчанию
          if (maxBodyBottom > source.position.dy + _nodeSize.height) {
            const double extraDown = 30.0;
            final double down = (maxBodyBottom - source.position.dy - _nodeSize.height) + extraDown;
            turnY = source.position.dy + _nodeSize.height + down;
          }


          final double startX = source.position.dx + _nodeSize.width;   // правая грань For
          final double endX = target.position.dx + _nodeSize.width / 2; // центр верхней грани цели

          // Середина горизонтального участка
          final double midX = (startX + endX) / 2 + 20;
          final Offset point = Offset(midX, turnY);

          points.add(InsertionPoint(point, conn));
        } else {
          // Для обычного блока – плюсик на горизонтальном участке сразу после For
          const double rightOffset = 40.0;   // длина горизонтального участка (должна совпадать с rightOffset в отрисовке)
          const double insertOffset = rightOffset / 2; // середина этого участка
          final pointX = startX + insertOffset;
          final pointY = startY;
          points.add(InsertionPoint(Offset(pointX, pointY), conn));
        }
        continue;
      }

      final path = _getConnectionPath(conn);
      for (final metric in path.computeMetrics()) {
        final length = metric.length;
        if (length <= 0.1) continue;
        const double t = 0.5;
        final distance = length * t;
        final tangent = metric.getTangentForOffset(distance);
        if (tangent != null) {
          points.add(InsertionPoint(tangent.position, conn));
        }
      }
    }
    setState(() {
      _insertionPoints = points;
    });
  }

  void _setNodeSize(Size newSize) {
    if (_nodeSize == newSize) return;

    _pushState();

    _nodeSize = newSize;
    _applyAutoLayout();
    _updateInsertionPoints();
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

    // return Size(width * _scale, height * _scale);
    return Size(width, height);
  }


  Future<void> _exportToSvg() async {
    if (_nodes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Нет элементов для экспорта')),
      );
      return;
    }

    // Диалог для ввода имени файла
    final fileNameController = TextEditingController(text: 'diagram');
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Экспорт в SVG'),
        content: TextField(
          controller: fileNameController,
          decoration: const InputDecoration(labelText: 'Имя файла'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Отмена')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Сохранить')),
        ],
      ),
    );
    if (confirmed != true) return;


    // Вычисление bounding box
    double minX = double.infinity, minY = double.infinity;
    double maxX = -double.infinity, maxY = -double.infinity;
    for (final entry in _nodes.entries) {
      final pos = entry.value.position;
      minX = math.min(minX, pos.dx);
      minY = math.min(minY, pos.dy);
      maxX = math.max(maxX, pos.dx + _nodeSize.width);
      maxY = math.max(maxY, pos.dy + _nodeSize.height);
    }
    for (final conn in _connections) {
      final path = _getConnectionPath(conn);
      for (final metric in path.computeMetrics()) {
        for (double dist = 0; dist <= metric.length; dist += 5) {
          final tangent = metric.getTangentForOffset(dist);
          if (tangent != null) {
            minX = math.min(minX, tangent.position.dx);
            minY = math.min(minY, tangent.position.dy);
            maxX = math.max(maxX, tangent.position.dx);
            maxY = math.max(maxY, tangent.position.dy);
          }
        }
      }
    }
    const padding = 40.0;
    final width = maxX - minX + padding * 2;
    final height = maxY - minY + padding * 2;
    final offsetX = -minX + padding;
    final offsetY = -minY + padding;

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
      final fileName = '${fileNameController.text}.svg';
      // final fileName = 'diagram_${DateTime.now().millisecondsSinceEpoch}.svg';
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
        // Внутри switch после case SubroutineBlock():
      case ForBlock():
        final w = size.width;
        final h = size.height;
        final h2 = h / 2;
        final w4 = w / 4;
        final points = '${w4},0 ${w * 3 / 4},0 $w,$h2 ${w * 3 / 4},$h $w4,$h 0,$h2';
        shapeSvg = '<polygon points="$points" stroke="black" stroke-width="2" fill="white"/>';
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
      final double stepXgrid = stepX! + 70;
      final double startCenterX = startPosition.dx + stepX! / 2;
      //print(startCenterX);
      // double x = (col + 1) * stepX!;
      double x = startCenterX + col * stepXgrid;
      //double x = (col + 1) * stepX;
      if (x < 0 || x > canvasSize.width) continue;
      final number = col + 1;
      buffer.writeln('<text x="$x" y="20" text-anchor="middle" $textStyle>$number</text>');
    }

    // Подписи строк (буквы) слева
    final double stepYgrid = stepY! + 40.0;
    // final double stepYgrid = stepY!;
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




class _ConnectionDragData {
  final String sourceNodeName;
  final String sourcePort;
  _ConnectionDragData({required this.sourceNodeName, required this.sourcePort});
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
      painter: GridLabelsPainter(
        stepX: stepX,
        stepY: stepY,
        startPosition: startPosition!,
      ),
    );
  }
}






