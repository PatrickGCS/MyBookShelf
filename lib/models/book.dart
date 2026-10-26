import 'package:flutter/material.dart';

// --- CLASSE NOVA: CITAÇÃO ---
class Quote {
  final int? id;
  final int bookId;
  final String text;
  final int page;

  Quote({this.id, required this.bookId, required this.text, required this.page});

  Map<String, dynamic> toMap() => {
    'id': id, 'bookId': bookId, 'text': text, 'page': page
  };

  factory Quote.fromMap(Map<String, dynamic> map) => Quote(
    id: map['id'], bookId: map['bookId'], text: map['text'], page: map['page']
  );
}

class ReadingSession {
  final int? id;
  final int bookId;
  final DateTime date;
  final int pageStopped;

  ReadingSession({this.id, required this.bookId, required this.date, required this.pageStopped});

  Map<String, dynamic> toMap() => {
    'id': id, 'bookId': bookId, 'date': date.toIso8601String(), 'pageStopped': pageStopped
  };

  factory ReadingSession.fromMap(Map<String, dynamic> map) => ReadingSession(
    id: map['id'], bookId: map['bookId'], date: DateTime.parse(map['date']), pageStopped: map['pageStopped']
  );
}

class Book {
  final int? id;
  final String title;
  final String author;
  final String publisher;
  final String genre;
  final int pageCount;
  final int currentPage;
  final double price;
  final bool isRead;
  final DateTime dateAcquired;
  final DateTime? startDate;
  final DateTime? targetDate;
  final String? imagePath;
  final double rating;
  final String? review;
  final bool isPaused;
  final DateTime? lastPauseDate;
  
  // --- NOVO CAMPO: CAMINHO DO EBOOK ---
  final String? ebookPath; 

  Book({
    this.id, required this.title, required this.author, required this.publisher, required this.genre,
    required this.pageCount, this.currentPage = 0, required this.price, required this.isRead,
    required this.dateAcquired, this.startDate, this.targetDate,
    this.imagePath, this.rating = 0.0, this.review,
    this.isPaused = false, this.lastPauseDate,
    this.ebookPath, // Construtor atualizado
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id, 'title': title, 'author': author, 'publisher': publisher, 'genre': genre,
      'pageCount': pageCount, 'currentPage': currentPage, 'price': price, 'isRead': isRead ? 1 : 0,
      'dateAcquired': dateAcquired.toIso8601String(),
      'startDate': startDate?.toIso8601String(),
      'targetDate': targetDate?.toIso8601String(),
      'imagePath': imagePath, 'rating': rating, 'review': review,
      'isPaused': isPaused ? 1 : 0,
      'lastPauseDate': lastPauseDate?.toIso8601String(),
      'ebookPath': ebookPath, // Salva no banco
    };
  }

  factory Book.fromMap(Map<String, dynamic> map) {
    return Book(
      id: map['id'], title: map['title'], author: map['author'], publisher: map['publisher'] ?? '', genre: map['genre'],
      pageCount: map['pageCount'], currentPage: map['currentPage'] ?? 0, price: map['price'], isRead: map['isRead'] == 1,
      dateAcquired: map['dateAcquired'] != null ? DateTime.parse(map['dateAcquired']) : DateTime.now(),
      startDate: map['startDate'] != null ? DateTime.parse(map['startDate']) : null,
      targetDate: map['targetDate'] != null ? DateTime.parse(map['targetDate']) : null,
      imagePath: map['imagePath'], rating: map['rating'] ?? 0.0, review: map['review'],
      isPaused: (map['isPaused'] ?? 0) == 1,
      lastPauseDate: map['lastPauseDate'] != null ? DateTime.parse(map['lastPauseDate']) : null,
      ebookPath: map['ebookPath'], // Lê do banco
    );
  }

  /// Cria uma cópia alterando apenas os campos informados.
  /// Use os parâmetros `clear*` para anular campos opcionais.
  Book copyWith({
    int? id, String? title, String? author, String? publisher, String? genre,
    int? pageCount, int? currentPage, double? price, bool? isRead,
    DateTime? dateAcquired, DateTime? startDate, DateTime? targetDate,
    String? imagePath, double? rating, String? review,
    bool? isPaused, DateTime? lastPauseDate, String? ebookPath,
    bool clearTargetDate = false, bool clearLastPauseDate = false,
    bool clearImagePath = false, bool clearEbookPath = false,
  }) {
    return Book(
      id: id ?? this.id,
      title: title ?? this.title,
      author: author ?? this.author,
      publisher: publisher ?? this.publisher,
      genre: genre ?? this.genre,
      pageCount: pageCount ?? this.pageCount,
      currentPage: currentPage ?? this.currentPage,
      price: price ?? this.price,
      isRead: isRead ?? this.isRead,
      dateAcquired: dateAcquired ?? this.dateAcquired,
      startDate: startDate ?? this.startDate,
      targetDate: clearTargetDate ? null : (targetDate ?? this.targetDate),
      imagePath: clearImagePath ? null : (imagePath ?? this.imagePath),
      rating: rating ?? this.rating,
      review: review ?? this.review,
      isPaused: isPaused ?? this.isPaused,
      lastPauseDate: clearLastPauseDate ? null : (lastPauseDate ?? this.lastPauseDate),
      ebookPath: clearEbookPath ? null : (ebookPath ?? this.ebookPath),
    );
  }

  double get progress => pageCount == 0 ? 0 : currentPage / pageCount;

  /// Dias restantes até a meta, comparando apenas datas (sem horário).
  /// Retorna 0 no próprio dia da meta e valor negativo se já passou.
  int daysLeft({DateTime? now}) {
    final today = DateUtils.dateOnly(now ?? DateTime.now());
    return DateUtils.dateOnly(targetDate!).difference(today).inDays;
  }

  /// Páginas por dia necessárias para cumprir a meta (conta o dia da meta).
  int requiredPace({DateTime? now}) {
    final pagesLeft = pageCount - currentPage;
    return (pagesLeft / (daysLeft(now: now) + 1)).ceil();
  }

  bool isOverdue({DateTime? now}) =>
      !isRead && !isPaused && startDate != null && targetDate != null && daysLeft(now: now) < 0;

  Color getUrgencyColor({DateTime? now}) {
    if (isRead) return Colors.green;
    if (isPaused) return Colors.grey;
    if (targetDate == null || startDate == null) return Colors.blue;
    if (isOverdue(now: now)) return Colors.red;

    final pace = requiredPace(now: now);
    if (pace > 100) return Colors.red;
    if (pace > 30) return Colors.orange;
    return Colors.green;
  }

  String getUrgencyText({DateTime? now}) {
    if (isRead) return "Concluído";
    if (isPaused) return "Pausado";
    if (startDate == null) return "Não iniciado";
    if (targetDate == null) return "Sem meta";
    if (isOverdue(now: now)) return "Atrasado!";
    return "${requiredPace(now: now)} pág/dia";
  }
}
