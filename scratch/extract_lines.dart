import 'dart:io';
import 'package:syncfusion_flutter_pdf/pdf.dart';

void main() {
  for (final filename in [
    'CHONG+Kyle_Transnational+Asia_V7I1_Teaching+American+Born+Chinese.pdf',
    'COLLINS+Lauren_Transnational+Asia_V7I1_Archives+as+Bridges_v2.pdf'
  ]) {
    final file = File('/Users/jordan/Code/Projects/html_galleys/$filename');
    if (!file.existsSync()) {
      print('File not found: $filename');
      continue;
    }
    print('=== $filename ===');
    final bytes = file.readAsBytesSync();
    final document = PdfDocument(inputBytes: bytes);
    final extractor = PdfTextExtractor(document);
    final lines = extractor.extractTextLines();
    
    bool foundKeywords = false;
    int countAfter = 0;
    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];
      final text = line.text.trim();
      final lowerText = text.toLowerCase();
      if (lowerText.contains('keywords')) {
        foundKeywords = true;
        countAfter = 0;
      }
      if (foundKeywords) {
        print('Line $i (FontSize: ${line.fontSize}): "$text"');
        countAfter++;
        if (countAfter > 8) {
          foundKeywords = false;
        }
      }
    }
    document.dispose();
  }
}
