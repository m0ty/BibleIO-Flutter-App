import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// A color picker with hex input, HSV controls, and quick color choices.
class ColorPickerDialog extends StatefulWidget {
  const ColorPickerDialog({
    super.key,
    required this.title,
    required this.initialColor,
  });

  final String title;
  final Color initialColor;

  @override
  State<ColorPickerDialog> createState() => _ColorPickerDialogState();
}

class _ColorPickerDialogState extends State<ColorPickerDialog> {
  late HSVColor _hsvColor;
  late TextEditingController _hexController;

  static const _quickColors = [
    Color(0xFFFFFFFF),
    Color(0xFFFDF6E3),
    Color(0xFFF4ECD8),
    Color(0xFF1E1E1E),
    Color(0xFF272822),
    Color(0xFF282A36),
    Color(0xFF002B36),
    Color(0xFF000000),
    Color(0xFFD4D4D4),
    Color(0xFFF8F8F2),
    Color(0xFF839496),
    Color(0xFF1F2937),
  ];

  @override
  void initState() {
    super.initState();
    _hsvColor = HSVColor.fromColor(widget.initialColor);
    _hexController = TextEditingController(
      text: formatColorHex(_hsvColor.toColor()),
    );
  }

  @override
  void dispose() {
    _hexController.dispose();
    super.dispose();
  }

  void _setColor(Color color) {
    setState(() {
      _hsvColor = HSVColor.fromColor(color);
      _hexController.text = formatColorHex(color);
      _hexController.selection = TextSelection.collapsed(
        offset: _hexController.text.length,
      );
    });
  }

  void _setHsvColor(HSVColor color) {
    setState(() {
      _hsvColor = color;
      _hexController.text = formatColorHex(color.toColor());
      _hexController.selection = TextSelection.collapsed(
        offset: _hexController.text.length,
      );
    });
  }

  void _updateFromHex(String value) {
    final color = _tryParseColor(value);
    if (color == null) {
      return;
    }
    setState(() {
      _hsvColor = HSVColor.fromColor(color);
    });
  }

  @override
  Widget build(BuildContext context) {
    final color = _hsvColor.toColor();
    return AlertDialog(
      title: Text('${widget.title} Color'),
      content: SizedBox(
        width: 360,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  ColorPreviewSwatch(color: color),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _hexController,
                      decoration: const InputDecoration(
                        labelText: 'Hex',
                        border: OutlineInputBorder(),
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                          RegExp(r'[#0-9a-fA-F]'),
                        ),
                        LengthLimitingTextInputFormatter(7),
                      ],
                      onChanged: _updateFromHex,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 190,
                child: _SaturationValuePicker(
                  color: _hsvColor,
                  onChanged: _setHsvColor,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  const SizedBox(width: 36, child: Text('Hue')),
                  Expanded(
                    child: Slider(
                      value: _hsvColor.hue,
                      min: 0,
                      max: 360,
                      activeColor: HSVColor.fromAHSV(
                        1,
                        _hsvColor.hue,
                        1,
                        1,
                      ).toColor(),
                      label: _hsvColor.hue.round().toString(),
                      onChanged: (hue) {
                        _setHsvColor(_hsvColor.withHue(hue));
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final quickColor in _quickColors)
                    Semantics(
                      button: true,
                      selected: quickColor.toARGB32() == color.toARGB32(),
                      label: 'Use ${formatColorHex(quickColor)}',
                      child: InkWell(
                        borderRadius: BorderRadius.circular(10),
                        onTap: () => _setColor(quickColor),
                        child: SizedBox.square(
                          dimension: 48,
                          child: Center(
                            child: ColorPreviewSwatch(color: quickColor),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, color),
          child: const Text('Apply'),
        ),
      ],
    );
  }

  Color? _tryParseColor(String value) {
    final normalized = value.replaceFirst('#', '').trim();
    if (normalized.length != 6) {
      return null;
    }

    final rgb = int.tryParse(normalized, radix: 16);
    if (rgb == null) {
      return null;
    }
    return Color(0xFF000000 | rgb);
  }
}

class _SaturationValuePicker extends StatelessWidget {
  const _SaturationValuePicker({required this.color, required this.onChanged});

  final HSVColor color;
  final ValueChanged<HSVColor> onChanged;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        return Semantics(
          label: 'Saturation and brightness',
          value:
              '${(color.saturation * 100).round()}% saturation, '
              '${(color.value * 100).round()}% brightness',
          onIncrease: () =>
              onChanged(color.withValue((color.value + 0.05).clamp(0.0, 1.0))),
          onDecrease: () =>
              onChanged(color.withValue((color.value - 0.05).clamp(0.0, 1.0))),
          child: GestureDetector(
            onTapDown: (details) =>
                _handlePosition(details.localPosition, size),
            onPanUpdate: (details) =>
                _handlePosition(details.localPosition, size),
            child: CustomPaint(
              painter: _SaturationValuePainter(color),
              size: size,
            ),
          ),
        );
      },
    );
  }

  void _handlePosition(Offset position, Size size) {
    final saturation = (position.dx / size.width).clamp(0.0, 1.0);
    final value = (1 - position.dy / size.height).clamp(0.0, 1.0);
    onChanged(color.withSaturation(saturation).withValue(value));
  }
}

class _SaturationValuePainter extends CustomPainter {
  const _SaturationValuePainter(this.color);

  final HSVColor color;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final hueColor = HSVColor.fromAHSV(1, color.hue, 1, 1).toColor();

    canvas.drawRect(rect, Paint()..color = hueColor);
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          colors: [Colors.white, Colors.transparent],
        ).createShader(rect),
    );
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.transparent, Colors.black],
        ).createShader(rect),
    );

    final handle = Offset(
      color.saturation * size.width,
      (1 - color.value) * size.height,
    );
    canvas.drawCircle(handle, 8, Paint()..color = Colors.white);
    canvas.drawCircle(
      handle,
      8,
      Paint()
        ..color = Colors.black
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(covariant _SaturationValuePainter oldDelegate) {
    return oldDelegate.color != color;
  }
}

/// A compact swatch for previewing a selected color.
class ColorPreviewSwatch extends StatelessWidget {
  const ColorPreviewSwatch({super.key, required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 32,
      height: 32,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: color,
          border: Border.all(color: Theme.of(context).dividerColor),
          borderRadius: BorderRadius.circular(6),
        ),
      ),
    );
  }
}

/// Formats the RGB channels of [color] as a six-digit hexadecimal string.
String formatColorHex(Color color) {
  final rgb = color.toARGB32() & 0xFFFFFF;
  return '#${rgb.toRadixString(16).padLeft(6, '0').toUpperCase()}';
}
