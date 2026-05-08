import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

void main() {
  test('PDF character extraction and encoding validation', () async {
    final bytes = await File('../COLLINS+Lauren_Transnational+Asia_V7I1_Archives+as+Bridges_v2.pdf').readAsBytes();
    final document = PdfDocument(inputBytes: bytes);
    final extractor = PdfTextExtractor(document);
    final lines = extractor.extractTextLines();
    
    bool foundTarget = false;
    for (int i = 0; i < 30 && i < lines.length; i++) {
      final text = lines[i].text;
      // Target the specific title line which contains both 'Asia' and 'Histories'
      if (text.contains('Asia') && text.contains('Histories')) {
        foundTarget = true;
        
        // Use expect to validate the text instead of printing it.
        // We expect the title to contain the correct smart quote '’' (U+2019)
        expect(text, contains('Asia’s Histories'));
        
        // Validate specific character code for the smart quote
        final apostropheIndex = text.indexOf('’');
        if (apostropheIndex != -1) {
          expect(text.codeUnitAt(apostropheIndex), 0x2019);
        }
      }
    }
    
    expect(foundTarget, isTrue, reason: 'Target text "Asia...Histories" not found in first 30 lines');
  });
}
