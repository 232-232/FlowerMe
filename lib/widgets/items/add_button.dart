import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';


import '../../theme/app_colors.dart';

/// A smart add/quantity widget. Shows a "+" initially; taps in transform to
/// an inline "− qty +" selector with HapticFeedback.
class AddButton extends StatefulWidget {
  const AddButton({
    super.key,
    this.onPressed,
    this.onQuantityChanged,
    this.externalQuantity,
    this.isDisabled = false,
  });

  /// Called when the "+" button is first tapped (qty goes from 0 → 1).
  final VoidCallback? onPressed;

  /// Called whenever quantity changes (including decrement back to 0).
  final ValueChanged<int>? onQuantityChanged;

  /// If non-null, this widget is "controlled" by the parent's quantity.
  final int? externalQuantity;

  /// If true, the user cannot increment quantity (e.g. out of stock).
  final bool isDisabled;

  @override
  State<AddButton> createState() => _AddButtonState();
}

class _AddButtonState extends State<AddButton>
    with SingleTickerProviderStateMixin {
  int _qty = 0;
  late final AnimationController _morphController;
  late final Animation<double> _morphAnim;

  @override
  void initState() {
    super.initState();
    _morphController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _morphAnim = CurvedAnimation(
      parent: _morphController,
      curve: Curves.easeOutBack,
      reverseCurve: Curves.easeInCubic,
    );
    if (widget.externalQuantity != null && widget.externalQuantity! > 0) {
      _qty = widget.externalQuantity!;
      _morphController.value = 1.0;
    }
  }

  @override
  void didUpdateWidget(AddButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.externalQuantity != null &&
        widget.externalQuantity != oldWidget.externalQuantity) {
      setState(() => _qty = widget.externalQuantity!);
      if (_qty > 0 && !_morphController.isCompleted) {
        _morphController.forward();
      } else if (_qty == 0 && _morphController.isCompleted) {
        _morphController.reverse();
      }
    }
  }

  @override
  void dispose() {
    _morphController.dispose();
    super.dispose();
  }

  void _handleAdd() {
    HapticFeedback.mediumImpact();
    setState(() => _qty++);
    if (_qty == 1) {
      _morphController.forward();
    }
    // Always notify – covers both the 0→1 first-add and subsequent increments.
    widget.onQuantityChanged?.call(_qty);
  }

  void _handleRemove() {
    HapticFeedback.lightImpact();
    setState(() {
      if (_qty > 0) _qty--;
    });
    if (_qty == 0) {
      _morphController.reverse();
    }
    widget.onQuantityChanged?.call(_qty);
  }

  @override
  Widget build(BuildContext context) {
    final accent = AppThemeScope.themeOf(context).primaryAccent;

    return AnimatedBuilder(
      animation: _morphAnim,
      builder: (context, _) {
        final t = _morphAnim.value;

        // Interpolate width: 34 (circle) → 68 (pill selector)
        final width = 34.0 + 34.0 * t;

        return SizedBox(
          width: width,
          height: 34,
          child: Material(
            color: Colors.transparent,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Background pill/circle
                Container(
                  width: width,
                  height: 34,
                  decoration: BoxDecoration(
                    color: widget.isDisabled && _qty == 0 
                        ? Colors.grey.withValues(alpha: 0.12) 
                        : accent,
                    borderRadius: BorderRadius.circular(17),
                    boxShadow: widget.isDisabled && _qty == 0 ? [] : [
                      BoxShadow(
                        color: accent.withValues(alpha: 0.35),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                ),

                // "+" icon (fades out as morph progresses)
                if (t < 0.5)
                  Opacity(
                    opacity: ((1 - t * 2) * (widget.isDisabled ? 0.4 : 1.0)).clamp(0.0, 1.0),
                    child: InkWell(
                      onTap: widget.isDisabled ? null : _handleAdd,
                      customBorder: const CircleBorder(),
                      splashColor: Colors.white.withValues(alpha: 0.2),
                      highlightColor: Colors.white.withValues(alpha: 0.1),
                      child: SizedBox(
                        width: 34,
                        height: 34,
                        child: Icon(
                          Icons.add_rounded,
                          color: widget.isDisabled ? Colors.grey : Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                  ),

                // Quantity selector (fades in as morph progresses)
                if (t > 0.4)
                  Opacity(
                    opacity: ((t - 0.4) / 0.6).clamp(0.0, 1.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Minus button
                        InkWell(
                          onTap: _handleRemove,
                          borderRadius: const BorderRadius.horizontal(left: Radius.circular(17)),
                          splashColor: Colors.white.withValues(alpha: 0.2),
                          highlightColor: Colors.white.withValues(alpha: 0.1),
                          child: SizedBox(
                            width: 22,
                            height: 34,
                            child: const Icon(
                              Icons.remove_rounded,
                              color: Colors.white,
                              size: 14,
                            ),
                          ),
                        ),

                        // Quantity count
                        AnimatedSwitcher(
                          duration: 150.ms,
                          transitionBuilder: (child, anim) =>
                              ScaleTransition(scale: anim, child: child),
                          child: Text(
                            '$_qty',
                            key: ValueKey<int>(_qty),
                            style: TextStyle(fontFamily: "PlusJakartaSans", 
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: widget.isDisabled && _qty == 0 ? Colors.grey : Colors.white,
                              height: 1,
                            ),
                          ),
                        ),

                        // Plus button
                        Opacity(
                          opacity: widget.isDisabled ? 0.4 : 1.0,
                          child: InkWell(
                            onTap: widget.isDisabled ? null : _handleAdd,
                            borderRadius: const BorderRadius.horizontal(right: Radius.circular(17)),
                            splashColor: Colors.white.withValues(alpha: 0.2),
                            highlightColor: Colors.white.withValues(alpha: 0.1),
                            child: SizedBox(
                              width: 22,
                              height: 34,
                              child: Icon(
                                Icons.add_rounded,
                                color: widget.isDisabled ? Colors.grey : Colors.white,
                                size: 14,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
