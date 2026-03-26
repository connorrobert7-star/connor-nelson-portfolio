'use client'

import { useRef, useEffect, useState, useCallback } from 'react'
import * as THREE from 'three'
import { GLTFLoader } from 'three/examples/jsm/loaders/GLTFLoader.js'
import { DRACOLoader } from 'three/examples/jsm/loaders/DRACOLoader.js'

// ---------------------------------------------------------------------------
// Bliss Background
// ---------------------------------------------------------------------------
function Bliss() {
  return (
    <div style={{
      position: 'absolute', inset: 0, pointerEvents: 'none', overflow: 'hidden',
      background: '#012265',
      display: 'flex', alignItems: 'center', justifyContent: 'center',
    }}>
      <div
        className="bliss-image"
        style={{
          height: '100%', aspectRatio: '1 / 2',
          maxWidth: '100%',
          backgroundImage: 'url(/photos/bliss.jpg)',
          backgroundSize: 'cover',
          backgroundPosition: 'center',
          position: 'relative',
        }}
      >
        {/* Scanlines — only inside the Bliss image, not over blue bars */}
        <div style={{
          position: 'absolute', inset: 0, pointerEvents: 'none',
          background: 'repeating-linear-gradient(0deg, transparent, transparent 2px, rgba(0,0,0,0.03) 2px, rgba(0,0,0,0.03) 4px)',
        }} />
      </div>
    </div>
  )
}

// ---------------------------------------------------------------------------
// Jiggly vertex shader
// ---------------------------------------------------------------------------
const WIGGLE_VERT_PARS = `
  uniform float uWiggle;
  uniform float uTime;
`
const WIGGLE_VERT = `
  float hf = clamp(position.y / 1.7, 0.0, 1.0);
  float sw = hf * hf;
  transformed.x += sin(uTime * 10.0 + position.y * 4.0) * uWiggle * sw * 0.12;
  transformed.z += sin(uTime * 8.0 + position.y * 3.0 + 1.5) * uWiggle * sw * 0.08;
  transformed.y += cos(uTime * 12.0 + position.y * 5.0) * uWiggle * sw * 0.04;
`

// ---------------------------------------------------------------------------
// Grass bounds (in world space) — computed dynamically from viewport
// ---------------------------------------------------------------------------
// The camera is at (0,0,5) with FOV 50. The visible world at z=0:
//   halfH = tan(25deg) * 5 = 2.3315
//   halfW = halfH * aspect
//
// The Bliss image layout within the container (which is full viewport minus
// 30px taskbar):
//   - Blue side bars: each calc(50% - 25vh) wide, so visible image = 50vh wide
//     (where vh = window.innerHeight / 100)
//   - Blue top bar: 60px
//   - The grass is roughly the bottom 55% of the Bliss image
//
// We compute GRASS bounds at runtime so they track the actual viewport.
// ---------------------------------------------------------------------------
function computeGrassBounds(containerW: number, containerH: number) {
  const fov = 50
  const cameraDist = 5
  const halfH = Math.tan((fov / 2) * Math.PI / 180) * cameraDist // ~2.3315
  const aspect = containerW / containerH
  const halfW = halfH * aspect

  // --- Horizontal: visible Bliss image strip ---
  // The Bliss image has aspectRatio 1/2 (width = height/2) and maxWidth: 100%.
  // On desktop: image width = containerH / 2 (height-constrained).
  // On mobile: image width = min(containerH / 2, containerW) (width-clamped).
  // aspectRatio 1/2 means width = height/2, but clamped by maxWidth:100%
  const imageActualWidthPx = Math.min(containerH / 2, containerW)
  const imageHalfWidthPx = imageActualWidthPx / 2
  // Image left edge at px = containerW/2 - imageHalfWidthPx
  // NDC_x = 2*(px/containerW) - 1
  // For left edge: 2*((containerW/2 - imageHalfWidthPx)/containerW) - 1 = -2*imageHalfWidthPx/containerW
  const imageLeftNDC = -2 * imageHalfWidthPx / containerW
  const imageRightNDC = 2 * imageHalfWidthPx / containerW
  const minX = imageLeftNDC * halfW
  const maxX = imageRightNDC * halfW

  // --- Vertical: grass portion of Bliss image ---
  // The Bliss image fills the full container height. The top 60px is covered
  // by a blue bar (sky replacement). The grass starts at roughly 45% from the
  // top of the image and extends to the bottom.
  //
  // pixel-from-top -> NDC_y = 1 - 2*(py / containerH)
  // World Y = NDC_y * halfH
  const grassTopFrac = 0.50  // higher up — top of grass hill
  const grassTopNDC = 1 - 2 * grassTopFrac
  const grassBottomNDC = -1.0  // all the way to bottom

  const farY = grassTopNDC * halfH    // top of grass (far, smaller)
  const nearY = grassBottomNDC * halfH // bottom of grass (near, bigger)

  // On mobile viewports, scale the Mii larger so it's not tiny
  const isMobile = containerW < 768
  const scaleMult = isMobile ? 2.0 : 1.0

  return {
    minX,
    maxX,
    nearY,   // bottom of grass (most negative Y)
    farY,    // top of grass (less negative or positive Y)
    nearScale: 0.6 * scaleMult,
    farScale: 0.3 * scaleMult,
  }
}

