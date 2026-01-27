import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

class DesignItem {
  Offset position;
  double scale;
  double rotation;
  String text;
  String fontFamily;
  Color color;
  double fontSize;
  File? imageFile;
  bool locked;
  double shadowBlur;
  Color shadowColor;
  Offset shadowOffset;

  DesignItem({
    required this.position,
    this.scale = 1.0,
    this.rotation = 0.0,
    this.text = '',
    this.fontFamily = 'Roboto',
    this.color = Colors.black,
    this.fontSize = 32,
    this.imageFile,
    this.locked = false,
    this.shadowBlur = 4,
    this.shadowColor = const Color(0x80000000),
    this.shadowOffset = const Offset(2, 2),
  });

  DesignItem copy() => DesignItem(
    position: position,
    scale: scale,
    rotation: rotation,
    text: text,
    fontFamily: fontFamily,
    color: color,
    fontSize: fontSize,
    imageFile: imageFile,
    locked: locked,
    shadowBlur: shadowBlur,
    shadowColor: shadowColor,
    shadowOffset: shadowOffset,
  );
}

void main() {
  runApp(const MaterialApp(home: DesignEditorScreen(designType: 'Poster')));
}

class DesignEditorScreen extends StatefulWidget {
  final String designType;
  const DesignEditorScreen({Key? key, required this.designType}) : super(key: key);

  @override
  State<DesignEditorScreen> createState() => _DesignEditorScreenState();
}

class _DesignEditorScreenState extends State<DesignEditorScreen> {
  List<DesignItem> _items = [];
  List<List<DesignItem>> _undoStack = [];
  List<List<DesignItem>> _redoStack = [];
  Color _backgroundColor = Colors.white;
  bool _showGrid = false;

  String? _selectedFrame;

  int? _selectedIndex;

  final GlobalKey _canvasKey = GlobalKey();

  // Available frames
  final List<String> _frames = [
    'assets/frames/frame1.png',
    'assets/frames/frame2.png',
    'assets/frames/frame3.png',
  ];

  void _saveStateForUndo() {
    _undoStack.add(_items.map((e) => e.copy()).toList());
    _redoStack.clear();
  }

  void _undo() {
    if (_undoStack.isNotEmpty) {
      _redoStack.add(_items.map((e) => e.copy()).toList());
      setState(() {
        _items = _undoStack.removeLast();
        _selectedIndex = null;
      });
    }
  }

  void _redo() {
    if (_redoStack.isNotEmpty) {
      _undoStack.add(_items.map((e) => e.copy()).toList());
      setState(() {
        _items = _redoStack.removeLast();
        _selectedIndex = null;
      });
    }
  }

  void _addTextItem() {
    _saveStateForUndo();
    setState(() {
      _items.add(DesignItem(position: const Offset(100, 100), text: 'New Text'));
      _selectedIndex = _items.length - 1;
    });
  }

  void _addShapeItem(Color color) {
    _saveStateForUndo();
    setState(() {
      _items.add(DesignItem(position: const Offset(100, 100), text: '⬛', color: color, fontSize: 60));
      _selectedIndex = _items.length - 1;
    });
  }

