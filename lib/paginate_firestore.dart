library paginate_firestore;

import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:provider/provider.dart';

import 'bloc/pagination_cubit.dart';
import 'bloc/pagination_listeners.dart';
import 'widgets/bottom_loader.dart';
import 'widgets/empty_display.dart';
import 'widgets/empty_separator.dart';
import 'widgets/error_display.dart';
import 'widgets/initial_loader.dart';

class PaginateFirestore extends StatefulWidget {
  const PaginateFirestore({
    Key? key,
    required this.itemBuilder,
    required this.queryProvider,
    this.gridDelegate =
        const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2),
    this.startAfterDocument,
    this.itemsPerPage = 15,
    this.onError,
    this.onReachedEnd,
    this.onLoaded,
    this.onEmpty = const EmptyDisplay(),
    this.separator = const EmptySeparator(),
    this.initialLoader = const InitialLoader(),
    this.bottomLoader = const BottomLoader(),
    this.shrinkWrap = false,
    this.reverse = false,
    this.scrollDirection = Axis.vertical,
    this.padding = const EdgeInsets.all(0),
    this.physics,
    this.listeners,
    this.scrollController,
    this.allowImplicitScrolling = false,
    this.keyboardDismissBehavior = ScrollViewKeyboardDismissBehavior.manual,
    this.pageController,
    this.onPageChanged,
    this.header,
    this.footer,
    this.isLive = false,
    this.includeMetadataChanges = false,
    this.options,
  }) : super(key: key);

  final Widget bottomLoader;
  final Widget onEmpty;
  final SliverGridDelegate gridDelegate;
  final Widget initialLoader;
  final int itemsPerPage;
  final List<ChangeNotifier>? listeners;
  final EdgeInsets padding;
  final ScrollPhysics? physics;
  final QueryChangeListener queryProvider;
  final bool reverse;
  final bool allowImplicitScrolling;
  final ScrollViewKeyboardDismissBehavior keyboardDismissBehavior;
  final ScrollController? scrollController;
  final PageController? pageController;
  final Axis scrollDirection;
  final Widget separator;
  final bool shrinkWrap;
  final bool isLive;
  final DocumentSnapshot? startAfterDocument;
  final Widget? header;
  final Widget? footer;

  /// Use this only if `isLive = false`
  final GetOptions? options;

  /// Use this only if `isLive = true`
  final bool includeMetadataChanges;

  @override
  _PaginateFirestoreState createState() => _PaginateFirestoreState();

  final Widget Function(Exception)? onError;

  final Widget Function(BuildContext, List<DocumentSnapshot>, int) itemBuilder;

  final void Function(PaginationLoaded)? onReachedEnd;

  final void Function(PaginationLoaded)? onLoaded;

  final void Function(int)? onPageChanged;
}

class _PaginateFirestoreState extends State<PaginateFirestore> {
  PaginationCubit? _cubit;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<PaginationCubit, PaginationState>(
      bloc: _cubit,
      builder: (context, state) {
        Widget? overrideWidget;
        PaginationLoaded? loadedState;
        if (state is PaginationInitial) {
          overrideWidget = widget.initialLoader;
        } else if (state is PaginationError) {
          return _buildWithScrollView(
              context,
              (widget.onError != null)
                  ? widget.onError!(state.error)
                  : ErrorDisplay(exception: state.error));
        } else {
          loadedState = state as PaginationLoaded;
          if (widget.onLoaded != null) {
            widget.onLoaded!(loadedState);
          }
          if (loadedState.hasReachedEnd && widget.onReachedEnd != null) {
            widget.onReachedEnd!(loadedState);
          }

          if (loadedState.documentSnapshots.isEmpty) {
            overrideWidget = widget.onEmpty;
          }
        }
        return _buildListView(loadedState, overrideWidget: overrideWidget);
      },
    );
  }

  Widget _buildWithScrollView(BuildContext context, Widget child) {
    return SingleChildScrollView(
      child: Container(
        alignment: Alignment.center,
        height: MediaQuery.of(context).size.height,
        child: child,
      ),
    );
  }

  @override
  void dispose() {
    widget.queryProvider.removeListener(queryListener);
    widget.scrollController?.dispose();
    _cubit?.dispose();
    super.dispose();
  }

  @override
  void initState() {
    if (widget.listeners != null) {
      for (var listener in widget.listeners!) {
        if (listener is PaginateRefreshedChangeListener) {
          listener.addListener(() {
            if (listener.refreshed) {
              _cubit!.refreshPaginatedList();
            }
          });
        } else if (listener is PaginateFilterChangeListener) {
          listener.addListener(() {
            if (listener.searchTerm.isNotEmpty) {
              _cubit!.filterPaginatedList(listener.searchTerm);
            }
          });
        }
      }
    }

    widget.queryProvider.addListener(queryListener);
    _updateQuery(widget.queryProvider.query);
    super.initState();
  }

  queryListener() {
    setState(() {
      _updateQuery(widget.queryProvider.query);
    });
  }

  _updateQuery(Query query) {
    _cubit = PaginationCubit(
      query,
      widget.itemsPerPage,
      widget.startAfterDocument,
      isLive: widget.isLive,
    )..fetchPaginatedList();
  }

  Widget _buildListView(PaginationLoaded? loadedState,
      {Widget? overrideWidget}) {
    var listView = CustomScrollView(
      reverse: widget.reverse,
      controller: widget.scrollController,
      shrinkWrap: widget.shrinkWrap,
      scrollDirection: widget.scrollDirection,
      physics: widget.physics,
      keyboardDismissBehavior: widget.keyboardDismissBehavior,
      slivers: [
        if (widget.header != null) widget.header!,
        (overrideWidget != null)
            ? SliverToBoxAdapter(child: overrideWidget)
            : (loadedState != null)
                ? SliverPadding(
                    padding: widget.padding,
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final itemIndex = index ~/ 2;
                          if (index.isEven) {
                            if (itemIndex >=
                                loadedState.documentSnapshots.length) {
                              _cubit!.fetchPaginatedList();
                              return widget.bottomLoader;
                            }
                            return widget.itemBuilder(
                              context,
                              loadedState.documentSnapshots,
                              itemIndex,
                            );
                          }
                          return widget.separator;
                        },
                        semanticIndexCallback: (widget, localIndex) {
                          if (localIndex.isEven) {
                            return localIndex ~/ 2;
                          }
                          // ignore: avoid_returning_null
                          return null;
                        },
                        childCount: max(
                            0,
                            (loadedState.hasReachedEnd
                                        ? loadedState.documentSnapshots.length
                                        : loadedState.documentSnapshots.length +
                                            1) *
                                    2 -
                                1),
                      ),
                    ),
                  )
                : Container(),
        if (widget.footer != null) widget.footer!,
      ],
    );

    if (widget.listeners != null && widget.listeners!.isNotEmpty) {
      return MultiProvider(
        providers: widget.listeners!
            .map((_listener) => ChangeNotifierProvider(
                  create: (context) => _listener,
                ))
            .toList(),
        child: listView,
      );
    }

    return listView;
  }
}

enum PaginateBuilderType { listView, gridView, pageView }
