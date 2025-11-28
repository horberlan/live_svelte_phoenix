# Drawing Performance Optimizations

This document describes the performance optimizations implemented for the collaborative drawing feature.

## Overview

Task 8 (Performance optimization) has been completed with three main subtasks:
1. Canvas rendering optimization
2. Stroke limits
3. Database query optimization

## 8.1 Canvas Rendering Optimization

### Implemented Changes

#### 1. RequestAnimationFrame for Smooth Drawing
- **Before**: Drawing operations were executed immediately on every `mousemove` event
- **After**: Coordinate updates are batched and rendered using `requestAnimationFrame`
- **Benefit**: Smoother drawing experience, reduced CPU usage, better frame rate

#### 2. Coordinate Buffering
- **Implementation**: Added `coordinateBuffer` array to batch multiple coordinate updates
- **Process**:
  1. Mouse/touch move events push coordinates to buffer
  2. `requestAnimationFrame` schedules a single render call
  3. `flushCoordinateBuffer()` processes all buffered coordinates at once
- **Benefit**: Reduces the number of canvas draw operations from potentially hundreds per stroke to just a few

#### 3. Efficient Redraw Logic
- **Before**: Canvas was redrawn on every reactive update
- **After**: 
  - Added `needsRedraw` flag to track when redrawing is necessary
  - Redraw only triggered when strokes actually change
  - Canvas context state is saved/restored during batch operations
- **Benefit**: Eliminates unnecessary redraws, improves performance when switching modes

#### 4. Canvas Initialization Fix
- **Issue**: Canvas was undefined when `onMount` ran because it's conditionally rendered
- **Solution**: 
  - Moved event listeners to `onMount` (always runs)
  - Added reactive statement `$: if (canvas && !ctx)` to initialize canvas when available
  - Guards all canvas operations with `if (ctx)` checks
- **Benefit**: Prevents runtime errors, ensures canvas initializes correctly

### Code Changes

```javascript
// Performance optimization variables
let animationFrameId = null
let coordinateBuffer = []
let needsRedraw = false

// Batched coordinate rendering
function draw(event) {
  if (!isDrawing || !enabled) return
  event.preventDefault()
  const coords = getCoordinates(event)
  
  // Buffer coordinates for batched rendering
  coordinateBuffer.push(coords)
  
  // Schedule rendering with requestAnimationFrame
  if (!animationFrameId) {
    animationFrameId = requestAnimationFrame(flushCoordinateBuffer)
  }
}

function flushCoordinateBuffer() {
  if (coordinateBuffer.length === 0) {
    animationFrameId = null
    return
  }
  
  // Append all buffered coordinates to the path
  coordinateBuffer.forEach(coords => {
    currentPath += ` L${coords.x},${coords.y}`
  })
  
  coordinateBuffer = []
  drawStroke(currentPath, currentColor, strokeWidth)
  animationFrameId = null
}
```

## 8.2 Stroke Limits

### Implemented Changes

#### 1. Maximum Strokes Per Session
- **Limit**: 1000 strokes per session
- **Enforcement**: Drawing is prevented when limit is reached
- **User Feedback**: Clear error message explaining the limit

#### 2. Warning System
- **Warning Threshold**: 900 strokes (90% of limit)
- **Behavior**: Shows warning once when threshold is crossed
- **Reset**: Warning flag resets when canvas is cleared

#### 3. Visual Stroke Counter
- **Display**: Shows current stroke count and limit (e.g., "150/1000 strokes")
- **Color Coding**:
  - Normal: Gray text
  - Warning (≥900): Orange text, bold
  - Limit Reached (≥1000): Red text, extra bold
- **Location**: In the drawing toolbar next to the clear button

### Code Changes

```javascript
const MAX_STROKES_PER_SESSION = 1000
const STROKE_WARNING_THRESHOLD = 900

function startDrawing(event) {
  if (!enabled) return
  
  // Check if stroke limit is reached
  if (strokes.length >= MAX_STROKES_PER_SESSION) {
    showError(`Maximum stroke limit (${MAX_STROKES_PER_SESSION}) reached. Please clear the canvas to continue drawing.`)
    return
  }
  
  // Show warning if approaching limit
  if (strokes.length >= STROKE_WARNING_THRESHOLD && !strokeLimitWarningShown) {
    showError(`Warning: Approaching stroke limit (${strokes.length}/${MAX_STROKES_PER_SESSION}). Consider clearing the canvas soon.`)
    strokeLimitWarningShown = true
  }
  
  // ... rest of drawing logic
}
```

