import 'package:flutter/material.dart';

import '../db/database_helper.dart';
import '../models/tenant.dart';
import '../models/tenant_note.dart';

Future<void> showTenantNotesDialog(BuildContext context, Tenant tenant) async {
  await showDialog(
    context: context,
    barrierDismissible: true,
    builder: (_) => TenantNotesDialog(tenant: tenant),
  );
}

class TenantNotesDialog extends StatefulWidget {
  final Tenant tenant;

  const TenantNotesDialog({super.key, required this.tenant});

  @override
  State<TenantNotesDialog> createState() => _TenantNotesDialogState();
}

class _TenantNotesDialogState extends State<TenantNotesDialog> {
  final _db = DatabaseHelper.instance;
  final _controller = TextEditingController();
  List<TenantNote> _notes = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final notes = await _db.getNotesForTenant(widget.tenant.id!);
    if (!mounted) return;
    setState(() {
      _notes = notes;
      _loading = false;
    });
  }

  Future<void> _addNote() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    await _db.insertTenantNote(TenantNote(
      tenantId: widget.tenant.id!,
      createdAt: DateTime.now(),
      text: text,
    ));
    _controller.clear();
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Kiracı Notları — ${widget.tenant.fullName}'),
      content: SizedBox(
        width: (MediaQuery.sizeOf(context).width - 64).clamp(0.0, 420.0).toDouble(),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _controller,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: 'Not ekleyin...',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                onPressed: _addNote,
                icon: const Icon(Icons.note_add_outlined, size: 18),
                label: const Text('Ekle'),
              ),
            ),
            const SizedBox(height: 12),
            if (_loading)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_notes.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Text('Henüz not eklenmemiş.'),
              )
            else
              SizedBox(
                width: double.maxFinite,
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: _notes.length,
                  separatorBuilder: (_, __) => const Divider(height: 12),
                  itemBuilder: (context, index) {
                    final note = _notes[index];
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      leading: const Icon(Icons.sticky_note_2_outlined, size: 18),
                      title: Text(note.text),
                      subtitle: Text(
                        '${note.createdAt.day.toString().padLeft(2, '0')}/${note.createdAt.month.toString().padLeft(2, '0')}/${note.createdAt.year}',
                        style: const TextStyle(fontSize: 11),
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Kapat'),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}
