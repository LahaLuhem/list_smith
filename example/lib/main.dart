import 'package:flutter/material.dart';
import 'package:list_smith/list_smith.dart';

void main() => runApp(const ListSmithExampleApp());

/// Placeholder demo for `list_smith`.
///
/// The package's list widgets are still being designed, so this app only
/// exercises the (temporary) public API to keep the example wired to the
/// package. It grows into a real pagination / pull-to-refresh / search
/// showcase once the API lands.
class ListSmithExampleApp extends StatelessWidget {
  const ListSmithExampleApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'list_smith example',
    theme: ThemeData(colorScheme: .fromSeed(seedColor: Colors.indigo)),
    home: const _HomePage(),
  );
}

class _HomePage extends StatefulWidget {
  const _HomePage();

  @override
  State<_HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<_HomePage> {
  final _calculator = Calculator();
  var _count = 0;

  void _increment() => setState(() => _count = _calculator.addOne(_count));

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('list_smith example')),
    body: Center(
      child: Column(
        mainAxisAlignment: .center,
        spacing: 8,
        children: [
          const Text('list_smith list widgets are coming soon.'),
          Text('$_count', style: Theme.of(context).textTheme.headlineMedium),
        ],
      ),
    ),
    floatingActionButton: FloatingActionButton(
      onPressed: _increment,
      tooltip: 'Increment via Calculator.addOne',
      child: const Icon(Icons.add),
    ),
  );
}
