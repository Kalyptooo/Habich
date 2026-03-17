import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  runApp(const HabIchApp());
}

class HabIchApp extends StatelessWidget {
  const HabIchApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'HabIch?',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2E7D6B),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        fontFamily: 'Roboto',
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2E7D6B),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}

// ─── Data Model ───────────────────────────────────────────────────────────────

class CheckItem {
  final String id;
  String name;
  String emoji;
  String? photoPath;
  DateTime? photoTime;

  CheckItem({
    required this.id,
    required this.name,
    required this.emoji,
    this.photoPath,
    this.photoTime,
  });

  bool get hasValidPhoto {
    if (photoPath == null || photoTime == null) return false;
    final age = DateTime.now().difference(photoTime!);
    return age.inHours < 24 && File(photoPath!).existsSync();
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'emoji': emoji,
        'photoPath': photoPath,
        'photoTime': photoTime?.toIso8601String(),
      };

  factory CheckItem.fromJson(Map<String, dynamic> j) => CheckItem(
        id: j['id'],
        name: j['name'],
        emoji: j['emoji'],
        photoPath: j['photoPath'],
        photoTime: j['photoTime'] != null ? DateTime.parse(j['photoTime']) : null,
      );
}

// ─── Home Screen ──────────────────────────────────────────────────────────────

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  List<CheckItem> _items = [];
  final _uuid = const Uuid();

  static const _defaultItems = [
    {'name': 'Herd', 'emoji': '🍳'},
    {'name': 'Haustür', 'emoji': '🚪'},
    {'name': 'Fenster', 'emoji': '🪟'},
    {'name': 'Bügeleisen', 'emoji': '👔'},
    {'name': 'Kaffeemaschine', 'emoji': '☕'},
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadItems();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _cleanExpiredPhotos();
      setState(() {});
    }
  }

  Future<void> _loadItems() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('items');
    if (raw != null) {
      final list = (jsonDecode(raw) as List)
          .map((e) => CheckItem.fromJson(e))
          .toList();
      setState(() => _items = list);
    } else {
      // First launch: load defaults
      setState(() {
        _items = _defaultItems
            .map((d) => CheckItem(
                  id: _uuid.v4(),
                  name: d['name']!,
                  emoji: d['emoji']!,
                ))
            .toList();
      });
      await _saveItems();
    }
    _cleanExpiredPhotos();
  }

  Future<void> _saveItems() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        'items', jsonEncode(_items.map((e) => e.toJson()).toList()));
  }

  void _cleanExpiredPhotos() {
    bool changed = false;
    for (final item in _items) {
      if (item.photoPath != null && !item.hasValidPhoto) {
        // Delete old file if exists
        try {
          final f = File(item.photoPath!);
          if (f.existsSync()) f.deleteSync();
        } catch (_) {}
        item.photoPath = null;
        item.photoTime = null;
        changed = true;
      }
    }
    if (changed) {
      _saveItems();
      setState(() {});
    }
  }

  Future<void> _takePhoto(CheckItem item) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 75,
      maxWidth: 1080,
    );
    if (picked == null) return;

    // Save to app's private dir
    final dir = await getApplicationDocumentsDirectory();
    final dest = '${dir.path}/habich_${item.id}.jpg';
    await File(picked.path).copy(dest);

    // Delete old temp file
    try { File(picked.path).deleteSync(); } catch (_) {}

    setState(() {
      item.photoPath = dest;
      item.photoTime = DateTime.now();
    });
    await _saveItems();
  }

  Future<void> _addItem() async {
    String name = '';
    String emoji = '✅';
    await showDialog(
      context: context,
      builder: (ctx) => _AddItemDialog(
        onSave: (n, e) {
          name = n;
          emoji = e;
        },
      ),
    );
    if (name.trim().isEmpty) return;
    setState(() {
      _items.add(CheckItem(id: _uuid.v4(), name: name.trim(), emoji: emoji));
    });
    await _saveItems();
  }

  Future<void> _deleteItem(CheckItem item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Löschen?'),
        content: Text('"${item.emoji} ${item.name}" wirklich entfernen?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Abbrechen')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Löschen'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      if (item.photoPath != null) File(item.photoPath!).deleteSync();
    } catch (_) {}
    setState(() => _items.removeWhere((i) => i.id == item.id));
    await _saveItems();
  }

  @override
  Widget build(BuildContext context) {
    final checkedCount = _items.where((i) => i.hasValidPhoto).length;

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: const Text(
          'HabIch?',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 24),
        ),
        centerTitle: false,
        actions: [
          if (_items.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: checkedCount == _items.length
                        ? const Color(0xFF2E7D6B)
                        : Theme.of(context).colorScheme.surfaceVariant,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '$checkedCount/${_items.length}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: checkedCount == _items.length
                          ? Colors.white
                          : Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
      body: _items.isEmpty
          ? _EmptyState(onAdd: _addItem)
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
              itemCount: _items.length,
              itemBuilder: (ctx, i) => _CheckCard(
                item: _items[i],
                onTap: () => _takePhoto(_items[i]),
                onDelete: () => _deleteItem(_items[i]),
                onViewPhoto: () => _showPhoto(_items[i]),
              ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addItem,
        icon: const Icon(Icons.add),
        label: const Text('Hinzufügen'),
        backgroundColor: const Color(0xFF2E7D6B),
        foregroundColor: Colors.white,
      ),
    );
  }

  void _showPhoto(CheckItem item) {
    if (!item.hasValidPhoto) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PhotoViewScreen(item: item),
      ),
    );
  }
}

