import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../theme/tokens.dart';

// ---- Buttons -------------------------------------------------------------

enum Variant { primary, secondary, reward, success, light, soft, ghost }

class _V {
  const _V(this.bg, this.lip, this.fg, {this.shadowText = false});
  final Color bg, lip, fg;
  final bool shadowText;
}

const _variants = {
  Variant.primary: _V(C.berry600, C.berry800, Colors.white, shadowText: true),
  Variant.secondary: _V(C.ice400, C.ice600, C.night800),
  Variant.reward: _V(C.sun500, C.sun700, C.night800),
  Variant.success: _V(C.mint500, C.mint700, C.night800),
  Variant.light: _V(C.paper, C.snow300, C.night800),
  // Pale berry, matching the stencil outline on the cut board.
  Variant.soft: _V(C.berry100, C.berry300, C.berry700),
  Variant.ghost: _V(C.surfaceGlass, Colors.transparent, Colors.white),
};

/// Tracks the pressed state for the “lip” press animation.
class _Pressable extends StatefulWidget {
  const _Pressable({required this.builder, this.onTap, this.enabled = true});
  final Widget Function(bool pressed) builder;
  final VoidCallback? onTap;
  final bool enabled;

  @override
  State<_Pressable> createState() => _PressableState();
}

class _PressableState extends State<_Pressable> {
  bool _down = false;

  void _set(bool v) {
    if (_down != v) setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) {
    final on = widget.enabled && widget.onTap != null;
    return Semantics(
      button: true,
      enabled: on,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: on ? (_) => _set(true) : null,
        onTapUp: on ? (_) => _set(false) : null,
        onTapCancel: on ? () => _set(false) : null,
        onTap: on ? widget.onTap : null,
        child: widget.builder(_down && on),
      ),
    );
  }
}

enum BtnSize { s, m, l }

class Btn extends StatelessWidget {
  const Btn(
    this.label, {
    super.key,
    this.variant = Variant.primary,
    this.size = BtnSize.m,
    this.icon,
    this.iconRight,
    this.iconColor,
    this.block = false,
    this.disabled = false,
    this.onTap,
  });

  final String label;
  final Variant variant;
  final BtnSize size;
  final IconData? icon, iconRight;

  /// Tint for [icon] instead of the label colour, e.g. a filled heart.
  final Color? iconColor;
  final bool block, disabled;
  final VoidCallback? onTap;

  static const _sizes = {
    BtnSize.s: (h: 40.0, px: 18.0, fs: 16.0, r: 14.0, lip: 4.0, icon: 18.0),
    BtnSize.m: (h: 52.0, px: 24.0, fs: 19.0, r: 18.0, lip: 6.0, icon: 22.0),
    BtnSize.l: (h: 64.0, px: 32.0, fs: 22.0, r: 22.0, lip: 6.0, icon: 26.0),
  };

  @override
  Widget build(BuildContext context) {
    final v = _variants[variant]!;
    final s = _sizes[size]!;
    final fg = disabled ? C.snow500 : v.fg;
    return _Pressable(
      enabled: !disabled,
      onTap: onTap,
      builder: (pressed) {
        final lipH = pressed ? 2.0 : s.lip;
        return Padding(
          padding: EdgeInsets.only(bottom: s.lip),
          child: AnimatedContainer(
            duration: Motion.press,
            curve: Motion.out,
            height: s.h,
            width: block ? double.infinity : null,
            padding: EdgeInsets.symmetric(horizontal: s.px),
            transform: Matrix4.translationValues(0, pressed ? s.lip - 2 : 0, 0),
            decoration: BoxDecoration(
              color: disabled ? C.snow200 : v.bg,
              borderRadius: BorderRadius.circular(s.r),
              boxShadow: variant == Variant.ghost
                  ? null
                  : [BoxShadow(color: disabled ? C.snow300 : v.lip, offset: Offset(0, lipH))],
            ),
            child: Row(
              mainAxisSize: block ? MainAxisSize.max : MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (icon != null) ...[Icon(icon, size: s.icon, color: disabled ? fg : iconColor ?? fg), const SizedBox(width: 10)],
                Flexible(
                  // A label too long for the button shrinks rather than spilling off-centre.
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      label,
                      maxLines: 1,
                      softWrap: false,
                      style: display(s.fs, color: fg).copyWith(
                        letterSpacing: s.fs * 0.01,
                        shadows: v.shadowText && !disabled
                            ? const [Shadow(color: Color(0x2E000000), offset: Offset(0, 2))]
                            : null,
                      ),
                    ),
                  ),
                ),
                if (iconRight != null) ...[const SizedBox(width: 10), Icon(iconRight, size: s.icon, color: fg)],
              ],
            ),
          ),
        );
      },
    );
  }
}

