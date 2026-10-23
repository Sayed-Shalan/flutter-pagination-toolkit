import 'dart:async';

import 'package:pagination_toolkit/pagination_toolkit.dart';
import 'package:test/test.dart';

void main() {
  test(
    'page mode appends, dedupes ids, and ignores a second loadMore',
    () async {
      final gate = Completer<void>();
      var calls = 0;
      final pager = PagePager<({String id, String label})>(
        pageSize: 2,
        idOf: (item) => item.id,
        fetch: (page, pageSize) async {
          calls += 1;
          if (page == 1) {
            return ItemBatch(
              items: [(id: '1', label: 'one'), (id: '2', label: 'two')],
              hasMore: true,
            );
          }
          await gate.future;
          return ItemBatch(
            items: [(id: '2', label: 'two-again'), (id: '3', label: 'three')],
            hasMore: false,
          );
        },
      );

      await pager.refresh();
      final first = pager.state as PagingReady<({String id, String label})>;
      expect(first.items.map((item) => item.id), ['1', '2']);
      expect(first.hasMore, isTrue);

      final firstMore = pager.loadMore();
      final secondMore = pager.loadMore();
      await Future<void>.delayed(Duration.zero);
      expect(calls, 2);

      gate.complete();
      await Future.wait([firstMore, secondMore]);
      final ready = pager.state as PagingReady<({String id, String label})>;
      expect(ready.items.map((item) => item.id), ['1', '2', '3']);
      expect(ready.items[1].label, 'two');
      expect(ready.hasMore, isFalse);
      expect(calls, 2);
    },
  );

  test('a newer refresh drops a stale page', () async {
    final firstGate = Completer<void>();
    var calls = 0;
    final pager = PagePager<String>(
      pageSize: 1,
      idOf: (item) => item,
      fetch: (page, pageSize) async {
        calls += 1;
        if (calls == 1) {
          await firstGate.future;
          return const ItemBatch(items: ['stale'], hasMore: false);
        }
        return const ItemBatch(items: ['fresh'], hasMore: false);
      },
    );

    final stale = pager.refresh();
    await Future<void>.delayed(Duration.zero);
    final fresh = pager.refresh();
    firstGate.complete();
    await Future.wait([stale, fresh]);

    expect((pager.state as PagingReady<String>).items, ['fresh']);
  });

  test('retry replaces a failed first page', () async {
    var calls = 0;
    final pager = PagePager<String>(
      pageSize: 1,
      idOf: (item) => item,
      fetch: (page, pageSize) async {
        calls += 1;
        if (calls == 1) {
          throw StateError('down');
        }
        return const ItemBatch(items: [], hasMore: false);
      },
    );

    await pager.refresh();
    expect((pager.state as PagingFailure<String>).error, isA<StateError>());
    await pager.retry();
    final ready = pager.state as PagingReady<String>;
    expect(ready.isEmpty, isTrue);
  });

  test('cursor mode stops when the next cursor is null', () async {
    final seen = <String?>[];
    final pager = CursorPager<String>(
      limit: 2,
      idOf: (item) => item,
      fetch: (cursor, limit) async {
        seen.add(cursor);
        if (cursor == null) {
          return const ItemBatch(
            items: ['a', 'b'],
            hasMore: true,
            nextCursor: 'c2',
          );
        }
        return const ItemBatch(
          items: ['b', 'c'],
          hasMore: true,
          nextCursor: null,
        );
      },
    );

    await pager.refresh();
    await pager.loadMore();
    final ready = pager.state as PagingReady<String>;
    expect(seen, [null, 'c2']);
    expect(ready.items, ['a', 'b', 'c']);
    expect(ready.hasMore, isFalse);
    await pager.loadMore();
    expect(seen, [null, 'c2']);
  });
}
