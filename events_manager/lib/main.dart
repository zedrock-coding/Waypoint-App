import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';
import 'models/event.dart';
import 'models/category.dart';
import 'models/settings.dart';
import 'settings_page.dart';
import 'add_event_page.dart';
import 'category_page.dart';
import 'app_shell.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final dir = await getApplicationDocumentsDirectory();
  final isar = await Isar.open([EventSchema, CategorySchema, SettingsSchema], directory: dir.path);
  
  // Ensure default settings exist
  await isar.writeTxn(() async {
    final settings = await isar.settings.get(0);
    if (settings == null) {
      await isar.settings.put(Settings()..id = 0);
    }
  });

  runApp(MyApp(isar: isar));
}

class MyApp extends StatelessWidget {
  final Isar isar;

  const MyApp({super.key, required this.isar});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Settings?>(
      stream: isar.settings.watchObject(0, fireImmediately: true).asBroadcastStream(),
      builder: (context, snapshot) {
        final settings = snapshot.data ?? Settings();
        
        ThemeData theme;
        if (settings.themeMode == 1) {
          theme = ThemeData.dark(useMaterial3: true);
        } else if (settings.themeMode == 2 && settings.customThemeJson != null) {
          try {
            final json = jsonDecode(settings.customThemeJson!);
            theme = _createThemeFromJson(json);
          } catch (e) {
            theme = ThemeData.light(useMaterial3: true);
          }
        } else {
          theme = ThemeData(
            colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
            useMaterial3: true,
          );
        }

        final fontScales = [0.7, 0.85, 1.0, 1.2, 1.4];
        final double scale = fontScales[settings.fontSizeIndex.clamp(0, 4)];

        return MaterialApp(
          title: 'Events Manager',
          theme: theme,
          builder: (context, child) {
            return MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaler: TextScaler.linear(scale),
              ),
              child: child!,
            );
          },
          initialRoute: '/',
          routes: {
            '/': (context) => MyHomePage(title: 'Events Manager', isar: isar),
            '/settings': (context) => SettingPage(isar: isar),
            '/add-event': (context) => AddEventPage(isar: isar),
            '/categories': (context) => CategoryPage(isar: isar),
          },
        );
      },
    );
  }

  ThemeData _createThemeFromJson(Map<String, dynamic> json) {
    try {
      final String? seedColorStr = json['seedColor'];
      final String? bgColorStr = json['backgroundColor'];
      
      final Color seedColor = seedColorStr != null 
          ? Color(int.parse(seedColorStr)) 
          : Colors.blue;
          
      final Brightness brightness = json['brightness'] == 'dark' 
          ? Brightness.dark 
          : Brightness.light;

      return ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: seedColor,
          brightness: brightness,
        ),
        scaffoldBackgroundColor: bgColorStr != null ? Color(int.parse(bgColorStr)) : null,
      );
    } catch (e) {
      debugPrint('Error creating theme from JSON: $e');
      return ThemeData.light(useMaterial3: true);
    }
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title, required this.isar});

  final String title;
  final Isar isar;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  late Stream<void> _changeStream;
  bool _sortByCategory = true;
  Id? _selectedCategoryId; // null means "All Categories"

  @override
  void initState() {
    super.initState();
    _changeStream = widget.isar.events.watchLazy().asBroadcastStream();
  }

  @override
  Widget build(BuildContext context) {
    return AppShell(
      title: widget.title,
      actions: [
        IconButton(
          tooltip: _sortByCategory ? 'Switch to Chronological' : 'Switch to Category View',
          icon: Icon(_sortByCategory ? Icons.sort_by_alpha : Icons.calendar_month),
          onPressed: () {
            setState(() {
              _sortByCategory = !_sortByCategory;
            });
          },
        ),
      ],
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.pushNamed(context, '/add-event');
        },
        tooltip: 'Add Event',
        child: const Icon(Icons.add),
      ),
      child: Column(
        children: [
          if (_sortByCategory) _buildCategoryFilterDropdown(),
          Expanded(
            child: StreamBuilder<void>(
              stream: _changeStream,
              builder: (context, snapshot) {
                return FutureBuilder<List<dynamic>>(
                  future: _getOptimizedFlattenedList(),
                  builder: (context, listSnapshot) {
                    if (listSnapshot.hasError) return Center(child: Text('Error: ${listSnapshot.error}'));
                    if (!listSnapshot.hasData) return const Center(child: CircularProgressIndicator());

                    final flattenedList = listSnapshot.data!;
                    if (flattenedList.isEmpty) {
                      return const Center(child: Text('No events found. Add one!'));
                    }

                    if (!_sortByCategory && _selectedCategoryId == null) {
                      return ListView.builder(
                        itemCount: flattenedList.length,
                        itemBuilder: (context, index) {
                          final item = flattenedList[index];
                          if (item is Event) {
                            return _buildEventCard(item);
                          }
                          return const SizedBox.shrink(); // Safety fallback
                        },
                      );
                    }

                    final Map<String, List<Event>> grouped = {};
                    String currentHeader = "";
                    for (var item in flattenedList) {
                      if (item is String) {
                        currentHeader = item;
                        grouped[currentHeader] = [];
                      } else {
                        grouped[currentHeader]?.add(item as Event);
                      }
                    }

                    final headers = grouped.keys.toList();

                    return ListView.builder(
                      itemCount: headers.length,
                      itemBuilder: (context, index) {
                        final header = headers[index];
                        final events = grouped[header]!;
                        
                        return ExpansionTile(
                          initiallyExpanded: true,
                          title: Text(
                            header,
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                          children: events.map((event) => _buildEventCard(event)).toList(),
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEventCard(Event event) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        title: Text(event.title),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(event.description),
            const SizedBox(height: 4),
            FutureBuilder(
              future: event.categories.load(),
              builder: (context, snapshot) {
                if (event.categories.isEmpty) return const SizedBox.shrink();
                return Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  children: event.categories.map((cat) => Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.secondaryContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      cat.name,
                      style: TextStyle(
                        fontSize: 10,
                        color: Theme.of(context).colorScheme.onSecondaryContainer,
                      ),
                    ),
                  )).toList(),
                );
              },
            ),
          ],
        ),
        trailing: Text(event.dateTime.toLocal().toString().split(' ')[0]),
        onLongPress: () async {
          await widget.isar.writeTxn(() async {
            await widget.isar.events.delete(event.id);
          });
        },
      ),
    );
  }

  Widget _buildCategoryFilterDropdown() {
    return FutureBuilder<List<Category>>(
      future: widget.isar.categorys.where().sortByName().findAll(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox.shrink();
        final categories = snapshot.data!;

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: DropdownButtonFormField<Id?>(
            value: _selectedCategoryId,
            decoration: const InputDecoration(
              labelText: 'Filter by Category',
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            items: [
              const DropdownMenuItem<Id?>(
                value: null,
                child: Text('All Categories'),
              ),
              ...categories.map((cat) => DropdownMenuItem<Id?>(
                    value: cat.id,
                    child: Text(cat.name),
                  )),
              const DropdownMenuItem<Id?>(
                value: -1,
                child: Text('Uncategorized'),
              ),
            ],
            onChanged: (value) {
              setState(() {
                _selectedCategoryId = value;
              });
            },
          ),
        );
      },
    );
  }

  Future<List<dynamic>> _getOptimizedFlattenedList() async {
    final List<dynamic> flattened = [];
    
    if (_selectedCategoryId != null) {
      // 1. FILTERED VIEW: Show only one category
      if (_selectedCategoryId == -1) {
        // Uncategorized
        final uncategorized = await widget.isar.events
            .filter()
            .categoriesLengthEqualTo(0)
            .sortByDateTime()
            .findAll();
        if (uncategorized.isNotEmpty) {
          flattened.add('Uncategorized');
          flattened.addAll(uncategorized);
        }
      } else {
        // Specific category
        final cat = await widget.isar.categorys.get(_selectedCategoryId!);
        if (cat != null) {
          final events = await widget.isar.events
              .filter()
              .categories((q) => q.idEqualTo(cat.id))
              .sortByDateTime()
              .findAll();
          if (events.isNotEmpty) {
            flattened.add(cat.name);
            flattened.addAll(events);
          }
        }
      }
    } else if (_sortByCategory) {
      // 2. CATEGORY VIEW (ALL)
      final categories = await widget.isar.categorys.where().sortByName().findAll();
      for (var cat in categories) {
        final events = await widget.isar.events
            .filter()
            .categories((q) => q.idEqualTo(cat.id))
            .sortByDateTime()
            .findAll();
        if (events.isNotEmpty) {
          flattened.add(cat.name);
          flattened.addAll(events);
        }
      }
      final uncategorized = await widget.isar.events
          .filter()
          .categoriesLengthEqualTo(0)
          .sortByDateTime()
          .findAll();
      if (uncategorized.isNotEmpty) {
        flattened.add('Uncategorized');
        flattened.addAll(uncategorized);
      }
    } else {
      // 3. CHRONOLOGICAL VIEW (ALL)
      final allEvents = await widget.isar.events.where().sortByDateTime().findAll();
      flattened.addAll(allEvents);
    }

    return flattened;
  }
}
