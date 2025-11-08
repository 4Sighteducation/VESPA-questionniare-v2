import { createApp } from 'vue'
import App from './App.vue'
import './style.css'

// Wait for Knack to be ready before mounting
function initializeApp() {
  const app = createApp(App)
  app.mount('#app')
  console.log('[VESPA Questionnaire V2] App initialized')
}

// Check if we're in Knack environment
if (typeof window.Knack !== 'undefined') {
  // Wait for Knack to be fully ready
  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', initializeApp)
  } else {
    initializeApp()
  }
} else {
  // Standalone mode (for testing)
  console.warn('[VESPA Questionnaire V2] Knack not detected - running in standalone mode')
  initializeApp()
}

// Global initializer function for KnackAppLoader
window.initializeQuestionnaireV2 = function() {
  console.log('[VESPA Questionnaire V2] Global initializer called')
  // App will initialize when mounted
  return true
}