class RoundBtn extends StatelessWidget {
  const RoundBtn(
    this.icon, {
    super.key,
    required this.label,
    this.variant = Variant.light,
    this.size = BtnSize.m,
    this.active = false,
    this.flat = false,
    this.disabled = false,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final Variant variant;
  final BtnSize size;
  final bool active, flat, disabled;
  final VoidCallback? onTap;

  static const _sizes = {
    BtnSize.s: (d: 44.0, i: 22.0, lip: 4.0),
    BtnSize.m: (d: 56.0, i: 26.0, lip: 5.0),
    BtnSize.l: (d: 72.0, i: 34.0, lip: 6.0),
  };

  @override
  Widget build(BuildContext context) {
    final v = _variants[variant]!;
    final s = _sizes[size]!;
    return Tooltip(
      message: label,
      child: _Pressable(
        enabled: !disabled,
        onTap: onTap,
        builder: (down) {
          final pressed = down && !disabled;
          // An active (selected) button stands a little larger instead of sinking.
          final grow = active && !disabled ? 1.12 : 1.0;
          return Padding(
            padding: EdgeInsets.only(bottom: s.lip),
            child: AnimatedContainer(
              duration: Motion.press,
              curve: Motion.out,
              width: s.d,
              height: s.d,
              transformAlignment: Alignment.center,
              transform: Matrix4.translationValues(0, pressed ? s.lip - 1 : 0, 0)..multiply(Matrix4.diagonal3Values(grow, grow, 1)),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: disabled ? C.snow200 : v.bg,
                boxShadow: [
                  if (variant != Variant.ghost && !flat)
                    BoxShadow(color: disabled ? C.snow300 : v.lip, offset: Offset(0, pressed ? 1 : s.lip)),
                ],
              ),
              child: Icon(icon, size: s.i, color: disabled ? C.snow500 : v.fg),
            ),
          );
        },
      ),
    );
  }
}

// ---- Dialog --------------------------------------------------------------

/// Pale ice card (the cut board's table colour) with an ice title ribbon and a berry close button.
class DsDialog extends StatelessWidget {
  const DsDialog({super.key, this.title, required this.child, this.actions = const [], this.onClose});

  final String? title;
  final Widget child;
  final List<Widget> actions;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 26),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 340),
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.topCenter,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(24, 44, 24, 24),
              decoration: BoxDecoration(
                color: C.surfaceTable,
                borderRadius: BorderRadius.circular(R.xl),
                boxShadow: const [
                  BoxShadow(color: Color(0x59101A3F), offset: Offset(0, 18), blurRadius: 40),
                  BoxShadow(color: C.snow300, offset: Offset(0, 8)),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DefaultTextStyle(
                    style: body(17, height: 1.4),
                    textAlign: TextAlign.center,
                    child: child,
                  ),
                  if (actions.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    for (var i = 0; i < actions.length; i++) ...[if (i > 0) const SizedBox(height: 8), actions[i]],
                  ],
                ],
              ),
            ),
            if (title != null)
              Positioned(
                top: -26,
                child: Container(
                  height: 52,
                  padding: const EdgeInsets.symmetric(horizontal: 28),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: C.ice500,
                    borderRadius: BorderRadius.circular(26),
                  ),
                  child: Text(
                    title!,
                    style: display(22, height: 1, shadows: const [Shadow(color: Color(0x26000000), offset: Offset(0, 2))]),
                  ),
                ),
              ),
            if (onClose != null)
              Positioned(
                top: -18,
                right: -10,
                child: RoundBtn(LucideIcons.x, label: 'Закрыть', variant: Variant.primary, size: BtnSize.s, onTap: onClose),
              ),
          ],
        ),
      ),
    );
  }
}

/// Modal dialog over a night-900/60% blurred scrim, popping in with a bounce.
/// A tap on the scrim closes it unless [dismissible] is false.
Future<T?> showDsDialog<T>(BuildContext context, {required Widget Function(BuildContext) builder, bool dismissible = true}) {
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: dismissible,
    barrierLabel: 'Закрыть',
    barrierColor: Colors.transparent,
    transitionDuration: Motion.pop,
    pageBuilder: (ctx, _, _) => builder(ctx),
    transitionBuilder: (ctx, anim, _, child) {
      final pop = CurvedAnimation(parent: anim, curve: Motion.bounce, reverseCurve: Curves.easeIn);
      return Stack(children: [
        // The scrim only paints: taps beside the card fall through to the
        // route's barrier, which closes the dialog.
        Positioned.fill(
          child: IgnorePointer(
            child: BackdropFilter(
              filter: ui.ImageFilter.blur(sigmaX: 2 * anim.value, sigmaY: 2 * anim.value),
              child: ColoredBox(color: Color.fromRGBO(16, 26, 63, .6 * anim.value)),
            ),
          ),
        ),
        SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: FadeTransition(
                opacity: anim,
                child: ScaleTransition(scale: Tween(begin: .6, end: 1.0).animate(pop), child: Material(type: MaterialType.transparency, child: child)),
              ),
            ),
          ),
        ),
      ]);
    },
  );
}

