import { createApp } from 'vue'
import App from './App.vue'
import './style.css'

// Global initializer function for KnackAppLoader
window.initializeQuestionnaireV2 = function() {
  console.log('[VESPA Questionnaire V2] Initializer called by KnackAppLoader')
  
  // Get config from KnackAppLoader
  const config = window.QUESTIONNAIRE_V2_CONFIG
  
  if (!config) {
    console.error('[VESPA Questionnaire V2] Config not found')
    return false
  }
  
  console.log('[VESPA Questionnaire V2] Config:', config)
  
  // Find the target element
  const targetElement = document.querySelector(config.elementSelector || '#view_3247')
  
  if (!targetElement) {
    console.error('[VESPA Questionnaire V2] Target element not found:', config.elementSelector)
    return false
  }
  
  console.log('[VESPA Questionnaire V2] Mounting into:', config.elementSelector)
  
  // Clear the rich text content
  targetElement.innerHTML = ''
  
  // Create mount point
  const appContainer = document.createElement('div')
  appContainer.id = 'vespa-questionnaire-v2-app'
  appContainer.style.width = '100%'
  appContainer.style.height = '100%'
  appContainer.style.minHeight = '600px'
  appContainer.style.display = 'flex'
  appContainer.style.flexDirection = 'column'
  targetElement.appendChild(appContainer)
  
  // Mount Vue app
  try {
    const app = createApp(App)
    app.mount('#vespa-questionnaire-v2-app')
    console.log('[VESPA Questionnaire V2] App mounted successfully')
    return true
  } catch (error) {
    console.error('[VESPA Questionnaire V2] Mount error:', error)
    return false
  }
}

console.log('[VESPA Questionnaire V2] Script loaded, waiting for KnackAppLoader to call initializer')

