import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../models/receipt_model.dart';

class ReceiptItemRow extends StatefulWidget {
  final ReceiptItem item;
  final void Function(ReceiptItem updated) onChanged;
  final VoidCallback onDelete;

  const ReceiptItemRow({
    super.key,
    required this.item,
    required this.onChanged,
    required this.onDelete,
  });

  @override
  State<ReceiptItemRow> createState() => _ReceiptItemRowState();
}

class _ReceiptItemRowState extends State<ReceiptItemRow> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _priceCtrl;
  late final TextEditingController _qtyCtrl;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.item.canonicalName);
    _priceCtrl = TextEditingController(
        text: widget.item.unitPrice > 0
            ? widget.item.unitPrice.toStringAsFixed(2)
            : '');
    _qtyCtrl = TextEditingController(text: widget.item.quantity.toString());
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _priceCtrl.dispose();
    _qtyCtrl.dispose();
    super.dispose();
  }

  void _notify() {
    widget.onChanged(widget.item.copyWith(
      canonicalName: _nameCtrl.text.trim(),
      unitPrice: double.tryParse(_priceCtrl.text) ?? widget.item.unitPrice,
      quantity: int.tryParse(_qtyCtrl.text) ?? widget.item.quantity,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          // Name row
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _nameCtrl,
                  onChanged: (_) => _notify(),
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                  decoration: const InputDecoration(
                    hintText: 'Item name',
                    hintStyle:
                        TextStyle(color: AppColors.textMuted, fontSize: 14),
                    isDense: true,
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ),
              GestureDetector(
                onTap: widget.onDelete,
                child: const Icon(Icons.close_rounded,
                    color: AppColors.textMuted, size: 18),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Price + qty row
          Row(
            children: [
              // Unit price
              Expanded(
                flex: 3,
                child: Row(
                  children: [
                    const Icon(Icons.attach_money_rounded,
                        color: AppColors.textMuted, size: 16),
                    const SizedBox(width: 4),
                    Expanded(
                      child: TextField(
                        controller: _priceCtrl,
                        onChanged: (_) => _notify(),
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        style: const TextStyle(
                          color: AppColors.income,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                        decoration: const InputDecoration(
                          hintText: '0.00',
                          hintStyle: TextStyle(
                              color: AppColors.textMuted, fontSize: 14),
                          isDense: true,
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // Qty
              const Text('×',
                  style: TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 16,
                      fontWeight: FontWeight.w600)),
              const SizedBox(width: 8),
              SizedBox(
                width: 40,
                child: TextField(
                  controller: _qtyCtrl,
                  onChanged: (_) => _notify(),
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                  decoration: const InputDecoration(
                    isDense: true,
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
