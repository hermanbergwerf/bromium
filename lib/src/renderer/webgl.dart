// Copyright (c) 2016, Herman Bergwerf. All rights reserved.
// Use of this source code is governed by an AGPL-3.0-style license
// that can be found in the LICENSE file.

part of bromium_webgl_renderer;

/// Mouse data for user interaction.
class MouseData {
  /// Zoom value
  double z;

  /// A mouse button is pressed
  bool down = false;

  /// Previous x and y coordinates
  int lastX = 0, lastY = 0;

  /// Rotation matrix applied to WebGL camera.
  Matrix4 rotationMatrix = new Matrix4.identity();

  /// Constructor
  MouseData(this.z);
}

class BromiumWebGLRenderer {
  /// Backend engine that is used to retrieve the particle information.
  BromiumEngine engine;

  /// Output canvas.
  CanvasElement canvas;

  // WebGL specific
  gl.RenderingContext _gl;
  gl.Program _shaderProgram;

  // Graphics parameters
  int _viewportWidth, _viewportHeight;

  // Vertex and color buffers
  gl.Buffer _particleVertexBuffer;
  gl.Buffer _particleColorBuffer;

  Matrix4 _viewMatrix;

  int _aVertexPosition;
  int _aVertexColor;

  gl.UniformLocation _uViewMatrix;

  /// Mouse data
  MouseData _mouse;

  /// Constructor
  BromiumWebGLRenderer(this.engine, this.canvas) {
    _mouse = new MouseData(-1000.0);
    _viewportWidth = canvas.width;
    _viewportHeight = canvas.height;
    _gl = canvas.getContext('experimental-webgl');

    _initShaders();
    _initBuffers();

    _gl.clearColor(0.0, 0.0, 0.0, 1.0);
    _gl.enable(gl.RenderingContext.DEPTH_TEST);

    canvas.onMouseDown.listen((MouseEvent event) {
      _mouse.down = true;
      _mouse.lastX = event.client.x;
      _mouse.lastY = event.client.y;
    });

    canvas.onMouseUp.listen((MouseEvent event) {
      _mouse.down = false;
    });

    canvas.onMouseOut.listen((MouseEvent event) {
      _mouse.down = false;
    });

    canvas.onMouseMove.listen((MouseEvent event) {
      if (!_mouse.down) return;

      // Apply rotation to rotationMatrix.
      var matrix = new Matrix4.identity();
      matrix.rotateY((event.client.x - _mouse.lastX) / 100);
      matrix.rotateX((event.client.y - _mouse.lastY) / 100);
      matrix.multiply(_mouse.rotationMatrix);
      _mouse.rotationMatrix = matrix;

      _mouse.lastX = event.client.x;
      _mouse.lastY = event.client.y;
    });

    canvas.onMouseWheel.listen((WheelEvent event) {
      var speed = engine.data.useIntegers ? engine.data.voxelsPerUnit : 1;
      _mouse.z += event.deltaY > 0 ? speed : -speed;
    });
  }

  void _initShaders() {
    // vertex shader source code. uPosition is our variable that we'll
    // use to create animation
    String vsSource = '''
attribute vec3 aVertexPosition;
attribute vec4 aVertexColor;

uniform mat4 uViewMatrix;

varying vec4 vColor;

void main(void) {
  gl_PointSize = 1.0;
  gl_Position = uViewMatrix * vec4(aVertexPosition, 1.0);
  vColor = aVertexColor;
}
''';

    // fragment shader source code. uColor is our variable that we'll
    // use to animate color
    String fsSource = '''
precision mediump float;
varying vec4 vColor;
void main(void) {
  gl_FragColor = vColor;
}
''';

    // vertex shader compilation
    gl.Shader vs = _gl.createShader(gl.RenderingContext.VERTEX_SHADER);
    _gl.shaderSource(vs, vsSource);
    _gl.compileShader(vs);

    // fragment shader compilation
    gl.Shader fs = _gl.createShader(gl.RenderingContext.FRAGMENT_SHADER);
    _gl.shaderSource(fs, fsSource);
    _gl.compileShader(fs);

    // attach shaders to a WebGL program
    _shaderProgram = _gl.createProgram();
    _gl.attachShader(_shaderProgram, vs);
    _gl.attachShader(_shaderProgram, fs);
    _gl.linkProgram(_shaderProgram);
    _gl.useProgram(_shaderProgram);

    // Check if shaders were compiled properly. This is probably the most
    // painful part since there's no way to "debug" shader compilation.
    if (!_gl.getShaderParameter(vs, gl.RenderingContext.COMPILE_STATUS)) {
      print(_gl.getShaderInfoLog(vs));
    }
    if (!_gl.getShaderParameter(fs, gl.RenderingContext.COMPILE_STATUS)) {
      print(_gl.getShaderInfoLog(fs));
    }
    if (!_gl.getProgramParameter(
        _shaderProgram, gl.RenderingContext.LINK_STATUS)) {
      print(_gl.getProgramInfoLog(_shaderProgram));
    }

    _aVertexPosition = _gl.getAttribLocation(_shaderProgram, "aVertexPosition");
    _gl.enableVertexAttribArray(_aVertexPosition);

    _aVertexColor = _gl.getAttribLocation(_shaderProgram, "aVertexColor");
    _gl.enableVertexAttribArray(_aVertexColor);

    _uViewMatrix = _gl.getUniformLocation(_shaderProgram, "uViewMatrix");
  }

