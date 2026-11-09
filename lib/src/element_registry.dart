// Copyright 2019 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/widgets.dart';

/// A registry to track some [Element]s in the tree.
class RegistryWidget extends StatefulWidget {
  /// Creates a [RegistryWidget].
  const RegistryWidget({super.key, this.elementNotifier, required this.child});

  /// The widget below this widget in the tree.
  final Widget child;

  /// Contains the current set of all [Element]s created by
  /// [RegisteredElementWidget]s in the tree below this widget.
  ///
  /// Note that if there is another [RegistryWidget] in this widget's subtree
  /// that registry, and not this one, will collect elements in its subtree.
  final ValueNotifier<Set<Element>?>? elementNotifier;

  @override
  State<StatefulWidget> createState() => _RegistryWidgetState();
}

/// A widget whose [Element] will be added its nearest ancestor
/// [RegistryWidget].
class RegisteredElementWidget extends ProxyWidget {
  /// Creates a [RegisteredElementWidget].
  const RegisteredElementWidget({super.key, required super.child});

  @override
  Element createElement() => _RegisteredElement(this);
}

class _RegistryWidgetState extends State<RegistryWidget> {
  final Set<Element> registeredElements = {};

  @override
  Widget build(BuildContext context) =>
      _InheritedRegistryWidget(state: this, child: widget.child);
}

class _InheritedRegistryWidget extends InheritedWidget {
  const _InheritedRegistryWidget({required this.state, required super.child});

  final _RegistryWidgetState state;

  @override
  // Dependents only use this to locate the registry state, which is stable for
  // the lifetime of the registry. Notifying on every rebuild would mark every
  // registered item element dirty each time the list rebuilds.
  bool updateShouldNotify(_InheritedRegistryWidget oldWidget) =>
      !identical(state, oldWidget.state);
}

class _RegisteredElement extends ProxyElement {
  _RegisteredElement(super.widget);

  @override
  void notifyClients(ProxyWidget oldWidget) {}

  _RegistryWidgetState? _registryWidgetState;

  @override
  void mount(Element? parent, Object? newSlot) {
    super.mount(parent, newSlot);
    _register();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _register();
  }

  void _register() {
    final registry =
        dependOnInheritedWidgetOfExactType<_InheritedRegistryWidget>()!.state;
    final previous = _registryWidgetState;
    // Moved under another registry (GlobalKey reparenting): leave the old one.
    if (previous != null && !identical(previous, registry)) {
      _unregisterFrom(previous);
    }
    _registryWidgetState = registry;
    registry.registeredElements.add(this);
    registry.widget.elementNotifier?.value = registry.registeredElements;
  }

  void _unregisterFrom(_RegistryWidgetState registry) {
    registry.registeredElements.remove(this);
    registry.widget.elementNotifier?.value = registry.registeredElements;
  }

  @override
  void unmount() {
    _unregisterFrom(_registryWidgetState!);
    super.unmount();
  }
}
