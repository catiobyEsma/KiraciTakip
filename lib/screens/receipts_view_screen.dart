import 'dart:io';
import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path/path.dart' as p;
import '../db/database_helper.dart';
import '../models/receipt.dart';
import '../models/tenant.dart';
import '../utils/currency_utils.dart';

class ReceiptsViewScreen extends StatefulWidget {
  final Tenant? initialTenant;
  final List<Tenant> tenants;
  const ReceiptsViewScreen(
      {super.key, this.initialTenant, required this.tenants});

  @override
  State<ReceiptsViewScreen> createState() => _ReceiptsViewScreenState();
}

class _ReceiptsViewScreenState extends State<ReceiptsViewScreen> {
  final _db = DatabaseHelper.instance;
  Tenant? _selectedTenant;
  List<Receipt> _receipts = [];
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _selectedTenant = widget.initialTenant;
    if (_selectedTenant != null) _load();
  }

  Future<void> _load() async {
    if (_selectedTenant == null) return;
    setState(() => _loading = true);
    final list = await _db.getReceiptsForTenant(_selectedTenant!.id!);
    setState(() {
      _receipts = list;
      _loading = false;
    });
  }

  bool _isImage(String path) => ['.jpg', '.jpeg', '.png', '.webp', '.heic']
      .contains(p.extension(path).toLowerCase());

  Future<void> _deleteReceipt(Receipt r) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Dekontu Sil'),
        content: const Text('Bu dekontu silmek istediğinize emin misiniz?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Vazgeç')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: FilledButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('Sil')),
        ],
      ),
    );
    if (confirm == true) {
      await _db.deleteReceipt(r.id!);
      final file = File(r.filePath);
      if (await file.exists()) {
        await file.delete();
      }
      _load();
    }
  }

  void _openFullView(Receipt r) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640, maxHeight: 700),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        r.description.isEmpty
                            ? p.basename(r.filePath)
                            : r.description,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Flexible(
                  child: _isImage(r.filePath)
                      ? InteractiveViewer(child: Image.file(File(r.filePath)))
                      : Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.picture_as_pdf,
                                size: 64, color: Colors.redAccent),
                            const SizedBox(height: 8),
                            Text(p.basename(r.filePath)),
                            const SizedBox(height: 12),
                            OutlinedButton.icon(
                              onPressed: () => OpenFilex.open(r.filePath),
                              icon: const Icon(Icons.open_in_new),
                              label: const Text('Dosyayı Aç'),
                            ),
                          ],
                        ),
                ),
                const SizedBox(height: 8),
                Text('Eklenme Tarihi: ${formatDate(r.addedDate)}',
                    style:
                        const TextStyle(color: Colors.black54, fontSize: 12)),
                const SizedBox(height: 10),
                TextButton.icon(
                  onPressed: () {
                    Navigator.pop(ctx);
                    _deleteReceipt(r);
                  },
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  label: const Text('Bu Dekontu Sil',
                      style: TextStyle(color: Colors.red)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Dekontları Görüntüle')),
      body: Padding(
        padding:
            EdgeInsets.all(MediaQuery.sizeOf(context).width < 480 ? 12 : 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DropdownButtonFormField<Tenant>(
              value: _selectedTenant,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Kiracı Seçiniz'),
              items: widget.tenants
                  .map((t) =>
                      DropdownMenuItem(value: t, child: Text(t.fullName)))
                  .toList(),
              onChanged: (t) {
                setState(() => _selectedTenant = t);
                _load();
              },
            ),
            const SizedBox(height: 20),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _selectedTenant == null
                      ? const Center(
                          child:
                              Text('Dekontları görmek için bir kiracı seçin.'))
                      : _receipts.isEmpty
                          ? const Center(
                              child: Text('Bu kiracıya ait dekont bulunmuyor.'))
                          : LayoutBuilder(
                              builder: (context, constraints) {
                                final columns = constraints.maxWidth < 480
                                    ? 2
                                    : constraints.maxWidth < 800
                                        ? 3
                                        : 4;
                                return GridView.builder(
                                  gridDelegate:
                                      SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: columns,
                                    mainAxisSpacing: 12,
                                    crossAxisSpacing: 12,
                                    childAspectRatio: 0.85,
                                  ),
                                  itemCount: _receipts.length,
                                  itemBuilder: (context, index) {
                                    final r = _receipts[index];
                                    return InkWell(
                                      onTap: () => _openFullView(r),
                                      borderRadius: BorderRadius.circular(12),
                                      child: Card(
                                        clipBehavior: Clip.antiAlias,
                                        child: Column(
                                          children: [
                                            Expanded(
                                              child: _isImage(r.filePath)
                                                  ? Image.file(File(r.filePath),
                                                      fit: BoxFit.cover,
                                                      width: double.infinity)
                                                  : Container(
                                                      color: const Color(
                                                          0xFFF1EDEF),
                                                      child: const Center(
                                                        child: Icon(
                                                            Icons
                                                                .picture_as_pdf,
                                                            size: 40,
                                                            color: Colors
                                                                .redAccent),
                                                      ),
                                                    ),
                                            ),
                                            Padding(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 8,
                                                      vertical: 6),
                                              child: Text(
                                                formatDate(r.addedDate),
                                                style: const TextStyle(
                                                    fontSize: 11,
                                                    color: Colors.black54),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                );
                              },
                            ),
            ),
          ],
        ),
      ),
    );
  }
}