// ---- Hint bubble ---------------------------------------------------------

class HintBubble extends StatelessWidget {
  const HintBubble(this.text, {super.key, this.icon = LucideIcons.hand, this.tailUp = false});
  final String text;
  final IconData icon;

  /// Tail on top, pointing at something above the bubble; otherwise below.
  final bool tailUp;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      alignment: tailUp ? Alignment.topCenter : Alignment.bottomCenter,
      children: [
        Positioned(
          top: tailUp ? -7 : null,
          bottom: tailUp ? null : -7,
          child: Transform.rotate(
            angle: math.pi / 4,
            child: Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(color: C.paper, borderRadius: BorderRadius.circular(4)),
            ),
          ),
        ),
        Container(
          constraints: const BoxConstraints(maxWidth: 300),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          decoration: BoxDecoration(
            color: C.paper,
            borderRadius: BorderRadius.circular(R.l),
            boxShadow: const [BoxShadow(color: Color(0x26101A3F), offset: Offset(0, 5))],
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 34,
              height: 34,
              decoration: const BoxDecoration(color: C.berry100, shape: BoxShape.circle),
              child: Icon(icon, size: 20, color: C.berry700),
            ),
            const SizedBox(width: 10),
            Flexible(child: Text(text, style: body(17, weight: FontWeight.w800, color: C.night800, height: 1.25))),
          ]),
        ),
      ],
    );
  }
}

// ---- Forms ---------------------------------------------------------------

