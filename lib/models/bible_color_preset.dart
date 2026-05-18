import 'dart:ui';

class BibleColorPreset {
  const BibleColorPreset({
    required this.id,
    required this.name,
    required this.backgroundColor,
    required this.textColor,
    this.isBuiltIn = false,
  });

  final String id;
  final String name;
  final Color backgroundColor;
  final Color textColor;
  final bool isBuiltIn;

  Color get verseNumberColor {
    final luminance = backgroundColor.computeLuminance();
    return luminance > 0.5 ? const Color(0xFF1D4ED8) : const Color(0xFF7DD3FC);
  }

  Brightness get brightness {
    return backgroundColor.computeLuminance() > 0.5
        ? Brightness.light
        : Brightness.dark;
  }

  BibleColorPreset copyWith({
    String? id,
    String? name,
    Color? backgroundColor,
    Color? textColor,
    bool? isBuiltIn,
  }) {
    return BibleColorPreset(
      id: id ?? this.id,
      name: name ?? this.name,
      backgroundColor: backgroundColor ?? this.backgroundColor,
      textColor: textColor ?? this.textColor,
      isBuiltIn: isBuiltIn ?? this.isBuiltIn,
    );
  }

  Map<String, Object?> toJson() {
    return {
      'id': id,
      'name': name,
      'backgroundColor': backgroundColor.toARGB32(),
      'textColor': textColor.toARGB32(),
    };
  }

  factory BibleColorPreset.fromJson(Map<String, Object?> json) {
    return BibleColorPreset(
      id: json['id'] as String,
      name: json['name'] as String,
      backgroundColor: Color(json['backgroundColor'] as int),
      textColor: Color(json['textColor'] as int),
    );
  }
}

const List<BibleColorPreset> builtInBibleColorPresets = [
  BibleColorPreset(
    id: 'light',
    name: 'Light',
    backgroundColor: Color(0xFFFFFFFF),
    textColor: Color(0xFF1F2937),
    isBuiltIn: true,
  ),
  BibleColorPreset(
    id: 'dark',
    name: 'Dark',
    backgroundColor: Color(0xFF1E1E1E),
    textColor: Color(0xFFD4D4D4),
    isBuiltIn: true,
  ),
  BibleColorPreset(
    id: 'monokai',
    name: 'Monokai',
    backgroundColor: Color(0xFF272822),
    textColor: Color(0xFFF8F8F2),
    isBuiltIn: true,
  ),
  BibleColorPreset(
    id: 'solarized_dark',
    name: 'Solarized Dark',
    backgroundColor: Color(0xFF002B36),
    textColor: Color(0xFF839496),
    isBuiltIn: true,
  ),
  BibleColorPreset(
    id: 'solarized_light',
    name: 'Solarized Light',
    backgroundColor: Color(0xFFFDF6E3),
    textColor: Color(0xFF657B83),
    isBuiltIn: true,
  ),
  BibleColorPreset(
    id: 'high_contrast',
    name: 'High Contrast',
    backgroundColor: Color(0xFF000000),
    textColor: Color(0xFFFFFFFF),
    isBuiltIn: true,
  ),
  BibleColorPreset(
    id: 'sepia',
    name: 'Sepia',
    backgroundColor: Color(0xFFF4ECD8),
    textColor: Color(0xFF3D2B1F),
    isBuiltIn: true,
  ),
];
