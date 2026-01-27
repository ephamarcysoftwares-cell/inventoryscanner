import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';

import '../API/payment_alternative.dart';

void main() {
  runApp(const Data());
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
Future<void> insertNcdData(
    String hospital,
    String indicator,
    String ageGroup,
    String gender,
    int value,
    ) async {
  final db = await DatabaseHelper.instance.database;
  await db.insert(
    'ncd_data',
    {
      'hospital': hospital,
      'indicator': indicator,
      'age_group': ageGroup,
      'gender': gender,
      'value': value,
      'created_at': DateTime.now().toIso8601String(), // ✅ Save date & time
    },
    conflictAlgorithm: ConflictAlgorithm.replace,
  );
}

class Data extends StatelessWidget {
  const Data({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: DefaultTabController(
        length: 3,
        child: Scaffold(

          appBar: AppBar(
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () {
                Navigator.of(context).maybePop(); // Go back if possible
              },
            ),
            title: Text(
              "PERFORM DATA ACCUMULATION HERE",
              style: TextStyle(color: Colors.white), // ✅ correct place
            ),
            centerTitle: true,
            backgroundColor: Colors.teal,
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(80)),
            ),
            bottom: const TabBar(
              tabs: [
                Tab(text: "Indicators"),
                Tab(text: "Data Table"),
                Tab(text: "All Combined"),
              ],
            ),
          ),

          body: const TabBarView(
            children: [
              IndicatorListScreen(),
              NcdDataTable(),
              AllHospitalsCombinedView(),
            ],
          ),
        ),
      ),
    );
  }
}

////////////////////////////////////////////////////
/// SCREEN 1: Indicators List
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
/// SCREEN 2: Data Entry Table with Hospitals
////////////////////////////////////////////////////

enum Gender { male, female }

class NcdDataTable extends StatefulWidget {
  const NcdDataTable({super.key});

  @override
  State<NcdDataTable> createState() => _NcdDataTableState();
}

class _NcdDataTableState extends State<NcdDataTable> {
  String selectedHospital = "Hospital A";
  final List<String> hospitals = ["Hospital A", "Hospital B", "Hospital C"];

  // Shared persistent data
  static final Map<String, Map<String, List<TextEditingController>>>
  hospitalData = {};
  static Map<String, Map<String, List<TextEditingController>>> get data =>
      hospitalData;

  @override
  void initState() {
    super.initState();
    for (var hospital in hospitals) {
      if (!hospitalData.containsKey(hospital)) {
        hospitalData[hospital] = {};
        for (var indicator in allIndicators) {
          hospitalData[hospital]![indicator] =
              List.generate(12, (_) => TextEditingController());
        }
      }
    }
  }

  void addHospital(String name) {
    if (hospitals.contains(name)) return;
    setState(() {
      hospitals.add(name);
      hospitalData[name] = {};
      for (var indicator in allIndicators) {
        hospitalData[name]![indicator] =
            List.generate(12, (_) => TextEditingController());
      }
      selectedHospital = name;
    });
  }

  int calculateTotal(String indicator, int startIndex, int endIndex) {
    final controllers = hospitalData[selectedHospital]![indicator]!;
    int total = 0;
    for (int i = startIndex; i <= endIndex; i++) {
      total += int.tryParse(controllers[i].text) ?? 0;
    }
    return total;
  }

  DataCell numberField(String indicator, int index, Gender gender) {
    final controllers = hospitalData[selectedHospital]![indicator]!;
    return DataCell(
      SizedBox(
        width: 60,
        child: TextField(
          controller: controllers[index],
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            border: InputBorder.none,
            isDense: true,
            contentPadding: EdgeInsets.all(5),
          ),
          onTapOutside: (_) => FocusScope.of(context).unfocus(),
          onChanged: (value) {
            if (value.isEmpty) return;

            if (!RegExp(r'^\d+$').hasMatch(value)) {
              controllers[index].text = '';
              return;
            }

            if (gender == Gender.male &&
                indicator.toLowerCase().contains("wanawake")) {
              controllers[index].text = '';
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                    content: Text("Cannot enter male data in female indicator")),
              );
            } else if (gender == Gender.female &&
                indicator.toLowerCase().contains("wanaume")) {
              controllers[index].text = '';
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                    content: Text("Cannot enter female data in male indicator")),
              );
            }