class DsSwitch extends StatelessWidget {
  const DsSwitch({super.key, required this.label, required this.checked, required this.onChanged});
  final String label;
  final bool checked;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      toggled: checked,
      label: label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => onChanged(!checked),
        child: Row(children: [
          Expanded(child: Text(label, textAlign: TextAlign.left, style: body(17, weight: FontWeight.w800, color: C.textStrong))),
          const SizedBox(width: 16),
          AnimatedContainer(
            duration: Motion.pop,
            curve: Motion.out,
            width: 64,
            height: 36,
            decoration: BoxDecoration(color: checked ? C.mint500 : C.snow300, borderRadius: BorderRadius.circular(18)),
            child: Stack(children: [
              // inset top shadow
              Positioned(
                left: 0,
                right: 0,
                top: 0,
                height: 18,
                child: Container(
                  decoration: const BoxDecoration(
                    borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
                    border: Border(top: BorderSide(color: Color(0x1F101A3F), width: 3)),
                  ),
                ),
              ),
              AnimatedPositioned(
                duration: Motion.pop,
                curve: Motion.bounce,
                top: 3,
                left: checked ? 31 : 3,
                child: Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: C.paper,
                    shape: BoxShape.circle,
                    boxShadow: [BoxShadow(color: checked ? C.mint700 : C.snow500, offset: const Offset(0, 3))],
                  ),
                ),
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}

class SegOption<T> {
  const SegOption(this.value, this.label, [this.icon]);
  final T value;
  final String label;
  final IconData? icon;
}

class Segmented<T> extends StatelessWidget {
  const Segmented({super.key, required this.options, required this.value, this.onChanged, this.dark = false});
  final List<SegOption<T>> options;
  final T value;
  final ValueChanged<T>? onChanged;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: dark ? const Color(0x73101A3F) : C.snow200,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final (i, o) in options.indexed) ...[
            if (i > 0) const SizedBox(width: 4),
            Flexible(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onChanged == null ? null : () => onChanged!(o.value),
                child: AnimatedContainer(
                  duration: Motion.press,
                  height: 44,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    color: o.value == value ? C.paper : Colors.transparent,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: o.value == value ? const [BoxShadow(color: C.snow300, offset: Offset(0, 3))] : null,
                  ),
                  child: Builder(builder: (_) {
                    final fg = o.value == value ? C.night800 : (dark ? C.ice200 : C.snow700);
                    return Row(mainAxisSize: MainAxisSize.min, mainAxisAlignment: MainAxisAlignment.center, children: [
                      if (o.icon != null) ...[Icon(o.icon, size: 20, color: fg), const SizedBox(width: 8)],
                      Text(o.label, style: display(16, weight: FontWeight.w700, color: fg)),
                    ]);
                  }),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ---- Game ----------------------------------------------------------------

enum Tone { sun, mint, ice, berry }

class ProgressBar extends StatelessWidget {
  const ProgressBar({super.key, required this.value, this.tone = Tone.sun, this.height = 20, this.label, this.dark = false});
  final double value, height;
  final Tone tone;
  final String? label;
  final bool dark;

  static const _tones = {
    Tone.sun: (C.sun500, C.sun700),
    Tone.mint: (C.mint500, C.mint700),
    Tone.ice: (C.ice400, C.ice600),
    Tone.berry: (C.berry500, C.berry700),
  };

  @override
  Widget build(BuildContext context) {
    final p = value.clamp(0.0, 1.0);
    final (fill, edge) = _tones[tone]!;
    final r = BorderRadius.circular(height / 2);
    return ClipRRect(
      borderRadius: r,
      child: SizedBox(
        height: height,
        child: LayoutBuilder(builder: (_, c) {
          final w = p == 0 ? 0.0 : math.max(p * c.maxWidth, height);
          return Stack(children: [
            Positioned.fill(child: ColoredBox(color: dark ? const Color(0x80101A3F) : C.snow200)),
            const Positioned(left: 0, right: 0, top: 0, height: 3, child: ColoredBox(color: Color(0x26101A3F))),
            AnimatedPositioned(
              duration: Motion.pop,
              curve: Motion.out,
              left: 0,
              top: 0,
              bottom: 0,
              width: w,
              child: ClipRRect(
                borderRadius: r,
                child: Column(children: [
                  Container(height: 3, color: Color.lerp(fill, Colors.white, .45)),
                  Expanded(child: ColoredBox(color: fill, child: const SizedBox.expand())),
                  Container(height: math.min(4, height / 3), color: edge),
                ]),
              ),
            ),
            if (label != null)
              Center(
                child: Text(label!, style: display(math.max(11, height * 0.6), height: 1, color: dark ? Colors.white : C.night800)),
              ),
          ]);
        }),
      ),
    );
  }
}

String formatRu(int n) {
  final s = n.abs().toString();
  final b = StringBuffer(n < 0 ? '-' : '');
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) b.write(' ');
    b.write(s[i]);
  }
  return b.toString();
}

class CurrencyPill extends StatelessWidget {
  const CurrencyPill({super.key, required this.amount, this.icon = LucideIcons.snowflake, this.iconColor = C.ice400});
  final int amount;
  final IconData icon;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 40,
      padding: const EdgeInsets.fromLTRB(6, 0, 16, 0),
      decoration: BoxDecoration(
        color: const Color(0x8C101A3F),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0x40C4ECFF), width: 2),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 28,
          height: 28,
          decoration: const BoxDecoration(color: C.night900, shape: BoxShape.circle),
          child: Icon(icon, size: 18, color: iconColor),
        ),
        const SizedBox(width: 8),
        ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 28),
          child: Text(
            formatRu(amount),
            style: display(18, height: 1).copyWith(fontFeatures: const [ui.FontFeature.tabularFigures()]),
          ),
        ),
      ]),
    );
  }
}

// ---- Layout --------------------------------------------------------------

/// Night sky gradient with the repeating snow-dot pattern.
class SkyBackground extends StatelessWidget {
  const SkyBackground({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [C.night800, C.night600, C.night500],
          stops: [0, .7, 1],
        ),
      ),
      child: CustomPaint(painter: _SnowDotsPainter(), child: child),
    );
  }
}

class _SnowDotsPainter extends CustomPainter {
  static const _layers = [
    (tile: 120.0, fx: .20, fy: .30, r: 1.75, a: .55),
    (tile: 80.0, fx: .70, fy: .60, r: 1.25, a: .35),
    (tile: 160.0, fx: .45, fy: .85, r: 2.25, a: .45),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    for (final l in _layers) {
      final p = Paint()..color = Color.fromRGBO(255, 255, 255, l.a);
      for (var y = 0.0; y < size.height; y += l.tile) {
        for (var x = 0.0; x < size.width; x += l.tile) {
          canvas.drawCircle(Offset(x + l.tile * l.fx, y + l.tile * l.fy), l.r, p);
        }
      }
    }
  }

  @override
  bool shouldRepaint(_SnowDotsPainter oldDelegate) => false;
}

class TopBar extends StatelessWidget {
  const TopBar({super.key, required this.left, required this.title, required this.right});
  final Widget left, right;
  final String title;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 60),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(screenPad, 6, screenPad, 0),
        child: Row(children: [
          left,
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: display(22, height: 1.1, shadows: drop(3)),
            ),
          ),
          const SizedBox(width: 12),
          right,
        ]),
      ),
    );
  }
}
