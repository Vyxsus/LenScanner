import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_scalable_ocr/flutter_scalable_ocr.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import 'package:excel/excel.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Permission.camera.request();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Scalable OCR',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const MyHomePage(title: 'Flutter Scalable OCR'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});
  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  String name = "";
  String id = "";
  String hasilScan1 = "";
  String hasilScan2 = "";
  double selisih = 0.0;

  int scanStep = 1; // 1 = scan pertama, 2 = scan kedua
  bool torchOn = false;
  int cameraSelection = 0;
  bool lockCamera = true;
  bool loading = false;

  bool dialogShown = false;
  Timer? debounceTimer;

  final GlobalKey<ScalableOCRState> cameraKey = GlobalKey<ScalableOCRState>();

  @override
  void dispose() {
    debounceTimer?.cancel();
    super.dispose();
  }

  void setText(String value) {
    setState(() {
      if (scanStep == 1) {
        hasilScan1 = value;
      } else if (scanStep == 2) {
        hasilScan2 = value;
        double num1 = double.tryParse(hasilScan1) ?? 0;
        double num2 = double.tryParse(hasilScan2) ?? 0;
        selisih = num2 - num1;
      }
    });
  }

  Future<void> saveToExcel() async {
    final now = DateTime.now();
    final waktuSimpan =
        "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')} "
        "${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year}";

    Directory downloadsDir = Directory('/storage/emulated/0/Download');
    if (!downloadsDir.existsSync()) {
      downloadsDir = await getExternalStorageDirectory() ?? downloadsDir;
    }

    final fileName = "DataScan.xlsx";
    final filePath = '${downloadsDir.path}/$fileName';
    final file = File(filePath);

    Excel excel;
    Sheet sheet;

    if (file.existsSync()) {
      final bytes = file.readAsBytesSync();
      excel = Excel.decodeBytes(bytes);
      sheet = excel['Sheet1'];
    } else {
      excel = Excel.createExcel();
      sheet = excel['Sheet1'];
      sheet.appendRow([
        'Nama',
        'ID',
        'Hasil Scan 1',
        'Hasil Scan 2',
        'Selisih',
        'Waktu Simpan'
      ]);
    }

    sheet.appendRow([
      name,
      id,
      hasilScan1,
      hasilScan2,
      selisih.toString(),
      waktuSimpan
    ]);

    final fileBytes = excel.encode();
    await file.writeAsBytes(fileBytes!);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Data tersimpan di: $filePath')),
    );
  }

  bool confirmScanEnabled = true; // flag untuk mengatur confirmScan aktif/mati
  
  Future<void> confirmAndSave() async {
    confirmScanEnabled = false; // matikan confirmScan saat dialog final muncul
  
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Konfirmasi Data Final'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Nama: $name"),
            Text("ID: $id"),
            Text("Scan 1: $hasilScan1"),
            Text("Scan 2: $hasilScan2"),
            Text("Selisih: $selisih"),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
  
    if (confirm == true) {
      await saveToExcel();
    }
  
    confirmScanEnabled = true; // hidupkan lagi setelah dialog final ditutup
  }
  
  Future<void> confirmScan(String hasil, int step) async {
    if (!confirmScanEnabled) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Konfirmasi Scan $step'),
        content: Text("Hasil Scan $step: $hasil\nApakah sudah benar?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Ulang'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Benar'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      if (step == 1) {
        setState(() {
          hasilScan1 = hasil;
          scanStep = 2;
        });
      } else if (step == 2) {
        setState(() {
          hasilScan2 = hasil;
          double num1 = double.tryParse(hasilScan1) ?? 0;
          double num2 = double.tryParse(hasilScan2) ?? 0;
          selisih = num2 - num1;
        });
        await confirmAndSave(); // Panggil setelah hasilScan2 fix
      }
    } else {
      setState(() {
        if (step == 1) hasilScan1 = "";
        if (step == 2) hasilScan2 = "";
      });
    }
  }

  void refreshScan() {
    setState(() {
      scanStep = 1;
      hasilScan1 = "";
      hasilScan2 = "";
      selisih = 0.0;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Scan telah direset')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          IconButton(
            icon: Icon(torchOn ? Icons.flash_on : Icons.flash_off),
            onPressed: () {
              setState(() {
                torchOn = !torchOn;
              });
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            if (!loading)
              ScalableOCR(
                key: cameraKey,
                torchOn: torchOn,
                cameraSelection: cameraSelection,
                lockCamera: lockCamera,
                paintboxCustom: Paint()
                  ..style = PaintingStyle.stroke
                  ..strokeWidth = 4.0
                  ..color = Colors.lightBlue,
                boxLeftOff: 5,
                boxBottomOff: 2.5,
                boxRightOff: 5,
                boxTopOff: 2.5,
                boxHeight: MediaQuery.of(context).size.height / 3,
                getScannedText: (value) {
                  if (value.isEmpty || dialogShown) return;
                  debounceTimer?.cancel();
                  debounceTimer = Timer(const Duration(milliseconds: 800), () async {
                    dialogShown = true;
                    setText(value);
                    if (scanStep == 1) {
                      await confirmScan(hasilScan1, 1);
                    } else if (scanStep == 2) {
                      await confirmScan(hasilScan2, 2);
                    }
                    dialogShown = false;
                  });
                },
              )
            else
              const Padding(
                padding: EdgeInsets.all(20.0),
                child: CircularProgressIndicator(),
              ),

            const SizedBox(height: 20),
            Text(
              scanStep == 1 ? "Silakan Scan Pertama" : "Silakan Scan Kedua",
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    decoration: const InputDecoration(labelText: 'Masukkan Nama', border: OutlineInputBorder()),
                    style: const TextStyle(fontSize: 18),
                    onChanged: (val) => setState(() => name = val),
                  ),
                  const SizedBox(height: 15),
                  TextField(
                    decoration: const InputDecoration(labelText: 'Masukkan ID', border: OutlineInputBorder()),
                    style: const TextStyle(fontSize: 18),
                    onChanged: (val) => setState(() => id = val),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(child: Text("Hasil Scan 1:", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold))),
                      Expanded(child: Text(hasilScan1, style: TextStyle(fontSize: 20))),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(child: Text("Hasil Scan 2:", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold))),
                      Expanded(child: Text(hasilScan2, style: TextStyle(fontSize: 20))),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(child: Text("Selisih:", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold))),
                      Expanded(child: Text(selisih.toString(), style: TextStyle(fontSize: 20))),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  loading = true;
                  cameraSelection = cameraSelection == 0 ? 1 : 0;
                });
                Future.delayed(const Duration(milliseconds: 300), () {
                  setState(() => loading = false);
                });
              },
              child: const Text("Ganti Kamera"),
            ),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: refreshScan,
              child: const Text("Refresh Scan"),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
