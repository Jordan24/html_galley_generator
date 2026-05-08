import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

void main() {
  test('Read PDF Lines', () async {
    final bytes = await File('/Users/jordan/Code/Projects/html_galleys/COLLINS+Lauren_Transnational+Asia_V7I1_Archives+as+Bridges_v2.pdf').readAsBytes();
    final doc = PdfDocument(inputBytes: bytes);
    final extractor = PdfTextExtractor(doc);
    final lines = extractor.extractTextLines();
    
    expect(lines, isNotEmpty);
    
    // Check for a specific line to ensure extraction is working correctly
    bool foundTitle = lines.any((l) => l.text.contains('Archives as Bridges'));
    expect(foundTitle, isTrue, reason: 'Should have found the article title in extracted lines');
    
    // Verify some properties of the lines
    for (int i = 0; i < 5 && i < lines.length; i++) {
      expect(lines[i].text, isNotEmpty);
      expect(lines[i].fontSize, greaterThan(0));
    }
  });
}

