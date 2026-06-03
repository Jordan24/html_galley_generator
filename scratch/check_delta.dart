import 'package:flutter_quill_delta_from_html/flutter_quill_delta_from_html.dart';

void main() {
  final html = '''
<p><em>Special thanks to CU Boulder Library Instructor Sean Babbs, <strong>Map Curator</strong> Naomi Heiser<strong>, Map Library Program Manager</strong> Ilene Raynes, the CU Boulder Center for Humanities, and CU Boulder Center for Teaching and Learning, whose collaboration, identification of relevant materials, and partnership co-created this project and the student learning experiences described here.</em></p>
<p>Following the profound impact of Edward Said’s <em>Orientalism</em> (Said 1979), much discussion has taken place on the pedagogy of Asian Studies. As the discipline tries to look at itself, examining the military and political urgency that culminated in the rapid growth of Asian Studies in the US post-WWII (Ludden 2000; Szanton 2004)</p>
''';
  final delta = HtmlToDelta().convert(html);
  print(delta.toString());
}
