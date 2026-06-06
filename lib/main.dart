import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'db_helper.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized(); // wajib untuk sqflite
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ),
  );
  runApp(const MyApp());
}

// ==================== MODEL ====================
class Catatan {
  final int? id; // nullable, di-generate SQLite saat insert
  final String judul;
  final String isi;
  final String kategori;
  final String email;
  final DateTime dibuatPada;

  Catatan({
    this.id,
    required this.judul,
    required this.isi,
    required this.kategori,
    required this.email,
    required this.dibuatPada,
  });

  // Dart object → baris database
  Map<String, Object?> toMap() => {
    if (id != null) 'id': id,
    'judul': judul,
    'isi': isi,
    'kategori': kategori,
    'email': email,
    'dibuat_pada': dibuatPada.millisecondsSinceEpoch,
  };

  // Baris database → Dart object
  static Catatan fromMap(Map<String, Object?> m) => Catatan(
    id: m['id'] as int?,
    judul: m['judul'] as String,
    isi: m['isi'] as String,
    kategori: m['kategori'] as String,
    email: m['email'] as String,
    dibuatPada:
    DateTime.fromMillisecondsSinceEpoch(m['dibuat_pada'] as int),
  );

  Catatan copyWith(
      {String? judul, String? isi, String? kategori, String? email}) {
    return Catatan(
      id: id,
      judul: judul ?? this.judul,
      isi: isi ?? this.isi,
      kategori: kategori ?? this.kategori,
      email: email ?? this.email,
      dibuatPada: dibuatPada,
    );
  }
}

// ==================== THEME ====================
class AppColors {
  static const bg = Color(0xFF0A0A0F);
  static const surface = Color(0xFF13131A);
  static const card = Color(0xFF1C1C26);
  static const accent = Color(0xFF7C6FF7);
  static const textPrimary = Color(0xFFF0F0F8);
  static const textSecondary = Color(0xFF8888AA);
  static const textMuted = Color(0xFF4A4A6A);
  static const danger = Color(0xFFFF5E7A);
  static const success = Color(0xFF4FFFB0);
  static const border = Color(0xFF2A2A3A);
}

Color _kategoriColor(String k) {
  switch (k) {
    case 'Kuliah':
      return const Color(0xFF7C6FF7);
    case 'Tugas':
      return const Color(0xFFFF8C5A);
    case 'Pribadi':
      return const Color(0xFF4FFFB0);
    default:
      return const Color(0xFF8888AA);
  }
}

IconData _kategoriIcon(String k) {
  switch (k) {
    case 'Kuliah':
      return Icons.school_rounded;
    case 'Tugas':
      return Icons.assignment_rounded;
    case 'Pribadi':
      return Icons.person_rounded;
    default:
      return Icons.label_rounded;
  }
}

// ==================== APP ====================
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Catatan Mahasiswa',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: AppColors.bg,
        colorScheme: const ColorScheme.dark(
          primary: AppColors.accent,
          surface: AppColors.surface,
        ),
        useMaterial3: true,
      ),
      initialRoute: '/',
      routes: {'/': (context) => const HomePage()},
      onGenerateRoute: (settings) {
        switch (settings.name) {
          case '/tambah':
            return _fadeRoute(const TambahCatatanPage());
          case '/edit':
            final c = settings.arguments as Catatan;
            return _fadeRoute(TambahCatatanPage(catatanEdit: c));
          case '/detail':
            final c = settings.arguments as Catatan;
            return _slideRoute(DetailCatatanPage(catatan: c));
        }
        return null;
      },
    );
  }

  PageRoute _fadeRoute(Widget page) => PageRouteBuilder(
    pageBuilder: (_, __, ___) => page,
    transitionsBuilder: (_, a, __, child) =>
        FadeTransition(opacity: a, child: child),
    transitionDuration: const Duration(milliseconds: 300),
  );

  PageRoute _slideRoute(Widget page) => PageRouteBuilder(
    pageBuilder: (_, __, ___) => page,
    transitionsBuilder: (_, a, __, child) => SlideTransition(
      position: Tween(
        begin: const Offset(1, 0),
        end: Offset.zero,
      ).animate(CurvedAnimation(parent: a, curve: Curves.easeOutCubic)),
      child: child,
    ),
    transitionDuration: const Duration(milliseconds: 350),
  );
}

