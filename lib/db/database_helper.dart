import 'dart:io';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart' as mobile_sqflite;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../models/tenant.dart';
import '../models/due_payment.dart';
import '../models/payment_record.dart';
import '../models/receipt.dart';
import '../models/tenant_note.dart';
import '../models/contract_change.dart';

/// Uygulamanın tüm verilerini (kiracılar, borç satırları, ödemeler,
/// dekontlar, notlar, sözleşme geçmişi) cihazın yerel SQLite
/// veritabanında saklayan sınıf. Tamamen çevrimdışı çalışır; hiçbir veri
/// internete gönderilmez.
class DatabaseHelper {
  DatabaseHelper._internal();
  static final DatabaseHelper instance = DatabaseHelper._internal();

  /// Şema sürümü. v1 -> v2 geçişinde depozito, stopaj, hatırlatma
  /// alanları ile notlar ve sözleşme geçmişi tabloları eklenir.
  /// Mevcut kayıtlarınız korunur, hiçbir veri silinmez.
  static const int _dbVersion = 2;

  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final appDocDir = await getApplicationSupportDirectory();
    final dbDir = Directory(join(appDocDir.path, 'KiraciTakip'));
    if (!await dbDir.exists()) {
      await dbDir.create(recursive: true);
    }
    final dbPath = join(dbDir.path, 'kiraci_takip.db');

    if (Platform.isAndroid || Platform.isIOS) {
      return mobile_sqflite.openDatabase(
        dbPath,
        version: _dbVersion,
        onCreate: _onCreate,
        onUpgrade: _onUpgrade,
      );
    }

    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;

    return await databaseFactory.openDatabase(
      dbPath,
      options: OpenDatabaseOptions(
        version: _dbVersion,
        onCreate: _onCreate,
        onUpgrade: _onUpgrade,
      ),
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE tenants (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        surname TEXT NOT NULL,
        contractStart TEXT NOT NULL,
        contractEnd TEXT NOT NULL,
        monthlyRent REAL NOT NULL,
        paymentDay INTEGER NOT NULL,
        phone TEXT,
        notes TEXT,
        propertyAddress TEXT,
        depositAmount REAL NOT NULL DEFAULT 0,
        depositReceivedDate TEXT,
        depositReturnedDate TEXT,
        depositNote TEXT,
        withholdingEnabled INTEGER NOT NULL DEFAULT 0,
        withholdingRate REAL NOT NULL DEFAULT 20,
        rentIsNet INTEGER NOT NULL DEFAULT 1,
        reminderDaysBefore INTEGER NOT NULL DEFAULT 60
      )
    ''');

    await db.execute('''
      CREATE TABLE due_payments (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        tenantId INTEGER NOT NULL,
        dueDate TEXT NOT NULL,
        dueAmount REAL NOT NULL,
        description TEXT,
        FOREIGN KEY (tenantId) REFERENCES tenants (id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE payment_records (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        tenantId INTEGER NOT NULL,
        duePaymentId INTEGER,
        paidDate TEXT NOT NULL,
        paidAmount REAL NOT NULL,
        note TEXT,
        FOREIGN KEY (tenantId) REFERENCES tenants (id) ON DELETE CASCADE,
        FOREIGN KEY (duePaymentId) REFERENCES due_payments (id) ON DELETE SET NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE receipts (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        tenantId INTEGER NOT NULL,
        filePath TEXT NOT NULL,
        addedDate TEXT NOT NULL,
        description TEXT,
        FOREIGN KEY (tenantId) REFERENCES tenants (id) ON DELETE CASCADE
      )
    ''');

    await _createV2Tables(db);
  }

  Future<void> _createV2Tables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS tenant_notes (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        tenantId INTEGER NOT NULL,
        createdAt TEXT NOT NULL,
        text TEXT NOT NULL,
        pinned INTEGER NOT NULL DEFAULT 0,
        FOREIGN KEY (tenantId) REFERENCES tenants (id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS contract_changes (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        tenantId INTEGER NOT NULL,
        changedAt TEXT NOT NULL,
        oldEnd TEXT NOT NULL,
        newEnd TEXT NOT NULL,
        oldRent REAL NOT NULL,
        newRent REAL NOT NULL,
        note TEXT,
        FOREIGN KEY (tenantId) REFERENCES tenants (id) ON DELETE CASCADE
      )
    ''');
  }

  /// Eski veritabanlarını (v1) yeni sürüme taşır. Var olan kiracı,
  /// ödeme ve dekont kayıtlarına dokunulmaz; yalnızca yeni sütunlar ve
  /// tablolar eklenir.
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      final existing = await db.rawQuery('PRAGMA table_info(tenants)');
      final columnNames = existing.map((c) => c['name'] as String).toSet();

      Future<void> addColumn(String name, String definition) async {
        if (columnNames.contains(name)) return;
        await db.execute('ALTER TABLE tenants ADD COLUMN $definition');
      }

      await addColumn('depositAmount', 'depositAmount REAL NOT NULL DEFAULT 0');
      await addColumn('depositReceivedDate', 'depositReceivedDate TEXT');
      await addColumn('depositReturnedDate', 'depositReturnedDate TEXT');
      await addColumn('depositNote', 'depositNote TEXT');
      await addColumn('withholdingEnabled', 'withholdingEnabled INTEGER NOT NULL DEFAULT 0');
      await addColumn('withholdingRate', 'withholdingRate REAL NOT NULL DEFAULT 20');
      await addColumn('rentIsNet', 'rentIsNet INTEGER NOT NULL DEFAULT 1');
      await addColumn('reminderDaysBefore', 'reminderDaysBefore INTEGER NOT NULL DEFAULT 60');

      await _createV2Tables(db);
    }
  }

