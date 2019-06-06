import 'dart:io';

import 'package:analyzer/dart/analysis/analysis_context.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:surveyor/src/driver.dart';
import 'package:surveyor/src/visitors.dart';

import 'package:path/path.dart' as path;

/// Analyzes projects, filtering specifically for errors of a specified type.
///
/// Run like so:
///
/// dart example/error_surveyor.dart <source dir>
main(List<String> args) async {
  if (args.length == 1) {
    final dir = args[0];
    if (!File('$dir/pubspec.yaml').existsSync()) {
      print("Recursing into '$dir'...");

      args = Directory(dir)
          .listSync()
          .where(
              (f) => !path.basename(f.path).startsWith('.') && f is Directory)
          .map((f) => f.path)
          .toList()
            ..sort();
      dirCount = args.length;
      print('(Found $dirCount subdirectories.)');
    }
  }

  if (_debuglimit != null) {
    print('Limiting analysis to $_debuglimit packages.');
  }

  final driver = Driver.forArgs(args);
  driver.visitor = AnalysisAdvisor();
  driver.showErrors = true;

  await driver.analyze();
}

int dirCount;

class AnalysisAdvisor extends SimpleAstVisitor
    implements PreAnalysisCallback, PostAnalysisCallback {
  int count = 0;

  @override
  void postAnalysis(AnalysisContext context, DriverCommands cmd) {
    cmd.continueAnalyzing = _debuglimit == null || count < _debuglimit;
  }

  @override
  void preAnalysis(AnalysisContext context,
      {bool subDir, DriverCommands commandCallback}) {
    if (subDir) {
      ++dirCount;
    }
    final root = context.contextRoot.root;
    String dirName = path.basename(root.path);
    if (subDir) {
      // Qualify.
      dirName = '${path.basename(root.parent.path)}/$dirName';
    }
    print("Analyzing '$dirName' • [${++count}/$dirCount]...");
  }
}

//
/// If non-null, stops once limit is reached (for debugging).
int _debuglimit = 100;
