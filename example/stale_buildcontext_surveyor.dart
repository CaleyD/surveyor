//  Copyright 2019 Google LLC
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//      https://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.

import 'dart:io';

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/source/line_info.dart';
import 'package:surveyor/src/driver.dart' show Driver;
import 'package:surveyor/src/visitors.dart' show AstContext;

/// Looks for instances where "async" is used as an identifier
/// and would break were it made a keyword.
///
/// Run like so:
///
/// dart example/async_surveyor.dart <source dir>
Future<int> main(List<String> args) async {
  if (args.length == 1) {
    var dir = args[0];
    if (!File('$dir/pubspec.yaml').existsSync()) {
      print("Recursing into '$dir'...");
      args = Directory(dir).listSync().map((f) => f.path).toList()..sort();
    }
  }

  final analyzer = StaleBuildContextAnalyzer();
  var driver = Driver.forArgs(args);
  driver.forceSkipInstall = true;
  driver.showErrors = false;
  driver.resolveUnits = false;
  driver.visitor = analyzer;

  await driver.analyze();

  print(analyzer.issues.join('\n'));
  print('Found ${analyzer.issues.length} errors in ${analyzer.issues.map((i) => i.filePath).toSet().length} files');
  return analyzer.issues.isEmpty ? 0 : 1;
}

class StaleBuildContextAnalyzer extends RecursiveAstVisitor
    implements AstContext {
  String filePath;
  LineInfo lineInfo;

  List<IssueLocation> issues = [];
  _Scope scope = _Scope();

  StaleBuildContextAnalyzer();

  @override
  void setFilePath(String filePath) => this.filePath = filePath;
  
  @override
  void setLineInfo(LineInfo lineInfo) => this.lineInfo = lineInfo;
  
  @override
  void visitArgumentList(ArgumentList node) {
    // print(node.arguments);
    //  notes.add(node.arguments.map((e) => e.staticType?.getDisplayString()).toString());
    super.visitArgumentList(node);
  }

  @override
  void visitAwaitExpression(AwaitExpression node) {
    super.visitAwaitExpression(node);
    scope.setDidAwait();
  }

  @override
  void visitMethodDeclaration(MethodDeclaration node) {
    scope.push();
    super.visitMethodDeclaration(node);
    scope.pop();
  }

  @override
  void visitFunctionDeclaration(FunctionDeclaration node) {
   // print (node.functionExpression.parameters.parameters.map((element) => element.toString()));

    scope.push();
    super.visitFunctionDeclaration(node);
    scope.pop();
  }

  @override
  void visitFunctionDeclarationStatement(FunctionDeclarationStatement node) {
    scope.push();
    super.visitFunctionDeclarationStatement(node);
    scope.pop();
  }

  @override
  void visitExpressionFunctionBody(ExpressionFunctionBody node) {
    scope.push();
    super.visitExpressionFunctionBody(node);
    scope.pop();
  }

  @override
  void visitFunctionExpression(FunctionExpression node) {
    scope.push();
    super.visitFunctionExpression(node);
    scope.pop();
  }

  @override
  void visitSimpleFormalParameter(SimpleFormalParameter node) {
    scope.addLocalIdentifier(node.identifier?.name, node.type?.toString());
   // print(node.toString() + ' ::: ' + node.type.toString());
    super.visitSimpleFormalParameter(node);
  }


  @override 
  void visitVariableDeclaration(VariableDeclaration node) {
   // print(node);
   // print(node.declaredElement?.type);
    scope.addLocalIdentifier(node.name.name, '???');
    super.visitVariableDeclaration(node);
  }

  @override
  void visitIfStatement(IfStatement node) {
   // print('visitIfStatementBEGIN');
    super.visitIfStatement(node);
   // print('visitIfStatementEND');
  }

  @override
  void visitBlock(Block node) {
    //print('visitBlockBEGIN');
    super.visitBlock(node);
    //print('visitBlockEND');
  }

  @override
  void visitSimpleIdentifier(SimpleIdentifier node) {
    var id = node.name;

    if (scope.isBuildContext(id) && scope.didAwaitSinceIdentifierWasDefined(id) /*&& filePath?.contains('/test/') == false*/) {
      var location = lineInfo.getLocation(node.offset);
      //   print(node.staticType);
      //   print(node.staticElement);
      //   print(node.staticParameterElement);
      //   print(node.runtimeType);
      //   print(node.tearOffTypeArgumentTypes);
      if(issues.any((e) => e.filePath == filePath && e.lineNumber == location.lineNumber) == false) {
        issues.add(IssueLocation(filePath, location.lineNumber, location.columnNumber));
      }
    }
    super.visitSimpleIdentifier(node);
  }
}

class IssueLocation {
  const IssueLocation(this.filePath, this.lineNumber, this.columnNumber);
  final String filePath;
  final int lineNumber;
  final int columnNumber;

  @override
  String toString() => 'error • stale_buildcontext • $filePath:$lineNumber:$columnNumber';
}

class _BlockContext {
  final Map<String, String> localScopaBuildIdentifiers = {}; // name => type
  bool didAlreadyAwait = false;
}


class _Scope {

  final List<_BlockContext> blockContext = [_BlockContext()];
  _BlockContext get latestScope => blockContext.last; 

  void push() {
    blockContext.add(_BlockContext());
  }

  void pop() {
    blockContext.removeLast();
  }

  void setDidAwait() {
    blockContext.last.didAlreadyAwait = true;
  }

  void addLocalIdentifier(String name, String type) {
    blockContext.last.localScopaBuildIdentifiers[name] = type;
  }

  bool didAwaitSinceIdentifierWasDefined(String identifier) {
    return blockContext.last.didAlreadyAwait;
  }

  bool isBuildContext(String identifier) {
    return identifier == 'context';
  }
}