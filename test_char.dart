import 'dart:io';
import 'package:syncfusion_flutter_pdf/pdf.dart';

void main() async {
  final bytes = await File('../COLLINS+Lauren_Transnational+Asia_V7I1_Archives+as+Bridges_v2.pdf').readAsBytes();
  final document = PdfDocument(inputBytes: bytes);
  final extractor = PdfTextExtractor(document);
  final lines = extractor.extractTextLines();
  
  for (int i = 0; i < 30; i++) {
    final text = lines[i].text;
    if (text.contains('Asia') || text.contains('Histories')) {
      print('Line: $text');
      for (int j = 0; j < text.length; j++) {
        print('${text[j]} : ${text.codeUnitAt(j).toRadixString(16)}');
      }
    }
  }
}
