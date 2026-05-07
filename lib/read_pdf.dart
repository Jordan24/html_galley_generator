import 'dart:io';
import 'package:syncfusion_flutter_pdf/pdf.dart';

void main() async {
  final bytes = await File('/Users/jordan/Code/Projects/html_galleys/COLLINS+Lauren_Transnational+Asia_V7I1_Archives+as+Bridges_v2.pdf').readAsBytes();
  final doc = PdfDocument(inputBytes: bytes);
  final text = PdfTextExtractor(doc).extractText();
  print(text.substring(0, 3000));
}
