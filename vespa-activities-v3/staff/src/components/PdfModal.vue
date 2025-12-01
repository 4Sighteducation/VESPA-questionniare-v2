<template>
  <div class="pdf-modal-overlay" @click.self="$emit('close')">
    <div class="pdf-modal">
      <div class="pdf-modal-header">
        <h3 class="pdf-modal-title">
          <i class="fas fa-file-pdf"></i>
          {{ title || 'PDF Document' }}
        </h3>
        <div class="pdf-modal-actions">
          <a :href="pdfUrl" target="_blank" class="btn-icon" title="Open in new tab">
            <i class="fas fa-external-link-alt"></i>
          </a>
          <a :href="pdfUrl" download class="btn-icon" title="Download PDF">
            <i class="fas fa-download"></i>
          </a>
          <button class="btn-icon" @click="$emit('close')" title="Close">
            <i class="fas fa-times"></i>
          </button>
        </div>
      </div>
      <div class="pdf-modal-body">
        <iframe
          :src="pdfUrl"
          class="pdf-viewer"
          frameborder="0"
        ></iframe>
      </div>
    </div>
  </div>
</template>

<script setup>
import { computed } from 'vue';

const props = defineProps({
  pdfUrl: {
    type: String,
    required: true
  },
  title: {
    type: String,
    default: ''
  }
});

defineEmits(['close']);
</script>

<style scoped>
.pdf-modal-overlay {
  position: fixed;
  top: 0;
  left: 0;
  right: 0;
  bottom: 0;
  background: rgba(0, 0, 0, 0.85);
  display: flex;
  align-items: center;
  justify-content: center;
  z-index: 9999;
  padding: 20px;
}

.pdf-modal {
  background: white;
  border-radius: 12px;
  width: 100%;
  max-width: 1200px;
  height: 90vh;
  display: flex;
  flex-direction: column;
  box-shadow: 0 20px 60px rgba(0, 0, 0, 0.5);
  overflow: hidden;
}

.pdf-modal-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  padding: 16px 24px;
  background: #f8f9fa;
  border-bottom: 1px solid #dee2e6;
}

.pdf-modal-title {
  margin: 0;
  font-size: 18px;
  font-weight: 600;
  color: #343a40;
  display: flex;
  align-items: center;
  gap: 10px;
}

.pdf-modal-title i {
  color: #dc3545;
  font-size: 22px;
}

.pdf-modal-actions {
  display: flex;
  gap: 8px;
  align-items: center;
}

.btn-icon {
  width: 40px;
  height: 40px;
  display: flex;
  align-items: center;
  justify-content: center;
  background: white;
  border: 1px solid #dee2e6;
  border-radius: 6px;
  color: #6c757d;
  cursor: pointer;
  transition: all 0.2s;
  text-decoration: none;
  font-size: 16px;
}

.btn-icon:hover {
  background: #079baa;
  color: white;
  border-color: #079baa;
  transform: translateY(-1px);
}

.pdf-modal-body {
  flex: 1;
  overflow: hidden;
  background: #525659;
}

.pdf-viewer {
  width: 100%;
  height: 100%;
  border: none;
}

@media (max-width: 768px) {
  .pdf-modal {
    height: 95vh;
    max-width: 100%;
    border-radius: 8px;
  }
  
  .pdf-modal-header {
    padding: 12px 16px;
  }
  
  .pdf-modal-title {
    font-size: 16px;
  }
  
  .btn-icon {
    width: 36px;
    height: 36px;
    font-size: 14px;
  }
}
</style>

