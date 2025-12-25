import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class PinInputWidget extends StatefulWidget {
  final Function(String) onPinChanged;
  final String currentPin;
  final bool enabled;

  const PinInputWidget({
    super.key,
    required this.onPinChanged,
    required this.currentPin,
    this.enabled = true,
  });

  @override
  State<PinInputWidget> createState() => _PinInputWidgetState();
}

class _PinInputWidgetState extends State<PinInputWidget> {
  String _pin = '';

  @override
  void initState() {
    super.initState();
    _pin = widget.currentPin;
  }

  @override
  void didUpdateWidget(PinInputWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.currentPin != oldWidget.currentPin) {
      setState(() {
        _pin = widget.currentPin;
      });
    }
  }

  void _onNumberPressed(String number) {
    if (!widget.enabled) return;

    if (_pin.length < 4) {
      HapticFeedback.lightImpact();
      setState(() {
        _pin += number;
      });
      widget.onPinChanged(_pin);
    }
  }

  void _onDeletePressed() {
    if (!widget.enabled) return;

    if (_pin.isNotEmpty) {
      HapticFeedback.lightImpact();
      setState(() {
        _pin = _pin.substring(0, _pin.length - 1);
      });
      widget.onPinChanged(_pin);
    }
  }

  Widget _buildPinDot(int index) {
    final bool isFilled = index < _pin.length;
    return Container(
      width: 20,
      height: 20,
      margin: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isFilled ? Colors.deepPurple : Colors.transparent,
        border: Border.all(
          color: isFilled ? Colors.deepPurple : Colors.grey[600]!,
          width: 2,
        ),
      ),
    );
  }

  Widget _buildNumberButton(String number) {
    return GestureDetector(
      onTap: () => _onNumberPressed(number),
      child: Container(
        width: 80,
        height: 80,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: widget.enabled ? Colors.grey[900] : Colors.grey[800],
          border: Border.all(
            color: widget.enabled ? Colors.grey[700]! : Colors.grey[600]!,
            width: 1,
          ),
        ),
        child: Center(
          child: Text(
            number,
            style: TextStyle(
              color: widget.enabled ? Colors.white : Colors.grey[500],
              fontSize: 24,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDeleteButton() {
    return GestureDetector(
      onTap: _onDeletePressed,
      child: Container(
        width: 80,
        height: 80,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: widget.enabled ? Colors.grey[900] : Colors.grey[800],
          border: Border.all(
            color: widget.enabled ? Colors.grey[700]! : Colors.grey[600]!,
            width: 1,
          ),
        ),
        child: Center(
          child: Icon(
            Icons.backspace_outlined,
            color: widget.enabled ? Colors.white : Colors.grey[500],
            size: 24,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // PIN dots
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(4, (index) => _buildPinDot(index)),
        ),

        const SizedBox(height: 48),

        // Number pad
        Column(
          children: [
            // Row 1: 1, 2, 3
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildNumberButton('1'),
                _buildNumberButton('2'),
                _buildNumberButton('3'),
              ],
            ),

            const SizedBox(height: 16),

            // Row 2: 4, 5, 6
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildNumberButton('4'),
                _buildNumberButton('5'),
                _buildNumberButton('6'),
              ],
            ),

            const SizedBox(height: 16),

            // Row 3: 7, 8, 9
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildNumberButton('7'),
                _buildNumberButton('8'),
                _buildNumberButton('9'),
              ],
            ),

            const SizedBox(height: 16),

            // Row 4: empty, 0, delete
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                const SizedBox(width: 80, height: 80), // Empty space
                _buildNumberButton('0'),
                _buildDeleteButton(),
              ],
            ),
          ],
        ),
      ],
    );
  }
}
