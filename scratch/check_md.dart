import 'dart:io';
import 'package:docx_to_markdown/docx_to_markdown.dart';

void main() async {
  final bytes = await File('/Users/jordan/Code/Projects/html_galleys/Collins_Styled.docx').readAsBytes();
  final converter = DocxConverter(bytes);
  String markdown = await converter.convert();
  print(markdown.substring(0, 3000));
}
