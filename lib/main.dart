import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

void main() => runApp(const PresidentielleApp());

class PresidentielleApp extends StatelessWidget {
  const PresidentielleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Présidentielle 2027',
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.blueGrey,
      ),
      home: const MainNavigationScreen(),
    );
  }
}

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  List<dynamic> allCandidates = [];
  String searchQuery = '';
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadJsonData();
  }

  Future<void> _loadJsonData() async {
    final String jsonString = await rootBundle.loadString('assets/programmes.json');
    final data = json.decode(jsonString);
    setState(() {
      allCandidates = data;
      isLoading = false;
    });
  }

  Future<void> _openUrl(String url) async {
    final Uri uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      debugPrint('Impossible d\'ouvrir $url');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Programmes 2027'),
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.person), text: 'Par Candidat'),
              Tab(icon: Icon(Icons.category), text: 'Par Thématique'),
            ],
          ),
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: TextField(
                decoration: InputDecoration(
                  hintText: 'Rechercher une mesure (ex. SMIC, nucléaire...)',
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                ),
                onChanged: (val) => setState(() => searchQuery = val.toLowerCase()),
              ),
            ),
            Expanded(
              child: TabBarView(
                children: [
                  _buildCandidatesView(),
                  _buildThematiquesView(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCandidatesView() {
    return ListView.builder(
      itemCount: allCandidates.length,
      itemBuilder: (context, index) {
        final cand = allCandidates[index];
        final List props = (cand['propositions'] as List).where((p) {
          final t = p['titre'].toString().toLowerCase();
          final d = p['detail'].toString().toLowerCase();
          final th = p['thematique'].toString().toLowerCase();
          return t.contains(searchQuery) || d.contains(searchQuery) || th.contains(searchQuery);
        }).toList();

        if (searchQuery.isNotEmpty && props.isEmpty) {
          return const SizedBox.shrink();
        }

        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: ExpansionTile(
            title: Text(cand['nom'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            subtitle: Text('${cand['parti']} • ${cand['statut']}'),
            trailing: IconButton(
              icon: const Icon(Icons.link, color: Colors.blue),
              tooltip: 'Site officiel',
              onPressed: () => _openUrl(cand['source_url']),
            ),
            children: props.map<Widget>((p) {
              return Container(
                decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: Colors.black12, width: 0.5)),
                ),
                child: ListTile(
                  title: Text(p['titre'], style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 4),
                      Text(p['detail']),
                      const SizedBox(height: 6),
                      Text('Source : ${p['source_texte']}',
                          style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: Colors.grey[700])),
                    ],
                  ),
                  trailing: Chip(
                    label: Text(p['thematique'], style: const TextStyle(fontSize: 11)),
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              );
            }).toList(),
          ),
        );
      },
    );
  }

  Widget _buildThematiquesView() {
    final Map<String, dynamic> byTheme = {};

    for (var cand in allCandidates) {
      for (var prop in cand['propositions']) {
        final th = prop['thematique'] as String;
        final t = prop['titre'].toString().toLowerCase();
        final d = prop['detail'].toString().toLowerCase();

        if (searchQuery.isEmpty || t.contains(searchQuery) || d.contains(searchQuery) || th.toLowerCase().contains(searchQuery)) {
          if (!byTheme.containsKey(th)) {
            byTheme[th] = [];
          }
          byTheme[th].add({
            'candidat': cand['nom'],
            'parti': cand['parti'],
            'titre': prop['titre'],
            'detail': prop['detail'],
            'source_texte': prop['source_texte'],
          });
        }
      }
    }

    if (byTheme.isEmpty) {
      return const Center(child: Text('Aucun résultat trouvé pour cette recherche.'));
    }

    return ListView(
      children: byTheme.entries.map((entry) {
        final List items = entry.value as List;
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: ExpansionTile(
            initiallyExpanded: searchQuery.isNotEmpty,
            title: Text(entry.key, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            subtitle: Text('${items.length} propositions enregistrées'),
            children: items.map<Widget>((item) {
              return Container(
                decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: Colors.black12, width: 0.5)),
                ),
                child: ListTile(
                  leading: const Icon(Icons.arrow_right, size: 28),
                  title: Text(item['titre'], style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 2),
                      Text(item['detail']),
                      const SizedBox(height: 4),
                      Text('${item['candidat']} (${item['parti']})',
                          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blueGrey)),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        );
      }).toList(),
    );
  }
}