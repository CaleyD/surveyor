
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
  Future<void> test() async {
    // this should not flag the outer scope
    await Future.delayed(const Duration(seconds: 1));
  }
  Theme.of(context); // no issue here
  await test();
  Navigator.of(context).pop();
}

Future<void> test2(BuildContext context, bool d) async {
  if (d) {
    await Future.delayed(const Duration(seconds: 1));
    Theme.of(context);
  } else {
    // TODO(caldavis): Theme.of(context); // no issue here because only await is in the previous conditional block that can't be executed if we get here
  }
  Navigator.of(context).pop();
}

Future testWhile(BuildContext context, int count) async {
  var remaining = count;
  while(remaining > 0) {
    Theme.of(context); // TODO(caldavis): this should fail
    await test(context);
  }
}