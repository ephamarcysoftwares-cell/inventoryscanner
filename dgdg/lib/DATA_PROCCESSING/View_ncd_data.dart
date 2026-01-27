import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import '../DB/database_helper.dart';

void main() {
  runApp(const DataViewApp());
}

////////////////////////////////////////////////////
/// SHARED DATA SOURCE
////////////////////////////////////////////////////
final Map<String, List<String>> indicatorGroups = {
  "CVD / Shinikizo la damu": [
    "Idadi ya watu waliopimwa shinikizo la damu",
    "Idadi ya watu waliopatikana na shinikizo la juu la damu",
    "Idadi ya watu walio na shinikizo la juu la damu waliopimwa ugonjwa sugu wa figo",
    "Idadi ya watu walio na shinikizo la juu la damu wanaopokea dawa",
    "Idadi ya wagonjwa wa shinikizo la juu la damu wenye shinikizo lililodhibitiwa",
  ],
  "Ugonjwa wa Kisukari": [
    "Idadi ya watu waliopimwa kisukari aina ya kwanza (Type 1)",
    "Idadi ya watu waliopimwa kisukari aina ya pili (Type 2)",
    "Idadi ya watu waliopimwa kisukari wakati wa ujauzito (GDM)",
    "Idadi ya watu waliogunduliwa na kisukari aina ya kwanza",
    "Idadi ya watu waliogunduliwa na kisukari aina ya pili",
    "Idadi ya watu waliogunduliwa na GDM",
    "Idadi ya watu wenye kisukari waliopimwa ugonjwa sugu wa figo",
    "Idadi ya wagonjwa wa kisukari waliogunduliwa na magonjwa sugu ya figo",
    "Idadi ya watu wenye kisukari waliopimwa miguu (diabetes foot)",
    "Idadi ya watu wenye kisukari waliogundulika na vidonda vya miguu",
    "Idadi ya wagonjwa wa kisukari waliokatwa miguu",
    "Idadi ya watu wenye kisukari waliochunguzwa macho (retinopathy)",
    "Idadi ya wagonjwa wa kisukari wenye upofu",
    "Jumla ya wagonjwa wa kisukari wanaopokea dawa",
    "Vidonge pekee",
    "Insulini pekee",
    "Idadi ya wagonjwa wa kisukari wenye udhibiti mzuri wa sukari",
  ],
  "Magonjwa Sugu ya Kupumua": [
    "Idadi ya watu waliogunduliwa na Pumu",
    "Idadi ya watu waliogunduliwa na COPD",
    "Idadi ya watu wenye Pumu wanaotibiwa",
    "Idadi ya watu wenye COPD wanaotibiwa",
  ],
  "Saratani": [
    "Wanawake 30-49 waliopimwa saratani ya shingo ya kizazi",
    "Wanawake 30-49 waliogunduliwa na saratani ya shingo ya kizazi",
    "Wanawake 30-49 waliopimwa saratani ya matiti",
    "Wanawake 30-49 waliogunduliwa na saratani ya matiti",
    "Wanawake 50-69 waliopimwa mammografia",
    "Wanawake wenye saratani ya shingo ya kizazi wanaotibiwa",
    "Wanawake wenye saratani ya matiti wanaotibiwa",
    "Wanaume waliopimwa saratani ya tezi dume",
    "Wanaume waliopatikana na saratani ya tezi dume",
    "Wanaume wenye saratani ya tezi dume wanaotibiwa",
  ],
  "Selimundu": [
    "Idadi ya watu waliochunguzwa ugonjwa wa seli mundu",
    "Idadi ya watu waliogunduliwa na ugonjwa wa seli mundu",
    "Idadi ya watu wenye ugonjwa wa seli mundu wanaopata matibabu",
  ],
  "Ajali": [
    "Idadi ya majeruhi wa ajali za barabarani waliopokelewa",
    "Idadi ya majeruhi waliopata matibabu",
  ],
  "Afya ya Kiakili": [
    "Jumla ya watu waliopimwa kwa matatizo ya akili",
    "Jumla ya watu waliopatikana na matatizo ya akili",
    "Wagonjwa wa matatizo ya akili wanaotibiwa",
  ],
};

final List<String> allIndicators =
indicatorGroups.values.expand((e) => e).toList();

