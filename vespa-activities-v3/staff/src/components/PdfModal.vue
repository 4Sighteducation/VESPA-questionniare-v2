<template>
  <div class="pdf-modal-overlay" @click.self="$emit('close')">
    <div class="pdf-modal">
      <div class="pdf-modal-header">
        <h3 class="pdf-modal-title">
          <i class="fas fa-file-pdf"></i>
          View PDF: {{ title || 'Document' }}
        </h3>
        <div class="pdf-modal-actions">
          <a :href="pdfUrl" target="_blank" class="btn-icon btn-primary" title="Open in new tab">
            <i class="fas fa-external-link-alt"></i>
          </a>
          <a :href="pdfUrl" download class="btn-icon" title="Download">
            <i class="fas fa-download"></i>
          </a>
          <button class="btn-icon btn-close" @click="$emit('close')" title="Close (or click outside)">
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
  position: fixed !important;
  top: 0 !important;
  left: 0 !important;
  right: 0 !important;
  bottom: 0 !important;
  background: rgba(0, 0, 0, 0.8) !important;
  display: flex !important;
  align-items: center !important;
  justify-content: center !important;
  z-index: 1000000 !important;  /* HIGHEST - above activity modal */
  padding: 20px !important;
  cursor: pointer !important;
}

.pdf-modal {
  background: white;
  border-radius: 12px;
  width: 100%;
  max-width: 800px;  /* MUCH smaller - was 1200px */
  height: 70vh;  /* MUCH smaller - was 90vh */
  display: flex;
  flex-direction: column;
  box-shadow: 0 20px 60px rgba(0, 0, 0, 0.5);
  overflow: hidden;
}

.pdf-modal-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  padding: 12px 20px;  /* Slightly smaller */
  background: #f8f9fa;
  border-bottom: 2px solid #dee2e6;
  flex-shrink: 0;
}

.pdf-modal-title {
  margin: 0;
  font-size: 16px;  /* Smaller */
  font-weight: 600;
  color: #343a40;
  display: flex;
  align-items: center;
  gap: 8px;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
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

.btn-close {
  background: #dc3545 !important;
  color: white !important;
  border-color: #dc3545 !important;
}

.btn-close:hover {
  background: #c82333 !important;
  border-color: #bd2130 !important;
}

.btn-primary {
  background: #079baa !important;
  color: white !important;
  border-color: #079baa !important;
}

.btn-primary:hover {
  background: #006b77 !important;
  border-color: #006b77 !important;
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

