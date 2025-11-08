<template>
  <div class="loading-check">
    <div class="loading-content">
      <img 
        src="https://vespa.academy/_astro/vespalogo.BGrK1ARl.png" 
        alt="VESPA Academy" 
        class="vespa-logo"
      >
      <div class="spinner"></div>
      <p class="loading-text">{{ loadingText }}</p>
      <p v-if="subText" class="loading-subtext">{{ subText }}</p>
    </div>
  </div>
</template>

<script>
export default {
  name: 'LoadingCheck',
  props: {
    loadingText: {
      type: String,
      default: 'Loading...'
    },
    subText: {
      type: String,
      default: ''
    }
  }
}
</script>

<style scoped>
.loading-check {
  min-height: 100vh;
  display: flex;
  align-items: center;
  justify-content: center;
  padding: 20px;
}

.loading-content {
  text-align: center;
  color: white;
}

.vespa-logo {
  width: 150px;
  height: auto;
  margin-bottom: 30px;
  animation: pulse 1.5s ease-in-out infinite;
}

@keyframes pulse {
  0%, 100% { 
    transform: scale(1); 
    opacity: 1;
  }
  50% { 
    transform: scale(1.05); 
    opacity: 0.8;
  }
}

.spinner {
  margin: 0 auto 20px;
}

.loading-text {
  font-size: 20px;
  font-weight: 300;
  letter-spacing: 1px;
  margin-bottom: 10px;
}

.loading-subtext {
  font-size: 14px;
  opacity: 0.7;
  animation: fadeInOut 2s ease-in-out infinite;
}

@keyframes fadeInOut {
  0%, 100% { opacity: 0.7; }
  50% { opacity: 0.4; }
}

@media (max-width: 768px) {
  .vespa-logo {
    width: 120px;
  }
  
  .loading-text {
    font-size: 18px;
  }
  
  .loading-subtext {
    font-size: 12px;
  }
}
</style>
