/* ProFrame — parametric 3D renderer.
 *
 * This file deliberately contains NO product knowledge. It receives an
 * explicit list of parts (position, size, rotation, material) that was built
 * in Dart from the parametric model, and instantiates real three.js meshes for
 * them. It cannot invent geometry, and it cannot disagree with the 2D drawing
 * or the price, because all three read the same model.
 *
 * Units: the payload is in millimetres; the scene works in metres.
 */
(function () {
  'use strict';

  var MM = 0.001;

  var container, renderer, scene, camera, controls, pmrem, envTexture;
  var productGroup, dimensionGroup, groundPlane;
  var currentScene = null;
  var raycaster, pointerVector, pointerDownAt;
  var currentStyle = 'realistic';
  var showDimensions = false;
  var autoRotate = false;
  var highlightedCell = null;
  var cameraAnimation = null;
  var materialCache = {};

  // ---------------------------------------------------------------- bootstrap

  function init() {
    container = document.getElementById('canvas-container');

    scene = new THREE.Scene();
    scene.background = new THREE.Color(0xf3f2ec);

    camera = new THREE.PerspectiveCamera(38, aspect(), 0.05, 200);
    camera.position.set(1.8, 1.2, 3.4);

    renderer = new THREE.WebGLRenderer({
      antialias: true,
      alpha: false,
      preserveDrawingBuffer: true
    });
    renderer.setPixelRatio(Math.min(window.devicePixelRatio || 1, 2));
    renderer.setSize(container.clientWidth, container.clientHeight);
    renderer.shadowMap.enabled = true;
    renderer.shadowMap.type = THREE.PCFSoftShadowMap;
    if (THREE.sRGBEncoding !== undefined) renderer.outputEncoding = THREE.sRGBEncoding;
    if (THREE.ACESFilmicToneMapping !== undefined) {
      renderer.toneMapping = THREE.ACESFilmicToneMapping;
      renderer.toneMappingExposure = 1.0;
    }
    container.appendChild(renderer.domElement);

    controls = new THREE.OrbitControls(camera, renderer.domElement);
    controls.enableDamping = true;
    controls.dampingFactor = 0.08;
    controls.screenSpacePanning = true;
    controls.minDistance = 0.4;
    controls.maxDistance = 40;
    controls.target.set(0, 0, 0);

    raycaster = new THREE.Raycaster();
    pointerVector = new THREE.Vector2();

    buildLighting();
    buildEnvironment();

    productGroup = new THREE.Group();
    dimensionGroup = new THREE.Group();
    dimensionGroup.visible = false;
    scene.add(productGroup);
    scene.add(dimensionGroup);

    window.addEventListener('resize', onResize);
    window.addEventListener('message', onHostMessage);

    // Tapping a part selects it. Orbiting must not count as a tap, so the
    // pointer has to come up close to where it went down.
    renderer.domElement.addEventListener('pointerdown', function (event) {
      pointerDownAt = { x: event.clientX, y: event.clientY };
    });
    renderer.domElement.addEventListener('pointerup', onPointerUp);

    animate();
    notifyFlutter('onEngineReady', { ok: true });
  }

  function aspect() {
    var w = container.clientWidth || 1;
    var h = container.clientHeight || 1;
    return w / h;
  }

  function onResize() {
    if (!renderer || !container) return;
    camera.aspect = aspect();
    camera.updateProjectionMatrix();
    renderer.setSize(container.clientWidth, container.clientHeight);
  }

  function buildLighting() {
    var hemi = new THREE.HemisphereLight(0xffffff, 0x8f9490, 0.40);
    hemi.position.set(0, 4, 0);
    scene.add(hemi);

    var key = new THREE.DirectionalLight(0xfff6e8, 1.05);
    key.position.set(3.2, 4.4, 4.0);
    key.castShadow = true;
    key.shadow.mapSize.width = 2048;
    key.shadow.mapSize.height = 2048;
    key.shadow.camera.near = 0.5;
    key.shadow.camera.far = 24;
    key.shadow.camera.left = -4;
    key.shadow.camera.right = 4;
    key.shadow.camera.top = 4;
    key.shadow.camera.bottom = -4;
    key.shadow.bias = -0.0006;
    scene.add(key);

    var fill = new THREE.DirectionalLight(0xdfe9f2, 0.34);
    fill.position.set(-4.0, 2.0, 2.4);
    scene.add(fill);

    var rim = new THREE.DirectionalLight(0xffffff, 0.22);
    rim.position.set(0, 1.5, -5);
    scene.add(rim);

    var shadowMat = new THREE.ShadowMaterial({ opacity: 0.18 });
    groundPlane = new THREE.Mesh(new THREE.PlaneGeometry(30, 30), shadowMat);
    groundPlane.rotation.x = -Math.PI / 2;
    groundPlane.receiveShadow = true;
    scene.add(groundPlane);
  }

  /* A small emissive room, rendered once into a PMREM cube map. This is what
   * gives the aluminium its satin gradient and the glass its reflections —
   * without it, metal reads as flat grey. */
  function buildEnvironment() {
    if (!THREE.PMREMGenerator) return;
    var envScene = new THREE.Scene();
    envScene.background = new THREE.Color(0xbfc6cc);

    var geo = new THREE.BoxGeometry(1, 1, 1);
    function panel(color, intensity, sx, sy, sz, px, py, pz) {
      var mat = new THREE.MeshBasicMaterial({ color: color });
      mat.color.multiplyScalar(intensity);
      var mesh = new THREE.Mesh(geo, mat);
      mesh.scale.set(sx, sy, sz);
      mesh.position.set(px, py, pz);
      envScene.add(mesh);
    }
    panel(0xffffff, 1.0, 12, 0.2, 12, 0, 6, 0);
    panel(0xf1e6d2, 2.6, 3.0, 0.1, 3.0, -2.4, 5.6, 1.2);
    panel(0xdcecff, 2.0, 3.0, 0.1, 3.0, 2.6, 5.6, -1.0);
    panel(0x9aa1a7, 0.6, 12, 8, 0.2, 0, 2, -6);
    panel(0xb9c0c6, 0.5, 0.2, 8, 12, -6, 2, 0);
    panel(0xb9c0c6, 0.5, 0.2, 8, 12, 6, 2, 0);

    pmrem = new THREE.PMREMGenerator(renderer);
    var target = pmrem.fromScene(envScene, 0.04);
    envTexture = target.texture;
    scene.environment = envTexture;
  }

  // ------------------------------------------------------------- scene build

  function updateScene(payload) {
    if (!payload) return;
    currentScene = payload;
    currentStyle = payload.style || currentStyle;
    rebuild();
  }

  function rebuild() {
    if (!currentScene) return;
    disposeGroup(productGroup);
    disposeGroup(dimensionGroup);
    materialCache = {};

    var materials = {};
    (currentScene.materials || []).forEach(function (m) {
      materials[m.key] = m;
    });

    var parts = currentScene.parts || [];
    for (var i = 0; i < parts.length; i++) {
      var mesh = buildPart(parts[i], materials[parts[i].material]);
      if (mesh) productGroup.add(mesh);
    }

    buildDimensions(currentScene.dimensions || []);

    // Stand the product on the ground plane.
    var heightM = (currentScene.height || 0) * MM;
    productGroup.position.y = heightM / 2 + 0.02;
    dimensionGroup.position.y = productGroup.position.y;
    if (groundPlane) groundPlane.position.y = 0;

    frameCamera();
  }

  function buildPart(part, materialSpec) {
    var geometry;
    var s = part.size;
    if (part.shape === 'cylinder') {
      geometry = new THREE.CylinderGeometry(s.x * MM, s.x * MM, s.y * MM, 24);
    } else {
      geometry = new THREE.BoxGeometry(
        Math.max(s.x, 0.1) * MM,
        Math.max(s.y, 0.1) * MM,
        Math.max(s.z, 0.1) * MM
      );
    }

    var material = resolveMaterial(part, materialSpec);
    var mesh = new THREE.Mesh(geometry, material);
    mesh.position.set(part.center.x * MM, part.center.y * MM, part.center.z * MM);
    if (part.rotation) {
      mesh.rotation.set(
        THREE.MathUtils.degToRad(part.rotation.x || 0),
        THREE.MathUtils.degToRad(part.rotation.y || 0),
        THREE.MathUtils.degToRad(part.rotation.z || 0)
      );
    }
    mesh.castShadow = part.role !== 'glass';
    mesh.receiveShadow = true;
    mesh.userData.role = part.role;
    mesh.userData.partId = part.id;
    mesh.userData.cellPath = part.cellPath || null;
    mesh.userData.materialKey = part.material;

    if (currentStyle === 'technical' && part.role !== 'glass') {
      var edges = new THREE.LineSegments(
        new THREE.EdgesGeometry(geometry, 25),
        new THREE.LineBasicMaterial({ color: 0x013e37, transparent: true, opacity: 0.55 })
      );
      mesh.add(edges);
    }
    return mesh;
  }

  function resolveMaterial(part, spec) {
    var key = (part.material || 'default') + '|' + currentStyle +
      (highlightedCell && part.cellPath === highlightedCell ? '|hl' : '');
    if (materialCache[key]) return materialCache[key];

    var color = spec ? spec.color : 0xb0b5ba;
    var material;

    if (currentStyle === 'technical') {
      var isGlass = spec && spec.transmission > 0;
      material = new THREE.MeshLambertMaterial({
        color: isGlass ? 0xcfe0e2 : color,
        transparent: isGlass,
        opacity: isGlass ? 0.28 : 1.0
      });
    } else if (spec && spec.transmission > 0) {
      // Glass is drawn with blended opacity plus a strong environment
      // reflection rather than raw transmission: physically-accurate
      // transmission renders a pane that is effectively invisible, which
      // reads as an empty hole in the frame instead of glazing.
      material = new THREE.MeshPhysicalMaterial({
        color: color,
        roughness: spec.roughness,
        metalness: 0.0,
        transparent: true,
        opacity: spec.opacity,
        clearcoat: 0.25 + spec.clearcoat * 0.75,
        clearcoatRoughness: 0.04,
        reflectivity: 0.4 + spec.clearcoat * 0.5,
        side: THREE.DoubleSide,
        depthWrite: false
      });
      if (envTexture) material.envMap = envTexture;
      material.envMapIntensity = 0.8 + spec.clearcoat * 1.2;
    } else {
      material = new THREE.MeshPhysicalMaterial({
        color: color,
        roughness: spec ? spec.roughness : 0.5,
        metalness: spec ? spec.metalness : 0.2,
        clearcoat: spec ? spec.clearcoat : 0.0,
        clearcoatRoughness: 0.25
      });
      if (envTexture) material.envMap = envTexture;
      material.envMapIntensity = 1.0;
    }

    if (highlightedCell && part.cellPath === highlightedCell) {
      material.emissive = new THREE.Color(0xffefb3);
      material.emissiveIntensity = 0.35;
    }

    materialCache[key] = material;
    return material;
  }

  // ------------------------------------------------------------- dimensions

  function buildDimensions(dims) {
    for (var i = 0; i < dims.length; i++) {
      var d = dims[i];
      var from = new THREE.Vector3(d.from.x * MM, d.from.y * MM, d.from.z * MM);
      var to = new THREE.Vector3(d.to.x * MM, d.to.y * MM, d.to.z * MM);

      var lineGeo = new THREE.BufferGeometry().setFromPoints([from, to]);
      var line = new THREE.Line(
        lineGeo,
        new THREE.LineBasicMaterial({ color: 0x013e37 })
      );
      dimensionGroup.add(line);

      var sprite = makeLabel(d.label);
      sprite.position.copy(from.clone().add(to).multiplyScalar(0.5));
      dimensionGroup.add(sprite);
    }
    dimensionGroup.visible = showDimensions;
  }

  function makeLabel(text) {
    var canvas = document.createElement('canvas');
    canvas.width = 512;
    canvas.height = 128;
    var ctx = canvas.getContext('2d');
    ctx.fillStyle = 'rgba(255,255,255,0.94)';
    roundRect(ctx, 8, 24, 496, 80, 16);
    ctx.fill();
    ctx.strokeStyle = '#013E37';
    ctx.lineWidth = 4;
    roundRect(ctx, 8, 24, 496, 80, 16);
    ctx.stroke();
    ctx.fillStyle = '#013E37';
    ctx.font = 'bold 52px -apple-system, "Segoe UI", Roboto, sans-serif';
    ctx.textAlign = 'center';
    ctx.textBaseline = 'middle';
    ctx.fillText(text, 256, 66);

    var texture = new THREE.CanvasTexture(canvas);
    texture.needsUpdate = true;
    var sprite = new THREE.Sprite(new THREE.SpriteMaterial({ map: texture, depthTest: false }));
    sprite.scale.set(0.42, 0.105, 1);
    return sprite;
  }

  function roundRect(ctx, x, y, w, h, r) {
    ctx.beginPath();
    ctx.moveTo(x + r, y);
    ctx.arcTo(x + w, y, x + w, y + h, r);
    ctx.arcTo(x + w, y + h, x, y + h, r);
    ctx.arcTo(x, y + h, x, y, r);
    ctx.arcTo(x, y, x + w, y, r);
    ctx.closePath();
  }

  // ----------------------------------------------------------------- picking

  function onPointerUp(event) {
    var start = pointerDownAt;
    pointerDownAt = null;
    if (!start) return;
    var dx = event.clientX - start.x;
    var dy = event.clientY - start.y;
    if (Math.sqrt(dx * dx + dy * dy) > 5) return; // that was an orbit, not a tap

    var rect = renderer.domElement.getBoundingClientRect();
    pointerVector.x = ((event.clientX - rect.left) / rect.width) * 2 - 1;
    pointerVector.y = -((event.clientY - rect.top) / rect.height) * 2 + 1;
    raycaster.setFromCamera(pointerVector, camera);

    var hits = raycaster.intersectObjects(productGroup.children, true);
    if (!hits.length) {
      notifyFlutter('onPartTapped', { role: null, cellPath: null, partId: null });
      return;
    }

    // Edge overlays are children of their mesh, so walk up to the part itself.
    var object = hits[0].object;
    while (object && !object.userData.role && object.parent) {
      object = object.parent;
    }
    notifyFlutter('onPartTapped', {
      role: object.userData.role || null,
      cellPath: object.userData.cellPath || null,
      partId: object.userData.partId || null
    });
  }

  // ------------------------------------------------------------------ camera

  function boundingRadius() {
    if (!currentScene) return 1.5;
    var w = (currentScene.width || 1000) * MM;
    var h = (currentScene.height || 1000) * MM;
    var d = (currentScene.depth || 100) * MM;
    return Math.sqrt(w * w + h * h + d * d) / 2;
  }

  function frameCamera() {
    var radius = boundingRadius();
    var distance = radius / Math.sin(THREE.MathUtils.degToRad(camera.fov) / 2) * 1.15;
    controls.target.set(0, productGroup.position.y, 0);
    setCameraTarget(
      new THREE.Vector3(distance * 0.55, productGroup.position.y + radius * 0.28, distance * 0.85),
      controls.target.clone(),
      false
    );
    controls.maxDistance = distance * 6;
  }

  function setCameraPreset(name) {
    var radius = boundingRadius();
    var distance = radius / Math.sin(THREE.MathUtils.degToRad(camera.fov) / 2) * 1.1;
    var centre = new THREE.Vector3(0, productGroup.position.y, 0);
    var position;
    switch (name) {
      case 'front': position = new THREE.Vector3(0, centre.y, distance); break;
      case 'back': position = new THREE.Vector3(0, centre.y, -distance); break;
      case 'left': position = new THREE.Vector3(-distance, centre.y, 0.001); break;
      case 'right': position = new THREE.Vector3(distance, centre.y, 0.001); break;
      case 'top': position = new THREE.Vector3(0.001, centre.y + distance, 0.001); break;
      default:
        position = new THREE.Vector3(distance * 0.55, centre.y + radius * 0.28, distance * 0.85);
    }
    setCameraTarget(position, centre, true);
  }

  function setCameraTarget(position, target, animated) {
    if (!animated) {
      camera.position.copy(position);
      controls.target.copy(target);
      controls.update();
      cameraAnimation = null;
      return;
    }
    cameraAnimation = {
      fromPos: camera.position.clone(),
      toPos: position,
      fromTarget: controls.target.clone(),
      toTarget: target,
      t: 0
    };
  }

  function stepCameraAnimation(delta) {
    if (!cameraAnimation) return;
    cameraAnimation.t = Math.min(1, cameraAnimation.t + delta * 2.2);
    var e = easeInOut(cameraAnimation.t);
    camera.position.lerpVectors(cameraAnimation.fromPos, cameraAnimation.toPos, e);
    controls.target.lerpVectors(cameraAnimation.fromTarget, cameraAnimation.toTarget, e);
    if (cameraAnimation.t >= 1) cameraAnimation = null;
  }

  function easeInOut(t) {
    return t < 0.5 ? 2 * t * t : -1 + (4 - 2 * t) * t;
  }

  // ------------------------------------------------------------------- loop

  var clock = new THREE.Clock();

  function animate() {
    requestAnimationFrame(animate);
    var delta = clock.getDelta();
    stepCameraAnimation(delta);
    if (autoRotate && !cameraAnimation) {
      productGroup.rotation.y += delta * 0.35;
      dimensionGroup.rotation.y = productGroup.rotation.y;
    }
    controls.update();
    renderer.render(scene, camera);
  }

  function disposeGroup(group) {
    for (var i = group.children.length - 1; i >= 0; i--) {
      var child = group.children[i];
      group.remove(child);
      child.traverse(function (node) {
        if (node.geometry) node.geometry.dispose();
        if (node.material) {
          if (node.material.map) node.material.map.dispose();
          node.material.dispose();
        }
      });
    }
  }

  // -------------------------------------------------------------- public API

  var api = {
    updateScene: function (payload) {
      updateScene(typeof payload === 'string' ? JSON.parse(payload) : payload);
    },
    setCameraPreset: function (name) { setCameraPreset(name); },
    setStyle: function (style) {
      if (style === currentStyle) return;
      currentStyle = style;
      rebuild();
    },
    toggleDimensions: function (visible) {
      showDimensions = !!visible;
      dimensionGroup.visible = showDimensions;
    },
    toggleAutoRotate: function (enabled) {
      autoRotate = !!enabled;
      if (!autoRotate) {
        productGroup.rotation.y = 0;
        dimensionGroup.rotation.y = 0;
      }
    },
    highlightCell: function (path) {
      highlightedCell = path || null;
      rebuild();
    },
    resetView: function () {
      autoRotate = false;
      productGroup.rotation.y = 0;
      dimensionGroup.rotation.y = 0;
      frameCamera();
    },
    requestSnapshot: function () {
      renderer.render(scene, camera);
      notifyFlutter('onSnapshotData', { dataUrl: renderer.domElement.toDataURL('image/png') });
    }
  };

  window.OpeningViewer = api;

  function onHostMessage(event) {
    var data = event.data;
    if (typeof data === 'string') {
      try { data = JSON.parse(data); } catch (e) { return; }
    }
    if (!data || !data.action) return;
    switch (data.action) {
      case 'updateScene': api.updateScene(data.scene); break;
      case 'setCameraPreset': api.setCameraPreset(data.preset); break;
      case 'setStyle': api.setStyle(data.style); break;
      case 'toggleDimensions': api.toggleDimensions(data.visible); break;
      case 'toggleAutoRotate': api.toggleAutoRotate(data.enabled); break;
      case 'highlightCell': api.highlightCell(data.cellPath); break;
      case 'resetView': api.resetView(); break;
      case 'requestSnapshot': api.requestSnapshot(); break;
    }
  }

  function notifyFlutter(handler, data) {
    if (window.flutter_inappwebview && window.flutter_inappwebview.callHandler) {
      window.flutter_inappwebview.callHandler(handler, data || {});
    } else if (window.parent && window.parent !== window) {
      window.parent.postMessage(JSON.stringify({ handler: handler, data: data || {} }), '*');
    }
  }

  if (document.readyState === 'complete' || document.readyState === 'interactive') {
    setTimeout(init, 0);
  } else {
    window.addEventListener('DOMContentLoaded', init);
  }
})();