  void _initBuffers() {
    _particleVertexBuffer = _gl.createBuffer();
    _particleColorBuffer = _gl.createBuffer();
  }

  void render(double time) {
    // Run a simulation cycle.
    engine.step();

    // Check if the vertex and color buffers can be updated directly or have to
    // be reallocated (due to a simulation reset with a different number of
    // particles).
    _gl.bindBuffer(gl.RenderingContext.ARRAY_BUFFER, _particleVertexBuffer);
    int size = _gl.getBufferParameter(
        gl.RenderingContext.ARRAY_BUFFER, gl.BUFFER_SIZE);
    if (size == engine.data.particleType.length) {
      // Substitute new data, if the vertex buffer did not change the color
      // buffer should not have changed either.
      _gl.bufferSubData(gl.RenderingContext.ARRAY_BUFFER, 0,
          engine.data.particleVertexBuffer);

      // Substitute color data.
      _gl.bindBuffer(gl.RenderingContext.ARRAY_BUFFER, _particleColorBuffer);
      _gl.bufferSubData(
          gl.RenderingContext.ARRAY_BUFFER, 0, engine.data.particleColor);
    } else {
      // Reallocate buffers, if the vertex buffer did change the color buffer
      // must have changed as well.
      _gl.bufferData(gl.RenderingContext.ARRAY_BUFFER,
          engine.data.particleVertexBuffer, gl.RenderingContext.DYNAMIC_DRAW);

      // Reallocate color buffer.
      _gl.bindBuffer(gl.RenderingContext.ARRAY_BUFFER, _particleColorBuffer);
      _gl.bufferData(gl.RenderingContext.ARRAY_BUFFER,
          engine.data.particleColor, gl.RenderingContext.DYNAMIC_DRAW);
    }

    // Clear view.
    _gl.viewport(0, 0, _viewportWidth, _viewportHeight);
    _gl.clear(gl.RenderingContext.COLOR_BUFFER_BIT |
        gl.RenderingContext.DEPTH_BUFFER_BIT);

    // Field of view is 45deg, width-to-height ratio,
    // hide things closer than 0.1 or further than 100.
    _viewMatrix = makePerspectiveMatrix(
        radians(45.0), _viewportWidth / _viewportHeight, 0.1, 10000.0);
    _viewMatrix.translate(new Vector3(0.0, 0.0, _mouse.z));
    _viewMatrix.multiply(_mouse.rotationMatrix);

    // Bind particle positions.
    _gl.bindBuffer(gl.RenderingContext.ARRAY_BUFFER, _particleVertexBuffer);
    _gl.vertexAttribPointer(
        _aVertexPosition, 3, engine.data.particleVertexBufferType, false, 0, 0);

    // Bind particle colors.
    _gl.bindBuffer(gl.RenderingContext.ARRAY_BUFFER, _particleColorBuffer);
    _gl.vertexAttribPointer(
        _aVertexColor, 4, gl.RenderingContext.UNSIGNED_BYTE, false, 0, 0);

    // Apply view matrix.
    Float32List viewMatrix = new Float32List(16);
    _viewMatrix.copyIntoArray(viewMatrix);
    _gl.uniformMatrix4fv(_uViewMatrix, false, viewMatrix);

    // Draw particles.
    _gl.drawArrays(gl.RenderingContext.POINTS, 0,
        engine.data.particleType.length); // triangles, start at 0, total 3

    // Schedule next frame.
    this._requestFrame();
  }

  void start() {
    this._requestFrame();
  }

  void _requestFrame() {
    window.requestAnimationFrame((num time) {
      this.render(time);
    });
  }
}
