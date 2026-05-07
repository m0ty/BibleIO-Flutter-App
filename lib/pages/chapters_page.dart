import 'package:flutter/material.dart';
import 'package:bible_io/bible_io.dart';
import 'verses_page.dart';

class ChaptersPage extends StatelessWidget {
  final Book book;
  final Bible bible;

  const ChaptersPage({super.key, required this.book, required this.bible});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(book.name)),
      body: GridView.builder(
        padding: const EdgeInsets.all(8.0),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 5,
          crossAxisSpacing: 8.0,
          mainAxisSpacing: 8.0,
        ),
        itemCount: book.chapters.length,
        itemBuilder: (context, index) {
          final chapterNum = index + 1;
          return InkWell(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => VersesPage(book: book, chapterNum: chapterNum, bible: bible),
                ),
              );
            },
            child: Container(
              alignment: Alignment.center,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.blue),
                borderRadius: BorderRadius.circular(8.0),
              ),
              child: Text('$chapterNum'),
            ),
          );
        },
      ),
    );
  }
}
