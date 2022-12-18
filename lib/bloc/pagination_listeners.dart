import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/widgets.dart';

class PaginateChangeListener extends ChangeNotifier {}

class PaginateRefreshedChangeListener extends PaginateChangeListener {
  PaginateRefreshedChangeListener();

  bool _refreshed = false;

  set refreshed(bool value) {
    _refreshed = value;
    if (value) {
      notifyListeners();
    }
  }

  bool get refreshed {
    return _refreshed;
  }
}

class PaginateFilterChangeListener extends PaginateChangeListener {
  PaginateFilterChangeListener();

  late String _filterTerm;

  set searchTerm(String value) {
    _filterTerm = value;
    if (value.isNotEmpty) {
      notifyListeners();
    }
  }

  String get searchTerm {
    return _filterTerm;
  }
}

class QueryChangeListener<T extends Object?> extends PaginateChangeListener {
  Query<T> _query;

  QueryChangeListener(this._query);

  set query(Query<T> query) {
    _query = query;
    notifyListeners();
  }

  Query<T> get query {
    return _query;
  }
}
