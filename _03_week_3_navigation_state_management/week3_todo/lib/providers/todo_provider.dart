import 'package:flutter_riverpod/flutter_riverpod.dart';

class Todo {
  final String id;
  final String title;
  final String category;
  final bool done;

  Todo({
    required this.id,
    required this.title,
    required this.category,
    this.done = false,
  });

  Todo copyWith({String? title, String? category, bool? done}) {
    return Todo(
      id: id,
      title: title ?? this.title,
      category: category ?? this.category,
      done: done ?? this.done,
    );
  }
}

class TodoListNotifier extends Notifier<List<Todo>> {
  @override
  List<Todo> build() => [
        Todo(id: '1', title: 'Rancang UI Dashboard', category: 'Desain', done: true),
        Todo(id: '2', title: 'Implementasi Riverpod State', category: 'Koding', done: false),
      ];

  void add(String title, String category) {
    state = [
      ...state,
      Todo(id: DateTime.now().toString(), title: title, category: category),
    ];
  }

  void toggle(String id) {
    state = [
      for (final todo in state)
        if (todo.id == id) todo.copyWith(done: !todo.done) else todo
    ];
  }

  void remove(String id) {
    state = state.where((todo) => todo.id != id).toList();
  }
}

final todoListProvider = NotifierProvider<TodoListNotifier, List<Todo>>(TodoListNotifier.new);

enum TodoCategoryFilter { all, desain, koding, lainnya }

class TodoFilterNotifier extends Notifier<TodoCategoryFilter> {
  @override
  TodoCategoryFilter build() => TodoCategoryFilter.all;

  void setFilter(TodoCategoryFilter filter) => state = filter;
}

final todoFilterProvider = NotifierProvider<TodoFilterNotifier, TodoCategoryFilter>(TodoFilterNotifier.new);

final filteredTodosProvider = Provider<List<Todo>>((ref) {
  final filter = ref.watch(todoFilterProvider);
  final todos = ref.watch(todoListProvider);

  switch (filter) {
    case TodoCategoryFilter.desain:
      return todos.where((t) => t.category == 'Desain').toList();
    case TodoCategoryFilter.koding:
      return todos.where((t) => t.category == 'Koding').toList();
    case TodoCategoryFilter.lainnya:
      return todos.where((t) => t.category == 'Lainnya').toList();
    case TodoCategoryFilter.all:
      return todos;
  }
});