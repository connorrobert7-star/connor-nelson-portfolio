'use client'

import { useRef, useEffect, useState, useCallback } from 'react'
import * as THREE from 'three'
import { GLTFLoader } from 'three/examples/jsm/loaders/GLTFLoader.js'

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
      <div style={{
        height: '100%', aspectRatio: '1 / 2',
        backgroundImage: 'url(/photos/bliss.jpg)',
        backgroundSize: 'cover',
        backgroundPosition: 'center',
      }} />
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
  float hf = clamp((position.y + 1.0) / 2.0, 0.0, 1.0);
  float sw = hf * hf;
  transformed.x += sin(uTime * 10.0 + position.y * 4.0) * uWiggle * sw * 0.12;
  transformed.z += sin(uTime * 8.0 + position.y * 3.0 + 1.5) * uWiggle * sw * 0.08;
  transformed.y += cos(uTime * 12.0 + position.y * 5.0) * uWiggle * sw * 0.04;
`

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

    // Lighting
    scene.add(new THREE.AmbientLight(0xffffff, 3))
    const d1 = new THREE.DirectionalLight(0xffffff, 3); d1.position.set(5, 5, 5); scene.add(d1)
    const d2 = new THREE.DirectionalLight(0xccddff, 1.5); d2.position.set(-3, 3, -2); scene.add(d2)
    scene.add(new THREE.HemisphereLight(0x87ceeb, 0x4a9e2f, 1.5))

    // Wiggle uniforms
    const wU = { uWiggle: { value: 0 }, uTime: { value: 0 } }

    // State
    let model: THREE.Group | null = null
    let shadow: THREE.Mesh | null = null
    let pointsCloud: THREE.Points | null = null
    let namePoints: THREE.Points | null = null
    let namePointsMat: THREE.PointsMaterial | null = null
    let meshMaterials: THREE.MeshStandardMaterial[] = []
    let pointsMat: THREE.PointsMaterial | null = null
    let disposed = false
    let animId = 0
    let time = 0
    let dragging = false
    let wasHeld = false
    const grabOrigin = new THREE.Vector3() // where cursor was when grabbed
    const dragTarget = new THREE.Vector3()
    const pos = new THREE.Vector3(0, -1.35, 0)
    const vel = new THREE.Vector2(0, 0)
    const prevDrag = new THREE.Vector3()
    let spinRotation = 0
    let currentRotY = 0
    let wiggle = 0
    let transition = 0 // 0=mesh, 1=points
    let holdTime = 0 // how long held continuously

    // Name label

    // White overlay — sits between Bliss (z:auto) and canvas container (z:1)
    const whiteOverlay = document.createElement('div')
    whiteOverlay.style.cssText = `
      position: absolute; inset: 0; background: white;
      opacity: 0; pointer-events: none; z-index: 0;
    `
    // Insert into parent (the outer wrapper), before the canvas container
    container.parentElement!.insertBefore(whiteOverlay, container)

    // Build lightweight points cloud — sample every 8th vertex for performance
    function buildPoints(mdl: THREE.Group): THREE.Points | null {
      const verts: number[] = []
      const cols: number[] = []

      mdl.traverse((child) => {
        if (!(child as THREE.Mesh).isMesh) return
        const mesh = child as THREE.Mesh
        const posAttr = mesh.geometry.getAttribute('position')
        if (!posAttr) return
        const mat = mesh.material as THREE.MeshStandardMaterial
        const c = mat.color || new THREE.Color(1, 1, 1)

        // Blue dots matching the side bar color (#012265)
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
        size: 0.014,
        vertexColors: true,
        transparent: true,
        opacity: 0,
        sizeAttenuation: true,
        depthWrite: false,
      })

      return new THREE.Points(geo, pointsMat)
    }

    // Load model
    new GLTFLoader().load('/mii/connor.glb', (gltf) => {
      if (disposed) return
      model = gltf.scene
      model.position.copy(pos)
      model.scale.setScalar(0.5)

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
      if (pointsCloud) {
        pointsCloud.visible = true
        model.add(pointsCloud)
      }

      // Build 3D name point cloud — dense, every pixel sampled
      {
        const tmpCanvas = document.createElement('canvas')
        tmpCanvas.width = 300
        tmpCanvas.height = 30
        const tc = tmpCanvas.getContext('2d')!
        tc.fillStyle = '#000'
        tc.fillRect(0, 0, 300, 30)
        tc.font = 'bold 22px monospace'
        tc.fillStyle = '#fff'
        tc.textAlign = 'center'
        tc.textBaseline = 'middle'
        tc.fillText('Connor Nelson', 150, 15)
        const td = tc.getImageData(0, 0, 300, 30)
        const nv: number[] = []
        const baseNv: number[] = []
        const nc: number[] = []
        // Sample every 2nd pixel — dense enough to read, light enough to run
        for (let py = 0; py < 30; py += 2) {
          for (let px = 0; px < 300; px += 2) {
            if (td.data[(py * 300 + px) * 4] > 100) {
              const x = (px - 150) * 0.006
              const y = (15 - py) * 0.006 + 1.25
              nv.push(x, y, 0.01)
              baseNv.push(x, y, 0.01)
              nc.push(1 / 255, 34 / 255, 101 / 255)
            }
          }
        }
        if (nv.length > 0) {
          const ng = new THREE.BufferGeometry()
          ng.setAttribute('position', new THREE.Float32BufferAttribute(nv, 3))
          ng.setAttribute('basePosition', new THREE.Float32BufferAttribute(baseNv, 3))
          ng.setAttribute('color', new THREE.Float32BufferAttribute(nc, 3))
          namePointsMat = new THREE.PointsMaterial({
            size: 0.008,
            vertexColors: true,
            transparent: true,
            opacity: 0,
            sizeAttenuation: true,
            depthWrite: false,
          })
          namePoints = new THREE.Points(ng, namePointsMat)
          model.add(namePoints)
        }
      }

      // Ground shadow — round circle under feet
      const shadowGeo = new THREE.CircleGeometry(0.5, 32)
      const shadowMat = new THREE.MeshBasicMaterial({
        color: 0x000000,
        transparent: true,
        opacity: 0.55,
        depthWrite: false,
      })
      shadow = new THREE.Mesh(shadowGeo, shadowMat)
      shadow.rotation.x = -Math.PI / 2
      shadow.position.set(0, -1.02, 0)
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
      if (Math.hypot(w.x - pos.x, w.y - (pos.y + 0.5)) < 2.5) {
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

      // Track hold duration — points get stronger the longer you hold
      if (dragging) {
        holdTime += dt
      } else {
        holdTime *= 0.92 // decay when released
      }

      // holdStrength ramps from 0 to 1 over ~2 seconds of holding
      const holdStrength = Math.min(1, holdTime / 2)

      // Crossfade: mesh fades out, points fade in — intensity grows with hold time
      const target = dragging ? 0.4 + holdStrength * 0.6 : 0
      transition += (target - transition) * 0.08

      for (const mat of meshMaterials) {
        mat.opacity = 1 - transition
      }
      if (pointsMat) {
        pointsMat.opacity = transition
        pointsMat.size = 0.014 + holdStrength * 0.012
      }
      if (namePointsMat) {
        namePointsMat.opacity = transition
        namePointsMat.size = 0.014 + holdStrength * 0.012
      }
      if (shadow) {
        const shadowTargetScale = dragging ? 0 : 1
        const shadowTargetOpacity = dragging ? 0 : 0.55
        const sMat = shadow.material as THREE.MeshBasicMaterial
        // Scale grows from 0 to full — spreading from center
        const curScale = shadow.scale.x
        const newScale = curScale + (shadowTargetScale - curScale) * (dragging ? 0.3 : 0.06)
        shadow.scale.set(newScale, newScale, 1)
        // Opacity fades in alongside scale
        sMat.opacity += (shadowTargetOpacity - sMat.opacity) * (dragging ? 0.3 : 0.06)
      }

      if (dragging) {
        // dragOffset = difference between cursor and center, so model stays centered
        // but moves relative to where you drag from there
        const offsetX = dragTarget.x - grabOrigin.x
        const offsetY = dragTarget.y - grabOrigin.y
        const tx = 0 + offsetX
        const ty = 0 + offsetY
        pos.x += (tx - pos.x) * 0.15
        pos.y += (ty - pos.y) * 0.15
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

        // Sync spin on drop
        if (wasHeld) {
          wasHeld = false
          spinRotation = model.rotation.y
        }

        // Drift to center
        pos.x += (0 - pos.x) * 0.02
        pos.y += (-1.35 - pos.y) * 0.02
        model.position.set(pos.x, pos.y, 0)

        // Spin
        spinRotation += dt * 0.5
        currentRotY = spinRotation
        model.rotation.y = spinRotation

        // Settle
        model.rotation.z = THREE.MathUtils.lerp(model.rotation.z, 0, 0.05)
        model.rotation.x = THREE.MathUtils.lerp(model.rotation.x, 0, 0.05)

        // Bob
        model.position.y += Math.sin(time * 1.5) * 0.015

        // Decay wiggle
        wiggle *= 0.93
        wU.uWiggle.value = wiggle
      }

      vel.multiplyScalar(0.85)

      // Scale: small idle, big when held — smooth lerp
      const vFov = (camera.fov * Math.PI) / 180
      const vw = 2 * Math.tan(vFov / 2) * camera.position.z * camera.aspect
      const baseScale = Math.min(1, vw / 8)
      const smallScale = baseScale * 0.5
      const bigScale = baseScale * 1.6
      const targetScale = dragging ? bigScale : smallScale
      const currentScale = model.scale.x
      model.scale.setScalar(currentScale + (targetScale - currentScale) * 0.08)

      // Fade wallpaper to white when holding
      const whiteTarget = dragging ? 1 : 0
      const curWhite = parseFloat(whiteOverlay.style.opacity) || 0
      whiteOverlay.style.opacity = String(curWhite + (whiteTarget - curWhite) * 0.08)

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
      if (container.contains(canvas)) container.removeChild(canvas)
      if (whiteOverlay.parentElement) whiteOverlay.parentElement.removeChild(whiteOverlay)
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
    }}>
      <Bliss />
      <div ref={canvasContainer} style={{ position: 'absolute', inset: 0, zIndex: 1 }} />
      {/* Blue bars ON TOP of canvas — flush with image edges. Image is 1:2 aspect (w=h/2), centered */}
      <div style={{ position: 'absolute', top: 0, bottom: 0, left: 0, width: 'calc(50% - 25vh)', background: '#012265', zIndex: 2, pointerEvents: 'none' }} />
      <div style={{ position: 'absolute', top: 0, bottom: 0, right: 0, width: 'calc(50% - 25vh)', background: '#012265', zIndex: 2, pointerEvents: 'none' }} />
      <div style={{ position: 'absolute', top: 0, left: 0, right: 0, height: 60, background: '#012265', zIndex: 2, pointerEvents: 'none' }} />
    </div>
  )
}
