import 'dart:io';

import 'package:pagination_toolkit/pagination_toolkit.dart';

Future<void> main() async {
  final pager = PagePager<String>(
    pageSize: 2,
    idOf: (item) => item,
    fetch: (page, pageSize) async {
      return switch (page) {
        1 => const ItemBatch(items: ['studio', 'site'], hasMore: true),
        _ => const ItemBatch(items: ['site', 'critique'], hasMore: false),
      };
    },
  );

  await pager.refresh();
  await pager.loadMore();
  final state = pager.state;
  if (state is! PagingReady<String> ||
      state.items.join(',') != 'studio,site,critique' ||
      state.hasMore) {
    stderr.writeln('example failed: $state');
    exitCode = 1;
    return;
  }
  stdout.writeln(state.items.join(','));
}
