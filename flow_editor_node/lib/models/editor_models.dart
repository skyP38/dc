import 'package:flutter/material.dart';
import '../factories/node_factory.dart';


class NodeWidgetData {
  NodeModel node;
  Offset position;
  NodeWidgetData({required this.node, required this.position});
}

class ConnectionData {
  final String? id;
  final String sourceNodeName;
  final String sourcePort;
  final String targetNodeName;
  final String targetPort;
  ConnectionData({
    this.id,
    required this.sourceNodeName,
    required this.sourcePort,
    required this.targetNodeName,
    required this.targetPort,
  });
}


class InsertionPoint {
  final Offset position;
  final ConnectionData connection;
  InsertionPoint(this.position, this.connection);
}
