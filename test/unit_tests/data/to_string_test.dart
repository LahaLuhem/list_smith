import 'dart:io';

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:bdd_framework/bdd_framework.dart';
import 'package:checks/checks.dart';
import 'package:flutter/widgets.dart';
import 'package:list_smith/src/data/edits/edits.dart';
import 'package:list_smith/src/data/grouping/grouping.dart';
import 'package:list_smith/src/data/pagination/pagination.dart';
import 'package:list_smith/src/data/presentation/presentation.dart';
import 'package:list_smith/src/data/refresh/refresh.dart';
import 'package:list_smith/src/data/search/search.dart';
import 'package:list_smith/src/data/source/source.dart';

void main() {
  final toStringFeature = BddFeature('Value type toString');

  Bdd(toStringFeature)
      .scenario('each value type shows every field by name, with its value')
      .given(
        'a value of each class with fields to show, under lib/src/data or with its own toString',
      )
      .when('each value is turned into a string')
      .then('each of those fields reads as name: value')
      .run((_) {
        final fieldNamesToShowByClassName = Map.fromEntries(
          Directory('lib/src')
              .listSync(recursive: true)
              .whereType<File>()
              .where((file) => file.path.endsWith('.dart'))
              .expand((file) {
                final isUnderData = file.uri.path.startsWith('lib/src/data/');

                return parseString(
                  content: file.readAsStringSync(),
                  featureSet: .latestLanguageVersion(),
                ).unit.declarations.whereType<ClassDeclaration>().where(
                  (declaration) =>
                      isUnderData ||
                      declaration.body.members.whereType<MethodDeclaration>().any(
                        (member) => member.name.lexeme == 'toString',
                      ),
                );
              })
              .where((declaration) {
                final className = declaration.namePart.typeName.lexeme;

                return !className.startsWith('_') && !_opaqueTypeNames.contains(className);
              })
              .map((declaration) {
                final namePart = declaration.namePart;
                final parameterNames = namePart is PrimaryConstructorDeclaration
                    ? namePart.formalParameters.parameters
                          .where(
                            (parameter) =>
                                (parameter is SuperFormalParameter ||
                                    parameter.finalKeyword != null ||
                                    parameter.varKeyword != null) &&
                                _isShown(parameter.type, parameter.metadata),
                          )
                          .map((parameter) => parameter.name?.lexeme)
                          .nonNulls
                    : const <String>[];
                final bodyFieldNames = declaration.body.members
                    .whereType<FieldDeclaration>()
                    .where(
                      (member) => !member.isStatic && _isShown(member.fields.type, member.metadata),
                    )
                    .expand((member) => member.fields.variables)
                    .map((variable) => variable.name.lexeme);

                return MapEntry(
                  namePart.typeName.lexeme,
                  parameterNames
                      .followedBy(bodyFieldNames)
                      .where((name) => !name.startsWith('_'))
                      .toSet(),
                );
              })
              .where((entry) => entry.value.isNotEmpty),
        );
        check(
          _samplesByClassName.map(
            (name, sample) => MapEntry(name, sample.shownValuesByField.keys.toSet()),
          ),
        ).deepEquals(fieldNamesToShowByClassName);

        final hiddenFieldNamesByClassName = Map.fromEntries(
          _samplesByClassName
              .map(
                (name, sample) => MapEntry(
                  name,
                  sample.shownValuesByField.entries
                      .where((field) => !'${sample.value}'.contains('${field.key}: ${field.value}'))
                      .map((field) => field.key)
                      .toSet(),
                ),
              )
              .entries
              .where((entry) => entry.value.isNotEmpty),
        );
        check(hiddenFieldNamesByClassName).isEmpty();
      });
}

typedef _Sample = ({Object value, Map<String, Object?> shownValuesByField});

