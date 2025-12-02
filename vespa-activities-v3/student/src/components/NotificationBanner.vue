<template>
  <transition name="slide-down">
    <div v-if="visibleNotifications.length > 0" class="notification-banner">
      <div class="banner-content">
        <div class="notification-item" v-for="(notification, index) in visibleNotifications" :key="notification.id || index">
          <span class="notification-icon">{{ getIcon(notification.notification_type) }}</span>
          <span class="notification-message">{{ notification.message }}</span>
          <button 
            @click="dismissNotification(notification.id)" 
            class="dismiss-btn"
            title="Dismiss"
          >
            ×
          </button>
        </div>
      </div>
      <button v-if="notifications.length > 1" @click="dismissAll" class="dismiss-all-btn">
        Dismiss All
      </button>
    </div>
  </transition>
</template>

<script setup>
import { computed } from 'vue';

const props = defineProps({
  notifications: {
    type: Array,
    default: () => []
  }
});

const emit = defineEmits(['dismiss', 'dismiss-all', 'click-notification']);

// Show max 3 notifications at a time
const visibleNotifications = computed(() => {
  return props.notifications.slice(0, 3);
});

const getIcon = (type) => {
  const icons = {
    'feedback_received': '💬',
    'activity_assigned': '📚',
    'achievement_earned': '🏆',
    'reminder': '⏰',
    'milestone': '🎯',
    'staff_note': '✉️',
    'encouragement': '⭐'
  };
  return icons[type] || '🔔';
};

const dismissNotification = (id) => {
  emit('dismiss', id);
};

const dismissAll = () => {
  emit('dismiss-all');
};
</script>

<style scoped>
.notification-banner {
  position: fixed;
  top: 70px;
  left: 50%;
  transform: translateX(-50%);
  z-index: 1000;
  max-width: 600px;
  width: 95%;
}

.banner-content {
  display: flex;
  flex-direction: column;
  gap: 8px;
}

.notification-item {
  display: flex;
  align-items: center;
  gap: 12px;
  background: white;
  border-left: 4px solid #079baa;
  padding: 12px 16px;
  border-radius: 8px;
  box-shadow: 0 4px 16px rgba(0, 0, 0, 0.15);
  animation: slideIn 0.3s ease-out;
}

@keyframes slideIn {
  from {
    opacity: 0;
    transform: translateY(-10px);
  }
  to {
    opacity: 1;
    transform: translateY(0);
  }
}

.notification-icon {
  font-size: 1.5rem;
  flex-shrink: 0;
}

.notification-message {
  flex: 1;
  font-size: 0.9375rem;
  color: #212529;
  line-height: 1.4;
}

.dismiss-btn {
  width: 28px;
  height: 28px;
  border: none;
  background: #f1f5f9;
  border-radius: 50%;
  color: #64748b;
  font-size: 1.25rem;
  cursor: pointer;
  transition: all 0.2s;
  display: flex;
  align-items: center;
  justify-content: center;
  flex-shrink: 0;
}

.dismiss-btn:hover {
  background: #dc3545;
  color: white;
}

.dismiss-all-btn {
  display: block;
  margin: 8px auto 0;
  padding: 8px 16px;
  background: #f8fafc;
  border: 1px solid #e2e8f0;
  border-radius: 6px;
  color: #64748b;
  font-size: 0.875rem;
  cursor: pointer;
  transition: all 0.2s;
}

.dismiss-all-btn:hover {
  background: #e2e8f0;
  color: #475569;
}

/* Transition */
.slide-down-enter-active,
.slide-down-leave-active {
  transition: all 0.3s ease;
}

.slide-down-enter-from,
.slide-down-leave-to {
  opacity: 0;
  transform: translateX(-50%) translateY(-20px);
}

/* Different border colors for notification types */
.notification-item[data-type="feedback_received"] {
  border-left-color: #dc3545;
}

.notification-item[data-type="achievement_earned"] {
  border-left-color: #ffc107;
}

.notification-item[data-type="activity_assigned"] {
  border-left-color: #079baa;
}

@media (max-width: 768px) {
  .notification-banner {
    top: 60px;
    width: 98%;
  }
  
  .notification-item {
    padding: 10px 12px;
  }
  
  .notification-message {
    font-size: 0.875rem;
  }
}
</style>

