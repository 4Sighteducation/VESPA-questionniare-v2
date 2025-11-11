<template>
  <div class="activity-modal-overlay" @click.self="handleClose">
    <div class="activity-modal">
      <!-- Header -->
      <div class="modal-header">
        <div class="header-content">
          <h2>{{ activity.name }}</h2>
          <div class="activity-meta">
            <span class="category-badge" :style="{ backgroundColor: categoryColor }">
              {{ activity.vespa_category }}
            </span>
            <span>⏱️ {{ activity.time_minutes || 'N/A' }} min</span>
            <span>📊 {{ activity.level }}</span>
          </div>
        </div>
        <button @click="handleClose" class="close-btn">✕</button>
      </div>
      
      <!-- Content Sections -->
      <div class="modal-content">
        <!-- DO Section -->
        <section v-if="activity.do_section_html" class="content-section">
          <h3>DO</h3>
          <div class="section-content" v-html="activity.do_section_html"></div>
        </section>
        
        <!-- THINK Section -->
        <section v-if="activity.think_section_html" class="content-section">
          <h3>THINK</h3>
          <div class="section-content" v-html="activity.think_section_html"></div>
        </section>
        
        <!-- LEARN Section -->
        <section v-if="activity.learn_section_html" class="content-section">
          <h3>LEARN</h3>
          <div class="section-content" v-html="activity.learn_section_html"></div>
        </section>
        
        <!-- Questions -->
        <section v-if="questions.length > 0" class="questions-section">
          <h3>Your Responses</h3>
          <div class="questions-list">
            <QuestionRenderer
              v-for="question in questions"
              :key="question.id"
              :question="question"
              :model-value="responses[question.id] || getExistingResponse(question.id)"
              @update:model-value="updateResponse(question.id, $event)"
            />
          </div>
        </section>
        
        <!-- REFLECT Section -->
        <section v-if="activity.reflect_section_html" class="content-section">
          <h3>REFLECT</h3>
          <div class="section-content" v-html="activity.reflect_section_html"></div>
        </section>
        
        <!-- Reflection Textarea -->
        <section class="reflection-section">
          <label class="reflection-label">
            Final Reflection
            <span class="word-count">{{ reflectionWordCount }} words</span>
          </label>
          <textarea
            v-model="reflection"
            class="reflection-textarea"
            placeholder="Write your final thoughts and reflections here..."
            rows="6"
          ></textarea>
        </section>
        
        <!-- Staff Feedback -->
        <section v-if="existingResponses?.staff_feedback" class="feedback-section">
          <h3>💬 Feedback from Your Tutor</h3>
          <div class="feedback-content">
            <p>{{ existingResponses.staff_feedback }}</p>
            <div class="feedback-meta">
              <span>From: {{ existingResponses.staff_feedback_by }}</span>
              <span v-if="existingResponses.staff_feedback_at">
                {{ formatDate(existingResponses.staff_feedback_at) }}
              </span>
            </div>
          </div>
        </section>
      </div>
      
      <!-- Footer -->
      <div class="modal-footer">
        <div class="footer-info">
          <span v-if="autoSaveStatus" class="auto-save-status">{{ autoSaveStatus }}</span>
          <span v-if="timeSpent > 0" class="time-spent">
            ⏱️ {{ Math.floor(timeSpent / 60) }}m {{ timeSpent % 60 }}s
          </span>
        </div>
        <div class="footer-actions">
          <button @click="handleClose" class="btn btn-outline">Close</button>
          <button @click="handleSave" class="btn btn-secondary">Save Progress</button>
          <button @click="handleComplete" class="btn btn-primary" :disabled="!canComplete">
            Complete Activity
          </button>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, computed, onMounted, onUnmounted, watch } from 'vue';
import QuestionRenderer from './QuestionRenderer.vue';
import { CATEGORY_COLORS, AUTO_SAVE_INTERVAL } from '../../shared/constants';

const props = defineProps({
  activity: {
    type: Object,
    required: true
  },
  questions: {
    type: Array,
    default: () => []
  },
  existingResponses: {
    type: Object,
    default: null
  }
});

