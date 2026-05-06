import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../models/todo_model.dart';
import '../db/database_helper.dart';
import 'add_edit_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  final _dbHelper = DatabaseHelper();
  late TabController _tabController;
  final _searchController = TextEditingController();

  List<TodoModel> _todos = [];
  List<TodoModel> _notes = [];
  List<TodoModel> _searchResults = [];

  bool _isSearching = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final todos = await _dbHelper.getTodosByCategory('todo');
    final notes = await _dbHelper.getTodosByCategory('note');
    setState(() {
      _todos = todos;
      _notes = notes;
      _isLoading = false;
    });
  }

  Future<void> _search(String keyword) async {
    if (keyword.trim().isEmpty) {
      setState(() {
        _isSearching = false;
        _searchResults = [];
      });
      return;
    }
    final results = await _dbHelper.searchTodos(keyword);
    setState(() {
      _isSearching = true;
      _searchResults = results;
    });
  }

  Future<void> _toggleComplete(TodoModel todo) async {
    await _dbHelper.toggleComplete(todo.id!, !todo.isCompleted);
    _loadData();
  }

  Future<void> _delete(TodoModel todo) async {
    await _dbHelper.deleteTodo(todo.id!);
    _loadData();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Đã xóa "${todo.title}"'),
          action: SnackBarAction(
            label: 'Hoàn tác',
            onPressed: () async {
              await _dbHelper.insertTodo(todo.copyWith(id: null));
              _loadData();
            },
          ),
        ),
      );
    }
  }

  void _openAddEdit({TodoModel? todo}) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => AddEditScreen(todo: todo)),
    );
    if (result == true) _loadData();
  }

  Future<void> _deleteCompleted() async {
    final count = await _dbHelper.deleteCompleted();
    _loadData();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Đã xóa $count mục hoàn thành')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.background,
      body: NestedScrollView(
        headerSliverBuilder: (_, __) => [
          SliverAppBar(
            floating: true,
            snap: true,
            backgroundColor: theme.colorScheme.background,
            elevation: 0,
            title: _isSearching
                ? null
                : Text(
                    'My Tasks',
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.bold,
                      fontSize: 22,
                    ),
                  ),
            actions: [
              // Nút xóa hoàn thành
              if (!_isSearching)
                PopupMenuButton(
                  icon: const Icon(Icons.more_vert_rounded),
                  itemBuilder: (_) => [
                    PopupMenuItem(
                      onTap: _deleteCompleted,
                      child: const Row(
                        children: [
                          Icon(Icons.delete_sweep_rounded, color: Colors.red),
                          SizedBox(width: 8),
                          Text('Xóa đã hoàn thành'),
                        ],
                      ),
                    ),
                  ],
                ),
            ],
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(110),
              child: Column(
                children: [
                  // Search bar
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: TextField(
                      controller: _searchController,
                      onChanged: _search,
                      decoration: InputDecoration(
                        hintText: 'Tìm kiếm...',
                        hintStyle: GoogleFonts.poppins(),
                        prefixIcon: const Icon(Icons.search_rounded),
                        suffixIcon: _isSearching
                            ? IconButton(
                                icon: const Icon(Icons.close_rounded),
                                onPressed: () {
                                  _searchController.clear();
                                  _search('');
                                },
                              )
                            : null,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide.none,
                        ),
                        filled: true,
                        fillColor:
                            theme.colorScheme.surfaceVariant.withOpacity(0.5),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ),
                  // Tabs
                  if (!_isSearching)
                    TabBar(
                      controller: _tabController,
                      labelStyle:
                          GoogleFonts.poppins(fontWeight: FontWeight.w600),
                      unselectedLabelStyle: GoogleFonts.poppins(),
                      indicatorColor: theme.colorScheme.primary,
                      labelColor: theme.colorScheme.primary,
                      tabs: [
                        Tab(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.check_circle_outline_rounded,
                                  size: 18),
                              const SizedBox(width: 6),
                              Text('Task (${_todos.length})'),
                            ],
                          ),
                        ),
                        Tab(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.note_alt_outlined, size: 18),
                              const SizedBox(width: 6),
                              Text('Ghi chú (${_notes.length})'),
                            ],
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ],
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _isSearching
                ? _buildList(_searchResults)
                : TabBarView(
                    controller: _tabController,
                    children: [
                      _buildList(_todos),
                      _buildList(_notes),
                    ],
                  ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openAddEdit(),
        icon: const Icon(Icons.add_rounded),
        label: Text(
          'Thêm mới',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  Widget _buildList(List<TodoModel> items) {
    if (items.isEmpty) {
      return _buildEmpty();
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
        itemCount: items.length,
        itemBuilder: (_, index) => _buildItem(items[index]),
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.inbox_rounded,
            size: 80,
            color: Colors.grey.withOpacity(0.4),
          ),
          const SizedBox(height: 16),
          Text(
            'Chưa có gì ở đây',
            style: GoogleFonts.poppins(
              fontSize: 18,
              color: Colors.grey,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Nhấn + để thêm mới',
            style: GoogleFonts.poppins(color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildItem(TodoModel todo) {
    final color = Color(
        int.parse((todo.color ?? '#6C63FF').replaceFirst('#', '0xFF')));

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Slidable(
        key: ValueKey(todo.id),
        startActionPane: ActionPane(
          motion: const DrawerMotion(),
          children: [
            SlidableAction(
              onPressed: (_) => _openAddEdit(todo: todo),
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
              icon: Icons.edit_rounded,
              label: 'Sửa',
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(14),
                bottomLeft: Radius.circular(14),
              ),
            ),
          ],
        ),
        endActionPane: ActionPane(
          motion: const DrawerMotion(),
          dismissible: DismissiblePane(onDismissed: () => _delete(todo)),
          children: [
            SlidableAction(
              onPressed: (_) => _delete(todo),
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              icon: Icons.delete_rounded,
              label: 'Xóa',
              borderRadius: const BorderRadius.only(
                topRight: Radius.circular(14),
                bottomRight: Radius.circular(14),
              ),
            ),
          ],
        ),
        child: GestureDetector(
          onTap: () => _openAddEdit(todo: todo),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border(
                left: BorderSide(color: color, width: 4),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                // Checkbox (chỉ dành cho todo)
                if (todo.category == 'todo')
                  GestureDetector(
                    onTap: () => _toggleComplete(todo),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 24,
                      height: 24,
                      margin: const EdgeInsets.only(right: 14),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: todo.isCompleted ? color : Colors.transparent,
                        border: Border.all(
                          color: todo.isCompleted ? color : Colors.grey.shade400,
                          width: 2,
                        ),
                      ),
                      child: todo.isCompleted
                          ? const Icon(Icons.check_rounded,
                              color: Colors.white, size: 14)
                          : null,
                    ),
                  )
                else
                  Padding(
                    padding: const EdgeInsets.only(right: 14),
                    child: Icon(Icons.sticky_note_2_rounded,
                        color: color, size: 22),
                  ),
                // Nội dung
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        todo.title,
                        style: GoogleFonts.poppins(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          decoration: todo.isCompleted
                              ? TextDecoration.lineThrough
                              : null,
                          color: todo.isCompleted ? Colors.grey : null,
                        ),
                      ),
                      if (todo.description != null &&
                          todo.description!.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          todo.description!,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                      const SizedBox(height: 6),
                      Text(
                        DateFormat('dd/MM/yyyy HH:mm').format(todo.updatedAt),
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          color: Colors.grey.shade400,
                        ),
                      ),
                    ],
                  ),
                ),
                // Badge hoàn thành
                if (todo.isCompleted)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Xong',
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        color: Colors.green,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