// ==================== HOME PAGE ====================
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with TickerProviderStateMixin {
  late Future<List<Catatan>> _futureCatatan;
  String _filterAktif = 'Semua';
  final _filterOpsi = const ['Semua', 'Kuliah', 'Tugas', 'Pribadi', 'Lainnya'];

  late AnimationController _fabController;
  late Animation<double> _fabAnim;

  @override
  void initState() {
    super.initState();
    _muatUlang();
    _fabController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fabAnim =
        CurvedAnimation(parent: _fabController, curve: Curves.elasticOut);
    _fabController.forward();
  }

  @override
  void dispose() {
    _fabController.dispose();
    super.dispose();
  }

  void _muatUlang() {
    setState(() {
      _futureCatatan = DbHelper.instance.getAll();
    });
  }

  Future<void> _bukaTambah() async {
    await Navigator.pushNamed(context, '/tambah');
    _muatUlang();
  }

  Future<void> _konfirmasiHapus(Catatan c) async {
    final yakin = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Hapus catatan?',
          style: TextStyle(
              color: AppColors.textPrimary, fontWeight: FontWeight.w700),
        ),
        content: Text(
          '"${c.judul}" akan dihapus permanen.',
          style: const TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal',
                style: TextStyle(color: AppColors.textSecondary)),
          ),
          FilledButton(
            style:
            FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.pop(ctx, true),
            child:
            const Text('Hapus', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (yakin == true) {
      await DbHelper.instance.delete(c.id!);
      if (!mounted) return;
      _muatUlang();
      _showSnack('"${c.judul}" dihapus', AppColors.danger);
    }
  }

  void _showSnack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg,
            style: TextStyle(color: color, fontWeight: FontWeight.w600)),
        backgroundColor: AppColors.card,
        behavior: SnackBarBehavior.floating,
        shape:
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  String _formatTanggal(DateTime dt) =>
      '${dt.day.toString().padLeft(2, '0')}·${dt.month.toString().padLeft(2, '0')}·${dt.year}';

  @override
  Widget build(BuildContext context) {
    final filterColor = _filterAktif == 'Semua'
        ? AppColors.accent
        : _kategoriColor(_filterAktif);

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        elevation: 0,
        title: const Text(
          'CATATAN',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w900,
            color: AppColors.textPrimary,
            letterSpacing: 4,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Container(
              padding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: filterColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: filterColor.withOpacity(0.4)),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _filterAktif,
                  isDense: true,
                  dropdownColor: AppColors.card,
                  icon: Icon(Icons.keyboard_arrow_down_rounded,
                      color: filterColor, size: 18),
                  style: TextStyle(
                    color: filterColor,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    letterSpacing: 0.5,
                  ),
                  items: _filterOpsi.map((f) {
                    final color =
                    f == 'Semua' ? AppColors.accent : _kategoriColor(f);
                    return DropdownMenuItem(
                      value: f,
                      child: Row(
                        children: [
                          Icon(
                            f == 'Semua'
                                ? Icons.all_inbox_rounded
                                : _kategoriIcon(f),
                            color: color,
                            size: 15,
                          ),
                          const SizedBox(width: 8),
                          Text(f,
                              style: TextStyle(
                                  color: color,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13)),
                        ],
                      ),
                    );
                  }).toList(),
                  onChanged: (v) => setState(() => _filterAktif = v!),
                ),
              ),
            ),
          ),
        ],
      ),
      body: FutureBuilder<List<Catatan>>(
        future: _futureCatatan,
        builder: (context, snapshot) {
          // LOADING
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.accent),
            );
          }
          // ERROR
          if (snapshot.hasError) {
            return Center(
              child: Text('Error: ${snapshot.error}',
                  style: const TextStyle(color: AppColors.danger)),
            );
          }

          final semua = snapshot.data ?? [];
          final filtered = _filterAktif == 'Semua'
              ? semua
              : semua.where((c) => c.kategori == _filterAktif).toList();

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                child: Text(
                  '${filtered.length} dari ${semua.length} catatan',
                  style: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 12,
                      letterSpacing: 1),
                ),
              ),
              Expanded(
                child: filtered.isEmpty
                    ? _emptyState()
                    : ListView.builder(
                  padding:
                  const EdgeInsets.fromLTRB(16, 0, 16, 100),
                  itemCount: filtered.length,
                  itemBuilder: (context, i) {
                    final c = filtered[i];
                    return _CatatanCard(
                      catatan: c,
                      index: i,
                      onHapus: () => _konfirmasiHapus(c),
                      onTap: () async {
                        await Navigator.pushNamed(
                            context, '/detail',
                            arguments: c);
                        _muatUlang();
                      },
                      formatTanggal: _formatTanggal,
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: ScaleTransition(
        scale: _fabAnim,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: const LinearGradient(
              colors: [AppColors.accent, Color(0xFF5B54D4)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                  color: AppColors.accent.withOpacity(0.4),
                  blurRadius: 20,
                  offset: const Offset(0, 8)),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: _bukaTambah,
              borderRadius: BorderRadius.circular(20),
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.add_rounded, color: Colors.white, size: 22),
                    SizedBox(width: 8),
                    Text('TAMBAH',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 2,
                          fontSize: 13,
                        )),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _emptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.card,
              border: Border.all(color: AppColors.border),
            ),
            child: const Icon(Icons.note_alt_outlined,
                size: 36, color: AppColors.textMuted),
          ),
          const SizedBox(height: 20),
          Text(
            _filterAktif == 'Semua'
                ? 'Belum ada catatan'
                : 'Tidak ada catatan "$_filterAktif"',
            style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 16,
                letterSpacing: 1),
          ),
          const SizedBox(height: 8),
          const Text('Tap TAMBAH untuk mulai',
              style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
        ],
      ),
    );
  }
}

