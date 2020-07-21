
import 'package:flutter/material.dart';

class MyWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
     return InkWell(
      onTap: () async {
        await Navigator.of(context).push(null);
        await Navigator.of(context).push(null);
      }, 
      child: Text('hello', style: Theme.of(context).textTheme.bodyText1),
    );
  }
}

Future<void> test(BuildContext context) async {
  final object = HasContextProperty();
  Future<void> test() async {
    // this should not flag the outer scope
    await Future.delayed(const Duration(seconds: 1));
  }
  Theme.of(context); // no issue here
  await test();
  // TODO(caldavis): Theme.of(object.context); // don't complain about "context" properties accessed
  // don't complain about parameters named "context"
  Navigator.of(context).pop();
}

Future<void> test2(BuildContext context, bool d) async {  // ignore: unnecessary_final, unused_local_variable
  final aliased = context;
  if (d) {
    await Future.delayed(const Duration(seconds: 1));
    Theme.of(context);
  } else {
    // TODO(caldavis): Theme.of(context); // no issue here because only await is in the previous conditional block that can't be executed if we get here
  }
  Navigator.of(context).pop();
  // ignore: unnecessary_final, unused_local_variable
  final a = context;
  Navigator.of(aliased).pop(); // TODO(caldavis): can we get this to fail?
  // TODO(caldavis): await testNonBuildContextIdNamedContext(context: 1); // not a BuildContext identifier - don't report
}

Future testWhile(BuildContext context, int count) async {
  var remaining = count;
  while(remaining > 0) {
    Theme.of(context); // TODO(caldavis): this should fail
    await test(context);
  }
}



Future<void> testNonBuildContextIdNamedContext({int context}) async {
  await test(context);
  // ignore: unnecessary_final, unused_local_variable
  // TODO: this shouldn't be an error -  final a = context;
}

class HasContextProperty {
  final BuildContext context = null;
}