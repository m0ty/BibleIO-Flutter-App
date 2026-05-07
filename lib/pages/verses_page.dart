import 'package:flutter/material.dart';
import 'package:bible_io/bible_io.dart';

class VersesPage extends StatelessWidget {
  final Book book;
  final int chapterNum;
  final Bible bible;

  const VersesPage({super.key, required this.book, required this.chapterNum, required this.bible});

  @override
  Widget build(BuildContext context) {
    final chapter = bible[(book.bookEnum, chapterNum)];
    return Scaffold(
      appBar: AppBar(
        title: Text('${book.name} $chapterNum'),
        actions: [
          IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () {
              final bookIndex = bible.books.indexOf(book);
              Widget? nextPage;
              if (chapterNum > 1) {
                nextPage = VersesPage(book: book, chapterNum: chapterNum - 1, bible: bible);
              } else if (bookIndex > 0) {
                final prevBook = bible.books[bookIndex - 1];
                final lastChapter = prevBook.chapters.length;
                nextPage = VersesPage(book: prevBook, chapterNum: lastChapter, bible: bible);
              }
              if (nextPage != null) {
                Navigator.pushReplacement(
                  context,
                  PageRouteBuilder(
                    pageBuilder: (context, animation, secondaryAnimation) => nextPage!,
                    transitionsBuilder: (context, animation, secondaryAnimation, child) {
                      const begin = Offset(-1.0, 0.0);
                      const end = Offset.zero;
                      const curve = Curves.easeInOut;
                      var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
                      var offsetAnimation = animation.drive(tween);
                      return SlideTransition(position: offsetAnimation, child: child);
                    },
                  ),
                );
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.arrow_forward),
            onPressed: () {
              final bookIndex = bible.books.indexOf(book);
              Widget? nextPage;
              if (chapterNum < book.chapters.length) {
                nextPage = VersesPage(book: book, chapterNum: chapterNum + 1, bible: bible);
              } else if (bookIndex < bible.books.length - 1) {
                final nextBook = bible.books[bookIndex + 1];
                nextPage = VersesPage(book: nextBook, chapterNum: 1, bible: bible);
              }
              if (nextPage != null) {
                Navigator.pushReplacement(
                  context,
                  PageRouteBuilder(
                    pageBuilder: (context, animation, secondaryAnimation) => nextPage!,
                    transitionsBuilder: (context, animation, secondaryAnimation, child) {
                      const begin = Offset(1.0, 0.0);
                      const end = Offset.zero;
                      const curve = Curves.easeInOut;
                      var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
                      var offsetAnimation = animation.drive(tween);
                      return SlideTransition(position: offsetAnimation, child: child);
                    },
                  ),
                );
              }
            },
          ),
        ],
      ),
      body: ListView.builder(
        itemCount: chapter.verses.length,
        itemBuilder: (context, index) {
          final verse = chapter.verses[index];
          final verseNum = index + 1;
          return ListTile(
            title: Text('$verseNum: ${verse.text}'),
          );
        },
      ),
    );
  }
}
