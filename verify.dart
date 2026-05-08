import 'dart:io';
import 'package:syncfusion_flutter_pdf/pdf.dart';

void main() async {
  final file = File('../Input 1.pdf');
  final bytes = await file.readAsBytes();
  final document = PdfDocument(inputBytes: bytes);
  
  String title = '';
  String author = '';
  String vol = '';
  String iss = '';
  String articleId = '';

  if (document.documentInformation.title.isNotEmpty) {
    title = document.documentInformation.title;
  }
  if (document.documentInformation.author.isNotEmpty) {
    author = document.documentInformation.author.split(' ').last.toUpperCase();
  }

  String extractedText = PdfTextExtractor(document).extractText();
  
  final doiRegex = RegExp(r'10\.\d{4,9}/[a-zA-Z0-9.-]+v(\d+)i(\d+)\.(\d+)');
  final match = doiRegex.firstMatch(extractedText);
  if (match != null) {
    vol = match.group(1) ?? '';
    iss = match.group(2) ?? '';
    articleId = match.group(3) ?? '';
  }

  print('Title: $title');
  print('Author: $author');
  print('Volume: $vol');
  print('Issue: $iss');
  print('Article ID: $articleId');

  String authSafe = author.replaceAll(' ', '+');
  String titleSafe = title.replaceAll(' ', '+');
  String generatedFileName = 'Vol+$vol+No+${iss}_${authSafe}_$titleSafe.html';
  print('Filename: $generatedFileName');

  document.dispose();
}