////////////////////////////////////////////////////
/// MAIN APP
////////////////////////////////////////////////////
class DataViewApp extends StatelessWidget {
  const DataViewApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: DefaultTabController(
        length: 2,
        child: Scaffold(
          appBar: AppBar(
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () {
                Navigator.of(context).maybePop(); // Goes back if possible
              },
            ),
            title: const Text("VIEW NCD DATA"),
            centerTitle: true,
            backgroundColor: Colors.blue,
            bottom: const TabBar(
              tabs: [
                Tab(text: "Indicators"),
                Tab(text: "All Combined"),
              ],
            ),
          ),

          body: const TabBarView(
            children: [
              IndicatorListScreen(),
              AllHospitalsCombinedView(),
            ],
          ),
        ),
      ),
    );
  }
}

////////////////////////////////////////////////////
/// SCREEN 1: Indicators List (View Only)
////////////////////////////////////////////////////
class IndicatorListScreen extends StatelessWidget {
  const IndicatorListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(10),
      children: indicatorGroups.entries.map((entry) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SectionTitle(entry.key),
            ...entry.value.map((indicator) => Indicator(indicator)),
          ],
        );
      }).toList(),
    );
  }
}

class SectionTitle extends StatelessWidget {
  final String title;
  const SectionTitle(this.title, {super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: Colors.blue,
        ),
      ),
    );
  }
}

class Indicator extends StatelessWidget {
  final String text;
  const Indicator(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        leading: const Icon(Icons.check_circle_outline, color: Colors.blue),
        title: Text(text),
      ),
    );
  }
}

////////////////////////////////////////////////////
/// SCREEN 2: All Hospitals Combined (FROM DATABASE, VIEW ONLY)
////////////////////////////////////////////////////
class AllHospitalsCombinedView extends StatefulWidget {
  const AllHospitalsCombinedView({super.key});

  @override
  State<AllHospitalsCombinedView> createState() =>
      _AllHospitalsCombinedViewState();
}

class _AllHospitalsCombinedViewState extends State<AllHospitalsCombinedView> {
  Map<String, Map<String, List<int>>> loadedHospitalData = {};
  final List<String> hospitals = ["Hospital A", "Hospital B", "Hospital C"];
  DateTime? startDate;
  DateTime? endDate;

  @override
  void initState() {
    super.initState();
    for (var hospital in hospitals) {
      loadedHospitalData[hospital] = {};
      for (var indicator in allIndicators) {
        loadedHospitalData[hospital]![indicator] = List.filled(12, 0);
      }
    }
    loadSavedData();
  }

  Future<void> loadSavedData() async {
    final db = await DatabaseHelper.instance.database;

    String whereClause = '';
    List<dynamic> whereArgs = [];

    if (startDate != null && endDate != null) {
      whereClause = 'created_at BETWEEN ? AND ?';
      whereArgs = [startDate!.toIso8601String(), endDate!.toIso8601String()];
    }

    final rows =
    await db.query('ncd_data', where: whereClause, whereArgs: whereArgs);

    for (var h in hospitals) {
      for (var indicator in allIndicators) {
        loadedHospitalData[h]![indicator] = List.filled(12, 0);
      }
    }

    for (var row in rows) {
      final hospital = row['hospital'] as String;
      final indicator = row['indicator'] as String;
      final age = row['age_group'] as String;
      final gender = row['gender'] as String;
      final value = row['value'] as int;

      int index = 0;
      if (age == "0-17") index = gender == "M" ? 0 : 1;
      if (age == "18-29") index = gender == "M" ? 3 : 4;
      if (age == "30-69") index = gender == "M" ? 6 : 7;
      if (age == "70+") index = gender == "M" ? 9 : 10;

      loadedHospitalData[hospital]![indicator]![index] += value;
    }

    setState(() {});
  }

