import 'dart:io';
import 'package:budget/database/tables.dart';
import 'package:budget/struct/databaseGlobal.dart';
import 'package:budget/widgets/button.dart';
import 'package:budget/widgets/progressBar.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

class ImportSQL extends StatefulWidget {
  const ImportSQL({super.key});

  @override
  State<ImportSQL> createState() => _ImportSQLState();
}

class _ImportSQLState extends State<ImportSQL> {
  String? filePath;
  List<String> statements = [];
  int executed = 0;
  bool importing = false;

  Future<void> pickFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      allowedExtensions: ['sql'],
      type: FileType.custom,
    );
    if (result != null && result.files.isNotEmpty && result.files.single.path != null) {
      setState(() {
        filePath = result.files.single.path;
      });
      await readFile();
    }
  }

  Future<void> readFile() async {
    if (filePath == null) return;
    final file = File(filePath!);
    final content = await file.readAsString();
    final lines = content.split('\n');
    statements = [];
    String current = '';
    for (final line in lines) {
      if (line.trim().isEmpty || line.trim().startsWith('--')) continue;
      current += ' $line';
      if (current.trim().endsWith(';')) {
        statements.add(current.trim());
        current = '';
      }
    }
    setState(() {});
  }

  Future<void> runImport() async {
    if (statements.isEmpty || importing) return;
    
    setState(() {
      importing = true;
      executed = 0;
    });

    for (int i = 0; i < statements.length; i++) {
      final sql = statements[i];
      try {
        await database.customSelect(sql).get();
      } catch (e) {
        print('Error executing: ${sql.substring(0, sql.length > 50 ? 50 : sql.length)}...');
        print('Error: $e');
      }
      if (mounted) {
        setState(() {
          executed = i + 1;
        });
      }
    }

    if (mounted) {
      setState(() {
        importing = false;
      });
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).canvasColor,
      appBar: AppBar(
        title: Text('Import SQL'),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Select a .sql file to import'),
            SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: Text(
                    filePath ?? 'No file selected',
                    style: TextStyle(color: Theme.of(context).hintColor),
                  ),
                ),
                Button(
                  label: 'Browse',
                  onTap: pickFile,
                ),
              ],
            ),
            if (statements.isNotEmpty) ...[
              SizedBox(height: 20),
              Text('${statements.length} statements found'),
              SizedBox(height: 10),
              if (importing) ...[
                ProgressBar(
                  currentPercent: (executed / statements.length) * 100,
                  color: Colors.green,
                ),
                SizedBox(height: 10),
              ],
              Button(
                label: 'Execute',
                onTap: importing ? () {} : () => runImport(),
                disabled: importing,
              ),
            ],
          ],
        ),
      ),
    );
  }
}