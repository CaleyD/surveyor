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

import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:cli_util/cli_logging.dart';
import 'package:surveyor/src/analysis.dart';
import 'package:surveyor/src/driver.dart';
import 'package:surveyor/src/visitors.dart';
import 'package:analyzer/src/lint/linter.dart';

import 'package:analyzer/error/error.dart';
import 'package:analyzer/src/generated/engine.dart' show AnalysisErrorInfoImpl, AnalysisErrorInfo;

/// Looks for instances where "async" is used as an identifier
/// and would break were it made a keyword.
///
/// Run like so:
///
/// dart example/async_surveyor.dart <source dir>
void main(List<String> args) async {
  if (args.length == 1) {
    var dir = args[0];
    if (!File('$dir/pubspec.yaml').existsSync()) {
      print("Recursing into '$dir'...");
      args = Directory(dir).listSync().map((f) => f.path).toList()..sort();
    }
  }
  var errors = await analyze(args);
  displayResults(errors);
}

void displayResults(List<AnalysisErrorInfo> errors, [StringSink out]) {
  var stats = AnalysisStats();
  var formatter = HumanErrorFormatter(out ?? stdout, stats);
  for (var error in errors) {
    formatter.formatErrors([error]);
    formatter.flush();
  }
  stats.print(out ?? stdout);
}

Future<List<AnalysisErrorInfo>> analyze(List<String> args, {Logger logger}) async {
  var driver = Driver.forArgs(args);
  var advisor = AnalysisAdvisor();
  driver.visitor = advisor;
  driver.showErrors = true;
  driver.resolveUnits = true;
  driver.logger = logger ?? Logger.standard();
  driver.lints = [
    StaleBuildContextLint(),
  ];
  await driver.analyze();

  return advisor.errors;
}

class AnalysisAdvisor extends SimpleAstVisitor implements ErrorReporter {
  final List<AnalysisErrorInfo> errors = [];

  AnalysisAdvisor();

  @override
  void reportError(AnalysisResultWithErrors result) {
    
    bool showError(AnalysisError error) => error.errorCode.type == ErrorType.LINT;

    var errors = result.errors.where(showError).toList();
    if (errors.isEmpty) {
      return;
    }
    this.errors.add(AnalysisErrorInfoImpl(errors, result.lineInfo));
  }
}

class StaleBuildContextLint extends LintRule implements NodeLintRule {
  static const _desc = r'Avoid referencing BuildContext after an await boundary';
  static const _details = r'''
**DO** avoid `BuildContext` references after an await boundary.

**BAD:**
```
void doSomething(BuildContext context) {
  await Navigator.of(context).push(...);
  Navigator.of(context).pop();
}
```
''';

  StaleBuildContextLint()
      : super(
            name: 'stale_buildcontext',
            description: _desc,
            details: _details,
            group: Group.errors);

  @override
  void registerNodeProcessors(NodeLintRegistry registry, [LinterContext context]) {
    var visitor = _StaleBuildContextVisitor(this);

    registry.addMethodDeclaration(this, visitor);
    registry.addFunctionDeclaration(this, visitor);
  }
}

class _StaleBuildContextVisitor extends RecursiveAstVisitor {

  _StaleBuildContextVisitor(this.rule);

  final LintRule rule;
  final _Scope scope = _Scope();

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
    if (node.functionExpression.body.isAsynchronous) {
      scope.push();
      super.visitFunctionDeclaration(node);
      scope.pop();
    }
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
    super.visitSimpleFormalParameter(node);
  }

  @override 
  void visitVariableDeclaration(VariableDeclaration node) {
    scope.addLocalIdentifier(node.name.name, '???');
    super.visitVariableDeclaration(node);
  }

  @override
  void visitIfStatement(IfStatement node) {
    super.visitIfStatement(node);
  }

  @override
  void visitBlock(Block node) {
    super.visitBlock(node);
  }

  @override
  void visitSimpleIdentifier(SimpleIdentifier node) {
    var id = node.name;
    if (scope.isBuildContext(id) && scope.didAwaitSinceIdentifierWasDefined(id) /*&& filePath?.contains('/test/') == false*/) {
      rule.reportLint(node);
    }
    super.visitSimpleIdentifier(node);
  }
}

class _BlockContext {
  final Map<String, String> localScopaBuildIdentifiers = {}; // name => type
  bool didAlreadyAwait = false;
}

class _Scope {
  final List<_BlockContext> _stack = [_BlockContext()];
  _BlockContext get latestScope => _stack.last; 

  void push() => _stack.add(_BlockContext());

  void pop() => _stack.removeLast();

  void setDidAwait() => latestScope.didAlreadyAwait = true;

  void addLocalIdentifier(String name, String type) => latestScope.localScopaBuildIdentifiers[name] = type;

  bool didAwaitSinceIdentifierWasDefined(String identifier) => latestScope.didAlreadyAwait;

  bool isBuildContext(String identifier) => identifier == 'context';
}