  int calculateAllHospitalsTotal(String indicator, int start, int end) {
    int total = 0;
    for (var h in hospitals) {
      final list = loadedHospitalData[h]![indicator]!;
      total += list.sublist(start, end + 1).fold(0, (a, b) => a + b);
    }
    return total;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Date filter
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Row(
            children: [
              Expanded(
                child: TextButton(
                  child: Text(
                      "Start: ${startDate != null ? startDate!.toLocal().toIso8601String().split('T')[0] : 'Select'}"),
                  onPressed: () async {
                    final date = await showDatePicker(
                        context: context,
                        initialDate: DateTime.now(),
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2100));
                    if (date != null) setState(() => startDate = date);
                  },
                ),
              ),
              Expanded(
                child: TextButton(
                  child: Text(
                      "End: ${endDate != null ? endDate!.toLocal().toIso8601String().split('T')[0] : 'Select'}"),
                  onPressed: () async {
                    final date = await showDatePicker(
                        context: context,
                        initialDate: DateTime.now(),
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2100));
                    if (date != null) setState(() => endDate = date);
                  },
                ),
              ),
              IconButton(
                icon: const Icon(Icons.search),
                onPressed: loadSavedData,
              ),
            ],
          ),
        ),

        ElevatedButton.icon(
          onPressed: loadSavedData,
          icon: const Icon(Icons.refresh),
          label: const Text("Refresh Totals"),
        ),

        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: ConstrainedBox(
              constraints:
              BoxConstraints(minWidth: MediaQuery.of(context).size.width),
              child: SingleChildScrollView(
                scrollDirection: Axis.vertical,
                child: DataTable(
                  border: TableBorder.all(),
                  columnSpacing: 12,
                  headingRowHeight: 32,
                  dataRowHeight: 38,
                  columns: const [
                    DataColumn(label: Text("Indicator")),
                    DataColumn(label: Text("0-17 ME")),
                    DataColumn(label: Text("0-17 FE")),
                    DataColumn(label: Text("TOTAL")),
                    DataColumn(label: Text("18-29 ME")),
                    DataColumn(label: Text("18-29 FE")),
                    DataColumn(label: Text("TOTAL")),
                    DataColumn(label: Text("30-69 ME")),
                    DataColumn(label: Text("30-69 FE")),
                    DataColumn(label: Text("TOTAL")),
                    DataColumn(label: Text("70+ ME")),
                    DataColumn(label: Text("70+ FE")),
                    DataColumn(label: Text("TOTAL")),
                    DataColumn(label: Text("ALL TOTAL")),
                  ],
                  rows: [
                    for (var entry in indicatorGroups.entries) ...[
                      DataRow(
                        color: MaterialStateProperty.all(Colors.blue.shade100),
                        cells: [
                          DataCell(Text(entry.key,
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold))),
                          ...List.generate(12, (_) => const DataCell(Text(""))),
                          const DataCell(Text("")),
                        ],
                      ),
                      ...entry.value.map((indicator) {
                        return DataRow(
                          cells: [
                            DataCell(Text(indicator)),
                            DataCell(Text(
                                calculateAllHospitalsTotal(indicator, 0, 0)
                                    .toString())),
                            DataCell(Text(
                                calculateAllHospitalsTotal(indicator, 1, 1)
                                    .toString())),
                            DataCell(Text(
                                calculateAllHospitalsTotal(indicator, 0, 1)
                                    .toString())),
                            DataCell(Text(
                                calculateAllHospitalsTotal(indicator, 3, 3)
                                    .toString())),
                            DataCell(Text(
                                calculateAllHospitalsTotal(indicator, 4, 4)
                                    .toString())),
                            DataCell(Text(
                                calculateAllHospitalsTotal(indicator, 3, 4)
                                    .toString())),
                            DataCell(Text(
                                calculateAllHospitalsTotal(indicator, 6, 6)
                                    .toString())),
                            DataCell(Text(
                                calculateAllHospitalsTotal(indicator, 7, 7)
                                    .toString())),
                            DataCell(Text(
                                calculateAllHospitalsTotal(indicator, 6, 7)
                                    .toString())),
                            DataCell(Text(
                                calculateAllHospitalsTotal(indicator, 9, 9)
                                    .toString())),
                            DataCell(Text(
                                calculateAllHospitalsTotal(indicator, 10, 10)
                                    .toString())),
                            DataCell(Text(
                                calculateAllHospitalsTotal(indicator, 9, 10)
                                    .toString())),
                            DataCell(Text(
                                calculateAllHospitalsTotal(indicator, 0, 11)
                                    .toString())),
                          ],
                        );
                      }).toList(),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
