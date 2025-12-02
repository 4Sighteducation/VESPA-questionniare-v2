<template>
  <div class="confirm-modal-overlay" @click.self="cancel">
    <div class="confirm-modal" :class="{'danger-modal': isDanger}">
      <div class="confirm-header" :class="{'danger-header': isDanger}">
        <i :class="icon || (isDanger ? 'fas fa-exclamation-triangle' : 'fas fa-question-circle')"></i>
        <h3>{{ title || (isDanger ? 'Warning' : 'Confirm Action') }}</h3>
      </div>
      
      <div class="confirm-body">
        <p v-html="message"></p>
      </div>
      
      <div class="confirm-footer">
        <button class="btn btn-secondary" @click="cancel">
          {{ cancelText || 'Cancel' }}
        </button>
        <button :class="['btn', isDanger ? 'btn-danger' : 'btn-primary']" @click="confirm">
          {{ confirmText || 'Confirm' }}
        </button>
      </div>
    </div>
  </div>
</template>

<script setup>
const props = defineProps({
  title: String,
  message: String,
  confirmText: String,
  cancelText: String,
  isDanger: Boolean,
  icon: String
});

const emit = defineEmits(['confirm', 'cancel']);

const confirm = () => emit('confirm');
const cancel = () => emit('cancel');
</script>

<style scoped>
.confirm-modal-overlay {
  position: fixed !important;
  top: 0 !important;
  left: 0 !important;
  right: 0 !important;
  bottom: 0 !important;
  background: rgba(0, 0, 0, 0.7) !important;
  display: flex !important;
  align-items: center !important;
  justify-content: center !important;
  z-index: 1000001 !important;
  padding: 20px !important;
  animation: fadeIn 0.2s;
}

@keyframes fadeIn {
  from { opacity: 0; }
  to { opacity: 1; }
}

.confirm-modal {
  background: white;
  border-radius: 12px;
  max-width: 500px;
  width: 100%;
  box-shadow: 0 20px 60px rgba(0, 0, 0, 0.3);
  animation: slideIn 0.3s;
}

@keyframes slideIn {
  from { transform: translateY(-50px); opacity: 0; }
  to { transform: translateY(0); opacity: 1; }
}

.confirm-header {
  padding: 24px;
  border-bottom: 1px solid #dee2e6;
  display: flex;
  align-items: center;
  gap: 12px;
  background: #f8f9fa;
  border-radius: 12px 12px 0 0;
}

.confirm-header.danger-header {
  background: #fff5f5;
  border-bottom-color: #feb2b2;
}

.confirm-header i {
  font-size: 32px;
  color: #079baa;
}

.danger-header i {
  color: #dc3545;
}

.confirm-header h3 {
  margin: 0;
  font-size: 20px;
  font-weight: 600;
  color: #343a40;
}

.confirm-body {
  padding: 24px;
  font-size: 15px;
  line-height: 1.6;
  color: #495057;
}

.confirm-body p {
  margin: 0;
  white-space: pre-line;
}

.confirm-footer {
  padding: 16px 24px;
  border-top: 1px solid #dee2e6;
  display: flex;
  justify-content: flex-end;
  gap: 12px;
  background: #f8f9fa;
  border-radius: 0 0 12px 12px;
}

.btn {
  padding: 10px 24px;
  border-radius: 6px;
  font-size: 14px;
  font-weight: 600;
  border: none;
  cursor: pointer;
  transition: all 0.2s;
  display: inline-flex;
  align-items: center;
  gap: 8px;
}

.btn-secondary {
  background: #6c757d;
  color: white;
}

.btn-secondary:hover {
  background: #5a6268;
}

.btn-primary {
  background: #079baa;
  color: white;
}

.btn-primary:hover {
  background: #006b77;
}

.btn-danger {
  background: #dc3545;
  color: white;
}

.btn-danger:hover {
  background: #c82333;
}
</style>