### UI Changes

```svelte
<span 
  class="stroke-counter"
  class:warning={strokes.length >= STROKE_WARNING_THRESHOLD}
  class:limit-reached={strokes.length >= MAX_STROKES_PER_SESSION}
  title="Number of strokes in this session"
>
  {strokes.length}/{MAX_STROKES_PER_SESSION} strokes
</span>
```

## 8.3 Database Query Optimization

### Implemented Changes

#### 1. Index Verification
- **Existing Indexes**:
  - `drawing_strokes_session_id_index` on `session_id` (btree)
  - `drawing_strokes_inserted_at_index` on `inserted_at` (btree)
- **Verification**: Confirmed indexes are properly created and used by queries
- **Benefit**: Fast filtering and ordering of strokes

#### 2. Pagination Support
- **New Parameters**: Added `limit` and `offset` options to `list_strokes_by_session/2`
- **Usage**:
  ```elixir
  # Get first 100 strokes
  Drawing.list_strokes_by_session(session_id, limit: 100, offset: 0)
  
  # Get next 100 strokes
  Drawing.list_strokes_by_session(session_id, limit: 100, offset: 100)
  ```
- **Benefit**: Efficient loading of large sessions without loading all strokes at once

#### 3. Pagination Helper Function
- **Function**: `should_paginate?/2`
- **Purpose**: Determines if a session has enough strokes to benefit from pagination
- **Default Threshold**: 500 strokes
- **Usage**:
  ```elixir
  case Drawing.should_paginate?(session_id) do
    {:ok, true} -> # Use pagination
    {:ok, false} -> # Load all strokes
  end
  ```

#### 4. Enhanced Documentation
- Added comprehensive module documentation explaining:
  - Available indexes and their purpose
  - Query performance characteristics
  - When to use pagination
  - Performance best practices

### Code Changes

```elixir
def list_strokes_by_session(session_id, opts \\ []) do
  try do
    limit = Keyword.get(opts, :limit)
    offset = Keyword.get(opts, :offset, 0)

    query = Stroke
    |> where([s], s.session_id == ^session_id)
    |> order_by([s], asc: s.inserted_at)

    query = if limit, do: limit(query, ^limit), else: query
    query = if offset > 0, do: offset(query, ^offset), else: query

    strokes = Repo.all(query)
    {:ok, strokes}
  rescue
    # ... error handling
  end
end

def should_paginate?(session_id, threshold \\ 500) do
  case count_strokes_by_session(session_id) do
    {:ok, count} -> {:ok, count > threshold}
    error -> error
  end
end
```

### Test Coverage

Created comprehensive test suite in `test/live_svelte_pheonix/drawing/query_performance_test.exs`:
- Index usage verification
- Pagination with limit
- Pagination with offset
- Combined limit and offset
- Pagination helper function
- Count query efficiency

All tests pass successfully.

## Performance Impact

### Before Optimizations
- Canvas redraws on every mouse move event (potentially 60+ times per second)
- No limit on strokes per session (potential memory issues)
- All strokes loaded at once (slow for large sessions)

### After Optimizations
- Canvas redraws batched with requestAnimationFrame (smooth 60fps)
- Hard limit of 1000 strokes per session with warnings
- Pagination support for sessions with 500+ strokes
- Efficient database queries using proper indexes

## Future Improvements

Potential future optimizations:
1. **Stroke Simplification**: Reduce coordinate density for very long strokes
2. **Lazy Loading**: Load strokes in viewport only for very large canvases
3. **WebGL Rendering**: Use WebGL for hardware-accelerated rendering
4. **Stroke Compression**: Compress path data before storing in database
5. **Incremental Rendering**: Only redraw changed portions of canvas

## Testing

All existing tests continue to pass:
- ✅ Drawing context tests (16 tests)
- ✅ LiveView integration tests (1 test)
- ✅ Query performance tests (8 tests)

Total: 25 tests, 0 failures
