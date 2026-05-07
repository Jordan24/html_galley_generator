import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

void main() {
  test('Extract title characters', () async {
    final bytes = await File('../COLLINS+Lauren_Transnational+Asia_V7I1_Archives+as+Bridges_v2.pdf').readAsBytes();
    final document = PdfDocument(inputBytes: bytes);
    
    final infoTitle = document.documentInformation.title ?? '';
    final buffer = StringBuffer();
    buffer.writeln('TITLE: $infoTitle');
    for (int j = 0; j < infoTitle.length; j++) {
      buffer.writeln('CHAR: ${infoTitle[j]} -> \\u${infoTitle.codeUnitAt(j).toRadixString(16).padLeft(4, '0')}');
    }
    await File('output.txt').writeAsString(buffer.toString());
  });
}