// Fallback defaults (overwritten on first frame)
let GRASS = {
  minX: -1.2,
  maxX: 1.2,
  nearY: -2.33,
  farY: 0.23,
  nearScale: 0.6,
  farScale: 0.3,
}

// ---------------------------------------------------------------------------
// Three.js Scene
// ---------------------------------------------------------------------------
function useThreeScene(containerRef: React.RefObject<HTMLDivElement | null>) {
  useEffect(() => {
    const container = containerRef.current
    if (!container) return

    const renderer = new THREE.WebGLRenderer({ antialias: true, alpha: true })
    renderer.setPixelRatio(Math.min(window.devicePixelRatio, 2))
    renderer.setSize(container.clientWidth, container.clientHeight)
    renderer.setClearColor(0x000000, 0)
    renderer.outputColorSpace = THREE.SRGBColorSpace
    container.appendChild(renderer.domElement)

    const scene = new THREE.Scene()
    const camera = new THREE.PerspectiveCamera(50, container.clientWidth / container.clientHeight, 0.1, 100)
    camera.position.set(0, 0, 5)

    // Compute grass bounds from current viewport
    GRASS = computeGrassBounds(container.clientWidth, container.clientHeight)



    // Lighting
    scene.add(new THREE.AmbientLight(0xffffff, 3))
    const d1 = new THREE.DirectionalLight(0xffffff, 3); d1.position.set(5, 5, 5); scene.add(d1)
    const d2 = new THREE.DirectionalLight(0xccddff, 1.5); d2.position.set(-3, 3, -2); scene.add(d2)
    scene.add(new THREE.HemisphereLight(0x87ceeb, 0x4a9e2f, 1.5))

    // Wiggle uniforms
    const wU = { uWiggle: { value: 0 }, uTime: { value: 0 } }

    // State
    let model: THREE.Group | null = null
    let mixer: THREE.AnimationMixer | null = null
    let walkAction: THREE.AnimationAction | null = null
    let shadow: THREE.Mesh | null = null
    let pointsCloud: THREE.Points | null = null
    let namePoints: THREE.Points | null = null
    let namePointsMat: THREE.PointsMaterial | null = null
    let meshMaterials: THREE.MeshStandardMaterial[] = []
    let pointsMat: THREE.PointsMaterial | null = null
    let titleMat: THREE.MeshBasicMaterial | null = null
    let disposed = false
    let animId = 0
    let time = 0
    let dragging = false
    let wasHeld = false
    const grabOrigin = new THREE.Vector3()
    const dragTarget = new THREE.Vector3()
    // Start in the middle of the grass area
    const grassMidY = (GRASS.nearY + GRASS.farY) / 2
    const pos = new THREE.Vector3(0, grassMidY, 0)
    const vel = new THREE.Vector2(0, 0)
    const prevDrag = new THREE.Vector3()
    let currentRotY = -Math.PI * 0.4
    let wiggle = 0
    let transition = 0
    let holdTime = 0

    // Simple walk — always moving forward, gentle steering toward target
    const WALK_SPEED = 0.2
    const walkTarget = new THREE.Vector2(0, grassMidY)

    function pickTarget() {
      const padX = (GRASS.maxX - GRASS.minX) * 0.2
      const padY = (GRASS.farY - GRASS.nearY) * 0.2
      walkTarget.set(
        (GRASS.minX + padX) + Math.random() * (GRASS.maxX - GRASS.minX - padX * 2),
        (GRASS.nearY + padY) + Math.random() * (GRASS.farY - GRASS.nearY - padY * 2),
      )
    }
    pickTarget()

    // White overlay

    // Build points cloud
    function buildPoints(mdl: THREE.Group): THREE.Points | null {
      const verts: number[] = []
      const cols: number[] = []
      mdl.traverse((child) => {
        if (!(child as THREE.Mesh).isMesh) return
        const mesh = child as THREE.Mesh
        const posAttr = mesh.geometry.getAttribute('position')
        if (!posAttr) return
        for (let i = 0; i < posAttr.count; i += 4) {
          verts.push(posAttr.getX(i), posAttr.getY(i), posAttr.getZ(i))
          cols.push(1 / 255, 34 / 255, 101 / 255)
        }
      })
      if (verts.length === 0) return null
      const geo = new THREE.BufferGeometry()
      geo.setAttribute('position', new THREE.Float32BufferAttribute(verts, 3))
      geo.setAttribute('color', new THREE.Float32BufferAttribute(cols, 3))
      pointsMat = new THREE.PointsMaterial({
        size: 0.014, vertexColors: true, transparent: true,
        opacity: 0, sizeAttenuation: true, depthWrite: false,
      })
      return new THREE.Points(geo, pointsMat)
    }

    // Setup materials on a model
    // Load single model — use animation timeScale for walk/idle
    const dracoLoader = new DRACOLoader()
    dracoLoader.setDecoderPath('https://www.gstatic.com/draco/versioned/decoders/1.5.7/')
    const gltfLoader = new GLTFLoader()
    gltfLoader.setDRACOLoader(dracoLoader)

    gltfLoader.load('/mii/connor.glb', (gltf) => {
      if (disposed) return
      model = gltf.scene
      model.position.copy(pos)
      model.scale.setScalar(0.5)

      if (gltf.animations.length > 0) {
        mixer = new THREE.AnimationMixer(model)
        walkAction = mixer.clipAction(gltf.animations[0])
        walkAction.play()
      }

      model.traverse((child) => {
        if ((child as THREE.Mesh).isMesh) {
          const mat = (child as THREE.Mesh).material as THREE.MeshStandardMaterial
          if (mat.isMeshStandardMaterial) {
            mat.metalness = Math.min(mat.metalness, 0.2)
            mat.roughness = Math.max(mat.roughness, 0.6)
            mat.transparent = true
            mat.onBeforeCompile = (shader) => {
              shader.uniforms.uWiggle = wU.uWiggle
              shader.uniforms.uTime = wU.uTime
              shader.vertexShader = shader.vertexShader.replace('#include <common>', '#include <common>\n' + WIGGLE_VERT_PARS)
              shader.vertexShader = shader.vertexShader.replace('#include <begin_vertex>', '#include <begin_vertex>\n' + WIGGLE_VERT)
            }
            mat.needsUpdate = true
            meshMaterials.push(mat)
          }
        }
      })

      pointsCloud = buildPoints(model)
      if (pointsCloud) { pointsCloud.visible = true; model.add(pointsCloud) }

      // Name label — Mii-style font on a plane that rotates with the model
      {
        const nameCanvas = document.createElement('canvas')
        nameCanvas.width = 512; nameCanvas.height = 64
        const nc = nameCanvas.getContext('2d')!
        nc.clearRect(0, 0, 512, 64)
        nc.font = 'bold 36px "Trebuchet MS", "Segoe UI", "Helvetica Neue", Arial, sans-serif'
        nc.textAlign = 'center'
        nc.textBaseline = 'middle'
        nc.fillStyle = '#000000'
        nc.fillText('Connor Nelson', 256, 32)

        const nameTex = new THREE.CanvasTexture(nameCanvas)
        nameTex.needsUpdate = true
        const nameMat = new THREE.MeshBasicMaterial({
          map: nameTex,
          transparent: true,
          opacity: 1,
          depthWrite: false,
          side: THREE.DoubleSide,
        })
        const namePlane = new THREE.PlaneGeometry(1.6, 0.2)
        const nameMesh = new THREE.Mesh(namePlane, nameMat)
        nameMesh.position.set(0, 1.85, 0)
        model.add(nameMesh)
        namePointsMat = nameMat as any
      }

      // Title label — Director/Producer/Editor, only visible when grabbed
      {
        const titleCanvas = document.createElement('canvas')
        titleCanvas.width = 512; titleCanvas.height = 64
        const tc2 = titleCanvas.getContext('2d')!
        tc2.clearRect(0, 0, 512, 64)
        tc2.font = 'bold 28px "Trebuchet MS", "Segoe UI", "Helvetica Neue", Arial, sans-serif'
        tc2.textAlign = 'center'
        tc2.textBaseline = 'middle'
        tc2.fillStyle = '#000000'
        tc2.fillText('Director / Producer / Editor', 256, 32)

        const titleTex = new THREE.CanvasTexture(titleCanvas)
        titleTex.needsUpdate = true
        titleMat = new THREE.MeshBasicMaterial({
          map: titleTex,
          transparent: true,
          opacity: 0,
          depthWrite: false,
          side: THREE.DoubleSide,
        })
        const titlePlane = new THREE.PlaneGeometry(1.6, 0.2)
        const titleMesh = new THREE.Mesh(titlePlane, titleMat)
        titleMesh.position.set(0, -0.15, 0)
        model.add(titleMesh)
      }

      // Shadow
      const sg = new THREE.CircleGeometry(0.4, 32)
      const sm = new THREE.MeshBasicMaterial({ color: 0x000000, transparent: true, opacity: 0.55, depthWrite: false })
      shadow = new THREE.Mesh(sg, sm)
      shadow.rotation.x = -Math.PI / 2
      shadow.position.set(0, 0.01, 0)
      model.add(shadow)

      scene.add(model)
    })

    // Raycaster
    const hitPlane = new THREE.Plane(new THREE.Vector3(0, 0, 1), 0)
    const rc = new THREE.Raycaster()
    const ip = new THREE.Vector3()
    function toWorld(cx: number, cy: number): THREE.Vector3 {
      const rect = renderer.domElement.getBoundingClientRect()
      rc.setFromCamera(new THREE.Vector2(((cx - rect.left) / rect.width) * 2 - 1, -((cy - rect.top) / rect.height) * 2 + 1), camera)
      rc.ray.intersectPlane(hitPlane, ip)
      return ip.clone()
    }

    // Pointer events
    const canvas = renderer.domElement
    canvas.style.touchAction = 'none'

    const onDown = (e: PointerEvent) => {
      if (!model) return
      const w = toWorld(e.clientX, e.clientY)
      // Hit test — check distance to model center (model Y center is ~0.85 above pos.y)
      if (Math.hypot(w.x - pos.x, w.y - (pos.y + 0.85 * model.scale.x)) < 2.0) {
        dragging = true
        grabOrigin.copy(w)
        dragTarget.copy(w)
        prevDrag.copy(w)
        canvas.style.cursor = 'grabbing'
        canvas.setPointerCapture(e.pointerId)
      }
    }
    const onMove = (e: PointerEvent) => {
      const w = toWorld(e.clientX, e.clientY)
      if (dragging) {
        vel.set(w.x - prevDrag.x, w.y - prevDrag.y)
        prevDrag.copy(w)
        dragTarget.copy(w)
      }
    }
    const onUp = (e: PointerEvent) => {
      if (dragging) {
        dragging = false
        wasHeld = true
        canvas.style.cursor = ''
        canvas.releasePointerCapture(e.pointerId)
      }
    }
    canvas.addEventListener('pointerdown', onDown)
    canvas.addEventListener('pointermove', onMove)
    canvas.addEventListener('pointerup', onUp)
    canvas.addEventListener('pointerleave', onUp)

    // Resize
    const onResize = () => {
      if (!container || disposed) return
      camera.aspect = container.clientWidth / container.clientHeight
      camera.updateProjectionMatrix()
      renderer.setSize(container.clientWidth, container.clientHeight)
      GRASS = computeGrassBounds(container.clientWidth, container.clientHeight)
    }
    window.addEventListener('resize', onResize)

    // Animate
    const clock = new THREE.Clock()

    function animate() {
      if (disposed) return
      animId = requestAnimationFrame(animate)

      const dt = Math.min(clock.getDelta(), 0.05)
      time += dt
      wU.uTime.value = time

      if (!model) { renderer.render(scene, camera); return }

      // Animation mixer
      if (mixer) {
        if (walkAction) {
          const targetSpeed = dragging ? 0 : 1
          walkAction.timeScale += (targetSpeed - walkAction.timeScale) * 0.12
        }
        mixer.update(dt)
      }

      // Hold duration for point cloud intensity
      if (dragging) { holdTime += dt } else { holdTime *= 0.92 }
      const holdStrength = Math.min(1, holdTime / 2)

      // Solid Mii always visible, name always visible
      for (const mat of meshMaterials) { mat.opacity = 1 }
      if (pointsMat) { pointsMat.opacity = 0 }
      if (namePointsMat) {
        namePointsMat.opacity = 1
      }
      if (titleMat) {
        const titleTarget = dragging ? 1 : 0
        titleMat.opacity += (titleTarget - titleMat.opacity) * 0.1
      }
      if (shadow) {
        const sMat = shadow.material as THREE.MeshBasicMaterial
        const sTarget = dragging ? 0 : 0.55
        const sScaleTarget = dragging ? 0 : 1
        const curS = shadow.scale.x
        shadow.scale.set(
          curS + (sScaleTarget - curS) * (dragging ? 0.3 : 0.06),
          curS + (sScaleTarget - curS) * (dragging ? 0.3 : 0.06),
          1,
        )
        sMat.opacity += (sTarget - sMat.opacity) * (dragging ? 0.3 : 0.06)
      }

      if (dragging) {
        // --- DRAGGING ---
        // First snap to center, then move relative to where cursor goes from grab point
        const offsetX = dragTarget.x - grabOrigin.x
        const offsetY = dragTarget.y - grabOrigin.y
        // Center the model visually — model is 1.7 tall * scale, offset down so middle of body is at screen center
        const modelHalfH = 0.85 * model.scale.x
        const targetX = 0 + offsetX
        const targetY = -modelHalfH + offsetY
        pos.x += (targetX - pos.x) * 0.12
        pos.y += (targetY - pos.y) * 0.12
        model.position.set(pos.x, pos.y, 0)

        // Face camera
        currentRotY += (0 - currentRotY) * 0.1
        model.rotation.y = currentRotY

        // Wiggle
        const wm = Math.sqrt(vel.x * vel.x + vel.y * vel.y)
        wiggle += (wm * 20 - wiggle) * 0.15
        wiggle = Math.min(wiggle, 2)
        wU.uWiggle.value = wiggle

        // Tilt
        model.rotation.z = THREE.MathUtils.lerp(model.rotation.z, THREE.MathUtils.clamp(-vel.x * 4, -0.5, 0.5), 0.15)
        model.rotation.x = THREE.MathUtils.lerp(model.rotation.x, THREE.MathUtils.clamp(vel.y * 3, -0.4, 0.4), 0.12)

      } else {
        // --- WALKING ---
        if (wasHeld) {
          wasHeld = false
          pickTarget()
        }

        // Target direction
        const dx = walkTarget.x - pos.x
        const dy = walkTarget.y - pos.y
        const dist = Math.sqrt(dx * dx + dy * dy)

        // Pick new target when close
        if (dist < 0.15) pickTarget()

        // Desired facing angle toward target
        const targetRotY = Math.atan2(dx, -dy)
        let angleDiff = targetRotY - currentRotY
        while (angleDiff > Math.PI) angleDiff -= Math.PI * 2
        while (angleDiff < -Math.PI) angleDiff += Math.PI * 2

        // Gentle steering — always turning toward target
        currentRotY += angleDiff * 0.04

        // Always walk forward in the direction we're facing
        pos.x += Math.sin(currentRotY) * WALK_SPEED * dt
        pos.y += -Math.cos(currentRotY) * WALK_SPEED * dt

        // Clamp to grass — pick new target if we hit edge
        const px = pos.x, py = pos.y
        pos.x = THREE.MathUtils.clamp(pos.x, GRASS.minX, GRASS.maxX)
        pos.y = THREE.MathUtils.clamp(pos.y, GRASS.nearY, GRASS.farY)
        if (pos.x !== px || pos.y !== py) pickTarget()

        model.position.set(pos.x, pos.y, 0)
        model.rotation.y = currentRotY

        // Settle tilts
        model.rotation.z = THREE.MathUtils.lerp(model.rotation.z, 0, 0.05)
        model.rotation.x = THREE.MathUtils.lerp(model.rotation.x, 0, 0.05)

        wiggle *= 0.93
        wU.uWiggle.value = wiggle
      }

      vel.multiplyScalar(0.85)

      // Scale: perspective depth when walking, big when held
      const vFov = (camera.fov * Math.PI) / 180
      const vw = 2 * Math.tan(vFov / 2) * camera.position.z * camera.aspect
      const baseScale = Math.min(1, vw / 8)

      // Depth factor: 0 = far (top of grass), 1 = near (bottom of grass)
      const depthT = THREE.MathUtils.clamp(
        (pos.y - GRASS.farY) / (GRASS.nearY - GRASS.farY), 0, 1,
      )
      const depthScale = THREE.MathUtils.lerp(GRASS.farScale, GRASS.nearScale, depthT)
      const idleScale = baseScale * depthScale
      const bigScale = baseScale * 1.6
      const targetScale = dragging ? bigScale : idleScale
      const currentScale = model.scale.x
      model.scale.setScalar(currentScale + (targetScale - currentScale) * 0.08)


      renderer.render(scene, camera)
    }

    animate()

    return () => {
      disposed = true
      cancelAnimationFrame(animId)
      canvas.removeEventListener('pointerdown', onDown)
      canvas.removeEventListener('pointermove', onMove)
      canvas.removeEventListener('pointerup', onUp)
      canvas.removeEventListener('pointerleave', onUp)
      window.removeEventListener('resize', onResize)
      renderer.dispose()
      dracoLoader.dispose()
      if (container.contains(canvas)) container.removeChild(canvas)
    }
  }, [containerRef])
}

