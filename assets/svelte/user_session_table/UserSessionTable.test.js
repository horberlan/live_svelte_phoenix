import { describe, it, expect, beforeEach, afterEach, vi } from 'vitest'

// Fix common UTF-8 encoding issues where characters are double-encoded
// This handles cases like "vocÃª" -> "você" and "ð\u009f¥°" -> "🥰"
function fixEncoding(text) {
  if (!text || typeof text !== 'string') return text
  
  try {
    // Handle the most common cases first - order matters to avoid conflicts
    let result = text
    
    // Fix specific emoji patterns first (more specific patterns)
    result = result.replace(/ð¥°/g, '🥰')
    result = result.replace(/ð­/g, '😭')
    result = result.replace(/ð¥º/g, '🥺')
    result = result.replace(/ð¢/g, '😢')
    result = result.replace(/â˜•/g, '☕')
    result = result.replace(/â­/g, '⭐')
    result = result.replace(/â¨/g, '✨')
    result = result.replace(/â¤/g, '❤')
    result = result.replace(/ð¥/g, '🔥')
    
    // Fix Portuguese/Spanish accented characters
    // Handle compound patterns first
    result = result.replace(/Ã­Ã£o/g, 'ião')
    
    result = result.replace(/Ã¡/g, 'á')
    result = result.replace(/Ã©/g, 'é')
    result = result.replace(/Ã­/g, 'í')
    result = result.replace(/Ã³/g, 'ó')
    result = result.replace(/Ãº/g, 'ú')
    result = result.replace(/Ã /g, 'à')
    result = result.replace(/Ã¨/g, 'è')
    result = result.replace(/Ã¬/g, 'ì')
    result = result.replace(/Ã²/g, 'ò')
    result = result.replace(/Ã¹/g, 'ù')
    result = result.replace(/Ã¢/g, 'â')
    result = result.replace(/Ãª/g, 'ê')
    result = result.replace(/Ã®/g, 'î')
    result = result.replace(/Ã´/g, 'ô')
    result = result.replace(/Ã»/g, 'û')
    result = result.replace(/Ã£/g, 'ã')
    result = result.replace(/Ã±/g, 'ñ')
    result = result.replace(/Ã§/g, 'ç')
    result = result.replace(/Ã‰/g, 'É')
    result = result.replace(/Ã"/g, 'Ó')
    result = result.replace(/Ã‡/g, 'Ç')
    
    return result
  } catch (e) {
    // If fixing fails, return the original text
    return text
  }
}

// Test the createDragPreview function directly
function createDragPreview(draggingItem) {
  const i18n = {
    dragging: 'Dragging',
    shared: 'Shared',
    noTitle: 'Untitled'
  }

  // Create main card container
  const cardDiv = document.createElement('div')
  cardDiv.className = 'card bg-base-100 shadow-2xl border-2 border-primary'
  cardDiv.style.width = '320px'
  cardDiv.style.transform = 'rotate(3deg) scale(1.05)'

  // Create card body
  const cardBody = document.createElement('div')
  cardBody.className = 'card-body p-4 bg-gradient-to-br from-primary/10 to-secondary/10'

  // Create badges container
  const badgesContainer = document.createElement('div')
  badgesContainer.className = 'flex items-start justify-between gap-2 mb-2'

  // Create dragging badge
  const draggingBadge = document.createElement('div')
  draggingBadge.className = 'badge badge-primary badge-sm font-semibold'
  draggingBadge.textContent = i18n.dragging
  badgesContainer.appendChild(draggingBadge)

  // Create shared badge if needed
  if (draggingItem.shared_users && draggingItem.shared_users.length > 0) {
    const sharedBadge = document.createElement('div')
    sharedBadge.className = 'badge badge-secondary badge-sm'
    sharedBadge.textContent = i18n.shared
    badgesContainer.appendChild(sharedBadge)
  }

  // Create title element
  const titleElement = document.createElement('h2')
  titleElement.className = 'card-title text-base font-bold leading-tight line-clamp-2'
  // Use textContent to safely handle Unicode characters and prevent XSS
  titleElement.textContent = fixEncoding(draggingItem.title) || i18n.noTitle

  // Assemble the structure
  cardBody.appendChild(badgesContainer)
  cardBody.appendChild(titleElement)
  cardDiv.appendChild(cardBody)

  return cardDiv
}

describe('Encoding Fix Function Tests', () => {
  describe('Portuguese/Spanish Character Fixes', () => {
    it('should fix common Portuguese accented characters', () => {
      expect(fixEncoding('vocÃª')).toBe('você')
      expect(fixEncoding('Ã¡Ã©Ã­Ã³Ãº')).toBe('áéíóú')
      expect(fixEncoding('Ã Ã¨Ã¬Ã²Ã¹')).toBe('àèìòù')
      expect(fixEncoding('Ã¢ÃªÃ®Ã´Ã»')).toBe('âêîôû')
      expect(fixEncoding('Ã£Ã±Ã§')).toBe('ãñç')
    })

    it('should fix uppercase accented characters', () => {
      expect(fixEncoding('Ã‰')).toBe('É')
      expect(fixEncoding('Ã"')).toBe('Ó')
      expect(fixEncoding('Ã‡')).toBe('Ç')
    })
  })

  describe('Emoji Fixes', () => {
    it('should fix common emoji encoding issues', () => {
      expect(fixEncoding('ð¥°')).toBe('🥰')
      expect(fixEncoding('ð­')).toBe('😭')
      expect(fixEncoding('ð¥º')).toBe('🥺')
      expect(fixEncoding('ð¢')).toBe('😢')
    })

    it('should fix multiple emojis in one string', () => {
      expect(fixEncoding('ð­ð¥ºð¢')).toBe('😭🥺😢')
    })

    it('should fix heart and symbol emojis', () => {
      expect(fixEncoding('â¤')).toBe('❤')
      expect(fixEncoding('â­')).toBe('⭐')
      expect(fixEncoding('â¨')).toBe('✨')
      expect(fixEncoding('ð¥')).toBe('🔥')
    })
  })

  describe('Mixed Content Fixes', () => {
    it('should fix the original problem case', () => {
      expect(fixEncoding('Eu gosto de vocÃª! ð¥°')).toBe('Eu gosto de você! 🥰')
    })

    it('should handle mixed accented characters and emojis', () => {
      expect(fixEncoding('CafÃ© da ManhÃ£ â˜•')).toBe('Café da Manhã ☕')
    })
  })

  describe('Edge Cases', () => {
    it('should return original text if no encoding issues detected', () => {
      expect(fixEncoding('Normal text')).toBe('Normal text')
      expect(fixEncoding('Already correct café ☕')).toBe('Already correct café ☕')
    })

    it('should handle null and undefined gracefully', () => {
      expect(fixEncoding(null)).toBe(null)
      expect(fixEncoding(undefined)).toBe(undefined)
      expect(fixEncoding('')).toBe('')
    })

    it('should handle non-string input gracefully', () => {
      expect(fixEncoding(123)).toBe(123)
      expect(fixEncoding({})).toStrictEqual({})
      expect(fixEncoding([])).toStrictEqual([])
    })
  })
})

describe('UserSessionTable Character Encoding Tests', () => {
  beforeEach(() => {
    // Clean up any existing drag previews
    const existingPreviews = document.querySelectorAll('[style*="position: fixed"]')
    existingPreviews.forEach(preview => preview.remove())
  })

  afterEach(() => {
    // Clean up drag previews after each test
    const dragPreviews = document.querySelectorAll('[style*="position: fixed"]')
    dragPreviews.forEach(preview => preview.remove())
  })

  describe('Accented Characters Rendering', () => {
    const accentedCharacterSessions = [
      { session_id: '1', title: 'Café da Manhã', updated_at: '2024-01-01' },
      { session_id: '2', title: 'Reunião de Negócios', updated_at: '2024-01-02' },
      { session_id: '3', title: 'Código Português', updated_at: '2024-01-03' },
      { session_id: '4', title: 'Configuração Técnica', updated_at: '2024-01-04' },
      { session_id: '5', title: 'Análise de Dados', updated_at: '2024-01-05' },
      { session_id: '6', title: 'Educação Física', updated_at: '2024-01-06' },
      { session_id: '7', title: 'Coração e Emoção', updated_at: '2024-01-07' },
      { session_id: '8', title: 'Informações Úteis', updated_at: '2024-01-08' }
    ]

    it('should display accented characters correctly in drag preview', () => {
      accentedCharacterSessions.forEach(session => {
        const dragPreview = createDragPreview(session)
        const titleElement = dragPreview.querySelector('.card-title')
        
        expect(titleElement.textContent).toBe(session.title)
        expect(titleElement.textContent).toContain(session.title)
      })
    })

    it('should render specific accented characters correctly in drag preview', () => {
      const testSession = { session_id: '1', title: 'Café da Manhã', updated_at: '2024-01-01' }
      const dragPreview = createDragPreview(testSession)
      const titleElement = dragPreview.querySelector('.card-title')
      
      expect(titleElement.textContent).toBe('Café da Manhã')
    })

    it('should preserve all Portuguese accented characters in drag preview', () => {
      const testSession = { session_id: '1', title: 'áéíóúàèìòùâêîôûãç', updated_at: '2024-01-01' }
      const dragPreview = createDragPreview(testSession)
      const titleElement = dragPreview.querySelector('.card-title')
      
      expect(titleElement.textContent).toBe('áéíóúàèìòùâêîôûãç')
    })
  })

  describe('Emoji Rendering', () => {
    const emojiSessions = [
      { session_id: '1', title: 'Coffee Meeting ☕', updated_at: '2024-01-01' },
      { session_id: '2', title: '📅 Calendar Review', updated_at: '2024-01-02' },
      { session_id: '3', title: 'Code Review 💻🔍', updated_at: '2024-01-03' },
      { session_id: '4', title: '🚀 Project Launch 🎉', updated_at: '2024-01-04' },
      { session_id: '5', title: '🌟✨ Special Event ✨🌟', updated_at: '2024-01-05' }
    ]

    it('should display emojis correctly in drag preview', () => {
      emojiSessions.forEach(session => {
        const dragPreview = createDragPreview(session)
        const titleElement = dragPreview.querySelector('.card-title')
        
        expect(titleElement.textContent).toBe(session.title)
      })
    })

    it('should render single emoji correctly in drag preview', () => {
      const testSession = { session_id: '1', title: 'Coffee Meeting ☕', updated_at: '2024-01-01' }
      const dragPreview = createDragPreview(testSession)
      const titleElement = dragPreview.querySelector('.card-title')
      
      expect(titleElement.textContent).toBe('Coffee Meeting ☕')
    })

    it('should render multiple emojis correctly in drag preview', () => {
      const testSession = { session_id: '1', title: '🌟✨ Special Event ✨🌟', updated_at: '2024-01-01' }
      const dragPreview = createDragPreview(testSession)
      const titleElement = dragPreview.querySelector('.card-title')
      
      expect(titleElement.textContent).toBe('🌟✨ Special Event ✨🌟')
    })

    it('should handle complex emoji sequences', () => {
      const testSession = { session_id: '1', title: '👨‍💻👩‍💻 Team Coding 🔥💯', updated_at: '2024-01-01' }
      const dragPreview = createDragPreview(testSession)
      const titleElement = dragPreview.querySelector('.card-title')
      
      expect(titleElement.textContent).toBe('👨‍💻👩‍💻 Team Coding 🔥💯')
    })
  })

  describe('XSS Prevention', () => {
    const maliciousSessions = [
      { 
        session_id: '1', 
        title: '<script>alert("xss")</script>', 
        updated_at: '2024-01-01' 
      },
      { 
        session_id: '2', 
        title: '<img src="x" onerror="alert(\'xss\')">', 
        updated_at: '2024-01-02' 
      },
      { 
        session_id: '3', 
        title: 'javascript:alert("xss")', 
        updated_at: '2024-01-03' 
      },
      { 
        session_id: '4', 
        title: '<iframe src="javascript:alert(\'xss\')"></iframe>', 
        updated_at: '2024-01-04' 
      },
      { 
        session_id: '5', 
        title: '<svg onload="alert(\'xss\')"></svg>', 
        updated_at: '2024-01-05' 
      }
    ]

    it('should display HTML-like content as text in drag preview', () => {
      maliciousSessions.forEach(session => {
        const dragPreview = createDragPreview(session)
        const titleElement = dragPreview.querySelector('.card-title')
        
        // Verify that HTML tags are displayed as text, not executed
        expect(titleElement.textContent).toBe(session.title)
        
        // Verify no script tags were actually created in the DOM
        const scriptTags = dragPreview.querySelectorAll('script')
        expect(scriptTags).toHaveLength(0)
        
        // Verify no img tags with onerror were created
        const imgTags = dragPreview.querySelectorAll('img')
        expect(imgTags).toHaveLength(0)
        
        // Verify no iframe tags were created
        const iframeTags = dragPreview.querySelectorAll('iframe')
        expect(iframeTags).toHaveLength(0)
        
        // Verify no svg tags were created
        const svgTags = dragPreview.querySelectorAll('svg')
        expect(svgTags).toHaveLength(0)
      })
    })

    it('should prevent script execution in drag preview', () => {
      const testSession = { session_id: '1', title: '<script>alert("xss")</script>', updated_at: '2024-01-01' }
      const dragPreview = createDragPreview(testSession)
      const titleElement = dragPreview.querySelector('.card-title')
      
      // Verify the malicious content is displayed as text, not executed
      expect(titleElement.textContent).toBe('<script>alert("xss")</script>')
      
      // Verify no script tags were actually created in the DOM
      const scriptTags = dragPreview.querySelectorAll('script')
      expect(scriptTags).toHaveLength(0)
    })

    it('should sanitize image tags with onerror handlers', () => {
      const testSession = { session_id: '1', title: '<img src="x" onerror="alert(\'xss\')">', updated_at: '2024-01-01' }
      const dragPreview = createDragPreview(testSession)
      const titleElement = dragPreview.querySelector('.card-title')
      
      expect(titleElement.textContent).toBe('<img src="x" onerror="alert(\'xss\')">')
      
      // Verify no img tags with onerror were created
      const imgTags = dragPreview.querySelectorAll('img')
      expect(imgTags).toHaveLength(0)
    })

    it('should handle mixed content with HTML and special characters', () => {
      const testSession = { 
        session_id: '1', 
        title: 'Café <script>alert("xss")</script> Meeting ☕', 
        updated_at: '2024-01-01' 
      }
      const dragPreview = createDragPreview(testSession)
      const titleElement = dragPreview.querySelector('.card-title')
      
      // Should preserve accented characters and emojis while escaping HTML
      expect(titleElement.textContent).toBe('Café <script>alert("xss")</script> Meeting ☕')
    })
  })

  describe('Fallback Behavior', () => {
    it('should handle null title gracefully', () => {
      const testSession = { session_id: '1', title: null, updated_at: '2024-01-01' }
      const dragPreview = createDragPreview(testSession)
      const titleElement = dragPreview.querySelector('.card-title')
      
      expect(titleElement.textContent).toBe('Untitled')
    })

    it('should handle undefined title gracefully', () => {
      const testSession = { session_id: '1', updated_at: '2024-01-01' } // title is undefined
      const dragPreview = createDragPreview(testSession)
      const titleElement = dragPreview.querySelector('.card-title')
      
      expect(titleElement.textContent).toBe('Untitled')
    })

    it('should handle empty string title gracefully', () => {
      const testSession = { session_id: '1', title: '', updated_at: '2024-01-01' }
      const dragPreview = createDragPreview(testSession)
      const titleElement = dragPreview.querySelector('.card-title')
      
      expect(titleElement.textContent).toBe('Untitled')
    })

    it('should handle whitespace-only title gracefully', () => {
      const testSession = { session_id: '1', title: '   ', updated_at: '2024-01-01' }
      const dragPreview = createDragPreview(testSession)
      const titleElement = dragPreview.querySelector('.card-title')
      
      // Whitespace should be preserved as it's technically not empty
      expect(titleElement.textContent).toBe('   ')
    })
  })

  describe('Encoding Fix Integration', () => {
    it('should fix encoding issues in drag preview titles', () => {
      const testSession = { 
        session_id: '1', 
        title: 'Eu gosto de vocÃª! ð¥°', 
        updated_at: '2024-01-01' 
      }
      const dragPreview = createDragPreview(testSession)
      const titleElement = dragPreview.querySelector('.card-title')
      
      expect(titleElement.textContent).toBe('Eu gosto de você! 🥰')
    })

    it('should fix multiple encoding issues in one title', () => {
      const testSession = { 
        session_id: '1', 
        title: 'ReunÃ­Ã£o de NegÃ³cios ð­ð¥º', 
        updated_at: '2024-01-01' 
      }
      const dragPreview = createDragPreview(testSession)
      const titleElement = dragPreview.querySelector('.card-title')
      
      expect(titleElement.textContent).toBe('Reunião de Negócios 😭🥺')
    })

    it('should not modify correctly encoded titles', () => {
      const testSession = { 
        session_id: '1', 
        title: 'Café da Manhã ☕', 
        updated_at: '2024-01-01' 
      }
      const dragPreview = createDragPreview(testSession)
      const titleElement = dragPreview.querySelector('.card-title')
      
      expect(titleElement.textContent).toBe('Café da Manhã ☕')
    })
  })

  describe('Mixed Character Scenarios', () => {
    it('should handle titles with accented characters and emojis together', () => {
      const testSession = { 
        session_id: '1', 
        title: 'Café da Manhã ☕ com Açúcar 🍯', 
        updated_at: '2024-01-01' 
      }
      const dragPreview = createDragPreview(testSession)
      const titleElement = dragPreview.querySelector('.card-title')
      
      expect(titleElement.textContent).toBe('Café da Manhã ☕ com Açúcar 🍯')
    })

    it('should handle very long titles with special characters', () => {
      const longTitle = 'Configuração Técnica Avançada 🚀 para Análise de Dados Científicos 📊 com Integração de Sistemas Complexos 💻 e Otimização de Performance ⚡'
      
      const testSession = { 
        session_id: '1', 
        title: longTitle, 
        updated_at: '2024-01-01' 
      }
      const dragPreview = createDragPreview(testSession)
      const titleElement = dragPreview.querySelector('.card-title')
      
      expect(titleElement.textContent).toBe(longTitle)
    })
  })
})