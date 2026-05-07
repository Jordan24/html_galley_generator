import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

void main() {
  test('Search PDF', () async {
    final bytes = await File('/Users/jordan/Code/Projects/html_galleys/COLLINS+Lauren_Transnational+Asia_V7I1_Archives+as+Bridges_v2.pdf').readAsBytes();
    final doc = PdfDocument(inputBytes: bytes);
    final text = PdfTextExtractor(doc).extractText();
    print(text.contains('University of Colorado Boulder'));
    print(text.contains('0000-0002-2168-3352'));
    
    // print last 1000 characters
    print(text.substring(text.length - 1000));
  });
}
