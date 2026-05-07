import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

void main() {
  test('Read PDF Lines', () async {
    final bytes = await File('/Users/jordan/Code/Projects/html_galleys/COLLINS+Lauren_Transnational+Asia_V7I1_Archives+as+Bridges_v2.pdf').readAsBytes();
    final doc = PdfDocument(inputBytes: bytes);
    final extractor = PdfTextExtractor(doc);
    final lines = extractor.extractTextLines();
    
    for (int i = 0; i < 50; i++) {
      if (i < lines.length) {
        final line = lines[i];
        print('Text: "${line.text}", Font: ${line.fontName}, Size: ${line.fontSize}');
      }
    }
  });
}
