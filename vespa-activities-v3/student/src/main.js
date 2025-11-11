/**
 * VESPA Activities Student V3 - Main Entry Point
 * IIFE wrapping handled by Vite build (format: 'iife' in vite.config.js)
 */

import { createApp } from 'vue';
import App from './App.vue';
import './style.css';

// Global initializer function for KnackAppLoader
// This will be exposed on window by the IIFE wrapper
window.initializeStudentActivitiesV3 = function() {
  console.log('[VESPA Activities Student V3] Initializer called by KnackAppLoader');
  
  // Get config from KnackAppLoader
  const config = window.STUDENT_ACTIVITIES_V3_CONFIG;
  
  if (!config) {
    console.error('[VESPA Activities Student V3] Config not found');
    return false;
  }
  
  console.log('[VESPA Activities Student V3] Config:', config);
  
  // Find the target element
  const targetElement = document.querySelector(config.elementSelector || '#view_3262');
  
  if (!targetElement) {
    console.error('[VESPA Activities Student V3] Target element not found:', config.elementSelector);
    return false;
  }
  
  console.log('[VESPA Activities Student V3] Mounting into:', config.elementSelector);
  
  // Clear the rich text content
  targetElement.innerHTML = '';
  
  // Create mount point
  const appContainer = document.createElement('div');
  appContainer.id = 'vespa-activities-student-app';
  appContainer.style.width = '100%';
  appContainer.style.height = '100%';
  appContainer.style.minHeight = '600px';
  appContainer.style.display = 'flex';
  appContainer.style.flexDirection = 'column';
  targetElement.appendChild(appContainer);
  
  // Mount Vue app
  try {
    const app = createApp(App, { config });
    app.mount('#vespa-activities-student-app');
    console.log('[VESPA Activities Student V3] App mounted successfully');
    return true;
  } catch (error) {
    console.error('[VESPA Activities Student V3] Mount error:', error);
    return false;
  }
};

console.log('[VESPA Activities Student V3] Script loaded, waiting for KnackAppLoader to call initializer');

