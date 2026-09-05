/**
 * ProFrame Parametric 3D Engine
 * High-performance, real-time procedural window geometry with architectural studio lighting.
 */

(function () {
  'use strict';

  let scene, camera, renderer, controls;
  let windowAssemblyGroup, dimensionGroup;
  let currentConfig = {
    width: 1200,
    height: 1500,
    depth: 50,
    sections: 2,
    style: 'sliding',
    frameColor: 'black',
    customHexColor: null,
    glassType: 'clear',
    handleType: 'standardPull',
    handleColor: 'black',
    openingDirection: 'left',
    showDimensions: true
  };

  let isAnimatingCamera = false;
  let camTargetPos = new THREE.Vector3();
  let camTargetLookAt = new THREE.Vector3();
  let camStartPos = new THREE.Vector3();
  let camStartLookAt = new THREE.Vector3();
  let camAnimProgress = 0;
  const CAM_ANIM_DURATION = 0.45;

  let materials = {};

  const PROFILES = {
    outerFrameWidth: 55,
    mullionWidth: 46,
    sashProfileWidth: 48,
    sashDepth: 32,
    glassThickness: 6,
    trackOffsetZ: 14
  };

  const FRAME_COLORS = {
    white: 0xf8fafc,
    black: 0x18191c,
    anthraciteGray: 0x33383f,
    bronzeBrown: 0x483a30,
    anodizedSilver: 0xc8cbd0
  };

  const GLASS_PROPERTIES = {
    clear: {
      color: 0xecf6fc,
      transmission: 0.92,
      opacity: 1.0,
      transparent: true,
      roughness: 0.04,
      ior: 1.52,
      metalness: 0.05
    },
    tintedGray: {
      color: 0x5a636a,
      transmission: 0.76,
      opacity: 1.0,
      transparent: true,
      roughness: 0.06,
      ior: 1.52,
      metalness: 0.08
    },
    reflectiveBlue: {
      color: 0x3b82f6,
      transmission: 0.62,
      opacity: 1.0,
      transparent: true,
      roughness: 0.07,
      ior: 1.56,
      metalness: 0.48
    },
    frostedPrivacy: {
      color: 0xe2e8f0,
      transmission: 0.82,
      opacity: 0.96,
      transparent: true,
      roughness: 0.58,
      ior: 1.48,
      metalness: 0.0
    },
    solarDark: {
      color: 0x1e242a,
      transmission: 0.45,
      opacity: 1.0,
      transparent: true,
      roughness: 0.05,
      ior: 1.52,
      metalness: 0.12
    },
    lowEGreen: {
      color: 0xa7f3d0,
      transmission: 0.86,
      opacity: 1.0,
      transparent: true,
      roughness: 0.05,
      ior: 1.54,
      metalness: 0.12
    },
    flutedReeded: {
      color: 0xe0e7ff,
      transmission: 0.75,
      opacity: 0.95,
      transparent: true,
      roughness: 0.42,
      ior: 1.50,
      metalness: 0.04
    },
    opaquePanel: {
      color: 0x475569,
      transmission: 0.0,
      opacity: 1.0,
      transparent: false,
      roughness: 0.45,
      ior: 1.0,
      metalness: 0.65
    }
  };

  function init() {
    const container = document.getElementById('canvas-container');
    const width = container.clientWidth || window.innerWidth;
    const height = container.clientHeight || window.innerHeight;

    // 1. Scene with High-Contrast Architectural Studio Background
    scene = new THREE.Scene();
    scene.background = new THREE.Color(0xf1f5f9); // Clean studio off-white/light-slate

    // 2. Camera
    camera = new THREE.PerspectiveCamera(40, width / height, 10, 20000);
    camera.position.set(1300, 1600, 2600);

    // 3. Renderer
    renderer = new THREE.WebGLRenderer({ antialias: true, preserveDrawingBuffer: true, alpha: false });
    renderer.setSize(width, height);
    renderer.setPixelRatio(Math.min(window.devicePixelRatio, 2));
    renderer.toneMapping = THREE.ACESFilmicToneMapping;
    renderer.toneMappingExposure = 1.08;
    renderer.shadowMap.enabled = true;
    renderer.shadowMap.type = THREE.PCFSoftShadowMap;
    container.appendChild(renderer.domElement);

    // 4. Orbit Controls
    controls = new THREE.OrbitControls(camera, renderer.domElement);
    controls.enableDamping = true;
    controls.dampingFactor = 0.07;
    controls.maxPolarAngle = Math.PI / 2 + 0.05;
    controls.minDistance = 300;
    controls.maxDistance = 10000;
    controls.target.set(0, 750, 0);

    // 5. Lighting & Studio Environment
    setupLighting();
    setupGroundGrid();

    // 6. Geometry Groups
    windowAssemblyGroup = new THREE.Group();
    scene.add(windowAssemblyGroup);

    dimensionGroup = new THREE.Group();
    scene.add(dimensionGroup);

    // 7. Materials & Window Build
    initMaterials();
    rebuildWindow(currentConfig);
    frameCameraToObject(currentConfig.width, currentConfig.height, true);

    // 8. Event Listeners
    window.addEventListener('resize', onWindowResize, false);

    // 9. Animation Loop
    let lastTime = performance.now();
    function animate(currentTime) {
      requestAnimationFrame(animate);
      const delta = (currentTime - lastTime) / 1000;
      lastTime = currentTime;

      if (isAnimatingCamera) {
        camAnimProgress += delta / CAM_ANIM_DURATION;
        if (camAnimProgress >= 1.0) {
          camAnimProgress = 1.0;
          isAnimatingCamera = false;
        }
        const t = 1 - Math.pow(1 - camAnimProgress, 3);
        camera.position.lerpVectors(camStartPos, camTargetPos, t);
        controls.target.lerpVectors(camStartLookAt, camTargetLookAt, t);
      }

      controls.update();
      renderer.render(scene, camera);
    }
    requestAnimationFrame(animate);

    notifyFlutter('onEngineReady', { status: 'ready' });
  }

  function setupLighting() {
    // Hemispheric Sky/Ground Light
    const hemiLight = new THREE.HemisphereLight(0xffffff, 0xdbeafe, 0.85);
    scene.add(hemiLight);

    // Main Studio Key Light
    const keyLight = new THREE.DirectionalLight(0xffffff, 1.15);
    keyLight.position.set(1600, 3000, 2400);
    keyLight.castShadow = true;
    keyLight.shadow.mapSize.width = 2048;
    keyLight.shadow.mapSize.height = 2048;
    keyLight.shadow.camera.near = 100;
    keyLight.shadow.camera.far = 8000;
    const d = 2600;
    keyLight.shadow.camera.left = -d;
    keyLight.shadow.camera.right = d;
    keyLight.shadow.camera.top = d;
    keyLight.shadow.camera.bottom = -d;
    keyLight.shadow.bias = -0.0003;
    scene.add(keyLight);

    // Fill Light
    const fillLight = new THREE.DirectionalLight(0xe2e8f0, 0.55);
    fillLight.position.set(-2000, 1500, -1200);
    scene.add(fillLight);

    // Subtle Rim Light
    const rimLight = new THREE.DirectionalLight(0xffffff, 0.4);
    rimLight.position.set(0, 1800, -2500);
    scene.add(rimLight);
  }

  function setupGroundGrid() {
    // Soft Ground Shadow
    const planeGeo = new THREE.PlaneGeometry(12000, 12000);
    const planeMat = new THREE.ShadowMaterial({ opacity: 0.18 });
    const ground = new THREE.Mesh(planeGeo, planeMat);
    ground.rotation.x = -Math.PI / 2;
    ground.position.y = -1;
    ground.receiveShadow = true;
    scene.add(ground);

    // Clean Studio Floor Grid
    const grid = new THREE.GridHelper(8000, 40, 0xcbd5e1, 0xe2e8f0);
    grid.position.y = 0;
    scene.add(grid);
  }

  function initMaterials() {
    materials.frame = new THREE.MeshStandardMaterial({
      color: FRAME_COLORS[currentConfig.frameColor] || 0x18191c,
      roughness: 0.38,
      metalness: 0.72
    });

    const gp = GLASS_PROPERTIES[currentConfig.glassType] || GLASS_PROPERTIES.clear;
    materials.glass = new THREE.MeshPhysicalMaterial({
      color: gp.color,
      transmission: gp.transmission,
      opacity: gp.opacity,
      transparent: gp.transparent,
      roughness: gp.roughness,
      ior: gp.ior,
      metalness: gp.metalness,
      reflectivity: 0.55
    });

    materials.gasket = new THREE.MeshStandardMaterial({
      color: 0x1e293b,
      roughness: 0.95,
      metalness: 0.02
    });

    materials.hardwareChrome = new THREE.MeshStandardMaterial({
      color: 0xd8d8d8,
      roughness: 0.18,
      metalness: 0.95
    });

    materials.hardwareBlack = new THREE.MeshStandardMaterial({
      color: 0x1e2124,
      roughness: 0.35,
      metalness: 0.8
    });

    materials.hardwareWhite = new THREE.MeshStandardMaterial({
      color: 0xf8fafc,
      roughness: 0.45,
      metalness: 0.15
    });
  }

  function updateMaterials(config) {
    let hexColor = FRAME_COLORS[config.frameColor];
    if (config.customHexColor) {
      hexColor = parseInt(config.customHexColor.replace('#', '0x'), 16);
    }
    if (materials.frame) {
      materials.frame.color.setHex(hexColor || 0x18191c);
      if (config.frameColor === 'white') {
        materials.frame.metalness = 0.15;
        materials.frame.roughness = 0.45;
      } else if (config.frameColor === 'anodizedSilver') {
        materials.frame.metalness = 0.9;
        materials.frame.roughness = 0.25;
      } else {
        materials.frame.metalness = 0.75;
        materials.frame.roughness = 0.36;
      }
      materials.frame.needsUpdate = true;
    }

    const gp = GLASS_PROPERTIES[config.glassType] || GLASS_PROPERTIES.clear;
    if (materials.glass) {
      materials.glass.color.setHex(gp.color);
      materials.glass.transmission = gp.transmission;
      materials.glass.roughness = gp.roughness;
      materials.glass.ior = gp.ior;
      materials.glass.metalness = gp.metalness;
      materials.glass.needsUpdate = true;
    }
  }

  function rebuildWindow(config) {
    while (windowAssemblyGroup.children.length > 0) {
      const obj = windowAssemblyGroup.children[0];
      if (obj.geometry) obj.geometry.dispose();
      windowAssemblyGroup.remove(obj);
    }

    updateMaterials(config);

    const W = Math.max(300, config.width);
    const H = Math.max(300, config.height);
    const D = Math.max(30, config.depth || 50);
    const sections = Math.max(1, Math.min(12, config.sections || 2));
    const style = config.style || 'sliding';
    const productType = config.productType || 'window';
    const isDoor = productType === 'door';
    const isPartition = productType === 'partition';
    const isCabinet = productType === 'cabinet';

    const frameW = isPartition ? 38 : PROFILES.outerFrameWidth;
    const mullionW = isPartition ? 34 : PROFILES.mullionWidth;
    const sashW = isPartition ? 36 : PROFILES.sashProfileWidth;
    const sashD = isCabinet ? D * 0.9 : PROFILES.sashDepth;

    const frameGroup = new THREE.Group();

    // 1. Left Jamb
    const leftJamb = createBox(frameW, H, D, materials.frame);
    leftJamb.position.set(-W / 2 + frameW / 2, H / 2, 0);
    frameGroup.add(leftJamb);

    // 2. Right Jamb
    const rightJamb = createBox(frameW, H, D, materials.frame);
    rightJamb.position.set(W / 2 - frameW / 2, H / 2, 0);
    frameGroup.add(rightJamb);

    // 3. Top Header
    const innerW = W - 2 * frameW;
    const topHeader = createBox(innerW, frameW, D, materials.frame);
    topHeader.position.set(0, H - frameW / 2, 0);
    frameGroup.add(topHeader);

    // 4. Bottom Sill / Threshold
    const sillH = isDoor ? 16 : frameW;
    const sillD = isDoor ? D + 10 : (D + 15);
    const bottomSill = createBox(innerW, sillH, sillD, materials.frame);
    bottomSill.position.set(0, sillH / 2, isDoor ? 0 : 7.5);
    frameGroup.add(bottomSill);

    windowAssemblyGroup.add(frameGroup);

    // If Cabinet: Add back panel and interior glass shelf
    if (isCabinet) {
      const backPanel = createBox(innerW, H - 2 * frameW, 6, materials.frame);
      backPanel.position.set(0, H / 2, -D / 2 + 3);
      windowAssemblyGroup.add(backPanel);

      const shelf = createBox(innerW - 10, 8, D - 30, materials.glass);
      shelf.position.set(0, H / 2, 0);
      windowAssemblyGroup.add(shelf);
    }

    // Mullions & Sections
    const netOpenW = innerW - (sections - 1) * mullionW;
    const sectionW = netOpenW / sections;
    const innerH = H - frameW - sillH;
    const innerCenterY = sillH + innerH / 2;

    if (sections > 1) {
      for (let i = 0; i < sections - 1; i++) {
        const mullionX = -innerW / 2 + (i + 1) * sectionW + i * mullionW + mullionW / 2;
        const mullion = createBox(mullionW, innerH, D - 4, materials.frame);
        mullion.position.set(mullionX, innerCenterY, 0);
        windowAssemblyGroup.add(mullion);
      }
    }

    for (let k = 0; k < sections; k++) {
      const secCenterX = -innerW / 2 + k * (sectionW + mullionW) + sectionW / 2;
      const secCenterY = innerCenterY;

      if (style === 'fixed') {
        const glassW = sectionW - 12;
        const glassH = innerH - 12;
        const glass = createBox(glassW, glassH, PROFILES.glassThickness, materials.glass);
        glass.position.set(secCenterX, secCenterY, 0);
        windowAssemblyGroup.add(glass);

        const gasket = createFrameBorder(sectionW - 4, innerH - 4, 8, 12, materials.gasket);
        gasket.position.set(secCenterX, secCenterY, 0);
        windowAssemblyGroup.add(gasket);

      } else if (style === 'sliding') {
        const trackZ = (k % 2 === 0) ? PROFILES.trackOffsetZ : -PROFILES.trackOffsetZ;
        const sashWidth = sectionW + (sections > 1 ? 12 : 0);
        const sashHeight = innerH - 8;

        const sashGroup = new THREE.Group();
        sashGroup.position.set(secCenterX, secCenterY, trackZ);

        const sashFrame = createFrameBorder(sashWidth, sashHeight, sashW, sashD, materials.frame);
        sashGroup.add(sashFrame);

        const glassW = sashWidth - 2 * sashW + 10;
        const glassH = sashHeight - 2 * sashW + 10;
        const glass = createBox(glassW, glassH, PROFILES.glassThickness, materials.glass);
        sashGroup.add(glass);

        if (config.handleType && config.handleType !== 'none') {
          const handleMat = getHandleMaterial(config.handleColor);
          const handleSide = (k % 2 === 0) ? 1 : -1;
          const handleX = handleSide * (sashWidth / 2 - sashW / 2);
          const handleY = isDoor ? (1000 - secCenterY) : -20;
          const handle = createHandle(config.handleType, handleMat, handleSide);
          handle.position.set(handleX, handleY, (k % 2 === 0 ? sashD / 2 : -sashD / 2));
          if (k % 2 !== 0) handle.rotation.y = Math.PI;
          sashGroup.add(handle);
        }

        windowAssemblyGroup.add(sashGroup);

      } else { // Casement / Tilt & Turn / Hinged Door
        const sashWidth = sectionW - 6;
        const sashHeight = innerH - 6;

        const sashGroup = new THREE.Group();
        sashGroup.position.set(secCenterX, secCenterY, 4);

        const sashFrame = createFrameBorder(sashWidth, sashHeight, sashW, sashD, materials.frame);
        sashGroup.add(sashFrame);

        // For Hinged Doors: Add bottom solid kickplate
        if (isDoor) {
          const kickH = 220;
          const kickplate = createBox(sashWidth - 2 * sashW + 8, kickH, sashD - 4, materials.frame);
          kickplate.position.set(0, -sashHeight / 2 + sashW + kickH / 2 - 4, 0);
          sashGroup.add(kickplate);

          const glassW = sashWidth - 2 * sashW + 10;
          const glassH = sashHeight - 2 * sashW - kickH + 6;
          const glass = createBox(glassW, glassH, PROFILES.glassThickness, materials.glass);
          glass.position.set(0, kickH / 2, 0);
          sashGroup.add(glass);
        } else {
          const glassW = sashWidth - 2 * sashW + 10;
          const glassH = sashHeight - 2 * sashW + 10;
          const glass = createBox(glassW, glassH, PROFILES.glassThickness, materials.glass);
          sashGroup.add(glass);
        }

        if (config.handleType && config.handleType !== 'none') {
          const handleMat = getHandleMaterial(config.handleColor);
          const handleSide = (config.openingDirection === 'right' || k % 2 === 1) ? -1 : 1;
          const handleX = handleSide * (sashWidth / 2 - sashW / 2);
          const handleY = isDoor ? (1000 - secCenterY) : 0;
          const handle = createHandle(config.handleType, handleMat, handleSide);
          handle.position.set(handleX, handleY, sashD / 2);
          sashGroup.add(handle);
        }

        windowAssemblyGroup.add(sashGroup);
      }
    }

    rebuildDimensions(W, H, D, sections, config.showDimensions !== false);
  }

  function getHandleMaterial(handleColor) {
    if (handleColor === 'white') return materials.hardwareWhite;
    if (handleColor === 'silver') return materials.hardwareChrome;
    return materials.hardwareBlack;
  }

  function createFrameBorder(outerW, outerH, profileW, profileD, mat) {
    const group = new THREE.Group();

    const top = createBox(outerW, profileW, profileD, mat);
    top.position.set(0, outerH / 2 - profileW / 2, 0);
    group.add(top);

    const bottom = createBox(outerW, profileW, profileD, mat);
    bottom.position.set(0, -outerH / 2 + profileW / 2, 0);
    group.add(bottom);

    const innerH = outerH - 2 * profileW;
    const left = createBox(profileW, innerH, profileD, mat);
    left.position.set(-outerW / 2 + profileW / 2, 0, 0);
    group.add(left);

    const right = createBox(profileW, innerH, profileD, mat);
    right.position.set(outerW / 2 - profileW / 2, 0, 0);
    group.add(right);

    return group;
  }

  function createHandle(type, mat, orientation) {
    const handleGroup = new THREE.Group();

    if (type === 'leverHandle') {
      const rosette = createBox(28, 55, 6, mat);
      rosette.position.set(0, 0, 3);
      handleGroup.add(rosette);

      const post = createBox(16, 16, 32, mat);
      post.position.set(0, 5, 19);
      handleGroup.add(post);

      const lever = createBox(110, 16, 12, mat);
      lever.position.set(orientation * 45, 5, 36);
      handleGroup.add(lever);

    } else if (type === 'modernBar') {
      const topPost = createBox(20, 20, 36, mat);
      topPost.position.set(0, 160, 18);
      handleGroup.add(topPost);

      const btmPost = createBox(20, 20, 36, mat);
      btmPost.position.set(0, -160, 18);
      handleGroup.add(btmPost);

      const bar = createBox(22, 450, 18, mat);
      bar.position.set(0, 0, 42);
      handleGroup.add(bar);

    } else if (type === 'lockAndKey') {
      const escutcheon = createBox(32, 160, 8, mat);
      escutcheon.position.set(0, 0, 4);
      handleGroup.add(escutcheon);

      const lever = createBox(105, 16, 12, mat);
      lever.position.set(orientation * 42, 35, 24);
      handleGroup.add(lever);

      const cylinder = createBox(14, 28, 12, materials.gasket);
      cylinder.position.set(0, -35, 6);
      handleGroup.add(cylinder);

    } else if (type === 'flushLatch') {
      const face = createBox(24, 160, 4, mat);
      face.position.set(0, 0, 2);
      handleGroup.add(face);

      const pullPocket = createBox(14, 80, 8, materials.gasket);
      pullPocket.position.set(0, 0, 2);
      handleGroup.add(pullPocket);

    } else {
      const topPost = createBox(16, 16, 28, mat);
      topPost.position.set(0, 65, 14);
      handleGroup.add(topPost);

      const btmPost = createBox(16, 16, 28, mat);
      btmPost.position.set(0, -65, 14);
      handleGroup.add(btmPost);

      const bar = createBox(16, 180, 14, mat);
      bar.position.set(0, 0, 32);
      handleGroup.add(bar);
    }

    return handleGroup;
  }

  function createBox(w, h, d, mat) {
    const geo = new THREE.BoxGeometry(w, h, d);
    const mesh = new THREE.Mesh(geo, mat);
    mesh.castShadow = true;
    mesh.receiveShadow = true;
    return mesh;
  }

  function rebuildDimensions(W, H, D, sections, visible) {
    while (dimensionGroup.children.length > 0) {
      const obj = dimensionGroup.children[0];
      if (obj.geometry) obj.geometry.dispose();
      if (obj.material) {
        if (obj.material.map) obj.material.map.dispose();
        obj.material.dispose();
      }
      dimensionGroup.remove(obj);
    }

    if (!visible) return;

    // High contrast architectural blue dimension lines
    const lineMat = new THREE.LineBasicMaterial({
      color: 0x0284c7,
      linewidth: 2,
      depthTest: true
    });

    const offsetDist = 110;

    // 1. TOP WIDTH DIMENSION
    const yTop = H + offsetDist;
    const topPoints = [
      new THREE.Vector3(-W / 2, H + 5, 0),
      new THREE.Vector3(-W / 2, yTop + 25, 0),
      new THREE.Vector3(W / 2, H + 5, 0),
      new THREE.Vector3(W / 2, yTop + 25, 0),
      new THREE.Vector3(-W / 2, yTop, 0),
      new THREE.Vector3(W / 2, yTop, 0),
      new THREE.Vector3(-W / 2, yTop, 0),
      new THREE.Vector3(-W / 2 + 25, yTop + 14, 0),
      new THREE.Vector3(-W / 2, yTop, 0),
      new THREE.Vector3(-W / 2 + 25, yTop - 14, 0),
      new THREE.Vector3(W / 2, yTop, 0),
      new THREE.Vector3(W / 2 - 25, yTop + 14, 0),
      new THREE.Vector3(W / 2, yTop, 0),
      new THREE.Vector3(W / 2 - 25, yTop - 14, 0)
    ];

    const topGeo = new THREE.BufferGeometry().setFromPoints(topPoints);
    const topLine = new THREE.LineSegments(topGeo, lineMat);
    dimensionGroup.add(topLine);

    const widthSprite = createTextSprite(`${Math.round(W)} mm`);
    widthSprite.position.set(0, yTop + 45, 0);
    dimensionGroup.add(widthSprite);

    // 2. LEFT HEIGHT DIMENSION
    const xLeft = -W / 2 - offsetDist;
    const leftPoints = [
      new THREE.Vector3(-W / 2 - 5, 0, 0),
      new THREE.Vector3(xLeft - 25, 0, 0),
      new THREE.Vector3(-W / 2 - 5, H, 0),
      new THREE.Vector3(xLeft - 25, H, 0),
      new THREE.Vector3(xLeft, 0, 0),
      new THREE.Vector3(xLeft, H, 0),
      new THREE.Vector3(xLeft, 0, 0),
      new THREE.Vector3(xLeft + 14, 25, 0),
      new THREE.Vector3(xLeft, 0, 0),
      new THREE.Vector3(xLeft - 14, 25, 0),
      new THREE.Vector3(xLeft, H, 0),
      new THREE.Vector3(xLeft + 14, H - 25, 0),
      new THREE.Vector3(xLeft, H, 0),
      new THREE.Vector3(xLeft - 14, H - 25, 0)
    ];

    const leftGeo = new THREE.BufferGeometry().setFromPoints(leftPoints);
    const leftLine = new THREE.LineSegments(leftGeo, lineMat);
    dimensionGroup.add(leftLine);

    const heightSprite = createTextSprite(`${Math.round(H)} mm`);
    heightSprite.position.set(xLeft - 60, H / 2, 0);
    dimensionGroup.add(heightSprite);
  }

  function createTextSprite(text) {
    const canvas = document.createElement('canvas');
    canvas.width = 512;
    canvas.height = 160;
    const ctx = canvas.getContext('2d');

    // High contrast rounded badge: deep slate card with cyan border
    ctx.fillStyle = '#0f172a';
    ctx.strokeStyle = '#0284c7';
    ctx.lineWidth = 6;

    const x = 30, y = 20, w = 452, h = 120, r = 24;
    ctx.beginPath();
    ctx.moveTo(x + r, y);
    ctx.lineTo(x + w - r, y);
    ctx.quadraticCurveTo(x + w, y, x + w, y + r);
    ctx.lineTo(x + w, y + h - r);
    ctx.quadraticCurveTo(x + w, y + h, x + w - r, y + h);
    ctx.lineTo(x + r, y + h);
    ctx.quadraticCurveTo(x, y + h, x, y + h - r);
    ctx.lineTo(x, y + r);
    ctx.quadraticCurveTo(x, y, x + r, y);
    ctx.closePath();
    ctx.fill();
    ctx.stroke();

    ctx.font = 'bold 52px system-ui, -apple-system, sans-serif';
    ctx.fillStyle = '#f8fafc';
    ctx.textAlign = 'center';
    ctx.textBaseline = 'middle';
    ctx.fillText(text, 256, 80);

    const texture = new THREE.CanvasTexture(canvas);
    texture.minFilter = THREE.LinearFilter;
    const spriteMat = new THREE.SpriteMaterial({ map: texture, depthTest: false });
    const sprite = new THREE.Sprite(spriteMat);
    sprite.scale.set(160, 50, 1);
    return sprite;
  }

  function frameCameraToObject(W, H, immediate) {
    const maxDim = Math.max(W, H);
    const fov = camera.fov * (Math.PI / 180);
    let cameraDistance = (maxDim / 2) / Math.tan(fov / 2) * 1.45;
    cameraDistance = Math.max(cameraDistance, 1200);

    const targetPos = new THREE.Vector3(
      cameraDistance * 0.55,
      H / 2 + cameraDistance * 0.25,
      cameraDistance * 0.95
    );
    const targetLookAt = new THREE.Vector3(0, H / 2, 0);

    if (immediate) {
      camera.position.copy(targetPos);
      controls.target.copy(targetLookAt);
      controls.update();
    } else {
      animateCameraTo(targetPos, targetLookAt);
    }
  }

  function animateCameraTo(targetPos, targetLookAt) {
    camStartPos.copy(camera.position);
    camStartLookAt.copy(controls.target);
    camTargetPos.copy(targetPos);
    camTargetLookAt.copy(targetLookAt);
    camAnimProgress = 0;
    isAnimatingCamera = true;
  }

  function onWindowResize() {
    const container = document.getElementById('canvas-container');
    const width = container.clientWidth || window.innerWidth;
    const height = container.clientHeight || window.innerHeight;
    camera.aspect = width / height;
    camera.updateProjectionMatrix();
    renderer.setSize(width, height);
  }

  window.ConfiguratorBridge = {
    updateConfiguration: function (newConfigJson) {
      try {
        const config = typeof newConfigJson === 'string' ? JSON.parse(newConfigJson) : newConfigJson;
        const oldW = currentConfig.width;
        const oldH = currentConfig.height;

        currentConfig = Object.assign({}, currentConfig, config);
        rebuildWindow(currentConfig);

        if (Math.abs(oldW - currentConfig.width) > 200 || Math.abs(oldH - currentConfig.height) > 200) {
          controls.target.set(0, currentConfig.height / 2, 0);
        }
      } catch (err) {
        console.error('Error updating configuration:', err);
      }
    },

    setCameraPreset: function (preset) {
      const H = currentConfig.height;
      const W = currentConfig.width;
      const maxDim = Math.max(W, H);
      const dist = maxDim * 1.55;
      const lookAt = new THREE.Vector3(0, H / 2, 0);
      let pos = new THREE.Vector3();

      switch (preset) {
        case 'front':
          pos.set(0, H / 2, dist);
          break;
        case 'back':
          pos.set(0, H / 2, -dist);
          break;
        case 'left':
          pos.set(-dist, H / 2, 0);
          break;
        case 'right':
          pos.set(dist, H / 2, 0);
          break;
        case 'top':
          pos.set(0, dist * 1.3, 10);
          break;
        case 'perspective':
        default:
          pos.set(dist * 0.65, H / 2 + dist * 0.35, dist * 0.9);
          break;
      }

      animateCameraTo(pos, lookAt);
    },

    toggleDimensions: function (visible) {
      currentConfig.showDimensions = visible;
      rebuildDimensions(currentConfig.width, currentConfig.height, currentConfig.depth, currentConfig.sections, visible);
    },

    toggleAutoRotate: function (enabled) {
      controls.autoRotate = enabled;
      controls.autoRotateSpeed = 2.0;
    },

    resetView: function () {
      frameCameraToObject(currentConfig.width, currentConfig.height, false);
    },

    requestSnapshot: function () {
      try {
        renderer.render(scene, camera);
        const dataUrl = renderer.domElement.toDataURL('image/jpeg', 0.82);
        notifyFlutter('onSnapshotData', { dataUrl: dataUrl });
      } catch (err) {
        console.error('Error taking snapshot:', err);
      }
    },

    getConfig: function() {
      return currentConfig;
    }
  };

  function notifyFlutter(handlerName, data) {
    try {
      if (window.parent && window.parent !== window) {
        window.parent.postMessage({ handler: handlerName, data: data }, '*');
      }
    } catch (e) {}

    if (window.flutter_inappwebview && window.flutter_inappwebview.callHandler) {
      window.flutter_inappwebview.callHandler(handlerName, data);
    } else if (window.ToFlutter && window.ToFlutter.postMessage) {
      window.ToFlutter.postMessage(JSON.stringify({ handler: handlerName, data: data }));
    }
  }

  // Cross-window postMessage bridge listener for Flutter Web iframe integration
  window.addEventListener('message', function (event) {
    if (!event.data) return;
    let msg = event.data;
    if (typeof msg === 'string') {
      try {
        msg = JSON.parse(msg);
      } catch (e) {
        return;
      }
    }
    if (!msg || typeof msg !== 'object') return;

    if (msg.action === 'updateConfiguration' && msg.params) {
      window.ConfiguratorBridge.updateConfiguration(msg.params);
    } else if (msg.action === 'setCameraPreset') {
      const preset = msg.preset || 'perspective';
      window.ConfiguratorBridge.setCameraPreset(preset);
    } else if (msg.action === 'toggleDimensions') {
      const visible = msg.visible !== undefined ? Boolean(msg.visible) : !currentConfig.showDimensions;
      window.ConfiguratorBridge.toggleDimensions(visible);
    } else if (msg.action === 'toggleAutoRotate') {
      const enabled = msg.enabled !== undefined ? Boolean(msg.enabled) : !controls.autoRotate;
      window.ConfiguratorBridge.toggleAutoRotate(enabled);
    } else if (msg.action === 'resetView') {
      window.ConfiguratorBridge.resetView();
    } else if (msg.action === 'requestSnapshot') {
      window.ConfiguratorBridge.requestSnapshot();
    } else if (msg.action === 'ping') {
      notifyFlutter('onEngineReady', { status: 'ready' });
    }
  });

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', init);
  } else {
    init();
  }
})();