  // ---------------------------------------------------------------------
  // TENANTS
  // ---------------------------------------------------------------------

  Future<int> insertTenant(Tenant tenant) async {
    final db = await database;
    return await db.insert('tenants', tenant.toMap()..remove('id'));
  }

  Future<int> updateTenant(Tenant tenant) async {
    final db = await database;
    return await db.update('tenants', tenant.toMap(),
        where: 'id = ?', whereArgs: [tenant.id]);
  }

  Future<int> deleteTenant(int id) async {
    final db = await database;
    // İlişkili borç satırları, ödemeler, dekontlar, notlar ve sözleşme
    // geçmişi de silinir.
    await db.delete('due_payments', where: 'tenantId = ?', whereArgs: [id]);
    await db.delete('payment_records', where: 'tenantId = ?', whereArgs: [id]);
    await db.delete('receipts', where: 'tenantId = ?', whereArgs: [id]);
    await db.delete('tenant_notes', where: 'tenantId = ?', whereArgs: [id]);
    await db.delete('contract_changes', where: 'tenantId = ?', whereArgs: [id]);
    return await db.delete('tenants', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<Tenant>> getAllTenants() async {
    final db = await database;
    final maps = await db.query('tenants', orderBy: 'name ASC');
    return maps.map((m) => Tenant.fromMap(m)).toList();
  }

  Future<Tenant?> getTenant(int id) async {
    final db = await database;
    final maps = await db.query('tenants', where: 'id = ?', whereArgs: [id]);
    if (maps.isEmpty) return null;
    return Tenant.fromMap(maps.first);
  }

  // ---------------------------------------------------------------------
  // DUE PAYMENTS (Yapılması Gereken Ödemeler)
  // ---------------------------------------------------------------------

  Future<int> insertDuePayment(DuePayment duePayment) async {
    final db = await database;
    return await db.insert('due_payments', duePayment.toMap()..remove('id'));
  }

  Future<int> updateDuePayment(DuePayment duePayment) async {
    final db = await database;
    return await db.update('due_payments', duePayment.toMap(),
        where: 'id = ?', whereArgs: [duePayment.id]);
  }

  Future<int> deleteDuePayment(int id) async {
    final db = await database;
    await db.update('payment_records', {'duePaymentId': null},
        where: 'duePaymentId = ?', whereArgs: [id]);
    return await db.delete('due_payments', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<DuePayment>> getDuePaymentsForTenant(int tenantId) async {
    final db = await database;
    final maps = await db.query('due_payments',
        where: 'tenantId = ?', whereArgs: [tenantId], orderBy: 'dueDate ASC');
    return maps.map((m) => DuePayment.fromMap(m)).toList();
  }

  Future<List<DuePayment>> getAllDuePayments() async {
    final db = await database;
    final maps = await db.query('due_payments', orderBy: 'dueDate ASC');
    return maps.map((m) => DuePayment.fromMap(m)).toList();
  }

  // ---------------------------------------------------------------------
  // PAYMENT RECORDS (Yapılan Ödemeler)
  // ---------------------------------------------------------------------

  Future<int> insertPaymentRecord(PaymentRecord record) async {
    final db = await database;
    return await db.insert('payment_records', record.toMap()..remove('id'));
  }

  Future<int> updatePaymentRecord(PaymentRecord record) async {
    final db = await database;
    return await db.update('payment_records', record.toMap(),
        where: 'id = ?', whereArgs: [record.id]);
  }

  Future<int> deletePaymentRecord(int id) async {
    final db = await database;
    return await db.delete('payment_records', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<PaymentRecord>> getPaymentRecordsForTenant(int tenantId) async {
    final db = await database;
    final maps = await db.query('payment_records',
        where: 'tenantId = ?', whereArgs: [tenantId], orderBy: 'paidDate ASC');
    return maps.map((m) => PaymentRecord.fromMap(m)).toList();
  }

  Future<List<PaymentRecord>> getAllPaymentRecords() async {
    final db = await database;
    final maps = await db.query('payment_records', orderBy: 'paidDate ASC');
    return maps.map((m) => PaymentRecord.fromMap(m)).toList();
  }

  // ---------------------------------------------------------------------
  // RECEIPTS (Dekontlar)
  // ---------------------------------------------------------------------

  Future<int> insertReceipt(Receipt receipt) async {
    final db = await database;
    return await db.insert('receipts', receipt.toMap()..remove('id'));
  }

  Future<int> deleteReceipt(int id) async {
    final db = await database;
    return await db.delete('receipts', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<Receipt>> getReceiptsForTenant(int tenantId) async {
    final db = await database;
    final maps = await db.query('receipts',
        where: 'tenantId = ?', whereArgs: [tenantId], orderBy: 'addedDate DESC');
    return maps.map((m) => Receipt.fromMap(m)).toList();
  }

  // ---------------------------------------------------------------------
  // TENANT NOTES (Kiracı Notlar Paneli)
  // ---------------------------------------------------------------------

  Future<int> insertTenantNote(TenantNote note) async {
    final db = await database;
    return await db.insert('tenant_notes', note.toMap()..remove('id'));
  }

  Future<int> updateTenantNote(TenantNote note) async {
    final db = await database;
    return await db.update('tenant_notes', note.toMap(),
        where: 'id = ?', whereArgs: [note.id]);
  }

  Future<int> deleteTenantNote(int id) async {
    final db = await database;
    return await db.delete('tenant_notes', where: 'id = ?', whereArgs: [id]);
  }

  /// Sabitlenmiş notlar en üstte, sonra en yeni not en üstte olacak şekilde.
  Future<List<TenantNote>> getNotesForTenant(int tenantId) async {
    final db = await database;
    final maps = await db.query('tenant_notes',
        where: 'tenantId = ?',
        whereArgs: [tenantId],
        orderBy: 'pinned DESC, createdAt DESC');
    return maps.map((m) => TenantNote.fromMap(m)).toList();
  }

  // ---------------------------------------------------------------------
  // CONTRACT CHANGES (Sözleşme Uzatma Geçmişi)
  // ---------------------------------------------------------------------

  Future<int> insertContractChange(ContractChange change) async {
    final db = await database;
    return await db.insert('contract_changes', change.toMap()..remove('id'));
  }

  Future<List<ContractChange>> getContractChangesForTenant(int tenantId) async {
    final db = await database;
    final maps = await db.query('contract_changes',
        where: 'tenantId = ?', whereArgs: [tenantId], orderBy: 'changedAt DESC');
    return maps.map((m) => ContractChange.fromMap(m)).toList();
  }
}