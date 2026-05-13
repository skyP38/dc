import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'package:collection/collection.dart';
import '../models/flow_models.dart';
import '../factories/node_factory.dart';

class FlowController extends ChangeNotifier {
  final Map<String, NodeModel> _nodes = {};
  final List<Connection> _connections = [];
  final Uuid _uuid = const Uuid();

  Map<String, NodeModel> get nodes => Map.unmodifiable(_nodes);
  List<Connection> get connections => List.unmodifiable(_connections);

  // Добавление / удаление узлов
  void addNode(NodeModel node) {
    _nodes[node.name] = node;
    notifyListeners();
  }

  // Возвращает true, если удаление разрешено, иначе - false
  bool removeNode(String nodeName, {required Size nodeSize}) {
        final removedNode = _nodes[nodeName];
    if (removedNode == null) return false;

    if (removedNode.data is TerminalBlock) {
      final text = removedNode.data.text;
      if (text == 'Start' || text == 'End') return false;
    }

    final incoming = _connections.where((c) => c.targetNodeName == nodeName).toList();
    final outgoing = _connections.where((c) => c.sourceNodeName == nodeName).toList();
    final bool isLogic = removedNode.data is LogicBlock;

    if (isLogic) {
      // узлы на ветке no, исключая End
      final Set<String> nodesToRemove = {nodeName};
      final noOutgoing = outgoing.where((c) => c.sourcePort == 'no').toList();
      for (final conn in noOutgoing) {
        _collectSubtreeExcludingEnd(conn.targetNodeName, nodesToRemove);
      }
      for (final n in nodesToRemove) {
        if (n == nodeName) continue;
        final node = _nodes[n];
        if (node != null && node.data is TerminalBlock && node.data.text == 'End') continue;
        _nodes.remove(n);
      }

      final nodesToRemoveFinal = nodesToRemove.where((n) {
        final nd = _nodes[n];
        return !(nd != null && nd.data is TerminalBlock && nd.data.text == 'End');
      }).toSet();
      nodesToRemoveFinal.add(nodeName);

      _connections.removeWhere((c) =>
        nodesToRemoveFinal.contains(c.sourceNodeName) ||
        nodesToRemoveFinal.contains(c.targetNodeName));

      // вход к выходу yes
      final incomingConn = incoming.isNotEmpty ? incoming.first : null;
      final outgoingYes = outgoing.firstWhereOrNull((c) => c.sourcePort == 'yes');
      if (incomingConn != null && outgoingYes != null && _nodes.containsKey(outgoingYes.targetNodeName)) {
        _connections.add(Connection(
          id: _uuid.v4(),
          sourceNodeName: incomingConn.sourceNodeName,
          sourcePort: incomingConn.sourcePort,
          targetNodeName: outgoingYes.targetNodeName,
          targetPort: outgoingYes.targetPort,
        ));
      }
      _nodes.remove(nodeName);
    } else {
      if (incoming.length == 1 && outgoing.length == 1) {
        final inConn = incoming.first;
        final outConn = outgoing.first;
        _connections.add(Connection(
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

    notifyListeners();
    return true;
  }

  void addConnection(Connection conn) {
    if (_connections.any((c) =>
        c.sourceNodeName == conn.sourceNodeName &&
        c.sourcePort == conn.sourcePort &&
        c.targetNodeName == conn.targetNodeName &&
        c.targetPort == conn.targetPort)) return;
    _connections.add(conn);
    notifyListeners();
  }

  void removeConnection(String connectionId) {
    _connections.removeWhere((c) => c.id == connectionId);
    notifyListeners();
  }

  void updateNodePosition(String nodeName, Offset newPosition) {
    if (_nodes.containsKey(nodeName)) {
      _nodes[nodeName]!.position = newPosition;
      notifyListeners();
    }
  }

  void updateNodeText(String nodeName, String newText) {
    final node = _nodes[nodeName];
    if (node != null) {
      node.data = node.data.copyWith(text: newText);
      notifyListeners();
    }
  }

  void insertNodeOnConnection(Connection connection, GostNodeData prototype, Size nodeSize) {
    final sourceNode = _nodes[connection.sourceNodeName];
    final targetNode = _nodes[connection.targetNodeName];
    if (sourceNode == null || targetNode == null) return;

    final sourcePos = sourceNode.position;
    final targetPos = targetNode.position;
    final midpoint = Offset(
      (sourcePos.dx + targetPos.dx) / 2,
      (sourcePos.dy + targetPos.dy) / 2,
    );
    final newPos = midpoint;

    final newNode = NodeFactory.createNode(
      id: _uuid.v4(),
      data: prototype,
      position: newPos,
    );
    addNode(newNode);

    _connections.removeWhere((c) => c.id == connection.id);

    // source -> newNode, newNode -> target
    _connections.add(Connection(
      id: _uuid.v4(),
      sourceNodeName: connection.sourceNodeName,
      sourcePort: connection.sourcePort,
      targetNodeName: newNode.name,
      targetPort: 'in',
    ));

    if (prototype is LogicBlock) {
      // Ветка yes идёт к исходному целевому узлу
      _connections.add(Connection(
        id: _uuid.v4(),
        sourceNodeName: newNode.name,
        sourcePort: 'yes',
        targetNodeName: connection.targetNodeName,
        targetPort: connection.targetPort,
      ));

      NodeModel? endNode = _nodes.values.firstWhereOrNull(
        (n) => n.data is TerminalBlock && n.data.text == 'End'
      );
      if (endNode == null) {
        // новый End справа от нового блока
        final endPos = Offset(newPos.dx + nodeSize.width + 80, newPos.dy + nodeSize.height + 30);
        endNode = NodeFactory.createNode(
          id: _uuid.v4(),
          data: TerminalBlock('End'),
          position: endPos,
        );
        addNode(endNode);
      }

      _connections.add(Connection(
        id: _uuid.v4(),
        sourceNodeName: newNode.name,
        sourcePort: 'no',
        targetNodeName: endNode!.name,
        targetPort: 'in',
      ));

    } else {
      // Обычный блок
      _connections.add(Connection(
        id: _uuid.v4(),
        sourceNodeName: newNode.name,
        sourcePort: (prototype is LogicBlock) ? 'yes' : 'out',
        targetNodeName: connection.targetNodeName,
        targetPort: connection.targetPort,
      ));
    }

    notifyListeners();
  }


  void performAutoLayout(Size nodeSize) {
    // Найти стартовый узел
    final startEntry = _nodes.entries.firstWhereOrNull(
      (e) => e.value.data is TerminalBlock && e.value.data.text == 'Start',
    );
    if (startEntry == null) return;

    final startName = startEntry.key;
    final startPos = startEntry.value.position;

    // Построить исходящие связи для каждого узла
    final Map<String, List<Connection>> outgoing = {};
    for (final conn in _connections) {
      outgoing.putIfAbsent(conn.sourceNodeName, () => []).add(conn);
    }

    // Вычисление рангов (BFS с накоплением максимальной глубины)
    final Map<String, int> ranks = {};
    final queue = <String>[startName];
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

    // Рекурсивное определение x-координат
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

      final node = _nodes[nodeName];
      final isLogic = node?.data is LogicBlock;

      if (isLogic && children.length >= 2) {
        Connection? yesConn, noConn;
        for (final c in children) {
          if (c.sourcePort == 'yes') yesConn = c;
          if (c.sourcePort == 'no') noConn = c;
        }
        if (yesConn != null) {
          _layoutX(yesConn.targetNodeName, currentX, visited);
        }
        if (noConn != null) {
          // Сдвиг для ветки no
          final targetNode = _nodes[noConn.targetNodeName];
          final isEnd = targetNode != null && targetNode.data is TerminalBlock && targetNode.data.text == 'End';
          const double noOffset = 300;
          final offset = isEnd ? 0 : noOffset;
          _layoutX(noConn.targetNodeName, currentX + offset, visited);
        }
      } else {
        // Обычный блок
        for (final conn in children) {
          _layoutX(conn.targetNodeName, currentX, visited);
        }
      }
      return currentX;
    }

    final visited = <String>{};
    _layoutX(startName, startPos.dx, visited);

    final Map<int, List<String>> nodesByRank = {};
    for (final entry in ranks.entries) {
      nodesByRank.putIfAbsent(entry.value, () => []).add(entry.key);
    }
    const double gap = 50.0;
    for (final rank in nodesByRank.keys) {
      final nodeNames = nodesByRank[rank]!;
      nodeNames.sort((a, b) => xPositions[a]!.compareTo(xPositions[b]!));
      double nextMinX = startPos.dx; //x стартового блока
      for (final name in nodeNames) {
        double currentX = xPositions[name]!;
        if (currentX < nextMinX) {
          currentX = nextMinX;
          xPositions[name] = currentX;
        }
        nextMinX = currentX + nodeSize.width + gap;
      }
    }

    // Вычисление y-координат
    final stepY = nodeSize.height + 30.0;
    final Map<String, Offset> newPositions = {};
    for (final entry in ranks.entries) {
      final name = entry.key;
      final rank = entry.value;
      final x = xPositions[name] ?? startPos.dx;
      final y = startPos.dy + rank * stepY;
      newPositions[name] = Offset(x, y);
    }

    // Обработка блока End
    final endEntry = _nodes.entries.firstWhereOrNull(
      (e) => e.value.data is TerminalBlock && e.value.data.text == 'End'
    );
    if (endEntry != null) {
      final endName = endEntry.key;
      final maxRank = ranks.values.isEmpty ? 0 : ranks.values.reduce((a, b) => a > b ? a : b);
      final endY = startPos.dy + (maxRank + 1) * stepY;
      newPositions[endName] = Offset(startPos.dx, endY);
    }

    bool changed = false;
    for (final entry in newPositions.entries) {
      final node = _nodes[entry.key];
      if (node != null && node.position != entry.value) {
        node.position = entry.value;
        changed = true;
      }
    }
    if (changed) notifyListeners();
  }

  /// Рекурсивно собирает узлы, достижимые из startNode, но не включает блок End
  void _collectSubtreeExcludingEnd(String startNode, Set<String> collected) {
    if (collected.contains(startNode)) return;
    final node = _nodes[startNode];
    if (node != null && node.data is TerminalBlock && node.data.text == 'End') return;
    collected.add(startNode);
    final children = _connections.where((c) => c.sourceNodeName == startNode).toList();
    for (final child in children) {
      _collectSubtreeExcludingEnd(child.targetNodeName, collected);
    }
  }
}

class Connection {
  final String id;
  final String sourceNodeName;
  final String sourcePort;
  final String targetNodeName;
  final String targetPort;
  Connection({
    required this.id,
    required this.sourceNodeName,
    required this.sourcePort,
    required this.targetNodeName,
    required this.targetPort,
  });
}
