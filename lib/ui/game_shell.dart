import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../game/catalog.dart';
import '../game/engine.dart';
import '../game/state.dart';
import '../persistence/save_store.dart';
import 'cafe_scene.dart';

const ink = Color(0xFF263F36),
    sage = Color(0xFF436C59),
    cream = Color(0xFFF7F4EC),
    muted = Color(0xFF737D72);
const labels = [
  'Kafe',
  'Resep',
  'Dekorasi',
  'Cerita',
  'Lainnya',
  'Peralatan',
  'Tim',
  'Progres',
  'Akun & data',
];
const icons = [
  Icons.storefront_outlined,
  Icons.coffee_outlined,
  Icons.chair_outlined,
  Icons.forum_outlined,
  Icons.grid_view_rounded,
  Icons.kitchen_outlined,
  Icons.people_outline,
  Icons.insights_outlined,
  Icons.cloud_outlined,
];

class GameShell extends StatefulWidget {
  final GameEngine engine;
  final SaveStore store;
  final Widget? accountPanel;
  final VoidCallback? onSaved;
  const GameShell({
    super.key,
    required this.engine,
    required this.store,
    this.accountPanel,
    this.onSaved,
  });
  @override
  State<GameShell> createState() => _GameShellState();
}

class _GameShellState extends State<GameShell> with WidgetsBindingObserver {
  int page = 0;
  String? placing;
  int? moving;
  Timer? tick, checkpoint;
  String saveStatus = 'Tersimpan di perangkat';
  GameEngine get game => widget.engine;
  CafeState get s => game.state;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _start();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.store.warning != null) _toast(widget.store.warning!);
      if (game.offlineCoins > 0) {
        _toast(
          'Selamat datang kembali. Ayu menghasilkan ${game.offlineCoins} koin saat kamu pergi.',
        );
      }
    });
  }

  void _start() {
    tick?.cancel();
    checkpoint?.cancel();
    tick = Timer.periodic(const Duration(seconds: 1), (_) => game.tick());
    checkpoint = Timer.periodic(const Duration(seconds: 10), (_) => _save());
  }

  Future<void> _save() async {
    s.lastSeen = game.now;
    try {
      await widget.store.save(s);
      widget.onSaved?.call();
      if (mounted && saveStatus != 'Tersimpan di perangkat') {
        setState(() => saveStatus = 'Tersimpan di perangkat');
      }
    } catch (_) {
      if (mounted) {
        setState(() => saveStatus = 'Penyimpanan gagal · salin cadangan');
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      game.resume();
      _start();
      _save();
    } else {
      tick?.cancel();
      checkpoint?.cancel();
      _save();
    }
  }

  @override
  void dispose() {
    tick?.cancel();
    checkpoint?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _toast(String value) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(value),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 4),
        ),
      );
  }

  void _act(String Function() fn) {
    _toast(fn());
    _save();
  }

  void _navigate(int value) => setState(() {
    page = value;
    placing = null;
    moving = null;
  });
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: game,
    builder: (context, _) => LayoutBuilder(
      builder: (context, bounds) {
        final wide = bounds.maxWidth >= 960;
        return Scaffold(
          backgroundColor: cream,
          body: SafeArea(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (wide) _sidebar(),
                Expanded(
                  child: Column(
                    children: [
                      _header(wide),
                      Expanded(
                        child: SingleChildScrollView(
                          padding: EdgeInsets.fromLTRB(
                            wide ? 32 : 16,
                            8,
                            wide ? 32 : 16,
                            28,
                          ),
                          child: Align(
                            alignment: Alignment.topCenter,
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 1280),
                              child: _page(wide),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          bottomNavigationBar: wide
              ? null
              : NavigationBar(
                  selectedIndex: page < 5 ? page : 4,
                  onDestinationSelected: _navigate,
                  backgroundColor: const Color(0xFFFFFDF7),
                  destinations: List.generate(
                    5,
                    (i) => NavigationDestination(
                      icon: Icon(icons[i]),
                      label: labels[i],
                    ),
                  ),
                ),
        );
      },
    ),
  );
  Widget _sidebar() => Container(
    width: 210,
    decoration: const BoxDecoration(
      color: Color(0xFFFFFDF7),
      border: Border(right: BorderSide(color: Color(0xFFE4E7DC))),
    ),
    child: SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 10),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                    color: sage,
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: const Icon(
                    Icons.coffee_rounded,
                    color: Colors.white,
                    size: 26,
                  ),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'MY CLOUD\nCAFÉ',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        height: 1.15,
                        letterSpacing: 1.3,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 42),
            const Text(
              'KAFE MILIKMU',
              style: TextStyle(
                fontSize: 10,
                color: muted,
                letterSpacing: 2,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            for (final i in [0, 1, 5, 2, 6, 3, 7])
              Padding(
                padding: const EdgeInsets.only(bottom: 7),
                child: _navTile(i),
              ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF0F3E9),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.wifi_off_rounded, size: 20, color: sage),
                  SizedBox(height: 8),
                  Text(
                    'Bisa main offline',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                  ),
                  SizedBox(height: 5),
                  Text(
                    'Kafe tetap di perangkatmu.',
                    style: TextStyle(fontSize: 11, color: muted),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            _navTile(8),
            const SizedBox(height: 8),
          ],
        ),
      ),
    ),
  );
  Widget _navTile(int i) => Material(
    color: page == i ? const Color(0xFFEAF0E5) : Colors.transparent,
    borderRadius: BorderRadius.circular(12),
    child: InkWell(
      onTap: () => _navigate(i),
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 12),
        child: Row(
          children: [
            Icon(icons[i], color: page == i ? sage : muted, size: 21),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                labels[i],
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: page == i ? FontWeight.w700 : FontWeight.w500,
                  color: page == i ? ink : muted,
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
  Widget _header(bool wide) => Padding(
    padding: EdgeInsets.fromLTRB(
      wide ? 32 : 16,
      wide ? 26 : 16,
      wide ? 32 : 16,
      18,
    ),
    child: Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'MY CLOUD CAFÉ',
                style: const TextStyle(
                  color: muted,
                  fontSize: 10,
                  letterSpacing: 2.2,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                page == 0 ? 'Kafe hari ini' : labels[page],
                style: TextStyle(
                  fontSize: wide ? 30 : 24,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -.8,
                ),
              ),
            ],
          ),
        ),
        _pill(
          Icons.star_rounded,
          'Lv. ${s.level}',
          const Color(0xFFECEEDC),
          sage,
        ),
        const SizedBox(width: 8),
        _pill(
          Icons.toll_rounded,
          '${s.coins}',
          const Color(0xFFF5E6BC),
          const Color(0xFF8D6530),
        ),
        if (wide) ...[
          const SizedBox(width: 16),
          IconButton(
            tooltip: 'Akun dan cadangan',
            onPressed: () => _navigate(8),
            icon: const Icon(Icons.cloud_done_outlined, color: sage),
          ),
        ],
      ],
    ),
  );
  Widget _pill(IconData icon, String value, Color bg, Color fg) => Container(
    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
    decoration: BoxDecoration(
      color: bg,
      borderRadius: BorderRadius.circular(30),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18, color: fg),
        const SizedBox(width: 5),
        Text(
          value,
          style: TextStyle(
            color: fg,
            fontWeight: FontWeight.w800,
            fontSize: 13,
          ),
        ),
      ],
    ),
  );
  Widget _page(bool wide) => switch (page) {
    0 => _cafe(wide),
    1 => _recipes(),
    2 => _decoration(),
    3 => _stories(),
    5 => _equipment(),
    6 => _team(),
    7 => _progress(),
    8 => _data(),
    _ => _more(),
  };
  Widget _cafe(bool wide) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      if (s.served == 0)
        _notice(
          'Mulai dari secangkir espresso',
          'Tekan Siapkan pada pesanan, lalu Sajikan saat selesai.',
          Icons.waving_hand_outlined,
        ),
      const SizedBox(height: 12),
      if (wide)
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: 7, child: _room()),
            const SizedBox(width: 20),
            Expanded(flex: 3, child: _daily()),
          ],
        )
      else ...[
        _room(),
        const SizedBox(height: 16),
        _daily(),
      ],
      const SizedBox(height: 26),
      _section(
        'Pesanan masuk',
        '${s.orders.length} / ${s.capacity} kursi',
        action: TextButton(
          onPressed: () => _navigate(1),
          child: const Text('Lihat menu'),
        ),
      ),
      const SizedBox(height: 12),
      if (s.orders.isEmpty)
        _notice(
          'Meja sudah rapi',
          'Pelanggan berikutnya akan datang sebentar lagi.',
          Icons.coffee_outlined,
        )
      else
        LayoutBuilder(
          builder: (context, b) => Wrap(
            spacing: 12,
            runSpacing: 12,
            children: s.orders
                .map(
                  (o) => SizedBox(
                    width: b.maxWidth < 600
                        ? b.maxWidth
                        : (b.maxWidth - 24) / math.min(3, s.orders.length),
                    child: _order(o),
                  ),
                )
                .toList(),
          ),
        ),
      const SizedBox(height: 22),
      Row(
        children: [
          const Icon(Icons.check_circle_outline, size: 14, color: muted),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              saveStatus,
              style: const TextStyle(fontSize: 11, color: muted),
            ),
          ),
          Text(
            '${s.served} pesanan selesai',
            style: const TextStyle(fontSize: 11, color: muted),
          ),
        ],
      ),
    ],
  );
  Widget _room({bool edit = false}) => _card(
    padding: 0,
    child: Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
          child: Row(
            children: [
              Container(
                width: 7,
                height: 7,
                decoration: const BoxDecoration(
                  color: sage,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 7),
              const Text(
                'BUKA',
                style: TextStyle(
                  fontSize: 10,
                  letterSpacing: 1.5,
                  fontWeight: FontWeight.w800,
                  color: sage,
                ),
              ),
              const Spacer(),
              Icon(
                Icons.wb_sunny_outlined,
                size: 16,
                color: Colors.amber.shade800,
              ),
              const SizedBox(width: 5),
              Text(
                '${s.capacity} meja · ${s.charm} suasana',
                style: const TextStyle(fontSize: 11, color: muted),
              ),
            ],
          ),
        ),
        DecoratedBox(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFFFFFDF8), Color(0xFFF1F2E4)],
            ),
          ),
          child: CafeScene(
            state: s,
            editing: edit,
            selected: moving,
            onTile: edit ? (x, y) => _onTile(x, y) : null,
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: Row(
            children: [
              const Icon(Icons.chair_alt_outlined, size: 17, color: sage),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  edit
                      ? placing != null
                            ? 'Ketuk ubin untuk menempatkan ${furniture.firstWhere((f) => f.id == placing).name.toLowerCase()}'
                            : moving != null
                            ? 'Ketuk ubin tujuan'
                            : 'Ketuk perabot untuk memindahkannya'
                      : 'Sudut kecilmu di tengah kota',
                  style: const TextStyle(fontSize: 12, color: muted),
                ),
              ),
              if (!edit)
                TextButton(
                  onPressed: () => _navigate(2),
                  child: const Text('Atur ruang'),
                ),
            ],
          ),
        ),
      ],
    ),
  );
  Widget _daily() {
    final goal = GameEngine.goalTargets.indexWhere((t) => t > s.served);
    final target = goal < 0 ? 60 : GameEngine.goalTargets[goal];
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Sedikit demi sedikit',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          const Text(
            'Kembangkan kafe dengan ritmemu.',
            style: TextStyle(color: muted, fontSize: 12),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              const Icon(Icons.local_cafe_outlined, color: sage, size: 21),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Layani $target pesanan',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                '${math.min(s.served, target)}/$target',
                style: const TextStyle(color: muted, fontSize: 11),
              ),
            ],
          ),
          const SizedBox(height: 12),
          LinearProgressIndicator(
            value: (s.served / target).clamp(0, 1),
            minHeight: 6,
            borderRadius: BorderRadius.circular(8),
            backgroundColor: const Color(0xFFEAEDE1),
          ),
          const SizedBox(height: 18),
          _smallStat('Level berikutnya', '${s.xp % 100} / 100 XP'),
          const SizedBox(height: 12),
          _smallStat(
            'Tip dari suasana',
            '+${math.min(s.charm ~/ 3, 20)} / pesanan',
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () => _navigate(7),
              child: const Text('Lihat target'),
            ),
          ),
          const Divider(height: 32),
          Row(
            children: [
              CircleAvatar(
                backgroundColor: const Color(0xFFF5DFCC),
                child: Text(
                  s.staff ? 'A' : 'N',
                  style: const TextStyle(
                    color: Color(0xFF976348),
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      s.staff ? 'Ayu sedang bertugas' : 'Kenalan dengan Nara',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      s.staff
                          ? 'Pesanan dibantu otomatis'
                          : 'Cerita pertama · 1 pesanan',
                      style: const TextStyle(fontSize: 11, color: muted),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => _navigate(s.staff ? 6 : 3),
            child: Text(s.staff ? 'Lihat tim' : 'Buka cerita'),
          ),
        ],
      ),
    );
  }

  Widget _order(Order o) {
    final r = recipeById(o.recipe),
        brews = s.brews.where((b) => b.orderId == o.id);
    final brew = brews.isEmpty ? null : brews.first,
        ready = brew != null && brew.readyAt <= game.now;
    final seconds = brew == null
        ? 0
        : math.max(0, ((brew.readyAt - game.now) / 1000).ceil());
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 17,
                backgroundColor: const Color(0xFFEADDCF),
                child: Text(
                  o.name[0],
                  style: const TextStyle(
                    color: ink,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  o.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ),
              Text(
                '+${r.price}',
                style: const TextStyle(
                  color: sage,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Text(
                r.symbol,
                style: const TextStyle(fontFamily: 'CafeEmoji', fontSize: 30),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      r.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      brew == null
                          ? 'Menunggu · ${math.max(0, ((o.deadline - game.now) / 1000).ceil())} dtk'
                          : ready
                          ? 'Siap diantar'
                          : 'Disiapkan · $seconds dtk',
                      style: const TextStyle(fontSize: 11, color: muted),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          if (brew != null && !ready) ...[
            LinearProgressIndicator(
              value:
                  ((game.now - brew.startedAt) /
                          (brew.readyAt - brew.startedAt))
                      .clamp(0, 1),
              minHeight: 4,
              borderRadius: BorderRadius.circular(4),
            ),
            const SizedBox(height: 12),
          ],
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: brew == null
                  ? () => _act(() => game.brew(o.id))
                  : ready
                  ? () => _act(() => game.serve(o.id))
                  : null,
              child: Text(
                brew == null
                    ? 'Siapkan'
                    : ready
                    ? 'Sajikan'
                    : 'Sedang disiapkan',
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _recipes() => _catalogGrid(
    recipes.map((r) {
      final owned = s.unlocked.contains(r.id),
          allowed = s.level >= r.level && s.machines.contains(r.equipment);
      return _card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _art(
              r.symbol,
              owned ? const Color(0xFFEAF0E5) : const Color(0xFFF2EADC),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: Text(
                    r.name,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                if (owned)
                  const Icon(Icons.check_circle_rounded, color: sage, size: 19),
              ],
            ),
            const SizedBox(height: 7),
            Text(
              r.description,
              style: const TextStyle(color: muted, fontSize: 12, height: 1.6),
            ),
            const SizedBox(height: 18),
            _smallStat('Harga saji', '${r.price} koin'),
            const SizedBox(height: 8),
            _smallStat('Waktu', '${r.seconds} detik'),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: owned
                  ? OutlinedButton(
                      onPressed: null,
                      child: const Text('Ada di menu'),
                    )
                  : FilledButton(
                      onPressed: allowed
                          ? () => _act(() => game.unlockRecipe(r))
                          : null,
                      child: Text(
                        s.level < r.level
                            ? 'Level ${r.level}'
                            : !s.machines.contains(r.equipment)
                            ? 'Butuh ${equipment.firstWhere((e) => e.id == r.equipment).name}'
                            : 'Pelajari · ${r.cost} koin',
                      ),
                    ),
            ),
          ],
        ),
      );
    }).toList(),
    intro: 'Semua resep dibuka dengan koin hasil melayani pelanggan.',
  );
  Widget _equipment() => _catalogGrid(
    equipment.map((e) {
      final owned = s.machines.contains(e.id);
      return _card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _iconArt(Icons.coffee_maker_outlined),
            const SizedBox(height: 18),
            Text(
              e.name,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              e.description,
              style: const TextStyle(fontSize: 12, color: muted),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: owned || s.level < e.level
                    ? null
                    : () => _act(() => game.unlockEquipment(e)),
                child: Text(
                  owned
                      ? 'Siap digunakan'
                      : s.level < e.level
                      ? 'Level ${e.level}'
                      : 'Siapkan · ${e.cost} koin',
                ),
              ),
            ),
          ],
        ),
      );
    }).toList(),
    intro:
        'Peralatan membuka pilihan menu baru. Dua pesanan bisa disiapkan bersamaan.',
  );
  Widget _decoration() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _room(edit: true),
      const SizedBox(height: 16),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final theme in [
            ('sage', 'Sage'),
            ('terracotta', 'Terakota'),
            ('midnight', 'Senja'),
          ])
            ChoiceChip(
              label: Text(theme.$2),
              selected: s.theme == theme.$1,
              onSelected: (_) {
                game.setTheme(theme.$1);
                _save();
              },
            ),
          if (placing != null || moving != null)
            ActionChip(
              label: const Text('Selesai menata'),
              avatar: const Icon(Icons.check, size: 16),
              onPressed: () => setState(() {
                placing = null;
                moving = null;
              }),
            ),
        ],
      ),
      const SizedBox(height: 22),
      const Text(
        'Isi ruangmu',
        style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
      ),
      const SizedBox(height: 7),
      const Text(
        'Pilih perabot, lalu ketuk ubin. Untuk memindahkan, ketuk perabot yang ada.',
        style: TextStyle(fontSize: 12, color: muted),
      ),
      const SizedBox(height: 16),
      _catalogGrid(
        furniture
            .map(
              (f) => _card(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _art(f.symbol, const Color(0xFFF0E8D8)),
                    const SizedBox(height: 14),
                    Text(
                      f.name,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Text(
                      '+${f.charm} suasana${f.id == 'table' ? ' · +1 kursi (maks. 6)' : ''}',
                      style: const TextStyle(fontSize: 12, color: muted),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: () => setState(() {
                          placing = f.id;
                          moving = null;
                        }),
                        child: Text(
                          placing == f.id
                              ? 'Pilih ubin di atas'
                              : 'Tempatkan · ${f.cost}',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            )
            .toList(),
      ),
      const SizedBox(height: 16),
      _section('Pindahkan perabot', 'Akses tanpa mengetuk denah'),
      const SizedBox(height: 10),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: s.decor.indexed
            .map(
              (d) => ActionChip(
                label: Text(
                  '${furniture.firstWhere((f) => f.id == d.$2.kind).name} (${d.$2.x + 1}, ${d.$2.y + 1})',
                ),
                onPressed: () => _moveAccessible(d.$1),
              ),
            )
            .toList(),
      ),
    ],
  );
  void _onTile(int x, int y) {
    if (placing != null || moving != null) {
      final result = game.place(
        placing ?? s.decor[moving!].kind,
        x,
        y,
        moving: moving,
      );
      _toast(result);
      _save();
      setState(() => moving = null);
    } else {
      final index = s.decor.indexWhere((d) => d.x == x && d.y == y);
      if (index >= 0) setState(() => moving = index);
    }
  }

  Future<void> _moveAccessible(int index) async {
    int x = s.decor[index].x, y = s.decor[index].y;
    await showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, update) => AlertDialog(
          title: const Text('Pindahkan perabot'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<int>(
                initialValue: x,
                decoration: const InputDecoration(labelText: 'Kolom'),
                items: List.generate(
                  8,
                  (i) => DropdownMenuItem(value: i, child: Text('${i + 1}')),
                ),
                onChanged: (v) => update(() => x = v!),
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<int>(
                initialValue: y,
                decoration: const InputDecoration(labelText: 'Baris'),
                items: List.generate(
                  5,
                  (i) =>
                      DropdownMenuItem(value: i + 1, child: Text('${i + 2}')),
                ),
                onChanged: (v) => update(() => y = v!),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Batal'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(context);
                _act(
                  () => game.place(s.decor[index].kind, x, y, moving: index),
                );
              },
              child: const Text('Pindahkan'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _stories() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text(
        'Orang-orang di seberang meja',
        style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
      ),
      const SizedBox(height: 8),
      const Text(
        'Kenali pelangganmu. Cerita baru terbuka seiring pesanan yang selesai.',
        style: TextStyle(color: muted, fontSize: 13),
      ),
      const SizedBox(height: 22),
      for (final entry in chapters.indexed)
        Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: _card(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 25,
                  backgroundColor: const Color(0xFFF1DFCD),
                  child: Text(
                    entry.$2.name[0],
                    style: const TextStyle(
                      fontSize: 23,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF946B4E),
                    ),
                  ),
                ),
                const SizedBox(width: 18),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${entry.$2.name} · BAB ${entry.$1 + 1}',
                        style: const TextStyle(
                          fontSize: 10,
                          letterSpacing: 1.4,
                          color: muted,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        entry.$2.title,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        s.stories.contains(entry.$1)
                            ? entry.$2.response
                            : entry.$2.line,
                        style: const TextStyle(
                          fontSize: 13,
                          height: 1.7,
                          color: muted,
                        ),
                      ),
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed:
                            s.stories.contains(entry.$1) ||
                                s.served < entry.$2.requiredServed
                            ? null
                            : () => _openStory(entry.$1),
                        child: Text(
                          s.stories.contains(entry.$1)
                              ? 'Selesai'
                              : s.served < entry.$2.requiredServed
                              ? '${entry.$2.requiredServed} pesanan untuk membuka'
                              : 'Mengobrol · +${entry.$2.reward} koin',
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
    ],
  );
  void _openStory(int index) => showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(chapters[index].name),
      content: Text(chapters[index].line),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Nanti'),
        ),
        FilledButton(
          onPressed: () {
            Navigator.pop(context);
            _act(() => game.story(index));
          },
          child: Text(chapters[index].choice),
        ),
      ],
    ),
  );
  Widget _team() => _catalogGrid([
    _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _art('👩‍🍳', const Color(0xFFF0DFCB)),
          const SizedBox(height: 18),
          const Text(
            'Ayu',
            style: TextStyle(fontSize: 25, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          const Text(
            'BARISTA',
            style: TextStyle(
              fontSize: 10,
              letterSpacing: 1.5,
              color: sage,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Menyiapkan dan mengantar pesanan otomatis. Saat kafe ditutup, Ayu menghasilkan koin hingga 8 jam.',
            style: TextStyle(color: muted, fontSize: 13, height: 1.7),
          ),
          const SizedBox(height: 18),
          const Text(
            'Upah sekali · tidak ada potongan berkala',
            style: TextStyle(color: muted, fontSize: 11),
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: s.staff ? null : () => _act(game.hire),
              child: Text(s.staff ? 'Sudah bergabung' : 'Rekrut · 280 koin'),
            ),
          ),
        ],
      ),
    ),
  ], intro: 'Kamu tetap bisa melayani pesanan saat Ayu bertugas.');
  Widget _progress() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Wrap(
        spacing: 14,
        runSpacing: 14,
        children: [
          _stat('Pesanan selesai', '${s.served}', Icons.coffee_outlined),
          _stat('Koin dihasilkan', '${s.earned}', Icons.toll_outlined),
          _stat(
            'Resep dipelajari',
            '${s.unlocked.length} / ${recipes.length}',
            Icons.menu_book_outlined,
          ),
          _stat(
            'Cerita selesai',
            '${s.stories.length} / ${chapters.length}',
            Icons.forum_outlined,
          ),
        ],
      ),
      const SizedBox(height: 28),
      _section('Target kafe', 'Hadiah sekali per target'),
      const SizedBox(height: 16),
      for (final g in GameEngine.goalTargets.indexed)
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _card(
            child: Row(
              children: [
                const Icon(
                  Icons.emoji_events_outlined,
                  color: Color(0xFFAC8146),
                  size: 30,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Selesaikan ${g.$2} pesanan',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '+${(g.$1 + 1) * 75} koin',
                        style: const TextStyle(color: muted, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                FilledButton(
                  onPressed: s.claimedGoals.contains(g.$1) || s.served < g.$2
                      ? null
                      : () => _act(() => game.claimGoal(g.$1)),
                  child: Text(
                    s.claimedGoals.contains(g.$1)
                        ? 'Diklaim'
                        : s.served < g.$2
                        ? '${s.served}/${g.$2}'
                        : 'Klaim',
                  ),
                ),
              ],
            ),
          ),
        ),
    ],
  );
  Widget _more() => Column(
    children: [
      for (final i in [5, 6, 7, 8])
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _card(
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(icons[i], color: sage),
              title: Text(
                labels[i],
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              trailing: const Icon(Icons.arrow_forward_rounded),
              onTap: () => _navigate(i),
            ),
          ),
        ),
    ],
  );
  Widget _data() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      if (widget.accountPanel != null) ...[
        widget.accountPanel!,
        const SizedBox(height: 20),
      ],
      _card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Cadangan perangkat',
              style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 10),
            const Text(
              'Progres tersimpan otomatis. Salin cadangan sebelum membersihkan data browser atau pindah perangkat.',
              style: TextStyle(fontSize: 13, color: muted, height: 1.7),
            ),
            const SizedBox(height: 18),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                FilledButton.icon(
                  onPressed: () async {
                    try {
                      await Clipboard.setData(ClipboardData(text: s.encode()));
                      _toast(
                        'Cadangan disalin. Simpan sebagai teks di tempat aman.',
                      );
                    } catch (_) {
                      _showExport();
                    }
                  },
                  icon: const Icon(Icons.copy_rounded, size: 17),
                  label: const Text('Salin cadangan'),
                ),
                OutlinedButton.icon(
                  onPressed: _restore,
                  icon: const Icon(Icons.restore_rounded, size: 17),
                  label: const Text('Pulihkan'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              saveStatus,
              style: const TextStyle(fontSize: 12, color: muted),
            ),
          ],
        ),
      ),
      const SizedBox(height: 20),
      _notice(
        'My Cloud Café · 0.1.0',
        'Game single-player. Semua konten dibuka melalui permainan. Tidak ada transaksi uang asli.',
        Icons.coffee_outlined,
      ),
    ],
  );
  void _showExport() => showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Cadangan progres'),
      content: SizedBox(
        width: 500,
        child: SingleChildScrollView(child: SelectableText(s.encode())),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Tutup'),
        ),
      ],
    ),
  );
  Future<void> _restore() async {
    final input = TextEditingController();
    String? error;
    await showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, update) => AlertDialog(
          title: const Text('Pulihkan cadangan'),
          content: SizedBox(
            width: 440,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Progres perangkat saat ini akan diganti. Salin cadangan terlebih dahulu.',
                  style: TextStyle(color: muted, fontSize: 13),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: input,
                  maxLines: 6,
                  decoration: InputDecoration(
                    labelText: 'Tempel teks cadangan',
                    errorText: error,
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Batal'),
            ),
            FilledButton(
              onPressed: () {
                try {
                  final restored = CafeState.decode(input.text);
                  game.state = restored;
                  game.resume();
                  _save();
                  Navigator.pop(context);
                  _toast('Cadangan dipulihkan.');
                } catch (_) {
                  update(
                    () => error = 'Cadangan tidak valid. Progres tetap aman.',
                  );
                }
              },
              child: const Text('Ganti progres'),
            ),
          ],
        ),
      ),
    );
    input.dispose();
  }

  Widget _catalogGrid(List<Widget> children, {String? intro}) => LayoutBuilder(
    builder: (context, b) {
      final columns = b.maxWidth >= 1050
          ? 3
          : b.maxWidth >= 600
          ? 2
          : 1;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (intro != null) ...[
            Text(
              intro,
              style: const TextStyle(color: muted, fontSize: 13, height: 1.7),
            ),
            const SizedBox(height: 22),
          ],
          Wrap(
            spacing: 16,
            runSpacing: 16,
            children: children
                .map(
                  (child) => SizedBox(
                    width: (b.maxWidth - 16 * (columns - 1)) / columns,
                    child: child,
                  ),
                )
                .toList(),
          ),
        ],
      );
    },
  );
  Widget _card({required Widget child, double padding = 20}) => Material(
    clipBehavior: Clip.antiAlias,
    color: const Color(0xFFFFFDF8),
    shape: RoundedRectangleBorder(
      side: const BorderSide(color: Color(0xFFE3E5D9)),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Padding(padding: EdgeInsets.all(padding), child: child),
  );
  Widget _section(String title, String subtitle, {Widget? action}) => Row(
    children: [
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 21,
                fontWeight: FontWeight.w800,
                letterSpacing: -.4,
              ),
            ),
            const SizedBox(height: 5),
            Text(subtitle, style: const TextStyle(fontSize: 11, color: muted)),
          ],
        ),
      ),
      ?action,
    ],
  );
  Widget _smallStat(String label, String value) => Row(
    children: [
      Expanded(
        child: Text(label, style: const TextStyle(color: muted, fontSize: 12)),
      ),
      Text(
        value,
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
      ),
    ],
  );
  Widget _notice(String title, String subtitle, IconData icon) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(17),
    decoration: BoxDecoration(
      color: const Color(0xFFEAF0E4),
      borderRadius: BorderRadius.circular(16),
    ),
    child: Row(
      children: [
        Icon(icon, color: sage, size: 25),
        const SizedBox(width: 13),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: const TextStyle(fontSize: 12, color: muted, height: 1.5),
              ),
            ],
          ),
        ),
      ],
    ),
  );
  Widget _art(String symbol, Color bg) => Container(
    height: 118,
    width: double.infinity,
    decoration: BoxDecoration(
      color: bg,
      borderRadius: BorderRadius.circular(14),
    ),
    alignment: Alignment.center,
    child: Text(
      symbol,
      style: const TextStyle(fontFamily: 'CafeEmoji', fontSize: 54),
    ),
  );
  Widget _iconArt(IconData icon) => Container(
    height: 110,
    width: double.infinity,
    decoration: BoxDecoration(
      color: const Color(0xFFE8EEE2),
      borderRadius: BorderRadius.circular(14),
    ),
    child: Icon(icon, size: 55, color: sage),
  );
  Widget _stat(String title, String value, IconData icon) => SizedBox(
    width: 220,
    child: _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: sage),
          const SizedBox(height: 17),
          Text(
            value,
            style: const TextStyle(fontSize: 27, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Text(title, style: const TextStyle(fontSize: 12, color: muted)),
        ],
      ),
    ),
  );
}
