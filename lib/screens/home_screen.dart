import 'package:flutter/material.dart';
import '../db/database_helper.dart';
import '../models/tenant.dart';
import '../widgets/calendar_panel.dart';
import 'tenant_form_screen.dart';
import 'tenant_detail_screen.dart';
import 'edit_due_payments_screen.dart';
import 'add_payment_dialog.dart';
import 'receipts_add_screen.dart';
import 'receipts_view_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _db = DatabaseHelper.instance;
  List<Tenant> _tenants = [];
  Tenant? _selectedTenant;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadTenants();
  }

  Future<void> _loadTenants() async {
    setState(() => _loading = true);
    final tenants = await _db.getAllTenants();
    setState(() {
      _tenants = tenants;
      if (_selectedTenant != null) {
        // Seçili kiracı hâlâ listede mi diye kontrol et, yoksa null yap.
        final match = tenants.where((t) => t.id == _selectedTenant!.id);
        _selectedTenant = match.isEmpty ? null : match.first;
      }
      _loading = false;
    });
  }

  Future<void> _openCreateTenant() async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const TenantFormScreen()),
    );
    if (result == true) _loadTenants();
  }

  Future<void> _openEditTenant() async {
    if (_selectedTenant == null) return;
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => TenantFormScreen(tenant: _selectedTenant),
      ),
    );
    if (result == true) _loadTenants();
  }

  void _openDetail() {
    if (_selectedTenant == null) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => TenantDetailScreen(tenant: _selectedTenant!),
      ),
    );
  }

  Future<void> _openEditDuePayments() async {
    if (_selectedTenant == null) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => EditDuePaymentsScreen(tenant: _selectedTenant!),
      ),
    );
    setState(() {});
  }

  Future<void> _openAddPayment() async {
    if (_selectedTenant == null) return;
    final added = await showDialog<bool>(
      context: context,
      builder: (_) => AddPaymentDialog(tenant: _selectedTenant!),
    );
    if (added == true) setState(() {});
  }

  Future<void> _confirmDeleteTenant() async {
    if (_selectedTenant == null) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Kiracıyı Sil'),
        content: Text(
            '${_selectedTenant!.fullName} adlı kiracıyı ve tüm kayıtlarını (ödemeler, dekontlar) silmek istediğinize emin misiniz? Bu işlem geri alınamaz.'),
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
      await _db.deleteTenant(_selectedTenant!.id!);
      setState(() => _selectedTenant = null);
      _loadTenants();
    }
  }

  Future<void> _showTermsAndConditions() async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Terms & Conditions'),
        scrollable: true,
        content: const SizedBox(
          width: 480,
          child: Text(
            'Bu uygulama, kullanıcıya ait hiçbir kişisel veriyi veya uygulama '
            'kaydını toplamaz, internet üzerinden iletmez ya da harici bir '
            'sunucuda saklamaz. Uygulamaya girilen tüm bilgiler, bu uygulamanın '
            'kurulu olduğu cihazda yerel olarak depolanır.\n\n'
            'Verilerinizin korunması ve yedeklenmesi kullanıcının '
            'sorumluluğundadır. Uygulamanın cihazdan kaldırılması, cihazın '
            'sıfırlanması veya değiştirilmesi ya da cihazda/uygulamada meydana '
            'gelebilecek bir arıza nedeniyle uygulama içindeki kayıtlara '
            'erişilemeyebilir; bu kayıtlar kalıcı olarak kaybolabilir. Bu tür '
            'durumlarda verilerin kurtarılabileceği garanti edilmez. Önemli '
            'kayıtların düzenli olarak yedeklenmesi önerilir.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Kapat'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Kiracı Ödeme Takip Sistemi'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : LayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.maxWidth;
                final isDesktop = width >= 1100;
                final horizontalPadding = width < 600 ? 12.0 : 24.0;
                final calendar = CalendarPanel(
                  key: ValueKey(_tenants.map((t) => t.id).join(',')),
                  onCreateTenant: _openCreateTenant,
                );
                final rightPanel = _buildRightPanel();

                final content = isDesktop
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(flex: 4, child: calendar),
                          const SizedBox(width: 24),
                          Expanded(flex: 5, child: rightPanel),
                        ],
                      )
                    : Column(
                        children: [
                          Align(
                            alignment: Alignment.topCenter,
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 520),
                              child: calendar,
                            ),
                          ),
                          const SizedBox(height: 24),
                          rightPanel,
                        ],
                      );

                return SingleChildScrollView(
                  padding: EdgeInsets.symmetric(
                    horizontal: horizontalPadding,
                    vertical: width < 600 ? 12 : 24,
                  ),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1500),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          content,
                          const SizedBox(height: 20),
                          Align(
                            alignment: Alignment.center,
                            child: TextButton(
                              onPressed: _showTermsAndConditions,
                              style: TextButton.styleFrom(
                                foregroundColor: Theme.of(context)
                                    .colorScheme
                                    .onSurface
                                    .withValues(alpha: 0.45),
                                textStyle: const TextStyle(fontSize: 12),
                              ),
                              child: const Text('terms&conditions'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }

  Widget _buildRightPanel() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Kiracı Sorgula',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                DropdownButtonFormField<Tenant>(
                  value: _selectedTenant,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Kiracı İsmi Seçiniz',
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  items: _tenants
                      .map((t) => DropdownMenuItem(
                            value: t,
                            child: Text(t.shortName),
                          ))
                      .toList(),
                  onChanged: (t) => setState(() => _selectedTenant = t),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    FilledButton.icon(
                      onPressed: _selectedTenant == null ? null : _openAddPayment,
                      icon: const Icon(Icons.payments_outlined),
                      label: const Text('Yeni Ödeme Gir'),
                    ),
                    OutlinedButton.icon(
                      onPressed: _selectedTenant == null ? null : _openDetail,
                      icon: const Icon(Icons.receipt_long_outlined),
                      label: const Text('Kayıtlar / Ödeme Durumu'),
                    ),
                    OutlinedButton.icon(
                      onPressed: _selectedTenant == null ? null : _openEditDuePayments,
                      icon: const Icon(Icons.edit_calendar_outlined),
                      label: const Text('Ödemeleri Düzenle'),
                    ),
                    OutlinedButton.icon(
                      onPressed: _selectedTenant == null ? null : _openEditTenant,
                      icon: const Icon(Icons.person_outline),
                      label: const Text('Kiracıyı Düzenle'),
                    ),
                    TextButton.icon(
                      onPressed: _selectedTenant == null ? null : _confirmDeleteTenant,
                      icon: const Icon(Icons.delete_outline, color: Colors.red),
                      label: const Text('Kiracıyı Sil', style: TextStyle(color: Colors.red)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Dekontlar',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                const Text(
                  'Kiracıların banka dekontu / ödeme makbuzu fotoğraflarını ekleyin ve görüntüleyin. Tüm dosyalar cihazınızda saklanır.',
                  style: TextStyle(color: Colors.black54),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    FilledButton.icon(
                      onPressed: () async {
                        await Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => ReceiptsAddScreen(
                              initialTenant: _selectedTenant,
                              tenants: _tenants,
                            ),
                          ),
                        );
                      },
                      icon: const Icon(Icons.add_a_photo_outlined),
                      label: const Text('Dekont Ekle'),
                    ),
                    OutlinedButton.icon(
                      onPressed: () async {
                        await Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => ReceiptsViewScreen(
                              initialTenant: _selectedTenant,
                              tenants: _tenants,
                            ),
                          ),
                        );
                      },
                      icon: const Icon(Icons.photo_library_outlined),
                      label: const Text('Dekontları Görüntüle'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Tüm Kiracılar',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                if (_tenants.isEmpty)
                  const Text('Henüz kiracı eklenmedi. "Kiracı Oluştur" ile başlayın.',
                      style: TextStyle(color: Colors.black54))
                else
                  ..._tenants.map((t) => ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const CircleAvatar(child: Icon(Icons.person)),
                        title: Text(t.fullName),
                        subtitle: Text(
                            'Aylık Kira: ${t.monthlyRent.toStringAsFixed(0)} TL  •  Ödeme Günü: ${t.paymentDay}'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () {
                          setState(() => _selectedTenant = t);
                          _openDetail();
                        },
                      )),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
