import 'package:flutter_quill_delta_from_html/flutter_quill_delta_from_html.dart';

void main() {
  final html1 = '<p>Para 1</p><p>Para 2</p>';
  final html2 = '<p>Para 1</p>\n<p>Para 2</p>';
  final html3 = '<p>Para 1</p>\n\n<p>Para 2</p>';
  final html4 = '<p>Para 1</p><br><p>Para 2</p>';
  
  print('html1 (no whitespace):');
  print(HtmlToDelta().convert(html1).toString());
  
  print('html2 (single newline):');
  print(HtmlToDelta().convert(html2).toString());
  
  print('html3 (double newline):');
  print(HtmlToDelta().convert(html3).toString());

  print('html4 (with br):');
  print(HtmlToDelta().convert(html4).toString());
}
