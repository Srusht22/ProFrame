/**
 * ProFrame Parametric 3D Engine
 *
 * Procedurally builds a door/window assembly from a flat configuration
 * object (see ProductConfiguration.to3DParams() on the Dart side). Nothing
 * here is a static/pre-baked model — every box in the scene is generated
 * from the current width/height/section/hardware values, so changing the
 * configuration actually regenerates the geometry.
 *
 * Runs inside a WebView (mobile/desktop) or an iframe (web) and talks to
 * Flutter over window.flutter_inappwebview.callHandler(...) / postMessage.
 */
(function () {
  'use strict';

  let scene, camera, renderer, controls, container;
  let assemblyGroup, dimensionGroup;
  let showDimensions = true;
  let autoRotate = false;

  let isAnimatingCamera = false;
  let camAnimT = 0;
  const CAM_ANIM_DURATION = 0.5;
  const camStartPos = new THREE.Vector3();
  const camStartLook = new THREE.Vector3();
  const camTargetPos = new THREE.Vector3();
  const camTargetLook = new THREE.Vector3();
  let currentLookAt = new THREE.Vector3(0, 0, 0);

  let currentConfig = {
    category: 'window',
    productType: 'sliding',
    width: 1200,
    height: 1500,
    frameDepth: 55,
    frameThickness: 45,
    frameMaterial: 'aluminum',
    hasDoorJamb: false,
    hasThreshold: false,
    leafArrangement: 'custom',
    leafCount: 0,
    primaryLeafRatio: 0.5,
    openingDirection: 'slideLeft',
    panelType: 'glass',
    glassType: 'clear',
    glassThickness: 6,
    glassPanes: 1,
    hingeCount: 3,
    handleModel: 'standardLever',
    handleColor: 'black',
    lockType: 'standardCylinder',
    hasPullHandle: false,
    frameColor: 'black',
    customHexColor: null,
    sections: 2,
    transomFractions: [],
    hasMosquitoNet: false
  };

  const FRAME_COLORS = {
    white: 0xf5f5f0,
    black: 0x1c1f1e,
    darkGreen: 0x013e37,
    woodFinish: 0x6b4a2f,
    anthracite: 0x383d3c,
    silver: 0xc7ccc9,
    bronze: 0x4a3b30,
    custom: 0x888888
  };

  const GLASS_DEFS = {
    clear: { color: 0xdcecf2, transmission: 0.92, opacity: 1.0, roughness: 0.04, metalness: 0.05, ior: 1.5 },
    frosted: { color: 0xeef2f2, transmission: 0.55, opacity: 0.97, roughness: 0.55, metalness: 0.0, ior: 1.48 },
    tinted: { color: 0x6d7a7e, transmission: 0.72, opacity: 1.0, roughness: 0.08, metalness: 0.08, ior: 1.5 },
    tempered: { color: 0xcfe1e8, transmission: 0.88, opacity: 1.0, roughness: 0.03, metalness: 0.05, ior: 1.5 },
    laminated: { color: 0xc7dbe2, transmission: 0.8, opacity: 1.0, roughness: 0.05, metalness: 0.05, ior: 1.51 },
    doubleGlazed: { color: 0xaecdd9, transmission: 0.78, opacity: 1.0, roughness: 0.05, metalness: 0.05, ior: 1.52 },
    tripleGlazed: { color: 0x9dc0cf, transmission: 0.7, opacity: 1.0, roughness: 0.06, metalness: 0.05, ior: 1.53 },
    custom: { color: 0xd8e4e8, transmission: 0.75, opacity: 1.0, roughness: 0.1, metalness: 0.05, ior: 1.5 }
  };

  const HARDWARE_COLOR_BY_FRAME_COLOR = {
    white: 0xd9d9d4,
    black: 0x222222,
    darkGreen: 0x0b2c27,
    woodFinish: 0x2c2c2c,
    anthracite: 0x2a2a2a,
    silver: 0xb9bcbc,
    bronze: 0x2c2420,
    custom: 0x2b2b2b
  };

  const CAMERA_PRESETS = ['perspective', 'front', 'back', 'left', 'right', 'top', 'bottom'];

  // ---------------------------------------------------------------------
  // Flutter bridge
  // ---------------------------------------------------------------------
  function notifyFlutter(handler, data) {
    try {
      if (window.flutter_inappwebview) {
        window.flutter_inappwebview.callHandler(handler, data || {});
      } else if (window.parent) {
        window.parent.postMessage(JSON.stringify({ handler: handler, data: data || {} }), '*');
      }
    } catch (e) {
      // Bridge not ready yet — safe to ignore.
    }
  }

  function handleBridgeAction(action, payload) {
    switch (action) {
      case 'updateConfiguration':
        updateConfiguration(payload.params || {});
        break;
      case 'setCameraPreset':
        setCameraPreset(payload.preset, false);
        break;
      case 'toggleDimensions':
        toggleDimensions(!!payload.visible);
        break;
      case 'toggleAutoRotate':
        toggleAutoRotate(!!payload.enabled);
        break;
      case 'resetView':
        resetView();
        break;
      case 'requestSnapshot':
        requestSnapshot();
        break;
    }
  }

  window.addEventListener('message', function (event) {
    let msg = event.data;
    if (typeof msg === 'string') {
      try {
        msg = JSON.parse(msg);
      } catch (e) {
        return;
      }
    }
    if (!msg || !msg.action) return;
    handleBridgeAction(msg.action, msg);
  });

  // ---------------------------------------------------------------------
  // Scene setup
  // ---------------------------------------------------------------------
  function init() {
    container = document.getElementById('canvas-container');
    const w = container.clientWidth || window.innerWidth;
    const h = container.clientHeight || window.innerHeight;

    scene = new THREE.Scene();
    scene.background = new THREE.Color(0xf3f2ec);

    camera = new THREE.PerspectiveCamera(38, w / h, 10, 30000);

    renderer = new THREE.WebGLRenderer({ antialias: true, preserveDrawingBuffer: true, alpha: false });
    renderer.setSize(w, h);
    renderer.setPixelRatio(Math.min(window.devicePixelRatio || 1, 2));
    renderer.shadowMap.enabled = true;
    renderer.shadowMap.type = THREE.PCFSoftShadowMap;
    renderer.toneMapping = THREE.ACESFilmicToneMapping;
    renderer.toneMappingExposure = 1.05;
    if ('outputEncoding' in renderer) {
      renderer.outputEncoding = THREE.sRGBEncoding;
    }
    container.appendChild(renderer.domElement);

    controls = new THREE.OrbitControls(camera, renderer.domElement);
    controls.enableDamping = true;
    controls.dampingFactor = 0.08;
    controls.minDistance = 300;
    controls.maxDistance = 12000;
    controls.target.set(0, 0, 0);

    setupLights();

    assemblyGroup = new THREE.Group();
    scene.add(assemblyGroup);
    dimensionGroup = new THREE.Group();
    scene.add(dimensionGroup);

    setCameraPreset('perspective', true);
    buildAssembly(currentConfig);

    window.addEventListener('resize', onResize);
    animate();

    notifyFlutter('onEngineReady', {});
  }

  function setupLights() {
    scene.add(new THREE.HemisphereLight(0xffffff, 0x39433f, 0.65));

    const key = new THREE.DirectionalLight(0xfff6e4, 0.95);
    key.position.set(1000, 1500, 1200);
    key.castShadow = true;
    key.shadow.mapSize.set(1024, 1024);
    key.shadow.camera.left = -1800;
    key.shadow.camera.right = 1800;
    key.shadow.camera.top = 1800;
    key.shadow.camera.bottom = -1800;
    key.shadow.camera.far = 6000;
    key.shadow.bias = -0.0005;
    scene.add(key);

    const fill = new THREE.DirectionalLight(0xbcd7e0, 0.32);
    fill.position.set(-1300, 700, -700);
    scene.add(fill);

    const rim = new THREE.PointLight(0xfff3d0, 0.3, 8000);
    rim.position.set(0, 1900, -1600);
    scene.add(rim);

    const ground = new THREE.Mesh(
      new THREE.PlaneGeometry(20000, 20000),
      new THREE.ShadowMaterial({ opacity: 0.12 })
    );
    ground.rotation.x = -Math.PI / 2;
    ground.position.y = -1600;
    ground.receiveShadow = true;
    scene.add(ground);
  }

  function onResize() {
    if (!container || !camera || !renderer) return;
    const w = container.clientWidth || window.innerWidth;
    const h = container.clientHeight || window.innerHeight;
    camera.aspect = w / h;
    camera.updateProjectionMatrix();
    renderer.setSize(w, h);
  }

  function animate() {
    requestAnimationFrame(animate);
    if (isAnimatingCamera) {
      camAnimT += 1 / 60 / CAM_ANIM_DURATION;
      const t = Math.min(camAnimT, 1);
      const eased = 1 - Math.pow(1 - t, 3);
      camera.position.lerpVectors(camStartPos, camTargetPos, eased);
      currentLookAt.lerpVectors(camStartLook, camTargetLook, eased);
      controls.target.copy(currentLookAt);
      if (t >= 1) isAnimatingCamera = false;
    }
    if (autoRotate && !isAnimatingCamera) {
      const angle = 0.0025;
      const p = camera.position;
      const x = p.x * Math.cos(angle) - p.z * Math.sin(angle);
      const z = p.x * Math.sin(angle) + p.z * Math.cos(angle);
      camera.position.set(x, p.y, z);
    }
    controls.update();
    renderer.render(scene, camera);
  }

  // ---------------------------------------------------------------------
  // Materials
  // ---------------------------------------------------------------------
  function parseHex(hexStr) {
    if (!hexStr) return null;
    const clean = hexStr.replace('#', '').trim();
    const value = parseInt(clean, 16);
    return isNaN(value) ? null : value;
  }

  function frameMaterial(config) {
    const custom = config.frameColor === 'custom' ? parseHex(config.customHexColor) : null;
    const hex = custom !== null ? custom : (FRAME_COLORS[config.frameColor] || FRAME_COLORS.black);
    const isMetal = config.frameMaterial === 'aluminum' || config.frameMaterial === 'steel';
    return new THREE.MeshStandardMaterial({
      color: hex,
      metalness: isMetal ? 0.55 : 0.08,
      roughness: isMetal ? 0.38 : 0.6
    });
  }

  function glassMaterial(config) {
    const def = GLASS_DEFS[config.glassType] || GLASS_DEFS.clear;
    return new THREE.MeshPhysicalMaterial({
      color: def.color,
      transmission: def.transmission,
      opacity: def.opacity,
      transparent: true,
      roughness: def.roughness,
      metalness: def.metalness,
      ior: def.ior,
      thickness: Math.max(config.glassThickness || 6, 3),
      side: THREE.DoubleSide
    });
  }

  function hardwareMaterial(config) {
    const hex = HARDWARE_COLOR_BY_FRAME_COLOR[config.handleColor] || 0x2b2b2b;
    return new THREE.MeshStandardMaterial({ color: hex, metalness: 0.8, roughness: 0.28 });
  }

  // ---------------------------------------------------------------------
  // Geometry helpers
  // ---------------------------------------------------------------------
  function clearGroup(group) {
    while (group.children.length) {
      const child = group.children.pop();
      if (child.geometry) child.geometry.dispose();
      if (child.material) {
        if (Array.isArray(child.material)) {
          child.material.forEach(function (m) { m.dispose(); });
        } else {
          child.material.dispose();
        }
      }
      group.remove(child);
    }
  }

  function addBox(parent, w, h, d, x, y, z, material) {
    const geometry = new THREE.BoxGeometry(Math.max(w, 1), Math.max(h, 1), Math.max(d, 1));
    const mesh = new THREE.Mesh(geometry, material);
    mesh.position.set(x, y, z);
    mesh.castShadow = true;
    mesh.receiveShadow = true;
    parent.add(mesh);
    return mesh;
  }

  function addCylinder(parent, radius, height, x, y, z, material, rotationZ) {
    const geometry = new THREE.CylinderGeometry(radius, radius, height, 12);
    const mesh = new THREE.Mesh(geometry, material);
    mesh.position.set(x, y, z);
    if (rotationZ) mesh.rotation.z = rotationZ;
    mesh.castShadow = true;
    parent.add(mesh);
    return mesh;
  }

  // ---------------------------------------------------------------------
  // Assembly construction — this is the procedural core.
  // ---------------------------------------------------------------------
  function buildAssembly(config) {
    clearGroup(assemblyGroup);

    const width = Math.max(config.width || 1200, 200);
    const height = Math.max(config.height || 1500, 200);
    const depth = Math.max(config.frameDepth || 55, 20);
    const maxThickness = Math.min(width, height) / 2 - 15;
    const frameThickness = Math.min(Math.max(config.frameThickness || 45, 20), Math.max(maxThickness, 20));

    const fMat = frameMaterial(config);
    const hMat = hardwareMaterial(config);

    // Outer frame — four beams forming the border (spec: Frame/Outer frame/Border).
    addBox(assemblyGroup, width, frameThickness, depth, 0, height / 2 - frameThickness / 2, 0, fMat);
    addBox(assemblyGroup, width, frameThickness, depth, 0, -height / 2 + frameThickness / 2, 0, fMat);
    addBox(assemblyGroup, frameThickness, height - frameThickness * 2, depth, -width / 2 + frameThickness / 2, 0, 0, fMat);
    addBox(assemblyGroup, frameThickness, height - frameThickness * 2, depth, width / 2 - frameThickness / 2, 0, 0, fMat);

    if (config.hasThreshold) {
      addBox(assemblyGroup, width, 26, depth + 24, 0, -height / 2 - 13, 0, fMat);
    }
    if (config.hasDoorJamb) {
      const jambDepth = depth + 50;
      addBox(assemblyGroup, width + 50, 32, jambDepth, 0, height / 2 + 16, -8, fMat);
      addBox(assemblyGroup, 32, height + 32, jambDepth, -width / 2 - 16, 0, -8, fMat);
      addBox(assemblyGroup, 32, height + 32, jambDepth, width / 2 + 16, 0, -8, fMat);
    }

    const innerWidth = width - frameThickness * 2;
    const innerHeight = height - frameThickness * 2;
    const isDoor = config.category === 'door';
    const sections = isDoor ? 1 : Math.max(1, Math.min(config.sections || 1, 8));
    const mullionW = Math.max(24, Math.min(46, innerWidth / Math.max(sections, 1) * 0.12));

    const colBoundaries = [];
    for (let i = 0; i <= sections; i++) {
      colBoundaries.push(-innerWidth / 2 + (innerWidth * i) / sections);
    }

    const transomFractions = (config.transomFractions || []).slice().sort(function (a, b) { return a - b; });
    const rowFractions = [0].concat(transomFractions).concat([1]);
    const rowBoundaries = rowFractions.map(function (f) { return innerHeight / 2 - innerHeight * f; });

    for (let i = 1; i < sections; i++) {
      addBox(assemblyGroup, mullionW, innerHeight, depth * 0.9, colBoundaries[i], 0, 0, fMat);
    }
    for (let i = 1; i < rowFractions.length - 1; i++) {
      addBox(assemblyGroup, innerWidth, mullionW, depth * 0.9, 0, rowBoundaries[i], 0, fMat);
    }

    for (let c = 0; c < sections; c++) {
      const left = colBoundaries[c] + (c > 0 ? mullionW / 2 : 0);
      const right = colBoundaries[c + 1] - (c < sections - 1 ? mullionW / 2 : 0);
      const cellWidth = Math.max(right - left, 40);
      const cellCenterX = (left + right) / 2;

      for (let r = 0; r < rowBoundaries.length - 1; r++) {
        const top = rowBoundaries[r] - (r > 0 ? mullionW / 2 : 0);
        const bottom = rowBoundaries[r + 1] + (r < rowBoundaries.length - 2 ? mullionW / 2 : 0);
        const cellHeight = Math.max(top - bottom, 40);
        const cellCenterY = (top + bottom) / 2;

        if (isDoor) {
          buildDoorLeaves(config, cellWidth, cellHeight, cellCenterX, cellCenterY, depth, fMat, hMat);
        } else {
          buildSash(config, cellWidth, cellHeight, cellCenterX, cellCenterY, depth, fMat);
        }
      }
    }

    if (config.hasMosquitoNet) {
      const netMat = new THREE.MeshStandardMaterial({
        color: 0x2c2c2c,
        transparent: true,
        opacity: 0.24,
        side: THREE.DoubleSide,
        roughness: 0.9
      });
      addBox(assemblyGroup, innerWidth - 6, innerHeight - 6, 3, 0, 0, depth / 2 + 16, netMat);
    }

    buildDimensions(width, height, depth);
  }

  function buildSash(config, w, h, cx, cy, depth, fMat) {
    const sashT = Math.min(30, w / 4, h / 4);
    addBox(assemblyGroup, w, sashT, depth * 0.7, cx, cy + h / 2 - sashT / 2, 5, fMat);
    addBox(assemblyGroup, w, sashT, depth * 0.7, cx, cy - h / 2 + sashT / 2, 5, fMat);
    addBox(assemblyGroup, sashT, h - sashT * 2, depth * 0.7, cx - w / 2 + sashT / 2, cy, 5, fMat);
    addBox(assemblyGroup, sashT, h - sashT * 2, depth * 0.7, cx + w / 2 - sashT / 2, cy, 5, fMat);

    const panelW = Math.max(w - sashT * 2, 10);
    const panelH = Math.max(h - sashT * 2, 10);
    if (config.panelType === 'glass') {
      addBox(assemblyGroup, panelW, panelH, Math.max(config.glassThickness || 6, 4), cx, cy, 5, glassMaterial(config));
    } else {
      addBox(assemblyGroup, panelW, panelH, 18, cx, cy, 5, fMat);
    }
  }

  function buildDoorLeaves(config, w, h, cx, cy, depth, fMat, hMat) {
    const leafCount = Math.max(config.leafCount || 1, 1);
    const arrangement = config.leafArrangement;
    const ratio = Math.min(Math.max(config.primaryLeafRatio || 0.5, 0.2), 0.8);
    const leaves = [];

    if (leafCount === 1) {
      leaves.push({ w: w, x: cx });
    } else if (arrangement === 'unequalDouble') {
      const w1 = w * ratio;
      const w2 = w - w1;
      leaves.push({ w: w1, x: cx - w / 2 + w1 / 2 });
      leaves.push({ w: w2, x: cx + w / 2 - w2 / 2 });
    } else {
      const each = w / leafCount;
      for (let i = 0; i < leafCount; i++) {
        leaves.push({ w: each, x: cx - w / 2 + each * (i + 0.5) });
      }
    }

    leaves.forEach(function (leaf, idx) {
      const stileT = Math.min(60, leaf.w / 5);
      const railT = Math.min(75, h / 6);

      addBox(assemblyGroup, leaf.w, railT, depth * 0.85, leaf.x, cy + h / 2 - railT / 2, 6, fMat);
      addBox(assemblyGroup, leaf.w, railT, depth * 0.85, leaf.x, cy - h / 2 + railT / 2, 6, fMat);
      addBox(assemblyGroup, stileT, h - railT * 2, depth * 0.85, leaf.x - leaf.w / 2 + stileT / 2, cy, 6, fMat);
      addBox(assemblyGroup, stileT, h - railT * 2, depth * 0.85, leaf.x + leaf.w / 2 - stileT / 2, cy, 6, fMat);

      const panelW = Math.max(leaf.w - stileT * 2, 10);
      const panelH = Math.max(h - railT * 2, 10);
      if (config.panelType === 'glass') {
        addBox(assemblyGroup, panelW, panelH, Math.max(config.glassThickness || 6, 4), leaf.x, cy, 6, glassMaterial(config));
      } else {
        addBox(assemblyGroup, panelW, panelH, 22, leaf.x, cy, 6, fMat);
      }

      const hingeOnLeft = leafCount === 1
        ? config.openingDirection !== 'rightHinge'
        : idx === 0;
      const hingeX = hingeOnLeft ? leaf.x - leaf.w / 2 + 8 : leaf.x + leaf.w / 2 - 8;
      const hingeCount = Math.max(Math.min(config.hingeCount || 3, 6), 2);
      for (let hi = 0; hi < hingeCount; hi++) {
        const t = (hi + 1) / (hingeCount + 1);
        const hy = cy + h / 2 - h * t;
        addCylinder(assemblyGroup, 7, 46, hingeX, hy, depth / 2 + 10, hMat, Math.PI / 2);
      }

      if (config.handleModel && config.handleModel !== 'none') {
        const handleX = hingeOnLeft ? leaf.x + leaf.w / 2 - 34 : leaf.x - leaf.w / 2 + 34;
        addBox(assemblyGroup, 16, 115, 24, handleX, cy - h * 0.12, depth / 2 + 17, hMat);
        if (config.hasPullHandle) {
          addCylinder(assemblyGroup, 12, h * 0.4, handleX, cy, depth / 2 + 26, hMat, 0);
        }
      }
      if (config.lockType && config.lockType !== 'none') {
        const lockX = hingeOnLeft ? leaf.x + leaf.w / 2 - 34 : leaf.x - leaf.w / 2 + 34;
        addBox(assemblyGroup, 36, 36, 12, lockX, cy - h * 0.12 - 42, depth / 2 + 11, hMat);
      }
    });
  }

  // ---------------------------------------------------------------------
  // Dimension overlay (3D equivalent of the 2D dimension lines).
  // ---------------------------------------------------------------------
  function makeLabelSprite(text) {
    const canvas = document.createElement('canvas');
    canvas.width = 256;
    canvas.height = 96;
    const ctx = canvas.getContext('2d');
    ctx.fillStyle = 'rgba(255,255,255,0.92)';
    ctx.fillRect(0, 0, canvas.width, canvas.height);
    ctx.strokeStyle = '#013E37';
    ctx.lineWidth = 4;
    ctx.strokeRect(2, 2, canvas.width - 4, canvas.height - 4);
    ctx.fillStyle = '#013E37';
    ctx.font = 'bold 44px sans-serif';
    ctx.textAlign = 'center';
    ctx.textBaseline = 'middle';
    ctx.fillText(text, canvas.width / 2, canvas.height / 2);
    const texture = new THREE.CanvasTexture(canvas);
    const material = new THREE.SpriteMaterial({ map: texture, depthTest: false });
    const sprite = new THREE.Sprite(material);
    sprite.scale.set(180, 68, 1);
    return sprite;
  }

  function buildDimensions(width, height, depth) {
    clearGroup(dimensionGroup);
    const lineMat = new THREE.LineBasicMaterial({ color: 0x013e37 });
    const offset = depth / 2 + 140;

    const topPoints = [
      new THREE.Vector3(-width / 2, height / 2 + 60, offset),
      new THREE.Vector3(width / 2, height / 2 + 60, offset)
    ];
    const topLine = new THREE.Line(new THREE.BufferGeometry().setFromPoints(topPoints), lineMat);
    dimensionGroup.add(topLine);
    const widthLabel = makeLabelSprite(Math.round(width) + ' mm');
    widthLabel.position.set(0, height / 2 + 100, offset);
    dimensionGroup.add(widthLabel);

    const sidePoints = [
      new THREE.Vector3(-width / 2 - 60, height / 2, offset),
      new THREE.Vector3(-width / 2 - 60, -height / 2, offset)
    ];
    const sideLine = new THREE.Line(new THREE.BufferGeometry().setFromPoints(sidePoints), lineMat);
    dimensionGroup.add(sideLine);
    const heightLabel = makeLabelSprite(Math.round(height) + ' mm');
    heightLabel.position.set(-width / 2 - 110, 0, offset);
    dimensionGroup.add(heightLabel);

    dimensionGroup.visible = showDimensions;
  }

  // ---------------------------------------------------------------------
  // Camera control
  // ---------------------------------------------------------------------
  function cameraDistanceFor(config) {
    return Math.max(config.width || 1200, config.height || 1500) * 1.7 + 500;
  }

  function setCameraPreset(preset, instant) {
    const d = cameraDistanceFor(currentConfig);
    let pos;
    switch (preset) {
      case 'front':
        pos = new THREE.Vector3(0, 0, d);
        break;
      case 'back':
        pos = new THREE.Vector3(0, 0, -d);
        break;
      case 'left':
        pos = new THREE.Vector3(-d, 0, 0.01);
        break;
      case 'right':
        pos = new THREE.Vector3(d, 0, 0.01);
        break;
      case 'top':
        pos = new THREE.Vector3(0.01, d, 0.01);
        break;
      case 'bottom':
        pos = new THREE.Vector3(0.01, -d, 0.01);
        break;
      case 'perspective':
      default:
        pos = new THREE.Vector3(d * 0.62, d * 0.5, d * 0.78);
        break;
    }
    const look = new THREE.Vector3(0, 0, 0);

    if (instant || !camera) {
      if (camera) {
        camera.position.copy(pos);
        camera.lookAt(look);
      }
      if (controls) controls.target.copy(look);
      currentLookAt.copy(look);
      isAnimatingCamera = false;
      return;
    }

    camStartPos.copy(camera.position);
    camStartLook.copy(currentLookAt);
    camTargetPos.copy(pos);
    camTargetLook.copy(look);
    camAnimT = 0;
    isAnimatingCamera = true;
  }

  function resetView() {
    setCameraPreset('perspective', false);
  }

  function toggleDimensions(visible) {
    showDimensions = visible;
    if (dimensionGroup) dimensionGroup.visible = visible;
  }

  function toggleAutoRotate(enabled) {
    autoRotate = enabled;
  }

  function requestSnapshot() {
    if (!renderer) return;
    try {
      const dataUrl = renderer.domElement.toDataURL('image/png');
      notifyFlutter('onSnapshotData', { dataUrl: dataUrl });
    } catch (e) {
      notifyFlutter('onSnapshotData', { dataUrl: null, error: String(e) });
    }
  }

  // ---------------------------------------------------------------------
  // Configuration update entry point.
  // ---------------------------------------------------------------------
  function updateConfiguration(params) {
    currentConfig = Object.assign({}, currentConfig, params || {});
    if (!scene) return;
    buildAssembly(currentConfig);
  }

  window.ConfiguratorBridge = {
    updateConfiguration: updateConfiguration,
    setCameraPreset: function (preset) { setCameraPreset(preset, false); },
    toggleDimensions: toggleDimensions,
    toggleAutoRotate: toggleAutoRotate,
    resetView: resetView,
    requestSnapshot: requestSnapshot
  };

  if (document.readyState === 'complete' || document.readyState === 'interactive') {
    setTimeout(init, 0);
  } else {
    document.addEventListener('DOMContentLoaded', init);
  }
})();
