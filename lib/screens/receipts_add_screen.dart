import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import '../db/database_helper.dart';
import '../models/receipt.dart';
import '../models/tenant.dart';

class ReceiptsAddScreen extends StatefulWidget {
  final Tenant? initialTenant;
  final List<Tenant> tenants;
  const ReceiptsAddScreen(
      {super.key, this.initialTenant, required this.tenants});

  @override
  State<ReceiptsAddScreen> createState() => _ReceiptsAddScreenState();
}

class _ReceiptsAddScreenState extends State<ReceiptsAddScreen> {
  final _db = DatabaseHelper.instance;
  Tenant? _selectedTenant;
  final _descCtrl = TextEditingController();
  PlatformFile? _pickedPlatformFile;
  String? _pickError;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _selectedTenant = widget.initialTenant;
  }


  Future<void> _pickImage() async {
    if (!await _prepareImageAccess()) return;
    await _runPicker(
      () => FilePicker.platform.pickFiles(
        type: Platform.isAndroid || Platform.isIOS
            ? FileType.image
            : FileType.any,
        withData: true,
        dialogTitle: 'Dekont Fotoğrafı Seçin',
      ),
      expectedExtensions: const [
        '.jpg',
        '.jpeg',
        '.png',
        '.heic',
        '.webp',
        '.gif',
        '.bmp'
      ],
      wrongTypeMessage:
          'Lütfen bir resim dosyası seçin (jpg, png, heic, webp...).',
    );
  }

  Future<void> _pickPdf() async {
    if (!await _confirmPdfAccess()) return;
    await _runPicker(
      () => FilePicker.platform.pickFiles(
        type: FileType.any,
        withData: true,
        dialogTitle: 'Dekont PDF Dosyası Seçin',
      ),
      expectedExtensions: const ['.pdf'],
      wrongTypeMessage: 'Lütfen bir PDF dosyası seçin.',
    );
  }

  Future<bool> _confirmPdfAccess() async {
    if (!Platform.isAndroid && !Platform.isIOS) return true;
    return await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('PDF dosyasına erişim'),
            content: const Text(
              'Devam ettiğinizde sistem dosya seçicisi açılır. Uygulama yalnızca '
              'sizin seçtiğiniz PDF dosyasına erişebilir; cihazdaki diğer dosyalara '
              'erişim izni verilmez.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Vazgeç'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('Dosya Seç'),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<bool> _prepareImageAccess() async {
    if (!Platform.isAndroid && !Platform.isIOS) return true;

    final shouldContinue = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Fotoğraf erişim izni'),
        content: const Text(
          'Dekont fotoğrafı seçebilmeniz için fotoğraflara erişim izni gerekir. '
          'Uygulama fotoğrafları yalnızca sizin seçiminizle dekont olarak kaydeder; '
          'başka fotoğrafları toplamaz veya paylaşmaz.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('İzin Ver'),
          ),
        ],
      ),
    );
    if (shouldContinue != true) return false;

    final Permission photoPermission;
    if (Platform.isIOS) {
      photoPermission = Permission.photos;
    } else {
      final androidInfo = await DeviceInfoPlugin().androidInfo;
      photoPermission = androidInfo.version.sdkInt >= 33
          ? Permission.photos
          : Permission.storage;
    }

    var status = await photoPermission.status;
    if (!status.isGranted && !status.isLimited) {
      status = await photoPermission.request();
    }
    if (status.isGranted || status.isLimited) return true;

    if (mounted) {
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('İzin gerekli'),
          content: const Text(
            'Fotoğraf erişim izni verilmedi. Bu izin olmadan dekont fotoğrafı '
            'seçilemez. İzni cihazınızın Ayarlar bölümünden uygulama izinlerini '
            'açarak etkinleştirebilirsiniz.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Kapat'),
            ),
            FilledButton.icon(
              onPressed: () async {
                Navigator.pop(dialogContext);
                await openAppSettings();
              },
              icon: const Icon(Icons.settings_outlined),
              label: const Text('Ayarları Aç'),
            ),
          ],
        ),
      );
    }
    return false;
  }

  Future<void> _runPicker(
    Future<FilePickerResult?> Function() picker, {
    required List<String> expectedExtensions,
    required String wrongTypeMessage,
  }) async {
    // ignore: avoid_print
    print('[DEKONT] Buton tıklandı, dosya seçici açılıyor...');
    setState(() => _pickError = null);
    try {
      final result =
          await picker().timeout(const Duration(seconds: 120), onTimeout: () {
        // ignore: avoid_print
        print('[DEKONT] ZAMAN AŞIMI: 120 saniyede seçici hiç yanıt vermedi. '
            'file_picker eklentisi muhtemelen macOS tarafına bağlanmamış.');
        throw Exception(
            'Dosya seçici 120 saniye içinde yanıt vermedi. Bu, file_picker eklentisinin '
            'macOS tarafına doğru bağlanmadığını gösterir (native kayıt sorunu).');
      });
      // ignore: avoid_print
      print('[DEKONT] Seçici kapandı. Sonuç: '
          '${result == null ? "null (iptal edildi ya da hiç açılmadı)" : "${result.files.length} dosya seçildi"}');
      if (result == null || result.files.isEmpty) {

        return;
      }
      final file = result.files.single;
      // ignore: avoid_print
      print(
          '[DEKONT] Seçilen dosya: ${file.name}, path: ${file.path}, bytes: ${file.bytes?.length}');
      final ext = p.extension(file.name).toLowerCase();
      if (!expectedExtensions.contains(ext)) {
        setState(() => _pickError = wrongTypeMessage);
        return;
      }
      setState(() => _pickedPlatformFile = file);
    } catch (e, st) {
      // ignore: avoid_print
      print('[DEKONT] HATA: $e\n$st');
      setState(() {
        _pickError =
            'Dosya seçilemedi: $e\n\nBu genellikle macOS uygulamasının dosya erişim izninin '
            '(entitlement) eksik olmasından kaynaklanır. README\'deki "Dekont ekleme sorunu" '
            'bölümüne bakın ve macos/Runner/*.entitlements dosyalarını güncelledikten sonra '
            '"flutter clean" ile yeniden derleyin.';
      });
    }
  }

  Future<void> _save() async {
    if (_selectedTenant == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Lütfen bir kiracı seçin.')));
      return;
    }
    final picked = _pickedPlatformFile;
    if (picked == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Lütfen bir dosya seçin.')));
      return;
    }
    setState(() => _saving = true);

    try {

      final appDocDir = await getApplicationSupportDirectory();
      final receiptsDir = Directory(p.join(appDocDir.path, 'KiraciTakip',
          'Dekontlar', 'kiraci_${_selectedTenant!.id}'));
      if (!await receiptsDir.exists()) {
        await receiptsDir.create(recursive: true);
      }
      final ext = p.extension(picked.name).isNotEmpty
          ? p.extension(picked.name)
          : '.jpg';
      final fileName = 'dekont_${DateTime.now().millisecondsSinceEpoch}$ext';
      final destPath = p.join(receiptsDir.path, fileName);

      if (picked.bytes != null) {

        await File(destPath).writeAsBytes(picked.bytes!);
      } else if (picked.path != null) {
        await File(picked.path!).copy(destPath);
      } else {
        throw Exception('Seçilen dosyanın içeriğine ulaşılamadı.');
      }

      final receipt = Receipt(
        tenantId: _selectedTenant!.id!,
        filePath: destPath,
        addedDate: DateTime.now(),
        description: _descCtrl.text.trim(),
      );
      await _db.insertReceipt(receipt);

      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Dekont kaydedildi.')));
        setState(() {
          _pickedPlatformFile = null;
          _descCtrl.clear();
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _pickError = 'Dekont kaydedilemedi: $e');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final picked = _pickedPlatformFile;
    final isImage = picked != null &&
        ['.jpg', '.jpeg', '.png', '.webp', '.heic']
            .contains(p.extension(picked.name).toLowerCase());

    return Scaffold(
      appBar: AppBar(title: const Text('Dekont Ekle')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: SingleChildScrollView(
            padding: EdgeInsets.all(
                MediaQuery.sizeOf(context).width < 480 ? 14 : 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                DropdownButtonFormField<Tenant>(
                  value: _selectedTenant,
                  isExpanded: true,
                  decoration:
                      const InputDecoration(labelText: 'Kiracı Seçiniz'),
                  items: widget.tenants
                      .map((t) =>
                          DropdownMenuItem(value: t, child: Text(t.fullName)))
                      .toList(),
                  onChanged: (t) => setState(() => _selectedTenant = t),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _descCtrl,
                  decoration: const InputDecoration(
                      labelText: 'Açıklama (opsiyonel)',
                      hintText: 'Örn: Mayıs ayı kira dekontu'),
                ),
                const SizedBox(height: 20),
                Container(
                  height: 260,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: const Color(0xFFC9C9CC)),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: picked == null
                      ? const Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.image_search,
                                  size: 42, color: Colors.black38),
                              SizedBox(height: 10),
                              Text('Aşağıdaki butonlarla bir dekont seçin'),
                            ],
                          ),
                        )
                      : ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: isImage && picked.bytes != null
                              ? Image.memory(picked.bytes!, fit: BoxFit.contain)
                              : isImage && picked.path != null
                                  ? Image.file(File(picked.path!),
                                      fit: BoxFit.contain)
                                  : Center(
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(Icons.picture_as_pdf,
                                              size: 48,
                                              color: Colors.redAccent),
                                          const SizedBox(height: 8),
                                          Text(picked.name),
                                        ],
                                      ),
                                    ),
                        ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 12,
                  runSpacing: 8,
                  children: [
                    OutlinedButton.icon(
                      onPressed: _pickImage,
                      icon: const Icon(Icons.add_a_photo_outlined),
                      label: const Text('Fotoğraf Seç'),
                    ),
                    OutlinedButton.icon(
                      onPressed: _pickPdf,
                      icon: const Icon(Icons.picture_as_pdf_outlined),
                      label: const Text('PDF Seç'),
                    ),
                  ],
                ),
                if (_pickError != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFDECEC),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFE3A9A9)),
                    ),
                    child: Text(_pickError!,
                        style: const TextStyle(
                            color: Color(0xFF8A1F1F), fontSize: 12.5)),
                  ),
                ],
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: _saving ? null : _save,
                  icon: _saving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.save_outlined),
                  label: const Text('Dekontu Kaydet'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
