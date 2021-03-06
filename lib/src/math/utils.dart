// Copyright (c) 2016, Herman Bergwerf. All rights reserved.
// Use of this source code is governed by an AGPL-3.0-style license
// that can be found in the LICENSE file.

part of bromium.math;

/// Global random function.
final _rng = new Random();

/// Generate a random number between 0 and 1.
double rand() => _rng.nextDouble();

/// Generate a random vector between (0, 0, 0) and (1, 1, 1).
Vector3 randomVector3(Random rng) {
  return new Vector3(rng.nextDouble(), rng.nextDouble(), rng.nextDouble());
}

/// Generate a random unit vector.
void randomSphericalVector3(Random rng, Vector3 dst) {
  double x, y, z;
  do {
    x = rng.nextDouble() - .5;
    y = rng.nextDouble() - .5;
    z = rng.nextDouble() - .5;
  } while (sqrt(x * x + y * y + z * z) >= 0.25);
  dst.setValues(2.0 * x, 2.0 * y, 2.0 * z);
}