const emit = defineEmits(['close', 'save', 'complete']);

const responses = ref({});
const reflection = ref('');
const autoSaveStatus = ref('');
const timeSpent = ref(0);
const startTime = ref(Date.now());
let autoSaveInterval = null;
let timeInterval = null;

const categoryColor = computed(() => {
  return CATEGORY_COLORS[props.activity.vespa_category] || '#079baa';
});

const reflectionWordCount = computed(() => {
  if (!reflection.value) return 0;
  return reflection.value.trim().split(/\s+/).filter(w => w.length > 0).length;
});

const canComplete = computed(() => {
  // Check if all required questions are answered
  const requiredQuestions = props.questions.filter(q => q.answer_required);
  return requiredQuestions.every(q => {
    const value = responses.value[q.id] || getExistingResponse(q.id);
    return value !== null && value !== undefined && value !== '';
  });
});

const getExistingResponse = (questionId) => {
  if (!props.existingResponses?.responses) return null;
  return props.existingResponses.responses[questionId] || null;
};

const updateResponse = (questionId, value) => {
  responses.value[questionId] = value;
  // Trigger auto-save
  scheduleAutoSave();
};

const scheduleAutoSave = () => {
  if (autoSaveInterval) return;
  
  autoSaveInterval = setTimeout(async () => {
    await handleSave(true);
    autoSaveInterval = null;
  }, AUTO_SAVE_INTERVAL);
};

const handleSave = async (isAutoSave = false) => {
  try {
    autoSaveStatus.value = isAutoSave ? 'Saving...' : '';
    
    const saveData = {
      responses: responses.value,
      reflection: reflection.value,
      timeMinutes: Math.floor(timeSpent.value / 60),
      wordCount: reflectionWordCount.value
    };
    
    emit('save', saveData);
    
    if (isAutoSave) {
      autoSaveStatus.value = 'Saved';
      setTimeout(() => {
        autoSaveStatus.value = '';
      }, 2000);
    }
  } catch (err) {
    console.error('[ActivityModal] Save error:', err);
    autoSaveStatus.value = 'Save failed';
  }
};

const handleComplete = async () => {
  if (!canComplete.value) {
    alert('Please answer all required questions before completing.');
    return;
  }
  
  const completeData = {
    responses: responses.value,
    reflection: reflection.value,
    timeMinutes: Math.floor(timeSpent.value / 60),
    wordCount: reflectionWordCount.value
  };
  
  emit('complete', completeData);
};

const handleClose = () => {
  // Save before closing if there's progress
  if (Object.keys(responses.value).length > 0 || reflection.value) {
    if (confirm('You have unsaved changes. Save before closing?')) {
      handleSave();
    }
  }
  emit('close');
};

const formatDate = (dateString) => {
  if (!dateString) return '';
  const date = new Date(dateString);
  return date.toLocaleDateString() + ' ' + date.toLocaleTimeString();
};

// Load existing responses
onMounted(() => {
  if (props.existingResponses?.responses) {
    responses.value = { ...props.existingResponses.responses };
  }
  if (props.existingResponses?.responses_text) {
    reflection.value = props.existingResponses.responses_text;
  }
  
  // Start time tracking
  if (props.existingResponses?.time_spent_minutes) {
    timeSpent.value = props.existingResponses.time_spent_minutes * 60;
  }
  
  timeInterval = setInterval(() => {
    timeSpent.value = Math.floor((Date.now() - startTime.value) / 1000);
  }, 1000);
});

onUnmounted(() => {
  if (autoSaveInterval) {
    clearTimeout(autoSaveInterval);
  }
  if (timeInterval) {
    clearInterval(timeInterval);
  }
});
</script>

<style scoped>
.activity-modal-overlay {
  position: fixed;
  top: 0;
  left: 0;
  right: 0;
  bottom: 0;
  background: rgba(0, 0, 0, 0.7);
  display: flex;
  align-items: center;
  justify-content: center;
  z-index: 10000;
  padding: var(--spacing-lg);
  overflow-y: auto;
}

