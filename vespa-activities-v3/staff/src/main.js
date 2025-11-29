/**
 * VESPA Activities V3 - Staff Dashboard
 * Main entry point for KnackAppLoader integration
 */

import { createApp } from 'vue';
import App from './App.vue';
import './style.css';

// Global initializer function for KnackAppLoader
window.initializeStaffActivitiesMonitorV3 = function() {
  console.log('[VESPA Staff Activities V3] Initializer called by KnackAppLoader');
  
  // Get config from KnackAppLoader
  const config = window.STAFF_ACTIVITIES_MONITOR_V3_CONFIG;
  
  if (!config) {
    console.error('[VESPA Staff Activities V3] Config not found');
    return false;
  }
  
  console.log('[VESPA Staff Activities V3] Config:', config);
  
  // Find the target element
  const targetElement = document.querySelector(config.elementSelector || '#view_3268');
  
  if (!targetElement) {
    console.error('[VESPA Staff Activities V3] Target element not found:', config.elementSelector);
    return false;
  }
  
  console.log('[VESPA Staff Activities V3] Mounting into:', config.elementSelector);
  
  // Clear the rich text content
  targetElement.innerHTML = '';
  
  // Create mount point
  const appContainer = document.createElement('div');
  appContainer.id = 'vespa-staff-activities-app';
  appContainer.style.width = '100%';
  appContainer.style.minHeight = '600px';
  appContainer.style.display = 'flex';
  appContainer.style.flexDirection = 'column';
  targetElement.appendChild(appContainer);
  
  // Mount Vue app
  try {
    const app = createApp(App, { config });
    
    // Global error handler
    app.config.errorHandler = (err, instance, info) => {
      console.error('[VESPA Staff V3] Vue Error:', err);
      console.error('[VESPA Staff V3] Error Info:', info);
    };
    
    app.mount('#vespa-staff-activities-app');
    console.log('[VESPA Staff Activities V3] App mounted successfully');
    return true;
  } catch (error) {
    console.error('[VESPA Staff Activities V3] Mount error:', error);
    appContainer.innerHTML = '<div style="padding: 20px; color: red; text-align: center;"><h3>Error loading Staff Dashboard</h3><p>' + error.message + '</p></div>';
    return false;
  }
};

console.log('[VESPA Staff Activities V3] Script loaded, initializer function available');

