import { describe, it, expect, beforeEach, vi } from 'vitest'
import { render, waitFor } from '@testing-library/svelte'
import DrawingCanvas from '../DrawingCanvas.svelte'

describe('DrawingCanvas - Canvas Element and Context Initialization', () => {
  let mockLive

  beforeEach(() => {
    mockLive = {
      pushEvent: vi.fn(),
      handleEvent: vi.fn()
    }
  })

  it('should render canvas element in DOM', async () => {
    const { container } = render(DrawingCanvas, {
      props: {
        live: mockLive,
        strokes: []
      }
    })

    // Wait for loading to complete (100ms timeout in component)
    await new Promise(resolve => setTimeout(resolve, 150))

    const canvas = container.querySelector('canvas')
    expect(canvas).toBeTruthy()
    expect(canvas).toBeInstanceOf(HTMLCanvasElement)
    expect(canvas.classList.contains('drawing-canvas')).toBe(true)
  })

  it('should obtain 2D context from canvas', async () => {
    const { container } = render(DrawingCanvas, {
      props: {
        live: mockLive,
        strokes: []
      }
    })

    await vi.advanceTimersByTimeAsync(100)
    await tick()

    const canvas = container.querySelector('canvas')
    const ctx = canvas.getContext('2d')
    
    expect(ctx).toBeTruthy()
    expect(ctx).toBeInstanceOf(CanvasRenderingContext2D)
  })

  it('should set canvas dimensions with devicePixelRatio', async () => {
    // Mock devicePixelRatio
    const originalDPR = window.devicePixelRatio
    Object.defineProperty(window, 'devicePixelRatio', {
      writable: true,
      configurable: true,
      value: 2
    })

    const { container } = render(DrawingCanvas, {
      props: {
        live: mockLive,
        strokes: []
      }
    })

    await vi.advanceTimersByTimeAsync(100)
    await tick()

    const canvas = container.querySelector('canvas')
    const rect = canvas.getBoundingClientRect()
    
    // Canvas internal dimensions should be scaled by DPR
    expect(canvas.width).toBeGreaterThan(0)
    expect(canvas.height).toBeGreaterThan(0)
    
    // The internal dimensions should be approximately rect dimensions * DPR
    // We allow some tolerance for rounding
    const expectedWidth = rect.width * 2
    const expectedHeight = rect.height * 2
    
    expect(Math.abs(canvas.width - expectedWidth)).toBeLessThan(5)
    expect(Math.abs(canvas.height - expectedHeight)).toBeLessThan(5)

    // Restore original DPR
    Object.defineProperty(window, 'devicePixelRatio', {
      writable: true,
      configurable: true,
      value: originalDPR
    })
  })

  it('should set lineCap to round', async () => {
    const { container } = render(DrawingCanvas, {
      props: {
        live: mockLive,
        strokes: []
      }
    })

    await vi.advanceTimersByTimeAsync(100)
    await tick()

    const canvas = container.querySelector('canvas')
    const ctx = canvas.getContext('2d')
    
    expect(ctx.lineCap).toBe('round')
  })

  it('should set lineJoin to round', async () => {
    const { container } = render(DrawingCanvas, {
      props: {
        live: mockLive,
        strokes: []
      }
    })

    await vi.advanceTimersByTimeAsync(100)
    await tick()

    const canvas = container.querySelector('canvas')
    const ctx = canvas.getContext('2d')
    
    expect(ctx.lineJoin).toBe('round')
  })

  it('should verify reactive statement executes for context initialization', async () => {
    const { container } = render(DrawingCanvas, {
      props: {
        live: mockLive,
        strokes: []
      }
    })

    await vi.advanceTimersByTimeAsync(100)
    await tick()

    const canvas = container.querySelector('canvas')
    const ctx = canvas.getContext('2d')
    
    // If reactive statement executed, context should be initialized with proper settings
    expect(ctx).toBeTruthy()
    expect(ctx.lineCap).toBe('round')
    expect(ctx.lineJoin).toBe('round')
    
    // Verify canvas has dimensions set (reactive statement sets these)
    expect(canvas.width).toBeGreaterThan(0)
    expect(canvas.height).toBeGreaterThan(0)
  })

  it('should handle different devicePixelRatio values', async () => {
    const testDPRValues = [1, 1.5, 2, 3]

    for (const dpr of testDPRValues) {
      Object.defineProperty(window, 'devicePixelRatio', {
        writable: true,
        configurable: true,
        value: dpr
      })

      const { container, unmount } = render(DrawingCanvas, {
        props: {
          live: mockLive,
          strokes: []
        }
      })

      await vi.advanceTimersByTimeAsync(100)
      await tick()

      const canvas = container.querySelector('canvas')
      const rect = canvas.getBoundingClientRect()
      
      // Verify dimensions are scaled by current DPR
      const expectedWidth = rect.width * dpr
      const expectedHeight = rect.height * dpr
      
      expect(Math.abs(canvas.width - expectedWidth)).toBeLessThan(5)
      expect(Math.abs(canvas.height - expectedHeight)).toBeLessThan(5)

      unmount()
    }
  })

  it('should initialize context before attempting to draw strokes', async () => {
    const testStrokes = [
      {
        path_data: 'M10,20 L30,40',
        color: '#000000',
        stroke_width: 2.0
      }
    ]

    const { container } = render(DrawingCanvas, {
      props: {
        live: mockLive,
        strokes: testStrokes
      }
    })

    await vi.advanceTimersByTimeAsync(100)
    await tick()

    const canvas = container.querySelector('canvas')
    const ctx = canvas.getContext('2d')
    
    // Context should be initialized even with strokes present
    expect(ctx).toBeTruthy()
    expect(ctx.lineCap).toBe('round')
    expect(ctx.lineJoin).toBe('round')
  })
})
