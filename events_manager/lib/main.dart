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
      stream: isar.settings.watchObject(0, fireImmediately: true),
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
        final scale = fontScales[settings.fontSizeIndex];

        return MaterialApp(
          title: 'Events Manager',
          theme: theme.copyWith(
            textTheme: theme.textTheme.apply(fontSizeFactor: scale),
          ),
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
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: Color(int.parse(json['seedColor'] ?? '0xFF2196F3')),
        brightness: json['brightness'] == 'dark' ? Brightness.dark : Brightness.light,
      ),
      scaffoldBackgroundColor: json['backgroundColor'] != null ? Color(int.parse(json['backgroundColor'])) : null,
    );
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
  late Stream<List<Event>> _eventStream;

  @override
  void initState() {
    super.initState();
    _eventStream = widget.isar.events.where().watch(fireImmediately: true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary,
              ),
              child: const Text(
                'Menu',
                style: TextStyle(color: Colors.white, fontSize: 24),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.home),
              title: const Text('Home'),
              onTap: () {
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.settings),
              title: const Text('Settings'),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, '/settings');
              },
            ),
            ListTile(
              leading: const Icon(Icons.category),
              title: const Text('Categories'),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, '/categories');
              },
            ),
          ],
        ),
      ),
      body: StreamBuilder<List<Event>>(
        stream: _eventStream,
        builder: (context, snapshot) {
          if (snapshot.hasError) return Center(child: Text('Error: ${snapshot.error}'));
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

          final events = snapshot.data!;
          if (events.isEmpty) {
            return const Center(child: Text('No events found. Add one!'));
          }

          return FutureBuilder<List<dynamic>>(
            future: _getFlattenedGroupedList(events),
            builder: (context, listSnapshot) {
              if (!listSnapshot.hasData) return const Center(child: CircularProgressIndicator());
              final flattenedList = listSnapshot.data!;

              return ListView.builder(
                itemCount: flattenedList.length,
                itemBuilder: (context, index) {
                  final item = flattenedList[index];
                  if (item is String) {
                    // Category Header
                    return Padding(
                      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
                      child: Text(
                        item,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    );
                  } else {
                    // Event Card
                    final event = item as Event;
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
                },
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.pushNamed(context, '/add-event');
        },
        tooltip: 'Add Event',
        child: const Icon(Icons.add),
      ),
    );
  }

  Future<List<dynamic>> _getFlattenedGroupedList(List<Event> events) async {
    final Map<String, List<Event>> grouped = {};

    for (var event in events) {
      await event.categories.load();
      if (event.categories.isEmpty) {
        grouped.putIfAbsent('Uncategorized', () => []).add(event);
      } else {
        for (var cat in event.categories) {
          grouped.putIfAbsent(cat.name, () => []).add(event);
        }
      }
    }

    final sortedCategories = grouped.keys.toList()..sort();
    final List<dynamic> flattened = [];

    for (var catName in sortedCategories) {
      flattened.add(catName);
      flattened.addAll(grouped[catName]!);
    }

    return flattened;
  }
}
