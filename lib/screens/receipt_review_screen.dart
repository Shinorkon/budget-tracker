import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../theme/app_theme.dart';
import '../models/budget_provider.dart';
import '../models/receipt_model.dart';
import '../utils/formatters.dart';
import '../widgets/receipt_item_row.dart';

const _uuid = Uuid();

class ReceiptReviewScreen extends StatefulWidget {
  final ParsedReceipt parsed;
  final String? imagePath;
  final String? suggestedCategoryId; // may arrive late via setState from parent

  const ReceiptReviewScreen({
    super.key,
    required this.parsed,
    this.imagePath,
    this.suggestedCategoryId,
  });

  @override
  State<ReceiptReviewScreen> createState() => _ReceiptReviewScreenState();
}

class _ReceiptReviewScreenState extends State<ReceiptReviewScreen> {
  late final TextEditingController _storeCtrl;
  late DateTime _date;
  late TimeOfDay _time;
  late List<ReceiptItem> _items;
  late double _total;
  String? _categoryId;
  bool _totalOverridden = false;
  late final TextEditingController _totalCtrl;

  @override
  void initState() {
    super.initState();
    _storeCtrl = TextEditingController(text: widget.parsed.storeName);
    _date = DateTime(
      widget.parsed.date.year,
      widget.parsed.date.month,
      widget.parsed.date.day,
    );
    _time = TimeOfDay.now();
    _items = List.from(widget.parsed.items);
    _total = widget.parsed.totalAmount;
    _totalCtrl = TextEditingController(
        text: _total > 0 ? _total.toStringAsFixed(2) : '');
    _categoryId = widget.suggestedCategoryId;
  }

  @override
  void didUpdateWidget(ReceiptReviewScreen old) {
    super.didUpdateWidget(old);
    if (widget.suggestedCategoryId != null && _categoryId == null) {
      setState(() => _categoryId = widget.suggestedCategoryId);
    }
  }

  @override
  void dispose() {
    _storeCtrl.dispose();
    _totalCtrl.dispose();
    super.dispose();
  }

  double get _calculatedTotal =>
      _items.fold(0.0, (sum, item) => sum + item.lineTotal);

