import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../models/flow_models.dart';

class NodeModel {
  final String id;
  final String name;
  GostNodeData data;
  Offset position;

  NodeModel({
    required this.id,
    required this.name,
    required this.data,
    required this.position,
  });
}

class NodeFactory {
  static NodeModel createNode({
    required String id,
    required GostNodeData data,
    required Offset position,
  }) {
    return NodeModel(
      id: id,
      name: '${data.runtimeType}_${id.substring(0, 8)}',
      data: data,
      position: position,
    );
  }
}
