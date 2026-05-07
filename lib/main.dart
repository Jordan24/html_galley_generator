import 'dart:io';
import 'package:flutter/material.dart';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_selector/file_selector.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const HtmlGalleyGeneratorApp());
}

class HtmlGalleyGeneratorApp extends StatelessWidget {
  const HtmlGalleyGeneratorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'OJS HTML Galley Generator',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF334155), // Slate-800
          surface: const Color(0xFFF7F9FB),
        ),
        textTheme: const TextTheme(
          titleLarge: TextStyle(
            fontFamily: 'Inter',
            fontWeight: FontWeight.w600,
          ),
          bodyMedium: TextStyle(fontFamily: 'Inter', fontSize: 14),
          labelSmall: TextStyle(fontFamily: 'Inter', fontSize: 12),
        ),
      ),
      home: const GeneratorScreen(),
    );
  }
}

class GeneratorScreen extends StatefulWidget {
  const GeneratorScreen({super.key});

  @override
  State<GeneratorScreen> createState() => _GeneratorScreenState();
}

class _GeneratorScreenState extends State<GeneratorScreen> {
  bool _isHovering = false;
  File? _selectedPdf;

  // Metadata Controllers
  final TextEditingController _titleCtrl = TextEditingController();
  final TextEditingController _authorCtrl = TextEditingController();
  final TextEditingController _volumeCtrl = TextEditingController();
  final TextEditingController _issueCtrl = TextEditingController();
  final TextEditingController _articleIdCtrl = TextEditingController();

  // Settings Controllers
  final TextEditingController _baseUrlCtrl = TextEditingController();
  final TextEditingController _journalPathCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadSettings();

