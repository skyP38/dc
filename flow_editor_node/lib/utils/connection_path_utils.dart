import 'package:flutter/material.dart';
import 'dart:math';
import '../controllers/flow_controller.dart';
import '../factories/node_factory.dart';
import '../models/flow_models.dart';

Path buildConnectionPath({
    required Connection conn,
    required Map<String, NodeModel> nodes,
    required Size nodeSize,
}) {
    final sourceNode = nodes[conn.sourceNodeName];
    final targetNode = nodes[conn.targetNodeName];
    if (sourceNode == null || targetNode == null) return Path();

    final sourcePos = sourceNode.position;
    final targetPos = targetNode.position;
    final path = Path();

    // для расчёта общей нижней границы
    double maxBottomY = 0;
    for (final node in nodes.values) {
        maxBottomY = max(maxBottomY, node.position.dy + nodeSize.height);
    }
    final endLineY = maxBottomY - nodeSize.height - 10;

    if (conn.sourcePort == 'no') {
        final start = sourcePos + Offset(nodeSize.width, nodeSize.height / 2);
        final end = targetPos + Offset(nodeSize.width / 2, 0);
        final isEnd = targetNode.data is TerminalBlock && targetNode.data.text == 'End';

        if (isEnd) {
            final mid1 = Offset(start.dx + 30, start.dy);
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
        final start = sourcePos + Offset(nodeSize.width / 2, nodeSize.height);
        final end = targetPos + Offset(nodeSize.width / 2, 0);
        final targetNode = nodes[conn.targetNodeName];
        final isEnd = targetNode != null && targetNode.data is TerminalBlock && targetNode.data.text == 'End';
        print(end.dx);
        print(start.dx);
        if (isEnd && end.dx != start.dx) {
            const double verticalStep = 20.0;
            final mid1 = Offset(start.dx, endLineY);
            final mid2 = Offset(end.dx, endLineY);
            path.moveTo(start.dx, start.dy);
            path.lineTo(mid1.dx, mid1.dy);
            path.lineTo(mid2.dx, mid2.dy);
            path.lineTo(end.dx, end.dy);
        } else {
          path.moveTo(start.dx, start.dy);
          path.lineTo(end.dx, end.dy);
        }
    } else {
        final start = sourcePos + Offset(nodeSize.width / 2, nodeSize.height);
        final end = targetPos + Offset(nodeSize.width / 2, 0);
        final targetNode = nodes[conn.targetNodeName];
        final isEnd = targetNode != null && targetNode.data is TerminalBlock && targetNode.data.text == 'End';

        if (isEnd && end.dx != start.dx) {
            final mid1 = Offset(start.dx, start.dy + 20);
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
