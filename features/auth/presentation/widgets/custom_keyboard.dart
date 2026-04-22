import 'package:flutter/material.dart';

// iOS Dark Mode Keyboard Simulation
class CustomNumericKeyboard extends StatelessWidget {
  final Function(String) onTextInput;
  final Function() onBackspace;

  const CustomNumericKeyboard({
    super.key,
    required this.onTextInput,
    required this.onBackspace,
  });

  @override
  Widget build(final BuildContext context) => Container(
        color: const Color(0xFF1C1C1E),
        padding: const EdgeInsets.fromLTRB(6, 6, 6, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildRow(['1', '2', '3']),
            _buildRow(['4', '5', '6']),
            _buildRow(['7', '8', '9']),
            _buildBottomRow(),
          ],
        ),
      );

  Widget _buildRow(final List<String> keys) => Container(
        margin: const EdgeInsets.only(bottom: 6),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: keys
              .map((final key) => Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: _buildKey(key),
                  ))
              .toList(),
        ),
      );

  Widget _buildBottomRow() => Container(
        margin: const EdgeInsets.only(bottom: 6),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: _buildTextKey('+ * #'),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: _buildKey('0'),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: _buildIconKey(Icons.backspace_outlined, onBackspace),
            ),
          ],
        ),
      );

  Widget _buildTextKey(final String label) => Container(
        width: 110,
        height: 48,
        alignment: Alignment.center,
        child: Text(label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w400,
              letterSpacing: 2,
            )),
      );

  Widget _buildIconKey(final IconData icon, final VoidCallback onTap) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          width: 110,
          height: 48,
          color: Colors.transparent,
          child: Center(
            child: Icon(icon, color: Colors.white, size: 28),
          ),
        ),
      );

  Widget _buildKey(final String key) => GestureDetector(
        onTap: () => onTextInput(key),
        child: Container(
          width: 110,
          height: 52,
          decoration: BoxDecoration(
            color: const Color(0xFF4C4C4E),
            borderRadius: BorderRadius.circular(5),
          ),
          child: _buildNumberKeyContent(key),
        ),
      );

  Widget _buildNumberKeyContent(final String key) {
    const lettersMap = {
      '2': 'A B C',
      '3': 'D E F',
      '4': 'G H I',
      '5': 'J K L',
      '6': 'M N O',
      '7': 'P Q R S',
      '8': 'T U V',
      '9': 'W X Y Z',
      '0': '',
    };

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          key,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w400,
            color: Colors.white,
            height: 1.0,
          ),
        ),
        if (lettersMap.containsKey(key) && lettersMap[key]!.isNotEmpty)
          Text(
            lettersMap[key]!,
            style: const TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w600,
              color: Colors.white70,
              letterSpacing: 1.5,
              height: 1.2,
            ),
          ),
      ],
    );
  }
}
