import 'package:flutter/material.dart';
import 'package:list_smith/list_smith.dart';

void main() => runApp(const ListSmithExampleApp());

/// Demo app for `list_smith`: an async paginated list with pull-to-refresh,
/// dropped into a Material app to show the neutral defaults inherit the app's
/// look without list_smith importing Material itself.
class ListSmithExampleApp extends StatelessWidget {
  const ListSmithExampleApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'list_smith example',
    theme: ThemeData(colorScheme: .fromSeed(seedColor: Colors.indigo)),
    home: const _HomePage(),
  );
}

class _HomePage extends StatelessWidget {
  const _HomePage();

  static const _pageCount = 5;
  static const _fetchDelay = Duration(milliseconds: 600);

  /// A fake async source: five pages of items, then an empty page so
  /// [StopOnEmptyPages] ends the list.
  Future<List<String>> _fetchPage(int pageIndex, int pageSize) async {
    await Future<void>.delayed(_fetchDelay);
    if (pageIndex >= _pageCount) return const <String>[];

    return List.generate(pageSize, (index) => 'Item ${pageIndex * pageSize + index + 1}');
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('list_smith example')),
    body: ListSmith<String>.async(
      fetchPage: _fetchPage,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (_, item, _) => ListTile(title: Text(item)),
    ),
  );
}