    // Add listeners to update the preview name
    _titleCtrl.addListener(_updatePreview);
    _authorCtrl.addListener(_updatePreview);
    _volumeCtrl.addListener(_updatePreview);
    _issueCtrl.addListener(_updatePreview);
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _baseUrlCtrl.text =
          prefs.getString('baseUrl') ?? 'https://transnationalasia.rice.edu';
      _journalPathCtrl.text = prefs.getString('journalPath') ?? 'ta';
    });
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('baseUrl', _baseUrlCtrl.text);
    await prefs.setString('journalPath', _journalPathCtrl.text);
  }

  void _updatePreview() {
    setState(() {}); // Trigger rebuild to update preview text
  }

  String get _generatedFileName {
    String vol = _volumeCtrl.text.trim();
    String iss = _issueCtrl.text.trim();
    String auth = _authorCtrl.text.trim().replaceAll(' ', '+');

    String title = _titleCtrl.text.split(':').first.trim();
    title = title.replaceAll("'", "").replaceAll("’", "").replaceAll(' ', '+');

    return 'Vol+${vol}+No+${iss}_${auth}_${title}.html';
  }

  Future<void> _processFile(File file) async {
    setState(() {
      _selectedPdf = file;
    });

    try {
      final bytes = await file.readAsBytes();
      final document = PdfDocument(inputBytes: bytes);

      // Extract text to find metadata
      String extractedText = PdfTextExtractor(document).extractText();

      // 1. Title Extraction
      if (document.documentInformation.title.isNotEmpty) {
        _titleCtrl.text = document.documentInformation.title;
      }

      // 2. Author Extraction
      if (document.documentInformation.author.isNotEmpty) {
        _authorCtrl.text = document.documentInformation.author
            .split(' ')
            .last
            .toUpperCase();
      }

      // 3. DOI / Article ID / Vol / Issue extraction
      // Look for format like 10.25615/ta.v7i1.113
      final doiRegex = RegExp(r'10\.\d{4,9}/[a-zA-Z0-9.-]+v(\d+)i(\d+)\.(\d+)');
      final match = doiRegex.firstMatch(extractedText);
      if (match != null) {
        _volumeCtrl.text = match.group(1) ?? '';
        _issueCtrl.text = match.group(2) ?? '';
        _articleIdCtrl.text = match.group(3) ?? '';
      }

      document.dispose();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('PDF parsed successfully!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to parse PDF: $e')));
      }
    }
  }

  Future<void> _generateHtml() async {
    await _saveSettings();

    if (_articleIdCtrl.text.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please provide an Article ID.')),
        );
      }
      return;
    }

    // Construct the URL. Without a Galley ID, OJS might default to the primary file if formatted correctly,
    // or the journal admins use this template and manually adjust if needed.
    // We will omit the Galley ID (e.g. /195) and see if OJS serves it by article ID, or use a placeholder.
    // Based on user feedback, the Galley ID is generated post-upload, so we construct the URL up to the Article ID.
    // Actually, standard OJS syntax requires Galley ID for direct download links.
    // We will insert a placeholder "GALLEY_ID_PLACEHOLDER" if it's strictly needed, or just standard download URL.
    // Let's use the standard download/Article_ID format which OJS sometimes supports,
    // or just leave it as standard `download/${articleId}/...`

    String baseUrl = _baseUrlCtrl.text.trim();
    if (baseUrl.endsWith('/')) {
      baseUrl = baseUrl.substring(0, baseUrl.length - 1);
    }
    String path = _journalPathCtrl.text.trim();
    String articleId = _articleIdCtrl.text.trim();
    String title = _titleCtrl.text.trim();

    // The structure matching Output 1.html exactly (with generic galley id placeholder if needed)
    String htmlContent =
        '''
<!DOCTYPE html>
<html lang="en-US" xml:lang="en-US">
<head>
	<meta charset="utf-8">
	<meta name="viewport" content="width=device-width, initial-scale=1.0">
	<title>
		View of $title
							| Transnational Asia
			</title>

	
<link rel="icon" href="$baseUrl/public/journals/3/favicon_en_US.png">
<meta name="generator" content="Open Journal Systems">
	<link rel="stylesheet" href="$baseUrl/plugins/themes/healthSciences/libs/bootstrap.min.css" type="text/css" />
	<link rel="stylesheet" href="$baseUrl/index.php/$path/\$\$\$call\$\$\$/page/page/css?name=stylesheet" type="text/css" />
	<link rel="stylesheet" href="$baseUrl/plugins/generic/orcidProfile/css/orcidProfile.css" type="text/css" />
	<link rel="stylesheet" href="$baseUrl/public/journals/3/styleSheet.css" type="text/css" />
</head>
<body class="pkp_page_article pkp_op_view">

<header class="header_view">

	
	<a href="$baseUrl/index.php/$path/article/view/$articleId" class="return">
		<span class="pkp_screen_reader">
			Return to Article Details
		</span>
	</a>
			<a href="$baseUrl/index.php/$path/article/view/$articleId" class="title">
			$title
		</a>
			</header>

<div id="htmlContainer" class="galley_view" style="overflow:visible;-webkit-overflow-scrolling:touch">
	<iframe id="htmlGalleyFrame" name="htmlFrame" src="			$baseUrl/index.php/$path/article/download/$articleId/GALLEY_ID?inline=1
		" allowfullscreen webkitallowfullscreen></iframe>
</div>

</body>
</html>
''';

    final saveLocation = await getSaveLocation(
      suggestedName: _generatedFileName,
    );
    if (saveLocation != null) {
      final file = File(saveLocation.path);
      await file.writeAsString(htmlContent);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('HTML Galley generated successfully!')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FB),
      appBar: AppBar(
        title: const Text(
          'OJS HTML Galley Generator',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        backgroundColor: Colors.white,
        scrolledUnderElevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drop Zone
            DropTarget(
              onDragEntered: (details) => setState(() => _isHovering = true),
              onDragExited: (details) => setState(() => _isHovering = false),
              onDragDone: (details) async {
                setState(() => _isHovering = false);
                if (details.files.isNotEmpty) {
                  final file = File(details.files.first.path);
                  if (file.path.toLowerCase().endsWith('.pdf')) {
                    await _processFile(file);
                  }
                }
              },
              child: Container(
                width: double.infinity,
                height: 160,
                decoration: BoxDecoration(
                  color: _isHovering ? const Color(0xFFF2F4F6) : Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: _isHovering
                        ? const Color(0xFF334155)
                        : const Color(0xFFCBD5E1),
                    width: 2,
                    style: BorderStyle
                        .solid, // Using solid, visually simulate dashed via custom painter if needed
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.02),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.upload_file,
                      size: 48,
                      color: Colors.blueGrey[400],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _selectedPdf != null
                          ? 'Loaded: ${_selectedPdf!.path.split(Platform.pathSeparator).last}'
                          : 'Drag and drop PDF to start',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.blueGrey[700],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),

            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Article Metadata Form
                Expanded(
                  flex: 3,
                  child: Card(
                    color: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                      side: const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Article Metadata',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 24),
                          _buildTextField('Title', _titleCtrl),
                          _buildTextField(
                            'Author(s) (e.g., COLLINS)',
                            _authorCtrl,
                          ),
                          Row(
                            children: [
                              Expanded(
                                child: _buildTextField('Volume', _volumeCtrl),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: _buildTextField('Issue', _issueCtrl),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: _buildTextField(
                                  'Article ID',
                                  _articleIdCtrl,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 24),
                // Journal Settings Form
                Expanded(
                  flex: 2,
                  child: Card(
                    color: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                      side: const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Journal Settings',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 24),
                          _buildTextField('Journal Base URL', _baseUrlCtrl),
                          _buildTextField(
                            'Journal Path (e.g., ta)',
                            _journalPathCtrl,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),

            // Preview and Submit
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Output Filename Preview',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _generatedFileName,
                          style: const TextStyle(
                            fontSize: 16,
                            fontFamily: 'monospace',
                            color: Color(0xFF334155),
                          ),
                        ),
                      ],
                    ),
                  ),
                  ElevatedButton(
                    onPressed: _generateHtml,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1D2B3E), // Primary Dark
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 32,
                        vertical: 20,
                      ),
                      textStyle: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text('Generate HTML Galley'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(String label, TextEditingController controller) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Color(0xFF475569),
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: controller,
            decoration: InputDecoration(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 16,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(4),
                borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(4),
                borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(4),
                borderSide: const BorderSide(
                  color: Color(0xFF334155),
                  width: 2,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
