import 'dart:io';
import 'dart:typed_data';
import 'package:archive/archive.dart';

/// Helper to create a temporary mock .docx file for testing.
File createMockDocxFile({
  required String title,
  required String author,
  required String affiliation,
  required String abstractText,
  required String keywords,
  required String bodyText,
  String? bio,
  List<Map<String, String>> images = const [],
}) {
  final archive = Archive();

  // Create minimal word/document.xml
  final documentXml = StringBuffer();
  documentXml.write('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>');
  documentXml.write('<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main" ');
  documentXml.write('            xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">');
  documentXml.write('<w:body>');
  
  // Title
  documentXml.write('<w:p><w:r><w:t>$title</w:t></w:r></w:p>');
  
  // Author
  documentXml.write('<w:p><w:r><w:t>$author</w:t></w:r></w:p>');
  
  // Affiliation
  documentXml.write('<w:p><w:r><w:t>$affiliation</w:t></w:r></w:p>');

  // Bio
  if (bio != null) {
    documentXml.write('<w:p><w:r><w:t>$bio</w:t></w:r></w:p>');
  }
  
  // Abstract
  documentXml.write('<w:p><w:r><w:t>Abstract</w:t></w:r></w:p>');
  documentXml.write('<w:p><w:r><w:t>$abstractText</w:t></w:r></w:p>');
  
  // Keywords
  documentXml.write('<w:p><w:r><w:t>Keywords</w:t></w:r></w:p>');
  documentXml.write('<w:p><w:r><w:t>$keywords</w:t></w:r></w:p>');
  
  // Body text with indentation properties
  documentXml.write('<w:p>');
  documentXml.write('  <w:pPr>');
  documentXml.write('    <w:ind w:left="720"/>');
  documentXml.write('  </w:pPr>');
  documentXml.write('  <w:r>');
  documentXml.write('    <w:t>$bodyText</w:t>');
  documentXml.write('  </w:r>');
  documentXml.write('</w:p>');

  // Add dummy images if requested
  for (int i = 0; i < images.length; i++) {
    final img = images[i];
    documentXml.write('<w:p><w:r><w:drawing>');
    documentXml.write('  <w:cNvPr descr="${img['alt'] ?? ''}"/>');
    documentXml.write('  <w:blip r:embed="rIdImages${i + 1}"/>');
    documentXml.write('</w:drawing></w:r></w:p>');
    
    // Write image bytes to media folder
    final imgBytes = Uint8List(10);
    archive.addFile(ArchiveFile('word/media/image${i + 1}.png', imgBytes.length, imgBytes));
  }

  // Footnote markers/refs in document
  documentXml.write('<w:p><w:r><w:t>This is body text with footnote</w:t></w:r>');
  documentXml.write('<w:r><w:footnoteReference w:id="1"/></w:r></w:p>');

  documentXml.write('</w:body>');
  documentXml.write('</w:document>');

  archive.addFile(ArchiveFile('word/document.xml', documentXml.length, Uint8List.fromList(documentXml.toString().codeUnits)));

  // Footnotes definition
  final footnotesXml = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<w:footnotes xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
  <w:footnote w:id="1">
    <w:p>
      <w:r>
        <w:t>Footnote content</w:t>
      </w:r>
    </w:p>
  </w:footnote>
</w:footnotes>''';

  archive.addFile(ArchiveFile('word/footnotes.xml', footnotesXml.length, Uint8List.fromList(footnotesXml.codeUnits)));

  // Rels for images
  final relsXml = StringBuffer();
  relsXml.write('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>');
  relsXml.write('<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">');
  for (int i = 0; i < images.length; i++) {
    relsXml.write('  <Relationship Id="rIdImages${i + 1}" ');
    relsXml.write('              Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/image" ');
    relsXml.write('              Target="media/image${i + 1}.png"/>');
  }
  relsXml.write('</Relationships>');

  archive.addFile(ArchiveFile('word/_rels/document.xml.rels', relsXml.length, Uint8List.fromList(relsXml.toString().codeUnits)));

  // Volume/Issue in headers/footers
  final headerXml = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<w:hdr xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
  <w:p>
    <w:r>
      <w:t>Volume 8, Issue 1, doi.org/v8i1.101</w:t>
    </w:r>
  </w:p>
</w:hdr>''';
  archive.addFile(ArchiveFile('word/header1.xml', headerXml.length, Uint8List.fromList(headerXml.codeUnits)));

  final docxBytes = ZipEncoder().encode(archive);
  final tempFile = File('${Directory.systemTemp.path}/test_docx_${DateTime.now().millisecondsSinceEpoch}.docx');
  tempFile.writeAsBytesSync(docxBytes);
  return tempFile;
}
