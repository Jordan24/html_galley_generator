import 'dart:io';
import 'package:syncfusion_flutter_pdf/pdf.dart';

void main() {
  final file = File('/Users/jordan/Code/Projects/html_galleys/CHONG+Kyle_Transnational+Asia_V7I1_Teaching+American+Born+Chinese.pdf');
  final bytes = file.readAsBytesSync();
  final document = PdfDocument(inputBytes: bytes);
  final extractor = PdfTextExtractor(document);
  final lines = extractor.extractTextLines();
  
  for (int i = 0; i < lines.length; i++) {
    final line = lines[i];
    final text = line.text.trim();
    if (text.toLowerCase().contains('figure') || text.toLowerCase().contains('fig') || text.toLowerCase().contains('image') || text.toLowerCase().contains('picture')) {
      print('Line $i: $text');
    }
  }
}