.activity-modal {
  background: white;
  border-radius: var(--radius-xl);
  max-width: 900px;
  width: 100%;
  max-height: 90vh;
  display: flex;
  flex-direction: column;
  box-shadow: var(--shadow-lg);
}

.modal-header {
  display: flex;
  justify-content: space-between;
  align-items: flex-start;
  padding: var(--spacing-lg);
  border-bottom: 2px solid var(--gray);
}

.header-content h2 {
  margin-bottom: var(--spacing-sm);
}

.activity-meta {
  display: flex;
  gap: var(--spacing-md);
  align-items: center;
  font-size: 0.875rem;
  color: var(--dark-gray);
}

.category-badge {
  padding: 4px 12px;
  border-radius: 12px;
  color: white;
  font-size: 12px;
  font-weight: 600;
  text-transform: uppercase;
}

.close-btn {
  background: none;
  border: none;
  font-size: 24px;
  cursor: pointer;
  color: var(--dark-gray);
  padding: var(--spacing-xs);
  width: 32px;
  height: 32px;
  display: flex;
  align-items: center;
  justify-content: center;
  border-radius: 4px;
  transition: background 0.2s;
}

.close-btn:hover {
  background: var(--gray);
}

.modal-content {
  flex: 1;
  overflow-y: auto;
  padding: var(--spacing-lg);
}

.content-section {
  margin-bottom: var(--spacing-xl);
}

.content-section h3 {
  color: var(--primary);
  margin-bottom: var(--spacing-md);
  font-size: 1.5rem;
}

.section-content {
  line-height: 1.8;
  color: var(--text);
}

.section-content :deep(img) {
  max-width: 100%;
  height: auto;
  border-radius: var(--radius-md);
}

.section-content :deep(video),
.section-content :deep(iframe) {
  max-width: 100%;
  border-radius: var(--radius-md);
}

.questions-section {
  margin-bottom: var(--spacing-xl);
  padding: var(--spacing-lg);
  background: var(--light-gray);
  border-radius: var(--radius-lg);
}

.reflection-section {
  margin-bottom: var(--spacing-xl);
}

.reflection-label {
  display: flex;
  justify-content: space-between;
  align-items: center;
  font-weight: 600;
  margin-bottom: var(--spacing-sm);
  color: var(--dark-blue);
}

.word-count {
  font-size: 0.875rem;
  font-weight: normal;
  color: var(--dark-gray);
}

.reflection-textarea {
  width: 100%;
  padding: var(--spacing-md);
  border: 2px solid var(--gray);
  border-radius: var(--radius-md);
  font-family: inherit;
  font-size: 1rem;
  resize: vertical;
}

.feedback-section {
  margin-bottom: var(--spacing-xl);
  padding: var(--spacing-lg);
  background: #fff3cd;
  border-radius: var(--radius-lg);
  border-left: 4px solid #ffc107;
}

.feedback-content p {
  margin-bottom: var(--spacing-sm);
  line-height: 1.8;
}

.feedback-meta {
  display: flex;
  gap: var(--spacing-md);
  font-size: 0.875rem;
  color: var(--dark-gray);
}

.modal-footer {
  display: flex;
  justify-content: space-between;
  align-items: center;
  padding: var(--spacing-lg);
  border-top: 2px solid var(--gray);
  background: var(--light-gray);
}

.footer-info {
  display: flex;
  gap: var(--spacing-md);
  font-size: 0.875rem;
  color: var(--dark-gray);
}

.footer-actions {
  display: flex;
  gap: var(--spacing-sm);
}

@media (max-width: 768px) {
  .activity-modal-overlay {
    padding: 0;
  }
  
  .activity-modal {
    max-height: 100vh;
    border-radius: 0;
  }
  
  .modal-header {
    flex-direction: column;
  }
  
  .footer-actions {
    flex-direction: column;
  }
  
  .footer-actions .btn {
    width: 100%;
  }
}
</style>

