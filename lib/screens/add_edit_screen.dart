import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/todo_model.dart';
import '../db/database_helper.dart';

class AddEditScreen extends StatefulWidget {
  final TodoModel? todo; // null = thêm mới, có value = sửa

  const AddEditScreen({super.key, this.todo});

  @override
  State<AddEditScreen> createState() => _AddEditScreenState();
}

class _AddEditScreenState extends State<AddEditScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  final _dbHelper = DatabaseHelper();

  String _selectedCategory = 'todo';
  String _selectedColor = '#6C63FF';
  bool _isLoading = false;

  bool get isEditing => widget.todo != null;

  // Danh sách màu tag
  final List<Map<String, dynamic>> _colors = [
    {'hex': '#6C63FF', 'name': 'Tím'},
    {'hex': '#FF6584', 'name': 'Hồng'},
    {'hex': '#43AA8B', 'name': 'Xanh lá'},
    {'hex': '#F4A261', 'name': 'Cam'},
    {'hex': '#4CC9F0', 'name': 'Xanh dương'},
    {'hex': '#E63946', 'name': 'Đỏ'},
  ];

  @override
  void initState() {
    super.initState();
    if (isEditing) {
      _titleController.text = widget.todo!.title;
      _descController.text = widget.todo!.description ?? '';
      _selectedCategory = widget.todo!.category;
      _selectedColor = widget.todo!.color ?? '#6C63FF';
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Color _hexToColor(String hex) {
    return Color(int.parse(hex.replaceFirst('#', '0xFF')));
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      if (isEditing) {
        // Cập nhật
        final updated = widget.todo!.copyWith(
          title: _titleController.text.trim(),
          description: _descController.text.trim().isEmpty
              ? null
              : _descController.text.trim(),
          category: _selectedCategory,
          color: _selectedColor,
        );
        await _dbHelper.updateTodo(updated);
      } else {
        // Thêm mới
        final newTodo = TodoModel(
          title: _titleController.text.trim(),
          description: _descController.text.trim().isEmpty
              ? null
              : _descController.text.trim(),
          category: _selectedCategory,
          color: _selectedColor,
        );
        await _dbHelper.insertTodo(newTodo);
      }

      if (mounted) {
        Navigator.pop(context, true); // true = có thay đổi
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          isEditing ? 'Chỉnh sửa' : 'Thêm mới',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            TextButton.icon(
              onPressed: _save,
              icon: const Icon(Icons.check_rounded),
              label: Text(
                'Lưu',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
              ),
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // Chọn loại
            _buildCategorySelector(theme),
            const SizedBox(height: 20),

            // Tiêu đề
            _buildTitleField(theme),
            const SizedBox(height: 16),

            // Nội dung
            _buildDescField(theme),
            const SizedBox(height: 24),

            // Chọn màu
            _buildColorPicker(theme),
          ],
        ),
      ),
    );
  }

  Widget _buildCategorySelector(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceVariant.withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          _categoryTab('todo', Icons.check_circle_outline_rounded, 'Todo', theme),
          _categoryTab('note', Icons.note_alt_outlined, 'Ghi chú', theme),
        ],
      ),
    );
  }

  Widget _categoryTab(
      String value, IconData icon, String label, ThemeData theme) {
    final isSelected = _selectedCategory == value;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedCategory = value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? theme.colorScheme.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon,
                  size: 18,
                  color: isSelected
                      ? Colors.white
                      : theme.colorScheme.onSurfaceVariant),
              const SizedBox(width: 6),
              Text(
                label,
                style: GoogleFonts.poppins(
                  color: isSelected
                      ? Colors.white
                      : theme.colorScheme.onSurfaceVariant,
                  fontWeight:
                      isSelected ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTitleField(ThemeData theme) {
    return TextFormField(
      controller: _titleController,
      style: GoogleFonts.poppins(fontSize: 16),
      decoration: InputDecoration(
        labelText: 'Tiêu đề *',
        hintText: _selectedCategory == 'todo'
            ? 'Ví dụ: Học Flutter SQLite...'
            : 'Ví dụ: Ghi chú hôm nay...',
        prefixIcon: const Icon(Icons.title_rounded),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        filled: true,
        fillColor: theme.colorScheme.surfaceVariant.withOpacity(0.3),
      ),
      textCapitalization: TextCapitalization.sentences,
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return 'Vui lòng nhập tiêu đề';
        }
        if (value.trim().length < 2) {
          return 'Tiêu đề phải có ít nhất 2 ký tự';
        }
        return null;
      },
    );
  }

  Widget _buildDescField(ThemeData theme) {
    return TextFormField(
      controller: _descController,
      style: GoogleFonts.poppins(fontSize: 15),
      maxLines: 5,
      decoration: InputDecoration(
        labelText: 'Nội dung (tùy chọn)',
        hintText: 'Thêm mô tả chi tiết...',
        prefixIcon: const Padding(
          padding: EdgeInsets.only(bottom: 60),
          child: Icon(Icons.notes_rounded),
        ),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        filled: true,
        fillColor: theme.colorScheme.surfaceVariant.withOpacity(0.3),
        alignLabelWithHint: true,
      ),
      textCapitalization: TextCapitalization.sentences,
    );
  }

  Widget _buildColorPicker(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Màu nhãn',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            color: theme.colorScheme.onBackground,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: _colors.map((c) {
            final isSelected = _selectedColor == c['hex'];
            return GestureDetector(
              onTap: () => setState(() => _selectedColor = c['hex']),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.only(right: 12),
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: _hexToColor(c['hex']),
                  shape: BoxShape.circle,
                  border: isSelected
                      ? Border.all(
                          color: theme.colorScheme.onBackground, width: 2.5)
                      : null,
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: _hexToColor(c['hex']).withOpacity(0.5),
                            blurRadius: 8,
                            spreadRadius: 2,
                          )
                        ]
                      : null,
                ),
                child: isSelected
                    ? const Icon(Icons.check, color: Colors.white, size: 18)
                    : null,
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}
