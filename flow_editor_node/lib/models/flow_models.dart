import 'package:flutter/material.dart';

sealed class GostNodeData {
  final String text;
  const GostNodeData(this.text);

  GostNodeData copyWith({String? text});
}

class ProcessBlock extends GostNodeData {
  const ProcessBlock(super.text);
  @override
  ProcessBlock copyWith({String? text}) => ProcessBlock(text ?? this.text);
}

class LogicBlock extends GostNodeData {
  const LogicBlock(super.text);
  @override
  LogicBlock copyWith({String? text}) => LogicBlock(text ?? this.text);
}

class TerminalBlock extends GostNodeData {
  const TerminalBlock(super.text);
  @override
  TerminalBlock copyWith({String? text}) => TerminalBlock(text ?? this.text);
}

class IOBlock extends GostNodeData {
  const IOBlock(super.text);
  @override
  IOBlock copyWith({String? text}) => IOBlock(text ?? this.text);
}

class SubroutineBlock extends GostNodeData {
  const SubroutineBlock(super.text);
  @override
  SubroutineBlock copyWith({String? text}) => SubroutineBlock(text ?? this.text);
}
