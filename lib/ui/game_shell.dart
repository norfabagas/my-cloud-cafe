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
  Timer? tick, checkpoint;
  int? selectedOrder;
  bool editing = false;
  String? placing;
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
        _toast('Tim menghasilkan ${game.offlineCoins} koin saat kamu pergi.');
      }
    });
  }

  void _start() {
    tick?.cancel();
    checkpoint?.cancel();
    tick = Timer.periodic(
      const Duration(milliseconds: 200),
      (_) => game.tick(),
    );
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
    } else {
      tick?.cancel();
      checkpoint?.cancel();
    }
    _save();
  }

  @override
  void dispose() {
    tick?.cancel();
    checkpoint?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _toast(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(text),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
  }

  void _act(String Function() fn) {
    _toast(fn());
    unawaited(_save());
  }

  void _select(int id) => setState(() {
    selectedOrder = id;
    editing = false;
    placing = null;
  });
  void _tool(String tool) {
    if (editing) {
      _moveToolDialog(tool);
      return;
    }
    final o = s.orders.where((o) => o.id == selectedOrder).firstOrNull;
    if (o == null) {
      _toast('Pilih pelanggan atau pesanan dahulu.');
      return;
    }
    _act(() => game.prepare(o.id, tool));
  }

  Future<void> _popup(String title, Widget Function() content) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => Dialog(
        insetPadding: const EdgeInsets.all(16),
        clipBehavior: Clip.antiAlias,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: 760,
            maxHeight: MediaQuery.sizeOf(dialogContext).height * .85,
          ),
          child: AnimatedBuilder(
            animation: game,
            builder: (context, _) => Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 10, 8, 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          title == 'Tim'
                              ? 'Tim · ${s.workers.length}/3 staf'
                              : title,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Tutup',
                        onPressed: () => Navigator.pop(dialogContext),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: content(),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: game,
    builder: (context, _) => Scaffold(
      backgroundColor: const Color(0xFFE8EDE1),
      body: SafeArea(
        child: Column(
          children: [
            _header(),
            Expanded(
              child: Stack(
                children: [
                  Positioned.fill(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 25, bottom: 130),
                      child: CafeScene(
                        key: const ValueKey('live-cafe'),
                        state: s,
                        engine: game,
                        editing: editing,
                        selectedOrder: selectedOrder,
                        onCustomer: _select,
                        onTool: _tool,
                        onTile: _onTile,
                        onMove: (index, tool, x, y) {
                          if (tool != null) {
                            _act(() => game.moveTool(tool, x, y));
                          } else if (index != null) {
                            _act(
                              () => game.place(
                                s.decor[index].kind,
                                x,
                                y,
                                moving: index,
                              ),
                            );
                          }
                        },
                      ),
                    ),
                  ),
                  Positioned(top: 4, left: 12, right: 12, child: _orders()),
                  Positioned(
                    top: 64,
                    right: 12,
                    child: Column(
                      children: [
                        _glass(
                          child: IconButton(
                            tooltip: editing
                                ? 'Selesai atur ruang'
                                : 'Atur ruang',
                            onPressed: () => setState(() {
                              editing = !editing;
                              placing = null;
                            }),
                            icon: Icon(
                              editing ? Icons.check : Icons.open_with,
                              color: sage,
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        _glass(
                          child: IconButton(
                            tooltip: 'Cara bermain',
                            onPressed: () => _popup('Cara bermain', _help),
                            icon: const Icon(Icons.help_outline, color: sage),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Positioned(
                    left: 12,
                    right: 12,
                    bottom: 12,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (editing)
                          _layoutHint()
                        else if (s.orders.any((o) => o.id == selectedOrder))
                          _preparation(
                            s.orders.firstWhere((o) => o.id == selectedOrder),
                          )
                        else
                          _glass(
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Text(
                                s.orders.isEmpty
                                    ? 'Pelanggan baru akan segera datang.'
                                    : 'Pilih pelanggan, lalu ketuk alat untuk menyiapkan pesanannya.',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: sage,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ),
                        const SizedBox(height: 8),
                        _tools(),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            _toolbar(),
          ],
        ),
      ),
    ),
  );
  Widget _header() => Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    color: const Color(0xFFFFFDF6),
    child: Row(
      children: [
        const Icon(Icons.local_cafe, color: sage, size: 26),
        const SizedBox(width: 10),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'MY CLOUD CAFÉ',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1,
                ),
              ),
              Text(
                'Kafe hari ini',
                style: TextStyle(fontSize: 10, color: muted),
              ),
            ],
          ),
        ),
        Text(
          'Lv. ${s.level}',
          style: const TextStyle(
            fontSize: 12,
            color: sage,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(width: 12),
        const Icon(Icons.toll, color: Color(0xFFB18A45), size: 19),
        const SizedBox(width: 4),
        Text('${s.coins}', style: const TextStyle(fontWeight: FontWeight.w800)),
      ],
    ),
  );
  Widget _orders() => SizedBox(
    height: 50,
    child: ListView(
      scrollDirection: Axis.horizontal,
      children: [
        for (final o in s.orders)
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              selected: selectedOrder == o.id,
              onSelected: (_) => _select(o.id),
              avatar: CircleAvatar(
                backgroundColor:
                    PeoplePainter.shirts[(s.customers
                                .where((c) => c.id == o.customerId)
                                .firstOrNull
                                ?.look ??
                            o.id) %
                        6],
                child: Text(
                  o.name[0],
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                ),
              ),
              label: Text(
                '${o.name} · ${recipeById(o.recipe).name}',
                style: const TextStyle(fontSize: 11),
              ),
            ),
          ),
        if (s.orders.isEmpty)
          const Chip(label: Text('Meja siap · menunggu pelanggan')),
      ],
    ),
  );
  Widget _preparation(Order o) {
    final r = recipeById(o.recipe),
        b = game.brewFor(o.id),
        step = game.nextStep(o.id),
        cooking = b != null && b.readyAt > game.now,
        ready = b != null && !cooking && step == null,
        arriving = game.now < o.arrivedAt + GameEngine.walkMillis;
    return Align(
      alignment: Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 430),
        child: _glass(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 8, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${o.name} · ${r.name}',
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    Text(
                      '+${r.price}',
                      style: const TextStyle(
                        color: sage,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    IconButton(
                      tooltip: 'Tutup pesanan',
                      visualDensity: VisualDensity.compact,
                      onPressed: () => setState(() => selectedOrder = null),
                      icon: const Icon(Icons.close, size: 17),
                    ),
                  ],
                ),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    for (final entry in r.steps.indexed)
                      Text(
                        '${b != null && (entry.$1 < b.step || (entry.$1 == b.step && !cooking)) ? 'OK' : '${entry.$1 + 1}.'} ${entry.$2.ingredient} (${entry.$2.seconds} dtk)',
                        style: TextStyle(
                          fontSize: 11,
                          color: b != null && entry.$1 <= b.step ? sage : muted,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                if (cooking) ...[
                  LinearProgressIndicator(
                    value:
                        ((game.now - b.startedAt) / (b.readyAt - b.startedAt))
                            .clamp(0, 1),
                    minHeight: 5,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Menyiapkan ${r.steps[b.step].ingredient} · ${math.max(0, ((b.readyAt - game.now) / 1000).ceil())} dtk',
                    style: const TextStyle(fontSize: 12, color: sage),
                  ),
                ] else if (ready)
                  FilledButton.icon(
                    key: ValueKey('serve-${o.id}'),
                    onPressed: () => _act(() => game.serve(o.id)),
                    icon: const Icon(Icons.room_service_outlined, size: 18),
                    label: const Text('Sajikan'),
                  )
                else
                  Text(
                    arriving
                        ? 'Pelanggan sedang menuju kursi…'
                        : 'Ketuk ${equipment.firstWhere((e) => e.id == step!.tool).name} untuk ${step!.ingredient.toLowerCase()}.',
                    style: const TextStyle(fontSize: 12, color: sage),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _tools() => _glass(
    child: SizedBox(
      height: 62,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
        children: [
          for (final e in equipment.where((e) => s.machines.contains(e.id)))
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: OutlinedButton.icon(
                key: ValueKey('tool-${e.id}'),
                style: OutlinedButton.styleFrom(
                  backgroundColor:
                      game.nextStep(selectedOrder ?? -1)?.tool == e.id
                      ? const Color(0xFFE8EFD9)
                      : Colors.white,
                  side: BorderSide(
                    color: game.toolAvailable(e.id) ? sage : Colors.grey,
                  ),
                ),
                onPressed: editing
                    ? () => _moveToolDialog(e.id)
                    : () => _tool(e.id),
                icon: Icon(_toolIcon(e.id), size: 20),
                label: Text(
                  '${e.name}${game.toolAvailable(e.id) ? '' : ' · sibuk'}',
                  style: const TextStyle(fontSize: 11),
                ),
              ),
            ),
        ],
      ),
    ),
  );
  IconData _toolIcon(String id) => switch (id) {
    'coffee' => Icons.coffee_maker_outlined,
    'tea' => Icons.emoji_food_beverage_outlined,
    'milk' => Icons.water_drop_outlined,
    'oven' => Icons.microwave,
    'freezer' => Icons.ac_unit,
    _ => Icons.cookie_outlined,
  };
  Widget _toolbar() => Container(
    color: const Color(0xFFFFFDF6),
    height: 66,
    child: ListView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      children: [
        _nav('Menu', Icons.menu_book, () => _popup('Menu & resep', _recipes)),
        _nav(
          'Toko',
          Icons.chair_outlined,
          () => _popup('Toko & peralatan', _shop),
        ),
        _nav('Tim', Icons.people_outline, () => _popup('Tim', _team)),
        _nav(
          'Pelanggan',
          Icons.badge_outlined,
          () => _popup('Buku pelanggan', _customers),
        ),
        _nav(
          'Cerita',
          Icons.forum_outlined,
          () => _popup('Cerita & target', _stories),
        ),
        _nav(
          'Akun & data',
          Icons.cloud_outlined,
          () => _popup('Akun & data', _data),
        ),
      ],
    ),
  );
  Widget _nav(String name, IconData icon, VoidCallback action) => TextButton(
    onPressed: action,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 7),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 21, color: sage),
          const SizedBox(height: 4),
          Text(name, style: const TextStyle(fontSize: 10, color: ink)),
        ],
      ),
    ),
  );
  Widget _layoutHint() => _glass(
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Expanded(
            child: Text(
              placing == null
                  ? 'Tahan lalu seret perabot atau alat. Cubit dengan dua jari untuk zoom.'
                  : 'Ketuk ubin kosong untuk ${furniture.firstWhere((f) => f.id == placing).name}.',
              style: const TextStyle(fontSize: 12, color: sage),
            ),
          ),
          TextButton(
            onPressed: () => setState(() {
              placing = null;
              editing = false;
            }),
            child: const Text('Selesai'),
          ),
        ],
      ),
    ),
  );
  void _onTile(int x, int y) {
    if (placing != null) {
      final count = s.decor.length;
      _act(() => game.place(placing!, x, y));
      if (s.decor.length > count) setState(() => placing = null);
    } else {
      final i = s.decor.indexWhere((d) => d.x == x && d.y == y);
      if (i >= 0) _moveFurnitureDialog(i);
    }
  }

  Widget _recipes() => Column(
    children: [
      const Text(
        'Setiap bahan dibuat di alatnya. Matikan menu untuk pesanan baru; pesanan aktif tetap dilayani.',
        style: TextStyle(color: muted, fontSize: 12),
      ),
      const SizedBox(height: 12),
      for (final r in recipes)
        _card(
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                r.name,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                '${r.price} koin · ${r.seconds} detik\n${r.steps.map((s) => '${s.ingredient} ${s.seconds} dtk').join(' + ')}',
                style: const TextStyle(fontSize: 12, color: muted, height: 1.6),
              ),
              if (s.unlocked.contains(r.id))
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text(
                    'Tersedia di menu',
                    style: TextStyle(fontSize: 13),
                  ),
                  value: !s.disabledMenu.contains(r.id),
                  onChanged: (_) => _act(() => game.toggleMenu(r.id)),
                )
              else ...[
                const SizedBox(height: 8),
                Text(
                  'Level ${r.level} · alat: ${r.tools.map((t) => equipment.firstWhere((e) => e.id == t).name).join(', ')}',
                  style: const TextStyle(fontSize: 11, color: muted),
                ),
                const SizedBox(height: 8),
                FilledButton(
                  onPressed: () => _act(() => game.unlockRecipe(r)),
                  child: Text('Pelajari · ${r.cost} koin'),
                ),
              ],
            ],
          ),
        ),
    ],
  );
  Widget _shop() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text(
        'Peralatan',
        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
      ),
      const Text(
        'Alat wajib berada di meja bar atau meja kerja. Tahan dan seret dalam mode Atur ruang.',
        style: TextStyle(fontSize: 12, color: muted),
      ),
      const SizedBox(height: 12),
      for (final e in equipment)
        _card(
          Row(
            children: [
              Icon(_toolIcon(e.id), color: sage),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      e.name,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    Text(
                      'Level ${e.level} · ${e.cost} koin',
                      style: const TextStyle(fontSize: 11, color: muted),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: s.machines.contains(e.id)
                    ? () => _moveToolDialog(e.id)
                    : () => _act(() => game.unlockEquipment(e)),
                child: Text(s.machines.contains(e.id) ? 'Pindah' : 'Beli'),
              ),
            ],
          ),
        ),
      const SizedBox(height: 16),
      const Text(
        'Perabot',
        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
      ),
      const Text(
        'Kursi bersebelahan dengan meja menerima pelanggan. Maksimal 6 pelanggan sekaligus.',
        style: TextStyle(fontSize: 12, color: muted),
      ),
      const SizedBox(height: 12),
      for (final f in furniture)
        _card(
          Row(
            children: [
              const Icon(Icons.chair_alt, color: sage),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      f.name,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    Text(
                      '${f.cost} koin · +${f.charm} suasana',
                      style: const TextStyle(fontSize: 11, color: muted),
                    ),
                  ],
                ),
              ),
              FilledButton(
                onPressed: () {
                  Navigator.pop(context);
                  setState(() {
                    placing = f.id;
                    editing = true;
                    selectedOrder = null;
                  });
                },
                child: const Text('Tempatkan'),
              ),
            ],
          ),
        ),
      const SizedBox(height: 12),
      const Text(
        'Warna dinding',
        style: TextStyle(fontWeight: FontWeight.w700),
      ),
      Wrap(
        spacing: 8,
        children: [
          for (final t in ['sage', 'terracotta', 'midnight'])
            ChoiceChip(
              label: Text(t),
              selected: s.theme == t,
              onSelected: (_) => game.setTheme(t),
            ),
        ],
      ),
      const SizedBox(height: 12),
      OutlinedButton(
        onPressed: () {
          Navigator.pop(context);
          setState(() {
            editing = true;
            placing = null;
            selectedOrder = null;
          });
        },
        child: const Text('Atur ruang'),
      ),
    ],
  );
  Future<void> _coordinates(
    String title,
    int initialX,
    int initialY,
    void Function(int, int) apply, {
    bool tool = false,
  }) async {
    var x = initialX, y = initialY;
    await showDialog<void>(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, update) => AlertDialog(
          title: Text(title),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<int>(
                initialValue: x,
                decoration: const InputDecoration(labelText: 'Kolom'),
                items: [
                  for (var i = 0; i < 8; i++)
                    DropdownMenuItem(value: i, child: Text('${i + 1}')),
                ],
                onChanged: (v) => update(() => x = v!),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<int>(
                initialValue: y,
                decoration: const InputDecoration(labelText: 'Baris'),
                items: [
                  for (var i = tool ? 0 : 1; i < 6; i++)
                    DropdownMenuItem(
                      value: i,
                      child: Text(i == 0 ? 'Meja bar' : '${i + 1}'),
                    ),
                ],
                onChanged: (v) => update(() => y = v!),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c),
              child: const Text('Batal'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(c);
                apply(x, y);
              },
              child: const Text('Pindahkan'),
            ),
          ],
        ),
      ),
    );
  }

  void _moveToolDialog(String id) {
    final p = s.toolPositions[id]!;
    _coordinates(
      equipment.firstWhere((e) => e.id == id).name,
      p.x,
      p.y,
      (x, y) => _act(() => game.moveTool(id, x, y)),
      tool: true,
    );
  }

  void _moveFurnitureDialog(int i) {
    final d = s.decor[i];
    _coordinates(
      furniture.firstWhere((f) => f.id == d.kind).name,
      d.x,
      d.y,
      (x, y) => _act(() => game.place(d.kind, x, y, moving: i)),
    );
  }

  Widget _team() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text(
        'Staf mengikuti langkah resep dan memakai alat yang sama denganmu. Kamu tetap bisa melayani sendiri. Energi habis setelah 12 tugas; istirahat 10 detik untuk memulihkannya.',
        style: TextStyle(fontSize: 12, color: muted, height: 1.6),
      ),
      const SizedBox(height: 14),
      for (final entry in s.workers.indexed)
        _card(
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                entry.$2.name,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                entry.$2.restUntil > game.now
                    ? 'Istirahat · ${((entry.$2.restUntil - game.now) / 1000).ceil()} dtk'
                    : 'Energi ${entry.$2.energy}/12',
                style: const TextStyle(color: sage),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: entry.$2.role,
                decoration: const InputDecoration(labelText: 'Tugas'),
                items: const [
                  DropdownMenuItem(
                    value: 'all',
                    child: Text('Siapkan & sajikan'),
                  ),
                  DropdownMenuItem(
                    value: 'barista',
                    child: Text('Barista · siapkan bahan'),
                  ),
                  DropdownMenuItem(
                    value: 'server',
                    child: Text('Pelayan · sajikan pesanan'),
                  ),
                ],
                onChanged: (v) => _act(() => game.setRole(entry.$1, v!)),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: entry.$2.restUntil > game.now
                    ? null
                    : () => _act(() => game.restStaff(entry.$1)),
                child: const Text('Istirahat · 10 dtk'),
              ),
            ],
          ),
        ),
      FilledButton(
        onPressed: s.workers.length >= 3 ? null : () => _act(game.hire),
        child: Text(
          s.workers.length >= 3
              ? 'Tim lengkap · 3/3'
              : 'Rekrut ${['Ayu', 'Raka', 'Mira'][s.workers.length]} · ${280 + s.workers.length * 100} koin',
        ),
      ),
    ],
  );
  Widget _customers() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text(
        'Pelanggan baru dicatat otomatis. Identitas dan penampilan tetap sama saat kembali. Mode tamu menyimpan di perangkat; akun tersinkron mencatatnya ke database.',
        style: TextStyle(fontSize: 12, color: muted, height: 1.6),
      ),
      const SizedBox(height: 12),
      for (final c in s.customers)
        _card(
          Row(
            children: [
              SizedBox(
                width: 50,
                height: 68,
                child: CustomPaint(painter: _Portrait(c.look)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  c.name,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
              Text(
                '${c.visits} kunjungan',
                style: const TextStyle(color: muted, fontSize: 12),
              ),
            ],
          ),
        ),
    ],
  );
  Widget _stories() => Column(
    children: [
      for (final entry in chapters.indexed)
        _card(
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${entry.$2.name} · ${entry.$2.title}',
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 17,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                s.stories.contains(entry.$1)
                    ? entry.$2.response
                    : entry.$2.line,
                style: const TextStyle(color: muted, height: 1.6),
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed:
                    s.stories.contains(entry.$1) ||
                        s.served < entry.$2.requiredServed
                    ? null
                    : () => _act(() => game.story(entry.$1)),
                child: Text(
                  s.stories.contains(entry.$1)
                      ? 'Selesai'
                      : s.served < entry.$2.requiredServed
                      ? 'Layani ${entry.$2.requiredServed} pesanan'
                      : entry.$2.choice,
                ),
              ),
            ],
          ),
        ),
      for (final g in GameEngine.goalTargets.indexed)
        _card(
          Row(
            children: [
              Expanded(
                child: Text('Layani ${g.$2} pesanan · ${s.served}/${g.$2}'),
              ),
              FilledButton(
                onPressed: s.served < g.$2 || s.claimedGoals.contains(g.$1)
                    ? null
                    : () => _act(() => game.claimGoal(g.$1)),
                child: Text(
                  s.claimedGoals.contains(g.$1)
                      ? 'Diklaim'
                      : '+${(g.$1 + 1) * 75} koin',
                ),
              ),
            ],
          ),
        ),
    ],
  );
  Widget _data() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      if (widget.accountPanel != null) widget.accountPanel!,
      const SizedBox(height: 16),
      Text(saveStatus, style: const TextStyle(color: muted, fontSize: 12)),
      const SizedBox(height: 16),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          FilledButton.icon(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: s.encode()));
              _toast('Cadangan disalin.');
            },
            icon: const Icon(Icons.copy),
            label: const Text('Salin cadangan'),
          ),
          OutlinedButton(onPressed: _restore, child: const Text('Pulihkan')),
        ],
      ),
    ],
  );
  Future<void> _restore() async {
    final input = TextEditingController();
    String? error;
    await showDialog<void>(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, update) => AlertDialog(
          title: const Text('Pulihkan cadangan'),
          content: SizedBox(
            width: 440,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Progres saat ini akan diganti. Salin cadangan terlebih dahulu.',
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: input,
                  maxLines: 5,
                  decoration: InputDecoration(
                    labelText: 'Teks cadangan',
                    errorText: error,
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c),
              child: const Text('Batal'),
            ),
            FilledButton(
              onPressed: () {
                try {
                  final restored = CafeState.decode(input.text);
                  game.state = restored;
                  game.resume();
                  selectedOrder = null;
                  unawaited(_save());
                  Navigator.pop(c);
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

  Widget _help() => const Text(
    '1. Ketuk pelanggan atau kartu pesanan di atas.\n\n2. Ketuk alat yang diminta, tunggu bahan selesai, lalu ketuk alat untuk bahan berikutnya. Contoh latte: mesin espresso + milk steamer + Sajikan.\n\n3. Buka Menu untuk mempelajari dan mengatur resep. Setiap resep selesai dalam 5–12 detik waktu pembuatan aktif.\n\n4. Beli perabot di Toko, lalu ketuk ubin kosong. Kursi harus di sebelah meja. Alat hanya bisa diletakkan di meja bar, meja kayu, atau meja kerja kosong.\n\n5. Aktifkan Atur ruang. Tahan perabot atau alat, lalu seret dan lepaskan di tujuan. Kamu juga bisa mengetuk perabot untuk memilih koordinat.\n\n6. Cubit dengan dua jari untuk zoom. Seret ruang untuk menggeser kamera; sudut pandang tidak berputar.\n\n7. Rekrut maksimal 3 staf. Atur tugas dan beri istirahat saat energinya habis. Kamu selalu bisa menyiapkan bahan dan menyajikan sendiri.',
    style: TextStyle(height: 1.7, fontSize: 14),
  );
  Widget _card(Widget child) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F3E9),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Material(type: MaterialType.transparency, child: child),
    ),
  );
  Widget _glass({required Widget child}) => Material(
    color: const Color(0xFAFFFDF6),
    elevation: 2,
    shadowColor: const Color(0x20314A36),
    borderRadius: BorderRadius.circular(16),
    clipBehavior: Clip.antiAlias,
    child: child,
  );
}

class _Portrait extends CustomPainter {
  final int look;
  _Portrait(this.look);
  @override
  void paint(Canvas c, Size size) {
    PeoplePainter.person(c, Offset(size.width / 2, 64), look, 0);
  }

  @override
  bool shouldRepaint(covariant _Portrait old) => look != old.look;
}
