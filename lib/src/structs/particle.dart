// Copyright (c) 2016, Herman Bergwerf. All rights reserved.
// Use of this source code is governed by an AGPL-3.0-style license
// that can be found in the LICENSE file.

part of bromium.structs;

/// Particle information
///
/// Only [type] and [position] are included in the binary stream. The
/// [entered] array is only used for optimization.
class Particle implements Transferrable {
  /// Number of floats each particle allocates in a byte buffer
  static const floatCount = 7;

  /// Number of bytes each particle allocates in a byte buffer
  static const byteCount = Float32List.BYTES_PER_ELEMENT * floatCount;

  /// Type
  int type;

  /// Position
  Vector3 position;

  /// Display color
  Vector3 color;

  /// Speed
  double speed;

  /// Radius
  Float32View _radius;

  /// Stick membrane. If the particle is sticked to a membrane this integer is
  /// set to the membrane index. Else it is set to -1.
  int sticked = -1;

  /// List containing all entered membranes
  final List<int> entered;

  /// Optimization for [particlesRandomMotionNormal]: the optimization works by
  /// skipping some parts for particles that are far removed from the membrane.
  /// The approach that was tested works by computing the minimal number of
  /// steps the particle needs to reach the membrane and skipping that number of
  /// cycles. In practice this causes bumps in the simulation time and does not
  /// significantly speed up the simulations that were tested.
  final List<int> minSteps;

  Particle(this.type, this.position, this.color, this.speed, double radius,
      int membraneCount)
      : _radius = new Float32View.value(radius),
        entered = new List<int>(),
        minSteps = new List<int>.filled(membraneCount, 0, growable: true);

  Particle.raw(this.type, this.position, this.color, this.speed, this._radius,
      this.sticked, this.entered, int membraneCount)
      : minSteps = new List<int>.filled(membraneCount, 0, growable: true);

  /// Copy the given position into the position view.
  void setPosition(Vector3 _position) {
    position.copyFromArray(_position.storage);
  }

  /// Copy the given color into the color view.
  void setColor(Vector3 _color) {
    color.copyFromArray(_color.storage);
  }

  /// Check if the particle has entered the given membrane.
  bool hasEntered(int membrane) => entered.contains(membrane);

  /// Push new entered membrane.
  void pushEntered(int membrane) => entered.add(membrane);

  /// Remove entered membrane (leave membrane).
  bool popEntered(int membrane) => entered.remove(membrane);

  /// Stick the particle to the given membrane.
  ///
  /// When the particle is sticked to a given `membrane` then
  /// `hasEntered(membrane)` returns false.
  void stickTo(int index, Domain membrane) {
    sticked = index;
    popEntered(index);

    // Project position on the membrane using a ray from the membrane center
    // towards the particle.
    final ray =
        new Ray.originDirection(membrane.center, position - membrane.center);
    final proj = membrane.computeRayIntersections(ray);
    position.setFrom(ray.at(proj.reduce(max)));
  }

  // Interface for radius and speed.
  double get radius => _radius.get();
  set radius(double value) => _radius.set(value);

  /// Check if the particle is sticked to a membrane.
  bool get isSticked => sticked != -1;

  int get sizeInBytes => byteCount;
  int transfer(ByteBuffer buffer, int offset, [bool copy = true]) {
    position = transferVector3(buffer, offset, copy, position);
    offset += position.storage.lengthInBytes;
    color = transferVector3(buffer, offset, copy, color);
    offset += color.storage.lengthInBytes;
    offset = _radius.transfer(buffer, offset, copy);
    return offset;
  }
}