// ==================== CATATAN CARD ====================
class _CatatanCard extends StatefulWidget {
  final Catatan catatan;
  final int index;
  final VoidCallback onHapus;
  final VoidCallback onTap;
  final String Function(DateTime) formatTanggal;

  const _CatatanCard({
    required this.catatan,
    required this.index,
    required this.onHapus,
    required this.onTap,
    required this.formatTanggal,
  });

  @override
  State<_CatatanCard> createState() => _CatatanCardState();
}

class _CatatanCardState extends State<_CatatanCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 400 + widget.index * 80),
    );
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic);
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = _kategoriColor(widget.catatan.kategori);
    return FadeTransition(
      opacity: _anim,
      child: SlideTransition(
        position:
        Tween(begin: const Offset(0, 0.3), end: Offset.zero).animate(_anim),
        child: Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: widget.onTap,
              borderRadius: BorderRadius.circular(20),
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.border),
                  boxShadow: [
                    BoxShadow(
                        color: color.withOpacity(0.06),
                        blurRadius: 16,
                        offset: const Offset(0, 4)),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      height: 3,
                      decoration: BoxDecoration(
                        borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(20)),
                        gradient: LinearGradient(
                            colors: [color, color.withOpacity(0.2)]),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
                      child: Row(
                        children: [
                          Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              color: color.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                                _kategoriIcon(widget.catatan.kategori),
                                color: color,
                                size: 20),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  widget.catatan.judul,
                                  style: const TextStyle(
                                      color: AppColors.textPrimary,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 15),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: color.withOpacity(0.12),
                                        borderRadius:
                                        BorderRadius.circular(6),
                                      ),
                                      child: Text(widget.catatan.kategori,
                                          style: TextStyle(
                                              color: color,
                                              fontSize: 10,
                                              fontWeight: FontWeight.w700)),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                        widget.formatTanggal(
                                            widget.catatan.dibuatPada),
                                        style: const TextStyle(
                                            color: AppColors.textMuted,
                                            fontSize: 11)),
                                  ],
                                ),
                                const SizedBox(height: 3),
                                Row(
                                  children: [
                                    const Icon(Icons.email_outlined,
                                        size: 11,
                                        color: AppColors.textMuted),
                                    const SizedBox(width: 4),
                                    Text(widget.catatan.email,
                                        style: const TextStyle(
                                            color: AppColors.textMuted,
                                            fontSize: 11)),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline_rounded,
                                color: AppColors.textMuted, size: 20),
                            onPressed: widget.onHapus,
                          ),
                        ],
                      ),
                    ),
                    if (widget.catatan.isi.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(72, 0, 16, 14),
                        child: Text(
                          widget.catatan.isi,
                          style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 12,
                              height: 1.4),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ==================== TAMBAH / EDIT PAGE ====================
class TambahCatatanPage extends StatefulWidget {
  final Catatan? catatanEdit;
  const TambahCatatanPage({super.key, this.catatanEdit});

  @override
  State<TambahCatatanPage> createState() => _TambahCatatanPageState();
}

class _TambahCatatanPageState extends State<TambahCatatanPage> {
  final _formKey = GlobalKey<FormState>();
  final _judulCtrl = TextEditingController();
  final _isiCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  String _kategori = 'Kuliah';
  final _kategoriOpsi = const ['Kuliah', 'Tugas', 'Pribadi', 'Lainnya'];
  bool _menyimpan = false;

  @override
  void initState() {
    super.initState();
    if (widget.catatanEdit != null) {
      _judulCtrl.text = widget.catatanEdit!.judul;
      _isiCtrl.text = widget.catatanEdit!.isi;
      _emailCtrl.text = widget.catatanEdit!.email;
      _kategori = widget.catatanEdit!.kategori;
    }
  }

  @override
  void dispose() {
    _judulCtrl.dispose();
    _isiCtrl.dispose();
    _emailCtrl.dispose();
    super.dispose();
  }

  bool _isEmailValid(String email) {
    final regex = RegExp(r'^[\w\.-]+@[\w\.-]+\.\w{2,}$');
    return regex.hasMatch(email);
  }

  Future<void> _simpan() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _menyimpan = true);

    try {
      final isEdit = widget.catatanEdit != null;
      if (isEdit) {
        final updated = widget.catatanEdit!.copyWith(
          judul: _judulCtrl.text.trim(),
          isi: _isiCtrl.text.trim(),
          kategori: _kategori,
          email: _emailCtrl.text.trim(),
        );
        await DbHelper.instance.update(updated);
      } else {
        final baru = Catatan(
          judul: _judulCtrl.text.trim(),
          isi: _isiCtrl.text.trim(),
          kategori: _kategori,
          email: _emailCtrl.text.trim(),
          dibuatPada: DateTime.now(),
        );
        await DbHelper.instance.insert(baru);
      }

      if (!mounted) return;
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      setState(() => _menyimpan = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal menyimpan: $e',
              style: const TextStyle(color: AppColors.danger)),
          backgroundColor: AppColors.card,
        ),
      );
    }
  }

  InputDecoration _inputDeco(String label, IconData icon) => InputDecoration(
    labelText: label,
    labelStyle: const TextStyle(color: AppColors.textSecondary),
    prefixIcon: Icon(icon, color: AppColors.accent, size: 20),
    filled: true,
    fillColor: AppColors.card,
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: AppColors.border),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: AppColors.accent, width: 1.5),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: AppColors.danger),
    ),
    focusedErrorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: AppColors.danger, width: 1.5),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.catatanEdit != null;
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded,
              color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          isEdit ? 'EDIT CATATAN' : 'CATATAN BARU',
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w900,
            letterSpacing: 3,
            fontSize: 16,
          ),
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // ── JUDUL ──
            TextFormField(
              controller: _judulCtrl,
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: _inputDeco('Judul', Icons.title_rounded),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Judul wajib diisi';
                if (v.trim().length < 3) return 'Minimal 3 karakter';
                return null;
              },
            ),
            const SizedBox(height: 16),

            // ── KATEGORI ──
            DropdownButtonFormField<String>(
              value: _kategori,
              dropdownColor: AppColors.card,
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: _inputDeco('Kategori', Icons.category_rounded),
              items: _kategoriOpsi.map((k) {
                final color = _kategoriColor(k);
                return DropdownMenuItem(
                  value: k,
                  child: Row(
                    children: [
                      Icon(_kategoriIcon(k), color: color, size: 16),
                      const SizedBox(width: 8),
                      Text(k),
                    ],
                  ),
                );
              }).toList(),
              onChanged: (v) => setState(() => _kategori = v!),
            ),
            const SizedBox(height: 16),

            // ── EMAIL ──
            TextFormField(
              controller: _emailCtrl,
              style: const TextStyle(color: AppColors.textPrimary),
              keyboardType: TextInputType.emailAddress,
              decoration: _inputDeco('Email pengirim', Icons.email_rounded),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Email wajib diisi';
                if (!_isEmailValid(v.trim()))
                  return 'Format email tidak valid';
                return null;
              },
            ),
            const SizedBox(height: 16),

            // ── ISI ──
            TextFormField(
              controller: _isiCtrl,
              maxLines: 6,
              style:
              const TextStyle(color: AppColors.textPrimary, height: 1.6),
              decoration: _inputDeco('Isi catatan', Icons.notes_rounded),
              validator: (v) =>
              (v == null || v.trim().isEmpty) ? 'Isi wajib diisi' : null,
            ),
            const SizedBox(height: 32),

            // ── TOMBOL SIMPAN ──
            Container(
              height: 54,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: const LinearGradient(
                  colors: [AppColors.accent, Color(0xFF5B54D4)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.accent.withOpacity(0.35),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: _menyimpan ? null : _simpan,
                  borderRadius: BorderRadius.circular(16),
                  child: Center(
                    child: _menyimpan
                        ? const CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2)
                        : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                            isEdit
                                ? Icons.update_rounded
                                : Icons.save_rounded,
                            color: Colors.white),
                        const SizedBox(width: 10),
                        Text(
                          isEdit ? 'UPDATE' : 'SIMPAN',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 3,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ==================== DETAIL PAGE ====================
class DetailCatatanPage extends StatelessWidget {
  final Catatan catatan;
  const DetailCatatanPage({super.key, required this.catatan});

  String _formatTanggal(DateTime dt) =>
      '${dt.day.toString().padLeft(2, '0')}·${dt.month.toString().padLeft(2, '0')}·${dt.year}';

  @override
  Widget build(BuildContext context) {
    final color = _kategoriColor(catatan.kategori);
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded,
              color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'DETAIL',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w900,
            letterSpacing: 3,
            fontSize: 16,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_rounded, color: AppColors.accent),
            onPressed: () async {
              await Navigator.pushNamed(context, '/edit', arguments: catatan);
              if (context.mounted) Navigator.pop(context);
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── HEADER CARD ──
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: AppColors.border),
                boxShadow: [
                  BoxShadow(
                      color: color.withOpacity(0.08),
                      blurRadius: 24,
                      offset: const Offset(0, 8)),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: color.withOpacity(0.3)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(_kategoriIcon(catatan.kategori),
                                color: color, size: 14),
                            const SizedBox(width: 6),
                            Text(
                              catatan.kategori.toUpperCase(),
                              style: TextStyle(
                                  color: color,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1),
                            ),
                          ],
                        ),
                      ),
                      const Spacer(),
                      Text(_formatTanggal(catatan.dibuatPada),
                          style: const TextStyle(
                              color: AppColors.textMuted, fontSize: 12)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    catatan.judul,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Icon(Icons.email_outlined,
                          size: 14, color: AppColors.textMuted),
                      const SizedBox(width: 8),
                      Text(
                        catatan.email,
                        style: const TextStyle(
                            color: AppColors.textSecondary, fontSize: 13),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // ── ISI CARD ──
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'ISI CATATAN',
                    style: TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 2),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    catatan.isi,
                    style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 15,
                        height: 1.7),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}