  Future<void> _pickImage() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.image);
    if (result != null && result.files.isNotEmpty) {
      _saveStateForUndo();
      setState(() {
        _items.add(DesignItem(position: const Offset(100, 100), imageFile: File(result.files.first.path!)));
        _selectedIndex = _items.length - 1;
      });
    }
  }

  Future<void> _pickSticker() async {
    final stickers = ['assets/stickers/star.png', 'assets/stickers/heart.png', 'assets/stickers/smile.png'];
    String? selected;
    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Pick Sticker'),
        content: Wrap(
          spacing: 8,
          children: stickers.map((s) => GestureDetector(
            onTap: () {
              selected = s;
              Navigator.pop(context);
            },
            child: Image.asset(s, width: 60),
          )).toList(),
        ),
      ),
    );
    if (selected != null) {
      final bytes = await DefaultAssetBundle.of(context).load(selected!);
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/${selected?.split('/').last}');
      await file.writeAsBytes(bytes.buffer.asUint8List());
      _saveStateForUndo();
      setState(() {
        _items.add(DesignItem(position: const Offset(100, 100), imageFile: file));
        _selectedIndex = _items.length - 1;
      });
    }
  }


  void _duplicateSelected() {
    if (_selectedIndex == null) return;
    _saveStateForUndo();
    final item = _items[_selectedIndex!];
    setState(() {
      _items.add(item.copy()..position += const Offset(20, 20));
      _selectedIndex = _items.length - 1;
    });
  }

  void _toggleLockSelected() {
    if (_selectedIndex == null) return;
    _saveStateForUndo();
    setState(() {
      _items[_selectedIndex!].locked = !_items[_selectedIndex!].locked;
    });
  }

  void _removeSelected() {
    if (_selectedIndex == null) return;
    _saveStateForUndo();
    setState(() {
      _items.removeAt(_selectedIndex!);
      _selectedIndex = null;
    });
  }

  void _bringSelectedToFront() {
    if (_selectedIndex == null) return;
    _saveStateForUndo();
    final item = _items.removeAt(_selectedIndex!);
    setState(() {
      _items.add(item);
      _selectedIndex = _items.length - 1;
    });
  }

  void _sendSelectedToBack() {
    if (_selectedIndex == null) return;
    _saveStateForUndo();
    final item = _items.removeAt(_selectedIndex!);
    setState(() {
      _items.insert(0, item);
      _selectedIndex = 0;
    });
  }

  Future<void> _editSelectedText() async {
    if (_selectedIndex == null) return;
    final item = _items[_selectedIndex!];
    if (item.imageFile != null) return; // skip images

    final controller = TextEditingController(text: item.text);
    Color pickedColor = item.color;
    double fontSize = item.fontSize;
    double shadowBlur = item.shadowBlur;
    Color shadowColor = item.shadowColor;

    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Edit Text'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: controller, decoration: const InputDecoration(labelText: 'Text')),
              const SizedBox(height: 10),
              Text('Font Size: ${fontSize.toInt()}'),
              Slider(min: 16, max: 100, value: fontSize, onChanged: (v) => setState(() => fontSize = v)),
              const SizedBox(height: 10),
              Text('Shadow Blur: ${shadowBlur.toInt()}'),
              Slider(min: 0, max: 20, value: shadowBlur, onChanged: (v) => setState(() => shadowBlur = v)),
              const SizedBox(height: 10),
              ColorPicker(pickerColor: pickedColor, onColorChanged: (c) => setState(() => pickedColor = c), showLabel: false),
              const SizedBox(height: 10),
              const Text('Shadow Color:'),
              ColorPicker(pickerColor: shadowColor, onColorChanged: (c) => setState(() => shadowColor = c), showLabel: false),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(onPressed: () {
            _saveStateForUndo();
            setState(() {
              item.text = controller.text;
              item.color = pickedColor;
              item.fontSize = fontSize;
              item.shadowBlur = shadowBlur;
              item.shadowColor = shadowColor;
            });
            Navigator.pop(context);
          }, child: const Text('OK')),
        ],
      ),
    );
  }

  Future<void> _pickBackgroundColor() async {
    Color newColor = _backgroundColor;
    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Pick Background Color'),
        content: ColorPicker(pickerColor: newColor, onColorChanged: (c) => newColor = c, showLabel: false),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(onPressed: () {
            setState(() => _backgroundColor = newColor);
            Navigator.pop(context);
          }, child: const Text('OK')),
        ],
      ),
    );
  }

  void _selectFrame(String? frame) {
    setState(() {
      _selectedFrame = frame;
    });
  }

  Future<void> _exportToImage({bool asPng = true}) async {
    try {
      RenderRepaintBoundary boundary = _canvasKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      var image = await boundary.toImage(pixelRatio: 3);
      ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      final bytes = byteData!.buffer.asUint8List();

      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/design.${asPng ? 'png' : 'jpg'}');
      await file.writeAsBytes(bytes);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Exported: ${file.path}')));
    } catch (e) {
      debugPrint('Export failed: $e');
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Export failed')));
    }
  }

  Future<void> _exportToPdf() async {
    try {
      final pdf = pw.Document();

      Uint8List? frameBytes;
      if (_selectedFrame != null) {
        final bytes = await DefaultAssetBundle.of(context).load(_selectedFrame!);
        frameBytes = bytes.buffer.asUint8List();
      }

      pdf.addPage(pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (_) {
          return pw.Stack(children: [
            pw.Container(color: PdfColor.fromInt(_backgroundColor.value)),
            if (frameBytes != null)
              pw.Positioned.fill(child: pw.Image(pw.MemoryImage(frameBytes), fit: pw.BoxFit.cover)),
            ..._items.map((item) {
              final pos = item.position;
              final scaledFontSize = item.fontSize * item.scale;
              if (item.imageFile != null) {
                final img = pw.MemoryImage(item.imageFile!.readAsBytesSync());
                return pw.Positioned(
                  left: pos.dx,
                  top: pos.dy,
                  child: pw.Transform.rotate(angle: item.rotation, child: pw.Image(img, width: 100 * item.scale, height: 100 * item.scale)),
                );
              } else {
                return pw.Positioned(
                  left: pos.dx,
                  top: pos.dy,
                  child: pw.Transform.rotate(angle: item.rotation, child: pw.Text(item.text,
                      style: pw.TextStyle(fontSize: scaledFontSize, color: PdfColor.fromInt(item.color.value)))),
                );
              }
            }),
          ]);
        },
      ));

      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/design.pdf');
      await file.writeAsBytes(await pdf.save());
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Exported: ${file.path}')));
    } catch (e) {
      debugPrint('Export failed: $e');
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Export failed')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Canva Editor: ${widget.designType}'),
        actions: [
          IconButton(icon: const Icon(Icons.undo), onPressed: _undo),
          IconButton(icon: const Icon(Icons.redo), onPressed: _redo),
          IconButton(icon: const Icon(Icons.grid_on), onPressed: () => setState(() => _showGrid = !_showGrid)),
          IconButton(icon: const Icon(Icons.format_color_fill), onPressed: _pickBackgroundColor),
          PopupMenuButton<String>(
            icon: const Icon(Icons.filter_frames),
            tooltip: 'Select Frame',
            onSelected: _selectFrame,
            itemBuilder: (_) => [
              const PopupMenuItem(child: Text('No Frame'), value: null),
              ..._frames.map((f) => PopupMenuItem(
                value: f,
                child: Row(
                  children: [
                    Image.asset(f, width: 50, height: 50, fit: BoxFit.cover),
                    const SizedBox(width: 10),
                    Text(f.split('/').last),
                  ],
                ),
              )),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Center(
              child: RepaintBoundary(
                key: _canvasKey,
                child: Container(
                  width: 400,
                  height: 600,
                  color: _backgroundColor,
                  child: Stack(
                    children: [
                      if (_showGrid) CustomPaint(painter: _GridPainter(), size: Size.infinite),
                      if (_selectedFrame != null)
                        Positioned.fill(
                          child: Opacity(
                            opacity: 0.5,
                            child: Image.asset(_selectedFrame!, fit: BoxFit.cover),
                          ),
                        ),
                      ..._items.asMap().entries.map((entry) {
                        final index = entry.key;
                        final item = entry.value;
                        final isSelected = index == _selectedIndex;
                        return Positioned(
                          left: item.position.dx,
                          top: item.position.dy,
                          child: GestureDetector(
                            onTap: () {
                              if (!item.locked) {
                                setState(() => _selectedIndex = index);
                              }
                            },
                            onLongPress: () {
                              if (!item.locked) _duplicateSelected();
                            },
                            onDoubleTap: () {
                              if (!item.locked) _toggleLockSelected();
                            },
                            onScaleUpdate: (details) {
                              if (item.locked) return;
                              _saveStateForUndo();
                              setState(() {
                                item.position += details.focalPointDelta;
                                item.scale = (item.scale * details.scale).clamp(0.3, 5.0);
                                item.rotation += details.rotation;
                              });
                            },
                            child: Opacity(
                              opacity: item.locked ? 0.6 : 1,
                              child: Container(
                                decoration: isSelected
                                    ? BoxDecoration(border: Border.all(color: Colors.blueAccent, width: 2))
                                    : null,
                                child: Transform.rotate(
                                  angle: item.rotation,
                                  child: item.imageFile != null
                                      ? Image.file(item.imageFile!, width: 100 * item.scale, height: 100 * item.scale)
                                      : Text(item.text,
                                      style: GoogleFonts.getFont(
                                        item.fontFamily,
                                        color: item.color,
                                        fontSize: item.fontSize * item.scale,
                                        shadows: [Shadow(offset: item.shadowOffset, blurRadius: item.shadowBlur, color: item.shadowColor)],
                                      )),
                                ),
                              ),
                            ),
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Container(
            color: Colors.grey[200],
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton.icon(icon: const Icon(Icons.text_fields), label: const Text('Add Text'), onPressed: _addTextItem),
                  const SizedBox(width: 10),
                  ElevatedButton.icon(icon: const Icon(Icons.image), label: const Text('Add Image'), onPressed: _pickImage),
                  const SizedBox(width: 10),
                  ElevatedButton.icon(icon: const Icon(Icons.emoji_emotions), label: const Text('Add Sticker'), onPressed: _pickSticker),
                  const SizedBox(width: 10),
                  ElevatedButton.icon(icon: const Icon(Icons.crop_square), label: const Text('Add Shape'), onPressed: () => _addShapeItem(Colors.blue)),
                  const SizedBox(width: 10),
                  ElevatedButton.icon(icon: const Icon(Icons.edit), label: const Text('Edit Selected'), onPressed: _editSelectedText),
                  const SizedBox(width: 10),
                  ElevatedButton.icon(icon: const Icon(Icons.lock), label: const Text('Lock/Unlock'), onPressed: _toggleLockSelected),
                  const SizedBox(width: 10),
                  ElevatedButton.icon(icon: const Icon(Icons.delete), label: const Text('Delete Selected'), onPressed: _removeSelected),
                  const SizedBox(width: 10),
                  ElevatedButton.icon(icon: const Icon(Icons.vertical_align_top), label: const Text('Bring Front'), onPressed: _bringSelectedToFront),
                  const SizedBox(width: 10),
                  ElevatedButton.icon(icon: const Icon(Icons.vertical_align_bottom), label: const Text('Send Back'), onPressed: _sendSelectedToBack),
                  const SizedBox(width: 10),
                  ElevatedButton.icon(icon: const Icon(Icons.save), label: const Text('Export PNG'), onPressed: () => _exportToImage(asPng: true)),
                  const SizedBox(width: 10),
                  ElevatedButton.icon(icon: const Icon(Icons.picture_as_pdf), label: const Text('Export PDF'), onPressed: _exportToPdf),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.grey.withOpacity(0.2)..strokeWidth = 0.5;
    for (double x = 0; x < size.width; x += 20) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += 20) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
