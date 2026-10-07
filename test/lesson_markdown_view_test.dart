// I13 (achado da foto 51): aspas e `&` no texto da lição saíam como
// entidades HTML (`&quot;`) porque o `Document` vinha com `encodeHtml`.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zywny_course_format/course_files.dart';
import 'package:zywny/course/ui/markdown_view.dart';

void main() {
  testWidgets('aspas e & saem literais, sem entidades', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MarkdownView(
            text: 'A "Ode à Alegria" de Beethoven & amigos.\n',
            files: MemoryCourseFiles(const {}),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(
      find.textContaining('"Ode à Alegria"', findRichText: true),
      findsWidgets,
    );
    expect(find.textContaining('&quot;', findRichText: true), findsNothing);
    expect(find.textContaining('&amp;', findRichText: true), findsNothing);
  });
}
