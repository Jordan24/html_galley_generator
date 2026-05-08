import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

void main() {
  test('Verify PDF filename generation', () async {
    final file = File(
      '../COLLINS+Lauren_Transnational+Asia_V7I1_Archives+as+Bridges_v2.pdf',
    );
    final bytes = await file.readAsBytes();
    final document = PdfDocument(inputBytes: bytes);

    String title = '';
    String author = '';
    String vol = '';
    String iss = '';

    if (document.documentInformation.title.isNotEmpty) {
      title = document.documentInformation.title;
    }
    if (document.documentInformation.author.isNotEmpty) {
      author = document.documentInformation.author
          .split(' ')
          .last
          .toUpperCase();
    }

    String extractedText = PdfTextExtractor(document).extractText();

    final doiRegex = RegExp(r'10\.\d{4,9}/[a-zA-Z0-9.-]+v(\d+)i(\d+)\.(\d+)');
    final match = doiRegex.firstMatch(extractedText);
    if (match != null) {
      vol = match.group(1) ?? '';
      iss = match.group(2) ?? '';
    }

    expect(vol, '7');
    expect(iss, '1');

    String authSafe = author.replaceAll(' ', '+');
    String titleSafe = title.replaceAll(' ', '+');
    String generatedFileName = 'Vol+$vol+No+${iss}_${authSafe}_$titleSafe.html';

    expect(generatedFileName, contains('Vol+7+No+1'));
    expect(generatedFileName, contains('$titleSafe.html'));

    document.dispose();
  });
}
