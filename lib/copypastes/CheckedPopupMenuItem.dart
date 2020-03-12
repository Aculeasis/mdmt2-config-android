import 'package:flutter/material.dart';

/// original source https://github.com/flutter/flutter/blob/1ba4f1f509202f3d2ec16f053edcbe2df6b7107e/packages/flutter/lib/src/material/popup_menu.dart#L332
/// copypasting for adding onTap method and EdgeInsets.zero to ListTile
/// I don't have another way for override widget state :(

class CheckedPopupMenuItem<T> extends PopupMenuItem<T> {
  final OnTapFn onTap;
  final bool checked;

  const CheckedPopupMenuItem({
    Key key,
    T value,
    this.checked = false,
    bool enabled = true,
    Widget child,
    this.onTap,
  })  : assert(checked != null),
        super(
          key: key,
          value: value,
          enabled: enabled,
          child: child,
        );

  @override
  Widget get child => super.child;

  @override
  _CheckedPopupMenuItemState<T> createState() => _CheckedPopupMenuItemState<T>();
}

class _CheckedPopupMenuItemState<T> extends PopupMenuItemState<T, CheckedPopupMenuItem<T>>
    with SingleTickerProviderStateMixin {
  static const Duration _fadeDuration = Duration(milliseconds: 150);
  AnimationController _controller;
  Animation<double> get _opacity => _controller.view;
  bool _checked;

  @override
  void initState() {
    super.initState();
    _checked = widget.checked;
    _controller = AnimationController(duration: _fadeDuration, vsync: this, value: _checked ? 1.0 : 0.0)
      ..addListener(() => setState(() => null));
  }

  @override
  void handleTap() {
    (_checked = !_checked) ? _controller.forward() : _controller.reverse();
    widget.onTap != null ? widget.onTap(_checked) : super.handleTap();
  }

  @override
  Widget buildChild() {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      enabled: widget.enabled,
      leading: FadeTransition(
        opacity: _opacity,
        child: Icon(_controller.isDismissed ? null : Icons.done),
      ),
      title: widget.child,
    );
  }
}

typedef void OnTapFn(bool);
