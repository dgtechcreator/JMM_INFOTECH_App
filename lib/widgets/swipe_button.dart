import 'package:flutter/material.dart';

/// Slide-to-confirm control (no external package — a plain Draggable knob over a track). Resets to the
/// start whenever [busy] goes back to false, whether the action succeeded or failed; on success the
/// caller's own state change (e.g. hasPunchedIn flipping) naturally changes the label on the next build.
class SwipeToConfirmButton extends StatefulWidget {
  const SwipeToConfirmButton({super.key, required this.label, required this.onConfirm, required this.color, this.busy = false, this.enabled = true});

  final String label;
  final VoidCallback onConfirm;
  final Color color;
  final bool busy;
  final bool enabled;

  @override
  State<SwipeToConfirmButton> createState() => _SwipeToConfirmButtonState();
}

class _SwipeToConfirmButtonState extends State<SwipeToConfirmButton> {
  double _dragX = 0;
  static const double _knobSize = 52;

  @override
  void didUpdateWidget(covariant SwipeToConfirmButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.busy && !widget.busy) {
      setState(() => _dragX = 0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final interactive = widget.enabled && !widget.busy;
    final trackColor = widget.enabled ? widget.color : widget.color.withValues(alpha: 0.4);

    return LayoutBuilder(
      builder: (context, constraints) {
        final maxDrag = constraints.maxWidth - _knobSize - 8;
        return Container(
          height: _knobSize + 8,
          decoration: BoxDecoration(color: trackColor, borderRadius: BorderRadius.circular((_knobSize + 8) / 2)),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Center(
                child: Text(widget.label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 15)),
              ),
              AnimatedPositioned(
                duration: const Duration(milliseconds: 180),
                left: 4 + _dragX,
                child: GestureDetector(
                  onHorizontalDragUpdate: !interactive
                      ? null
                      : (details) => setState(() => _dragX = (_dragX + details.delta.dx).clamp(0, maxDrag)),
                  onHorizontalDragEnd: !interactive
                      ? null
                      : (details) {
                          if (_dragX > maxDrag * 0.7) {
                            setState(() => _dragX = maxDrag);
                            widget.onConfirm();
                          } else {
                            setState(() => _dragX = 0);
                          }
                        },
                  child: Container(
                    width: _knobSize,
                    height: _knobSize,
                    decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                    child: widget.busy
                        ? Padding(padding: const EdgeInsets.all(14), child: CircularProgressIndicator(strokeWidth: 2, color: widget.color))
                        : Icon(Icons.double_arrow_rounded, color: trackColor),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