// ─── Check Card ───────────────────────────────────────────────────────────────

class _CheckCard extends StatelessWidget {
  final CheckItem item;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final VoidCallback onViewPhoto;

  const _CheckCard({
    required this.item,
    required this.onTap,
    required this.onDelete,
    required this.onViewPhoto,
  });

  @override
  Widget build(BuildContext context) {
    final checked = item.hasValidPhoto;
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: checked
            ? const Color(0xFF2E7D6B).withOpacity(0.12)
            : theme.colorScheme.surfaceVariant.withOpacity(0.5),
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: checked ? onViewPhoto : onTap,
          onLongPress: onDelete,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: checked
                    ? const Color(0xFF2E7D6B).withOpacity(0.5)
                    : Colors.transparent,
                width: 2,
              ),
            ),
            child: Row(
              children: [
                // Emoji + status
                Stack(
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: checked
                            ? const Color(0xFF2E7D6B).withOpacity(0.2)
                            : theme.colorScheme.surface,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Center(
                        child: Text(item.emoji, style: const TextStyle(fontSize: 30)),
                      ),
                    ),
                    if (checked)
                      Positioned(
                        right: -2,
                        bottom: -2,
                        child: Container(
                          width: 22,
                          height: 22,
                          decoration: const BoxDecoration(
                            color: Color(0xFF2E7D6B),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.check, color: Colors.white, size: 14),
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 16),
                // Name + timestamp
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.name,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: checked ? const Color(0xFF2E7D6B) : null,
                        ),
                      ),
                      const SizedBox(height: 4),
                      if (checked && item.photoTime != null)
                        Text(
                          'Foto von heute, ${DateFormat('HH:mm', 'de_AT').format(item.photoTime!)} Uhr ✓',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: const Color(0xFF2E7D6B),
                            fontWeight: FontWeight.w500,
                          ),
                        )
                      else
                        Text(
                          'Tippen → Foto machen',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                    ],
                  ),
                ),
                // Arrow / preview
                if (checked && item.photoPath != null)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.file(
                      File(item.photoPath!),
                      width: 52,
                      height: 52,
                      fit: BoxFit.cover,
                    ),
                  )
                else
                  Icon(
                    Icons.camera_alt_outlined,
                    color: theme.colorScheme.onSurfaceVariant,
                    size: 28,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Photo View Screen ────────────────────────────────────────────────────────

class PhotoViewScreen extends StatelessWidget {
  final CheckItem item;

  const PhotoViewScreen({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    final timeStr = item.photoTime != null
        ? DateFormat('EEEE, dd. MMMM yyyy\nHH:mm \'Uhr\'', 'de_AT').format(item.photoTime!)
        : '';
    final ageMinutes = item.photoTime != null
        ? DateTime.now().difference(item.photoTime!).inMinutes
        : 0;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text('${item.emoji} ${item.name}'),
      ),
      body: Column(
        children: [
          Expanded(
            child: InteractiveViewer(
              child: Image.file(
                File(item.photoPath!),
                fit: BoxFit.contain,
                width: double.infinity,
              ),
            ),
          ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            color: const Color(0xFF1A1A1A),
            child: Column(
              children: [
                const Icon(Icons.check_circle, color: Color(0xFF2E7D6B), size: 40),
                const SizedBox(height: 12),
                Text(
                  timeStr,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'vor $ageMinutes Minuten aufgenommen',
                  style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 14),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2E7D6B).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(color: const Color(0xFF2E7D6B)),
                  ),
                  child: const Text(
                    '✅ Alles OK – du kannst entspannen!',
                    style: TextStyle(
                      color: Color(0xFF4CAF8F),
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Add Item Dialog ──────────────────────────────────────────────────────────

class _AddItemDialog extends StatefulWidget {
  final void Function(String name, String emoji) onSave;

  const _AddItemDialog({required this.onSave});

  @override
  State<_AddItemDialog> createState() => _AddItemDialogState();
}

class _AddItemDialogState extends State<_AddItemDialog> {
  final _controller = TextEditingController();
  String _selectedEmoji = '🔑';

  static const _emojis = [
    '🔑', '🚪', '🍳', '☕', '👔', '🪟', '💡', '🔌',
    '🚿', '🛁', '🔒', '🛡️', '🐾', '🌿', '🔥', '💧',
    '🧯', '⚡', '🪴', '🐱', '🐶', '✅', '❓', '🏠',
  ];

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Neuer Check'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _controller,
            decoration: const InputDecoration(
              labelText: 'Name (z.B. Herd)',
              border: OutlineInputBorder(),
            ),
            autofocus: true,
            textCapitalization: TextCapitalization.sentences,
          ),
          const SizedBox(height: 16),
          const Align(
            alignment: Alignment.centerLeft,
            child: Text('Emoji wählen:', style: TextStyle(fontWeight: FontWeight.w500)),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _emojis.map((e) {
              final selected = e == _selectedEmoji;
              return GestureDetector(
                onTap: () => setState(() => _selectedEmoji = e),
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: selected
                        ? const Color(0xFF2E7D6B).withOpacity(0.2)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: selected ? const Color(0xFF2E7D6B) : Colors.transparent,
                      width: 2,
                    ),
                  ),
                  child: Center(child: Text(e, style: const TextStyle(fontSize: 22))),
                ),
              );
            }).toList(),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Abbrechen'),
        ),
        FilledButton(
          onPressed: () {
            widget.onSave(_controller.text, _selectedEmoji);
            Navigator.pop(context);
          },
          style: FilledButton.styleFrom(backgroundColor: const Color(0xFF2E7D6B)),
          child: const Text('Hinzufügen'),
        ),
      ],
    );
  }
}

// ─── Empty State ──────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final VoidCallback onAdd;

  const _EmptyState({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('🏠', style: TextStyle(fontSize: 72)),
            const SizedBox(height: 24),
            Text(
              'Kein Panik-Ziel',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 12),
            Text(
              'Füge dein erstes Check-Ziel hinzu –\nz.B. Herd, Haustür oder Kaffeemaschine.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 32),
            FilledButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add),
              label: const Text('Erstes Ziel hinzufügen'),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF2E7D6B),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
