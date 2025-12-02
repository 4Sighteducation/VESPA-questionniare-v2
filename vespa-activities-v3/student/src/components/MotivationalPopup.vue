<template>
  <div class="modal-overlay" @click.self="handleDismiss">
    <div class="motivational-popup">
      <button class="popup-close" @click="handleDismiss">
        <i class="fas fa-times"></i>
      </button>
      
      <div class="popup-icon">
        {{ randomEmoji }}
      </div>
      
      <h3 class="popup-title">Keep Going!</h3>
      
      <p class="motivational-message">
        {{ randomMessage }}
      </p>
      
      <div class="progress-snippet" v-if="stats">
        <div class="stat-mini">
          <span class="stat-emoji">✅</span>
          <span class="stat-text">{{ stats.completed }} completed</span>
        </div>
        <div class="stat-mini">
          <span class="stat-emoji">⏳</span>
          <span class="stat-text">{{ stats.inProgress }} in progress</span>
        </div>
        <div class="stat-mini">
          <span class="stat-emoji">💎</span>
          <span class="stat-text">{{ stats.points }} points</span>
        </div>
      </div>
      
      <div class="popup-actions">
        <button class="btn btn-primary btn-block" @click="handleDismiss">
          <i class="fas fa-rocket"></i>
          Continue Working
        </button>
        <button class="btn btn-secondary btn-block" @click="handleAddMore">
          <i class="fas fa-plus-circle"></i>
          Got a New Study Issue? Add More Activities
        </button>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, computed, onMounted } from 'vue';

const props = defineProps({
  stats: {
    type: Object,
    default: () => ({ completed: 0, inProgress: 0, points: 0 })
  }
});

const emit = defineEmits(['dismiss', 'add-more']);

// 10 Motivational Messages
const motivationalMessages = [
  "Future you is watching. Revise in a way they'd be proud of, not puzzled by.",
  "You don't need to 'feel motivated' — you just need to start for five minutes.",
  "Every focused half-hour now is an hour of panic you skip later.",
  "This isn't about being 'smart' — it's about being prepared.",
  "You're not just studying for a grade; you're training how your brain works.",
  "Discipline is doing the boring bits on purpose. That's what you're doing now.",
  "You can't control the exam questions, but you can control your preparation.",
  "Your future opportunities are quietly being decided by what you do this hour.",
  "Perfection is optional. Showing up and doing something today is not.",
  "You don't have to overhaul your life. Just win this next 20 minutes."
];

// Random emoji for variety
const emojis = ['🌟', '💪', '🚀', '🎯', '⭐', '💡', '🔥', '✨', '🎓', '📚'];

const randomMessage = ref('');
const randomEmoji = ref('');

onMounted(() => {
  // Pick random message
  const messageIndex = Math.floor(Math.random() * motivationalMessages.length);
  randomMessage.value = motivationalMessages[messageIndex];
  
  // Pick random emoji
  const emojiIndex = Math.floor(Math.random() * emojis.length);
  randomEmoji.value = emojis[emojiIndex];
});

const handleDismiss = () => {
  emit('dismiss');
};

const handleAddMore = () => {
  console.log('[MotivationalPopup] 🎯 Add More button clicked');
  emit('add-more');
  console.log('[MotivationalPopup] 📤 Emitted add-more event');
};
</script>

<style scoped>
.motivational-popup {
  background: white;
  border-radius: 20px;
  padding: 2.5rem 2rem;
  max-width: 500px;
  width: 95%;
  text-align: center;
  box-shadow: 0 20px 60px rgba(0, 0, 0, 0.3);
  position: relative;
  animation: bounceIn 0.5s ease-out;
}

.popup-close {
  position: absolute;
  top: 1rem;
  right: 1rem;
  background: transparent;
  border: none;
  color: #6c757d;
  width: 32px;
  height: 32px;
  border-radius: 50%;
  cursor: pointer;
  display: flex;
  align-items: center;
  justify-content: center;
  transition: all 0.2s;
  font-size: 18px;
}

.popup-close:hover {
  background: #f8f9fa;
  color: #212529;
  transform: rotate(90deg);
}

.popup-icon {
  font-size: 4rem;
  margin-bottom: 1rem;
  animation: pulse 2s ease-in-out infinite;
}

@keyframes pulse {
  0%, 100% { transform: scale(1); }
  50% { transform: scale(1.1); }
}

.popup-title {
  font-size: 1.75rem;
  font-weight: 700;
  color: #079baa;
  margin: 0 0 1rem 0;
}

.motivational-message {
  font-size: 1.125rem;
  line-height: 1.6;
  color: #495057;
  margin: 0 0 1.5rem 0;
  font-style: italic;
  padding: 0 1rem;
}

.progress-snippet {
  display: flex;
  justify-content: center;
  gap: 1.5rem;
  margin-bottom: 1.5rem;
  padding: 1rem;
  background: linear-gradient(135deg, #f8f9fa 0%, #e9ecef 100%);
  border-radius: 12px;
}

.stat-mini {
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 0.25rem;
}

.stat-emoji {
  font-size: 1.5rem;
}

.stat-text {
  font-size: 0.875rem;
  font-weight: 600;
  color: #495057;
}

.popup-actions {
  display: flex;
  flex-direction: column;
  gap: 0.75rem;
}

.btn-block {
  width: 100%;
  padding: 0.875rem 1.5rem;
  font-size: 1rem;
}

.btn-secondary {
  background: white;
  border: 2px solid #079baa;
  color: #079baa;
}

.btn-secondary:hover {
  background: #079baa;
  color: white;
}

@keyframes bounceIn {
  0% {
    transform: scale(0.3);
    opacity: 0;
  }
  50% {
    transform: scale(1.05);
  }
  70% {
    transform: scale(0.9);
  }
  100% {
    transform: scale(1);
    opacity: 1;
  }
}

/* Mobile */
@media (max-width: 768px) {
  .motivational-popup {
    padding: 2rem 1.5rem;
  }
  
  .popup-title {
    font-size: 1.5rem;
  }
  
  .motivational-message {
    font-size: 1rem;
  }
  
  .progress-snippet {
    flex-direction: column;
    gap: 0.75rem;
  }
}
</style>

