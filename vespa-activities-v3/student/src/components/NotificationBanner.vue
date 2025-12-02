<template>
  <transition name="slide-down">
    <div v-if="visibleNotifications.length > 0" class="notification-banner">
      <div class="banner-header">
        <h2 class="banner-title">
          <span>🔔</span> New Updates!
        </h2>
      </div>
      <div class="banner-content">
        <div 
          class="notification-item" 
          :class="getTypeClass(notification.notification_type)"
          v-for="(notification, index) in visibleNotifications" 
          :key="notification.id || index"
        >
          <span class="notification-icon">{{ getIcon(notification.notification_type) }}</span>
          <span class="notification-message">{{ notification.message }}</span>
          <button 
            @click="dismissNotification(notification.id)" 
            class="dismiss-btn"
            title="Dismiss this notification"
          >
            ×
          </button>
        </div>
      </div>
      <button @click="dismissAll" class="dismiss-all-btn">
        ✓ Got it, thanks!
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

const getTypeClass = (type) => {
  const classes = {
    'feedback_received': 'feedback',
    'activity_assigned': 'activity',
    'achievement_earned': 'achievement'
  };
  return classes[type] || '';
};

const dismissNotification = (id) => {
  console.log('[NotificationBanner] 📤 Dismiss button clicked for id:', id);
  emit('dismiss', id);
};

const dismissAll = () => {
  console.log('[NotificationBanner] 📤 Dismiss All button clicked');
  emit('dismiss-all');
};
</script>

<style scoped>
.notification-banner {
  position: fixed;
  top: 50%;
  left: 50%;
  transform: translate(-50%, -50%);
  z-index: 9999;
  max-width: 550px;
  width: 90%;
  background: linear-gradient(135deg, rgba(255,255,255,0.98) 0%, rgba(248,250,252,0.98) 100%);
  border-radius: 20px;
  padding: 24px;
  box-shadow: 
    0 25px 50px rgba(0, 0, 0, 0.25),
    0 0 0 1px rgba(7, 155, 170, 0.1),
    inset 0 1px 0 rgba(255, 255, 255, 0.5);
  backdrop-filter: blur(10px);
  animation: popIn 0.4s cubic-bezier(0.175, 0.885, 0.32, 1.275);
}

@keyframes popIn {
  0% {
    opacity: 0;
    transform: translate(-50%, -50%) scale(0.8);
  }
  100% {
    opacity: 1;
    transform: translate(-50%, -50%) scale(1);
  }
}

/* Overlay backdrop */
.notification-banner::before {
  content: '';
  position: fixed;
  top: -100vh;
  left: -100vw;
  right: -100vw;
  bottom: -100vh;
  background: rgba(0, 0, 0, 0.4);
  z-index: -1;
}

.banner-header {
  text-align: center;
  margin-bottom: 20px;
}

.banner-title {
  font-size: 1.5rem;
  font-weight: 700;
  color: #079baa;
  margin: 0;
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 10px;
}

.banner-content {
  display: flex;
  flex-direction: column;
  gap: 12px;
}

.notification-item {
  display: flex;
  align-items: center;
  gap: 14px;
  background: linear-gradient(135deg, #ffffff 0%, #f8fafc 100%);
  border-left: 5px solid #079baa;
  padding: 16px 18px;
  border-radius: 12px;
  box-shadow: 0 4px 12px rgba(0, 0, 0, 0.08);
  animation: slideIn 0.3s ease-out;
  transition: all 0.2s ease;
}

.notification-item:hover {
  transform: translateX(4px);
  box-shadow: 0 6px 16px rgba(0, 0, 0, 0.12);
}

@keyframes slideIn {
  from {
    opacity: 0;
    transform: translateX(-20px);
  }
  to {
    opacity: 1;
    transform: translateX(0);
  }
}

.notification-icon {
  font-size: 2rem;
  flex-shrink: 0;
  filter: drop-shadow(0 2px 4px rgba(0,0,0,0.1));
}

.notification-message {
  flex: 1;
  font-size: 1rem;
  color: #1e293b;
  line-height: 1.5;
  font-weight: 500;
}

.dismiss-btn {
  width: 32px;
  height: 32px;
  border: none;
  background: linear-gradient(135deg, #f1f5f9 0%, #e2e8f0 100%);
  border-radius: 50%;
  color: #64748b;
  font-size: 1.25rem;
  cursor: pointer;
  transition: all 0.2s;
  display: flex;
  align-items: center;
  justify-content: center;
  flex-shrink: 0;
  box-shadow: 0 2px 4px rgba(0, 0, 0, 0.1);
}

.dismiss-btn:hover {
  background: linear-gradient(135deg, #ef4444 0%, #dc2626 100%);
  color: white;
  transform: scale(1.1);
  box-shadow: 0 4px 12px rgba(239, 68, 68, 0.4);
}

.dismiss-all-btn {
  display: block;
  margin: 20px auto 0;
  padding: 12px 28px;
  background: linear-gradient(135deg, #079baa 0%, #0891b2 100%);
  border: none;
  border-radius: 25px;
  color: white;
  font-size: 0.95rem;
  font-weight: 600;
  cursor: pointer;
  transition: all 0.3s;
  box-shadow: 0 4px 12px rgba(7, 155, 170, 0.3);
}

.dismiss-all-btn:hover {
  transform: translateY(-2px);
  box-shadow: 0 6px 20px rgba(7, 155, 170, 0.4);
  background: linear-gradient(135deg, #0891b2 0%, #0e7490 100%);
}

/* Transition */
.slide-down-enter-active,
.slide-down-leave-active {
  transition: all 0.3s ease;
}

.slide-down-enter-from,
.slide-down-leave-to {
  opacity: 0;
  transform: translate(-50%, -50%) scale(0.9);
}

/* Different border colors for notification types */
.notification-item.feedback {
  border-left-color: #ef4444;
  background: linear-gradient(135deg, #fff5f5 0%, #fef2f2 100%);
}

.notification-item.achievement {
  border-left-color: #f59e0b;
  background: linear-gradient(135deg, #fffbeb 0%, #fef3c7 100%);
}

.notification-item.activity {
  border-left-color: #079baa;
  background: linear-gradient(135deg, #f0fdfa 0%, #ccfbf1 100%);
}

@media (max-width: 768px) {
  .notification-banner {
    width: 95%;
    padding: 16px;
    max-width: none;
  }
  
  .notification-item {
    padding: 12px 14px;
  }
  
  .notification-message {
    font-size: 0.9rem;
  }
  
  .banner-title {
    font-size: 1.25rem;
  }
}
</style>