// ---------------------------------------------------------------------------
// Export
// ---------------------------------------------------------------------------
export default function MiiWalker() {
  const canvasContainer = useRef<HTMLDivElement>(null)
  useThreeScene(canvasContainer)

  return (
    <div style={{
      position: 'absolute', top: 0, bottom: 30, left: 0, right: 0,
      zIndex: 0, overflow: 'hidden',
      userSelect: 'none',
      WebkitUserSelect: 'none',
      touchAction: 'none',
      WebkitTouchCallout: 'none',
    } as React.CSSProperties}>
      <Bliss />
      <div ref={canvasContainer} style={{
        position: 'absolute', inset: 0, zIndex: 1,
        touchAction: 'none',
        WebkitTouchCallout: 'none',
        userSelect: 'none',
        WebkitUserSelect: 'none',
      } as React.CSSProperties} />
      <div style={{ position: 'absolute', top: -2, bottom: -2, left: -2, width: 'calc(max(0px, 50% - 25vh) + 4px)', background: '#012265', zIndex: 2, pointerEvents: 'none' }} />
      <div style={{ position: 'absolute', top: -2, bottom: -2, right: -2, width: 'calc(max(0px, 50% - 25vh) + 4px)', background: '#012265', zIndex: 2, pointerEvents: 'none' }} />
      <div style={{ position: 'absolute', top: -2, left: -2, right: -2, height: 64, background: '#012265', zIndex: 2, pointerEvents: 'none' }} />
      <div style={{ position: 'absolute', bottom: -2, left: -2, right: -2, height: 64, background: '#012265', zIndex: 2, pointerEvents: 'none' }} />
    </div>
  )
}
