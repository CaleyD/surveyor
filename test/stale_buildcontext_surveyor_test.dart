//  Copyright 2020 Google LLC
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

import 'package:surveyor/src/driver.dart';
import 'package:test/test.dart';

import '../example/stale_buildcontext_surveyor.dart';

Future<void> main() async {
  group('Stale BuildContext survey', () {
    test('stale', () async {
      // TODO(caldavis): convert to relative path
      expect(
        await analyze('test/data/stale_build_context_app'), 
        [
          allOf(startsWith('error • stale_buildcontext • '), endsWith('/test/data/stale_build_context_app/lib/main.dart:10:28')),
          allOf(startsWith('error • stale_buildcontext • '), endsWith('/test/data/stale_build_context_app/lib/main.dart:27:16')),
          allOf(startsWith('error • stale_buildcontext • '), endsWith('/test/data/stale_build_context_app/lib/main.dart:34:14')),
          allOf(startsWith('error • stale_buildcontext • '), endsWith('/test/data/stale_build_context_app/lib/main.dart:38:16')),
          allOf(startsWith('error • stale_buildcontext • '), endsWith('/test/data/stale_build_context_app/lib/main.dart:40:13')),
        ],
      );
    });
  });
}

Future<Iterable<String>> analyze(String path) async {
  var collector = StaleBuildContextAnalyzer();
  await (Driver.forArgs([path])..visitor = collector).analyze();
  return collector.issues.map((e) => e.toString()).toList();
}