            setState(() {});
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // SAVE BUTTON
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: ElevatedButton.icon(
            onPressed: () async {
              for (var hospital in hospitals) {
                final indicators = hospitalData[hospital]!;
                for (var indicator in indicators.keys) {
                  final controllers = indicators[indicator]!;

                  final List<Map<String, dynamic>> entries = [
                    {"age": "0-17", "gender": "M", "index": 0},
                    {"age": "0-17", "gender": "F", "index": 1},
                    {"age": "18-29", "gender": "M", "index": 3},
                    {"age": "18-29", "gender": "F", "index": 4},
                    {"age": "30-69", "gender": "M", "index": 6},
                    {"age": "30-69", "gender": "F", "index": 7},
                    {"age": "70+", "gender": "M", "index": 9},
                    {"age": "70+", "gender": "F", "index": 10},
                  ];

                  for (var e in entries) {
                    final value = int.tryParse(controllers[e["index"]].text) ?? 0;
                    if (value > 0) {
                      await insertNcdData(
                        hospital,
                        indicator,
                        e["age"],
                        e["gender"],
                        value,
                      );
                    }
                  }
                }
              }

              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Data saved successfully!")),
              );
            },
            icon: const Icon(Icons.save),
            label: const Text("Save All Data"),
          ),
        ),

        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Row(
            children: [
              Expanded(
                child: DropdownButton<String>(
                  value: selectedHospital,
                  isExpanded: true,
                  items: hospitals
                      .map((h) => DropdownMenuItem(value: h, child: Text(h)))
                      .toList(),
                  onChanged: (val) {
                    setState(() {
                      selectedHospital = val!;
                    });
                  },
                ),
              ),
              IconButton(
                icon: const Icon(Icons.add, color: Colors.blue),
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (ctx) {
                      final controller = TextEditingController();
                      return AlertDialog(
                        title: const Text("Add Hospital"),
                        content: TextField(
                          controller: controller,
                          decoration: const InputDecoration(
                              hintText: "Enter hospital name"),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () {
                              if (controller.text.isNotEmpty) {
                                addHospital(controller.text);
                              }
                              Navigator.pop(ctx);
                            },
                            child: const Text("ADD"),
                          ),
                        ],
                      );
                    },
                  );
                },
              )
            ],
          ),
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
                            numberField(indicator, 0, Gender.male),
                            numberField(indicator, 1, Gender.female),
                            DataCell(
                                Text(calculateTotal(indicator, 0, 1).toString())),
                            numberField(indicator, 3, Gender.male),
                            numberField(indicator, 4, Gender.female),
                            DataCell(
                                Text(calculateTotal(indicator, 3, 4).toString())),
                            numberField(indicator, 6, Gender.male),
                            numberField(indicator, 7, Gender.female),
                            DataCell(
                                Text(calculateTotal(indicator, 6, 7).toString())),
                            numberField(indicator, 9, Gender.male),
                            numberField(indicator, 10, Gender.female),
                            DataCell(
                                Text(calculateTotal(indicator, 9, 10).toString())),
                            DataCell(
                                Text(calculateTotal(indicator, 0, 11).toString())),
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

////////////////////////////////////////////////////
/// SCREEN 3: All Hospitals Combined View
////////////////////////////////////////////////////

class AllHospitalsCombinedView extends StatefulWidget {
  const AllHospitalsCombinedView({super.key});

  @override
  State<AllHospitalsCombinedView> createState() =>
      _AllHospitalsCombinedViewState();
}

class _AllHospitalsCombinedViewState extends State<AllHospitalsCombinedView> {
  int calculateAllHospitalsTotal(
      Map<String, Map<String, List<TextEditingController>>> hospitalData,
      String indicator,
      int startIndex,
      int endIndex) {
    int total = 0;
    for (var h in hospitalData.keys) {
      final controllers = hospitalData[h]![indicator]!;
      for (int i = startIndex; i <= endIndex; i++) {
        total += int.tryParse(controllers[i].text) ?? 0;
      }
    }
    return total;
  }

  @override
  Widget build(BuildContext context) {
    final hospitalData = _NcdDataTableState.data;

    return Column(
      children: [
        ElevatedButton.icon(
          onPressed: () => setState(() {}),
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
                              style:
                              const TextStyle(fontWeight: FontWeight.bold))),
                          ...List.generate(12, (_) => const DataCell(Text(""))),
                          const DataCell(Text("")),
                        ],
                      ),
                      ...entry.value.map((indicator) {
                        return DataRow(
                          cells: [
                            DataCell(Text(indicator)),
                            DataCell(Text(calculateAllHospitalsTotal(
                                hospitalData, indicator, 0, 0)
                                .toString())),
                            DataCell(Text(calculateAllHospitalsTotal(
                                hospitalData, indicator, 1, 1)
                                .toString())),
                            DataCell(Text(calculateAllHospitalsTotal(
                                hospitalData, indicator, 0, 1)
                                .toString())),
                            DataCell(Text(calculateAllHospitalsTotal(
                                hospitalData, indicator, 3, 3)
                                .toString())),
                            DataCell(Text(calculateAllHospitalsTotal(
                                hospitalData, indicator, 4, 4)
                                .toString())),
                            DataCell(Text(calculateAllHospitalsTotal(
                                hospitalData, indicator, 3, 4)
                                .toString())),
                            DataCell(Text(calculateAllHospitalsTotal(
                                hospitalData, indicator, 6, 6)
                                .toString())),
                            DataCell(Text(calculateAllHospitalsTotal(
                                hospitalData, indicator, 7, 7)
                                .toString())),
                            DataCell(Text(calculateAllHospitalsTotal(
                                hospitalData, indicator, 6, 7)
                                .toString())),
                            DataCell(Text(calculateAllHospitalsTotal(
                                hospitalData, indicator, 9, 9)
                                .toString())),
                            DataCell(Text(calculateAllHospitalsTotal(
                                hospitalData, indicator, 10, 10)
                                .toString())),
                            DataCell(Text(calculateAllHospitalsTotal(
                                hospitalData, indicator, 9, 10)
                                .toString())),
                            DataCell(Text(calculateAllHospitalsTotal(
                                hospitalData, indicator, 0, 11)
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
