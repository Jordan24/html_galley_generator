import 'package:vsc_quill_delta_to_html/vsc_quill_delta_to_html.dart';

void main() {
  final deltaJson = [
    {"insert": "Para 1"},
    {"insert": "\n"},
    {"insert": "Para 2"},
    {"insert": "\n"}
  ];
  
  // 1. With forEmail()
  final c1 = QuillDeltaToHtmlConverter(List<Map<String, dynamic>>.from(deltaJson), ConverterOptions.forEmail());
  print('forEmail():');
  print(c1.convert());

  // 2. Default options
  final c2 = QuillDeltaToHtmlConverter(List<Map<String, dynamic>>.from(deltaJson));
  print('Default:');
  print(c2.convert());
}