/// One table, since the check against the source reads it whole.
final _samplesByClassName = <String, _Sample>{
  'AdvanceToFirstNonEmpty': _sample(
    const AdvanceToFirstNonEmpty(maxPages: 5),
    (behaviour) => {'maxPages': behaviour.maxPages},
  ),
  'AnimatedEditTransition': _sample(
    const EditTransition(
      duration: Duration(milliseconds: 250),
      transitionBuilder: AnimatedSwitcher.defaultTransitionBuilder,
    ) as AnimatedEditTransition,
    (transition) => {'duration': transition.duration},
  ),
  'AsyncSearch': _sample(
    AsyncSearch<int>(
      fetchPage: SearchPageFetcher((_) async => const []),
      cachePolicy: const KeepCachePolicy(),
    ),
    (search) => {'cachePolicy': search.cachePolicy},
  ),
  'AsyncSource': _sample(
    AsyncSource<int>(
      fetchPage: PageFetcher((_) async => const []),
      pageSize: 17,
      endPolicy: const FixedPageCountPolicy(pageCount: 4),
      onEmptyPage: const ShowEmptySurface(),
      refresh: const NoRefresh(),
      search: const NoSearch(),
      itemIdGetter: (item) => item,
      editTransition: const NoEditTransition(),
      order: const UnknownOrder(),
      shouldKeepPosition: true,
    ),
    (source) => {
      'pageSize': source.pageSize,
      'endPolicy': source.endPolicy,
      'onEmptyPage': source.onEmptyPage,
      'refresh': source.refresh,
      'search': source.search,
      'editTransition': source.editTransition,
      'order': source.order,
      'shouldKeepPosition': source.shouldKeepPosition,
    },
  ),
  'CellLayout': _sample(
    const CellLayout(
      itemCount: 5,
      hasSeparators: true,
      hasFooter: false,
      headers: [(itemIndex: 0, key: 'a'), (itemIndex: 3, key: 'b')],
      isHeaderAfterItem: true,
    ),
    (layout) => {
      'itemCount': layout.itemCount,
      'hasSeparators': layout.hasSeparators,
      'hasFooter': layout.hasFooter,
      'headers': layout.headers,
      'isHeaderAfterItem': layout.isHeaderAfterItem,
    },
  ),
  'EmptyPageContext': _sample(
    const EmptyPageContext(isEmpty: true, isMoreAvailable: false, pagesLoaded: 3),
    (context) => {
      'isEmpty': context.isEmpty,
      'isMoreAvailable': context.isMoreAvailable,
      'pagesLoaded': context.pagesLoaded,
    },
  ),
  'EndContext': _sample(
    const EndContext(pageItemCounts: [17, 17, 3], pageSize: 17, lastPageSignal: 'cursor-37'),
    (context) => {
      'pageItemCounts': context.pageItemCounts,
      'pageSize': context.pageSize,
      'lastPageSignal': context.lastPageSignal,
    },
  ),
  'FixedPageCountPolicy': _sample(
    const FixedPageCountPolicy(pageCount: 4),
    (policy) => {'pageCount': policy.pageCount},
  ),
  'GroupHeaders': _sample(
    GroupHeaders(
      headers: const [(itemIndex: 0, key: 'a'), (itemIndex: 2, key: 'b')],
      headerFor: (_, _) => const SizedBox(),
    ),
    (groupHeaders) => {'headers': groupHeaders.headers},
  ),
  'ItemEdit': _sample(
    const ItemEdit<int>(item: 7, stamp: 3),
    (edit) => {'item': edit.item, 'stamp': edit.stamp},
  ),
  'KeyedGrouping': _sample(
    Grouping.by<int, int>(
      groupBy: (item) => item ~/ 10,
      headerBuilder: (_, _) => const SizedBox(),
      orderPolicy: const FailOnUnorderedPolicy(),
    ) as KeyedGrouping<int>,
    (grouping) => {'orderPolicy': grouping.orderPolicy},
  ),
  'ListScrollConfig': _sample(
    const ListScrollConfig(
      padding: EdgeInsets.all(7),
      physics: BouncingScrollPhysics(),
      reverse: true,
      scrollDirection: .horizontal,
      cacheExtent: 300,
    ),
    (config) => {
      'padding': config.padding,
      'physics': config.physics,
      'reverse': config.reverse,
      'scrollDirection': config.scrollDirection,
      'cacheExtent': config.cacheExtent,
    },
  ),
  'ListSmithRefreshState': _sample(
    const ListSmithRefreshState(phase: .armed, value: 0.5, pullDirection: .up),
    (state) => {'phase': state.phase, 'value': state.value, 'pullDirection': state.pullDirection},
  ),
  'LoadedPage': _sample(
    const LoadedPage(items: [1, 2, 3], readStamp: 4, previousSignal: 'cursor-3'),
    (page) => {
      'items': page.items.length,
      'readStamp': page.readStamp,
      'previousSignal': page.previousSignal,
    },
  ),
  'PageRequest': _sample(
    const PageRequest(pageIndex: 2, pageSize: 17, trigger: .nextPage, previousSignal: 'cursor-34'),
    (request) => {
      'pageIndex': request.pageIndex,
      'pageSize': request.pageSize,
      'trigger': request.trigger,
      'previousSignal': request.previousSignal,
    },
  ),
  'PagingState': _sample(
    PagingState<int>(
      pages: const [
        LoadedPage(items: [1], readStamp: 0),
        LoadedPage(items: [2], readStamp: 0),
      ],
      exception: Exception('network'),
      hasNextPage: false,
      isLoading: true,
    ),
    (state) => {
      'pages': state.pages?.length,
      'exception': state.exception,
      'hasNextPage': state.hasNextPage,
      'isLoading': state.isLoading,
    },
  ),
  'PullToRefresh': _sample(
    const PullToRefresh(
      indicatorExtent: 80,
      reload: ReloadToCurrentDepth(concurrency: 2),
      pullableSurfaces: {.error},
    ),
    (refresh) => {
      'indicatorExtent': refresh.indicatorExtent,
      'reload': refresh.reload,
      'pullableSurfaces': refresh.pullableSurfaces,
    },
  ),
  'ReloadToCurrentDepth': _sample(
    const ReloadToCurrentDepth(concurrency: 3),
    (reload) => {'concurrency': reload.concurrency},
  ),
  'SearchPageRequest': _sample(
    const SearchPageRequest(
      query: 'tea',
      pageIndex: 1,
      pageSize: 17,
      trigger: .queryChanged,
      previousSignal: 'cursor-17',
    ),
    (request) => {
      'query': request.query,
      'pageIndex': request.pageIndex,
      'pageSize': request.pageSize,
      'trigger': request.trigger,
      'previousSignal': request.previousSignal,
    },
  ),
  'StopOnEmptyPagesPolicy': _sample(
    const StopOnEmptyPagesPolicy(emptyRunBeforeEnd: 3),
    (policy) => {'emptyRunBeforeEnd': policy.emptyRunBeforeEnd},
  ),
  'SyncSource': _sample(
    SyncSource<int>(items: const [1, 2, 3], searchBy: (_, _) => true, shouldKeepPosition: true),
    (source) => {'items': source.items.length, 'shouldKeepPosition': source.shouldKeepPosition},
  ),
};

_Sample _sample<T extends Object>(
  T value,
  Map<String, Object?> Function(T value) shownValuesGetter,
) => (value: value, shownValuesByField: shownValuesGetter(value));

/// Callbacks, fetchers and controllers, which CODESTYLE has toString skip, and which need none of
/// their own.
const _opaqueTypeNames = {
  'AnimatedSwitcherTransitionBuilder',
  'Comparator',
  'ErrorBuilder',
  'GroupHeaderBuilder',
  'GroupKeyOf',
  'ItemIdGetter',
  'PageFetcher',
  'RefreshIndicatorBuilder',
  'ScrollController',
  'SearchPageFetcher',
  'SyncSearchPredicate',
  'WidgetBuilder',
};

bool _isShown(TypeAnnotation? type, NodeList<Annotation> metadata) =>
    !metadata.any((annotation) => annotation.name.name == 'Deprecated') &&
    !(type is NamedType && _opaqueTypeNames.contains(type.name.lexeme));