  void _recalcTotal() {
    if (!_totalOverridden) {
      final calc = _calculatedTotal;
      setState(() {
        _total = calc;
        _totalCtrl.text = calc.toStringAsFixed(2);
      });
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.dark(
            primary: AppColors.primary,
            surface: AppColors.surface,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _time,
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.dark(
            primary: AppColors.primary,
            surface: AppColors.surface,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _time = picked);
  }

  void _addItem() {
    setState(() {
      _items.add(ReceiptItem(
        id: _uuid.v4(),
        receiptId: '',
        rawName: '',
        canonicalName: '',
        unitPrice: 0,
        quantity: 1,
        storeName: _storeCtrl.text.trim(),
      ));
    });
  }

  @override
  Widget build(BuildContext context) {
    final budget = Provider.of<BudgetProvider>(context);
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, color: AppColors.textSecondary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('Review Receipt',
            style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w600)),
        centerTitle: true,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: AppColors.border),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Receipt image thumbnail
                  if (widget.imagePath != null) ...[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.file(
                        File(widget.imagePath!),
                        height: 140,
                        fit: BoxFit.cover,
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],

                  // Store name
                  _sectionLabel('Store Name'),
                  const SizedBox(height: 8),
                  _inputField(
                    controller: _storeCtrl,
                    hint: 'Store or restaurant name',
                    icon: Icons.storefront_rounded,
                  ),
                  const SizedBox(height: 16),

                  // Date
                  _sectionLabel('Date'),
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: _pickDate,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceLight,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.calendar_today_rounded,
                              color: AppColors.textMuted, size: 20),
                          const SizedBox(width: 12),
                          Text(formatDate(_date),
                              style: const TextStyle(
                                  color: AppColors.textPrimary, fontSize: 15)),
                          const Spacer(),
                          const Icon(Icons.chevron_right_rounded,
                              color: AppColors.textMuted),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Time
                  _sectionLabel('Time'),
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: _pickTime,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceLight,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.access_time_rounded,
                              color: AppColors.textMuted, size: 20),
                          const SizedBox(width: 12),
                          Text(_time.format(context),
                              style: const TextStyle(
                                  color: AppColors.textPrimary, fontSize: 15)),
                          const Spacer(),
                          const Icon(Icons.chevron_right_rounded,
                              color: AppColors.textMuted),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Items
                  Row(
                    children: [
                      _sectionLabel('Items'),
                      const Spacer(),
                      Text('${_items.length} item${_items.length == 1 ? '' : 's'}',
                          style: const TextStyle(
                              color: AppColors.textMuted, fontSize: 13)),
                    ],
                  ),
                  const SizedBox(height: 10),
                  ..._items.asMap().entries.map((entry) {
                    final i = entry.key;
                    final item = entry.value;
                    return ReceiptItemRow(
                      key: ValueKey(item.id),
                      item: item,
                      onChanged: (updated) {
                        setState(() => _items[i] = updated);
                        _recalcTotal();
                      },
                      onDelete: () {
                        setState(() => _items.removeAt(i));
                        _recalcTotal();
                      },
                    );
                  }),
                  TextButton.icon(
                    onPressed: _addItem,
                    icon: const Icon(Icons.add_rounded,
                        color: AppColors.primary, size: 20),
                    label: const Text('Add Item',
                        style: TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w600)),
                  ),
                  const SizedBox(height: 16),

                  // Total
                  _sectionLabel('Total'),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _totalCtrl,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                    ),
                    textAlign: TextAlign.center,
                    onChanged: (v) {
                      _totalOverridden = true;
                      _total = double.tryParse(v) ?? _total;
                    },
                    decoration: InputDecoration(
                      hintText: '0.00',
                      hintStyle: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textMuted.withValues(alpha: 0.5),
                      ),
                      suffixText: budget.currency,
                      suffixStyle: const TextStyle(
                          fontSize: 14, color: AppColors.textSecondary),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: AppColors.surfaceLight,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Category
                  _sectionLabel('Category'),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: budget.categories.map((cat) {
                      final isSelected = _categoryId == cat.id;
                      return GestureDetector(
                        onTap: () => setState(() => _categoryId = cat.id),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? cat.color.withValues(alpha: 0.2)
                                : AppColors.surfaceLight,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: isSelected ? cat.color : AppColors.border,
                              width: isSelected ? 2 : 1,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(cat.icon, color: cat.color, size: 16),
                              const SizedBox(width: 6),
                              Text(
                                cat.name,
                                style: TextStyle(
                                  color: isSelected
                                      ? cat.color
                                      : AppColors.textSecondary,
                                  fontSize: 13,
                                  fontWeight: isSelected
                                      ? FontWeight.w600
                                      : FontWeight.w400,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),

          // Save button
          SafeArea(
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: SizedBox(
                height: 52,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).pop({
                    'storeName': _storeCtrl.text.trim().isEmpty
                        ? 'Unknown Store'
                        : _storeCtrl.text.trim(),
                    'date': DateTime(
                      _date.year,
                      _date.month,
                      _date.day,
                      _time.hour,
                      _time.minute,
                    ),
                    'total': double.tryParse(_totalCtrl.text) ?? _total,
                    'items': _items,
                    'categoryId': _categoryId,
                  }),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const Text(
                    'Save Receipt',
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Colors.white),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionLabel(String text) => Text(
        text,
        style: const TextStyle(
          color: AppColors.textSecondary,
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
      );

  Widget _inputField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
  }) =>
      TextField(
        controller: controller,
        style:
            const TextStyle(color: AppColors.textPrimary, fontSize: 15),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle:
              const TextStyle(color: AppColors.textMuted, fontSize: 15),
          prefixIcon: Icon(icon, color: AppColors.textMuted, size: 20),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          filled: true,
          fillColor: AppColors.surfaceLight,
        ),
      );
}
