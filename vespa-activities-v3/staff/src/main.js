/**
 * VESPA Activities V3 - Staff Dashboard
 * Main entry point
 */

import { createApp } from 'vue';
import App from './App.vue';
import './style.css';

const app = createApp(App);

// Global error handler
app.config.errorHandler = (err, instance, info) => {
  console.error('Vue Error:', err);
  console.error('Error Info:', info);
  console.error('Component:', instance);
};

app.mount('#app');

console.log('🎯 VESPA Staff Dashboard V3 initialized');

