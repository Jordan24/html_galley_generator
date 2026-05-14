import 'dart:io';
import 'package:syncfusion_flutter_pdf/pdf.dart';

void main() {
  final file = File('/Users/jordan/Code/Projects/html_galleys/CHONG+Kyle_Transnational+Asia_V7I1_Teaching+American+Born+Chinese.pdf');
  final bytes = file.readAsBytesSync();
  final document = PdfDocument(inputBytes: bytes);
  for (int i = 0; i < document.pages.count; i++) {
    try {
      final images = document.pages[i].extractImages();
      print('Page $i has ${images.length} images.');
    } catch (e) {
      print('Page $i: error $e');
    }
  }
}
