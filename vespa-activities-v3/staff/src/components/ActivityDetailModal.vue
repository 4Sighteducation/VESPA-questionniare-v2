<template>
  <div class="modal-overlay" @click.self="$emit('close')">
    <div class="modal modal-large" @click.stop>
      <div class="modal-header">
        <div class="header-content">
          <h2 class="modal-title">{{ activity.activities?.name }}</h2>
          <div class="activity-meta-header">
            <span class="student-badge">
              <i class="fas fa-user"></i> {{ student.full_name }}
            </span>
            <span :class="['category-badge', categoryClass]">
              {{ activity.activities?.vespa_category }}
            </span>
            <span class="level-badge">
              {{ activity.activities?.level }}
            </span>
            <span v-if="isCompleted" class="status-badge completed">
              <i class="fas fa-check-circle"></i> Completed
            </span>
            <span v-else class="status-badge incomplete">
              <i class="fas fa-clock"></i> {{ activity.status || 'Assigned' }}
            </span>
          </div>
        </div>
        <button class="modal-close" @click="$emit('close')">
          <i class="fas fa-times"></i>
        </button>
      </div>

      <div class="modal-body">
        <!-- Activity Content Tabs -->
        <div class="content-tabs">
          <button
            :class="['tab-btn', { active: activeTab === 'responses' }]"
            @click="handleTabChange('responses')"
          >
            <i class="fas fa-comments"></i> Student Responses
          </button>
          <button
            :class="['tab-btn', { active: activeTab === 'content' }]"
            @click="handleTabChange('content')"
          >
            <i class="fas fa-book"></i> Activity Content
          </button>
          <button
            :class="['tab-btn', { active: activeTab === 'feedback' }]"
            @click="handleTabChange('feedback')"
          >
            <i class="fas fa-comment-alt"></i>
            Feedback
            <span v-if="hasUnreadFeedback" class="notification-dot"></span>
          </button>
        </div>

        <!-- Tab: Student Responses with Inline Feedback -->
        <div v-show="activeTab === 'responses'" class="tab-content">
          <div v-if="isCompleted && parsedResponses.length > 0" class="responses-with-feedback-layout">
            <!-- Left: Student Responses -->
            <div class="responses-section">
              <div class="response-context">
                <h4><i class="fas fa-comments"></i> Student Responses</h4>
                <p>Review the student's answers below</p>
              </div>
              <div
                v-for="(resp, index) in parsedResponses"
                :key="index"
                class="response-item"
              >
                <div class="response-question">
                  <strong>Q{{ resp.questionNumber }}:</strong> {{ resp.question }}
                  <span v-if="!resp.found" class="question-note" title="Question text not available in database">
                    (migrated from old system)
                  </span>
                </div>
                <div class="response-answer">
                  <strong style="color: #495057; font-size: 13px; display: block; margin-bottom: 8px;">Answer:</strong>
                  {{ resp.answer }}
                </div>
              </div>
            </div>
            
            <!-- Right: Quick Feedback Panel -->
            <div class="inline-feedback-panel">
              <div class="feedback-panel-header">
                <i class="fas fa-comment-dots"></i>
                <h5>Give Feedback</h5>
              </div>
              
              <div v-if="activity.staff_feedback && activity.staff_feedback_by === getStaffEmail()" class="your-previous-feedback">
                <div class="previous-badge">Your previous feedback:</div>
                <div class="previous-text">{{ activity.staff_feedback }}</div>
                <div class="previous-meta">{{ formatDate(activity.staff_feedback_at) }}</div>
              </div>
              
              <textarea
                v-model="feedbackText"
                placeholder="Enter feedback for the student..."
                rows="8"
                class="feedback-textarea-inline"
              ></textarea>
              
              <button
                class="btn btn-primary btn-block"
                @click="saveFeedback"
                :disabled="!feedbackText.trim() || isSaving"
              >
                <i class="fas fa-paper-plane"></i>
                {{ isSaving ? 'Saving...' : 'Send Feedback to Student' }}
              </button>
              
              <div class="feedback-hint-inline">
                <i class="fas fa-bell"></i>
                Student will be notified
              </div>
            </div>
          </div>
          <div v-else class="empty-responses">
            <i class="fas fa-inbox empty-icon"></i>
            <p>{{ isCompleted ? 'No responses recorded' : 'Student has not completed this activity yet' }}</p>
          </div>
        </div>

        <!-- Tab: Activity Content - Clean Minimal Design -->
        <div v-show="activeTab === 'content'" class="tab-content">
          <div class="activity-content-clean">
            <!-- DO Section -->
            <div v-if="activity.activities?.do_section_html" class="content-block">
              <div class="html-content" v-html="activity.activities.do_section_html"></div>
            </div>
            
            <!-- THINK Section -->
            <div v-if="activity.activities?.think_section_html" class="content-block">
              <div class="html-content" v-html="activity.activities.think_section_html"></div>
            </div>
            
            <!-- LEARN Section -->
            <div v-if="activity.activities?.learn_section_html" class="content-block">
              <div class="html-content" v-html="activity.activities.learn_section_html"></div>
            </div>
            
            <!-- REFLECT Section -->
            <div v-if="activity.activities?.reflect_section_html" class="content-block">
              <div class="html-content" v-html="activity.activities.reflect_section_html"></div>
            </div>

            <div v-if="!hasAnyContent" class="empty-content">
              <i class="fas fa-file-alt empty-icon"></i>
              <p>No detailed content available for this activity</p>
            </div>
          </div>
        </div>

        <!-- Tab: Feedback -->
        <div v-show="activeTab === 'feedback'" class="tab-content">
          <div class="feedback-section">
            <div v-if="activity.staff_feedback" class="existing-feedback">
              <div class="feedback-meta">
                <span><i class="fas fa-user"></i> {{ activity.staff_feedback_by || 'Staff' }}</span>
                <span><i class="fas fa-calendar"></i> {{ formatDate(activity.staff_feedback_at) }}</span>
                <span v-if="activity.feedback_read_by_student" class="read-status read">
                  <i class="fas fa-check-double"></i> Read by student
                </span>
                <span v-else class="read-status unread">
                  <i class="fas fa-envelope"></i> Unread
                </span>
              </div>
              <div class="feedback-display">
                {{ activity.staff_feedback }}
              </div>
            </div>

            <div class="feedback-editor">
              <label for="feedback-input">
                <i class="fas fa-comment-alt"></i>
                {{ activity.staff_feedback ? 'Update Feedback' : 'Provide Feedback' }}
              </label>
              <textarea
                id="feedback-input"
                v-model="feedbackText"
                placeholder="Enter your feedback for the student..."
                rows="6"
                class="feedback-textarea"
              ></textarea>
              <div class="feedback-hint">
                <i class="fas fa-info-circle"></i>
                Student will be notified of new feedback
              </div>
            </div>
          </div>
        </div>
      </div>

      <div class="modal-footer">
        <div class="footer-actions-left">
          <button
            v-if="isCompleted"
            class="btn btn-warning"
            @click="markIncomplete"
            :disabled="isSaving"
          >
            <i class="fas fa-undo"></i> Mark Incomplete
          </button>
          <button
            v-else
            class="btn btn-success"
            @click="markComplete"
            :disabled="isSaving"
          >
            <i class="fas fa-check"></i> Mark Complete
          </button>
          
          <button
            class="btn btn-danger"
            @click="clearAndRemove"
            :disabled="isSaving"
            title="Clear all answers and remove from student - cannot be undone!"
          >
            <i class="fas fa-eraser"></i> Clear All Answers
          </button>
        </div>

        <div class="footer-actions-right">
          <button class="btn btn-secondary" @click="$emit('close')">
            Cancel
          </button>
          <button
            class="btn btn-primary"
            @click="saveFeedback"
            :disabled="!feedbackText.trim() || isSaving"
          >
            <i class="fas fa-save"></i>
            {{ isSaving ? 'Saving...' : 'Save Feedback' }}
          </button>
        </div>
      </div>
    </div>

    <!-- PDF Modal -->
    <PdfModal
      v-if="pdfModalOpen"
      :pdf-url="pdfUrl"
      :title="pdfTitle"
      @close="pdfModalOpen = false"
    />

    <!-- Confirm Modal -->
    <ConfirmModal
      v-if="confirmModalOpen"
      :title="confirmModalConfig.title"
      :message="confirmModalConfig.message"
      :confirm-text="confirmModalConfig.confirmText"
      :cancel-text="confirmModalConfig.cancelText"
      :is-danger="confirmModalConfig.isDanger"
      :icon="confirmModalConfig.icon"
      @confirm="confirmModalConfig.onConfirm"
      @cancel="confirmModalOpen = false"
    />
  </div>
</template>

<script setup>
import { ref, computed, onMounted, nextTick } from 'vue';
import { useActivities } from '../composables/useActivities';
import { useFeedback } from '../composables/useFeedback';
import { useAuth } from '../composables/useAuth';
import PdfModal from './PdfModal.vue';
import ConfirmModal from './ConfirmModal.vue';

const props = defineProps({
  activity: {
    type: Object,
    required: true
  },
  student: {
    type: Object,
    required: true
  },
  staffContext: {
    type: Object,
    required: true
  }
});

const emit = defineEmits(['close', 'feedback-saved', 'status-changed']);

// Composables
const { loadActivityQuestions, markActivityComplete: markCompleteAPI, markActivityIncomplete: markIncompleteAPI, deleteActivityPermanently: deleteAPI } = useActivities();
const { saveFeedback: saveFeedbackAPI } = useFeedback();
const { getStaffEmail } = useAuth();

// State
const activeTab = ref('responses');
const feedbackText = ref(props.activity.staff_feedback || '');
const questions = ref([]);
const isLoadingQuestions = ref(false);
const isSaving = ref(false);
const pdfModalOpen = ref(false);
const pdfUrl = ref('');
const pdfTitle = ref('');
const confirmModalOpen = ref(false);
const confirmModalConfig = ref({
  title: '',
  message: '',
  confirmText: 'Confirm',
  cancelText: 'Cancel',
  isDanger: false,
  onConfirm: () => {}
});

// Computed
const isCompleted = computed(() => !!props.activity.completed_at);

const hasUnreadFeedback = computed(() => {
  return props.activity.staff_feedback && !props.activity.feedback_read_by_student;
});

const categoryClass = computed(() => {
  return props.activity.activities?.vespa_category?.toLowerCase() || '';
});

const hasAnyContent = computed(() => {
  return props.activity.activities?.do_section_html ||
         props.activity.activities?.think_section_html ||
         props.activity.activities?.learn_section_html ||
         props.activity.activities?.reflect_section_html;
});

const parsedResponses = computed(() => {
  if (!props.activity.responses) return [];

  try {
    const responsesData = typeof props.activity.responses === 'string' 
      ? JSON.parse(props.activity.responses) 
      : props.activity.responses;

    console.log('📝 Parsing responses:', responsesData);
    console.log('📝 Available questions:', questions.value);

    // Parse responses - handle nested cycle structure from old Knack data
    const entries = Object.entries(responsesData);
    
    // Sort questions by display_order for matching
    const sortedQuestions = [...questions.value].sort((a, b) => a.display_order - b.display_order);
    
    return entries.map(([questionId, answerData], index) => {
      // Try to find question by ID first
      let question = questions.value.find(q => q.id === questionId);
      
      // If not found and we have questions, match by index/order
      if (!question && sortedQuestions.length > index) {
        question = sortedQuestions[index];
        console.log(`📝 Matched by order: old ID ${questionId} => question at display_order ${question.display_order}`);
      }
      
      // Extract answer from nested structure (cycle_1, cycle_2, etc.)
      let answerText = '';
      if (typeof answerData === 'object' && answerData !== null) {
        // Handle {cycle_1: {value: "text"}} structure
        const cycleKeys = Object.keys(answerData).filter(k => k.startsWith('cycle_'));
        if (cycleKeys.length > 0) {
          const cycleData = answerData[cycleKeys[0]];
          answerText = cycleData?.value || JSON.stringify(cycleData);
        } else if (answerData.value) {
          answerText = answerData.value;
        } else {
          answerText = JSON.stringify(answerData);
        }
      } else {
        answerText = String(answerData);
      }
      
      // Generate question label - use question_title from database
      const questionLabel = question?.question_title || `Question ${index + 1}`;
      
      console.log(`📝 Q${index + 1} [${questionId}] => "${questionLabel}" (${question ? 'MATCHED' : 'FALLBACK'})`);
      
      return {
        question: questionLabel,
        answer: answerText,
        questionNumber: index + 1,
        found: !!question
      };
    }).filter(r => r.answer && r.answer.trim() !== ''); // Filter out empty answers
  } catch (e) {
    console.error('Error parsing responses:', e);
    return [];
  }
});

// Methods
const openPdfModal = (url, title = '') => {
  pdfUrl.value = url;
  pdfTitle.value = title;
  pdfModalOpen.value = true;
};

const interceptPdfLinks = () => {
  // Wait for content to render, then intercept PDF links
  nextTick(() => {
    const pdfLinks = document.querySelectorAll('.html-content a[href*=".pdf"]');
    pdfLinks.forEach(link => {
      link.addEventListener('click', (e) => {
        e.preventDefault();
        const url = link.getAttribute('href');
        const title = link.textContent || 'PDF Document';
        openPdfModal(url, title);
      });
    });
  });
};

onMounted(async () => {
  // Load questions for response matching
  if (props.activity.activity_id) {
    isLoadingQuestions.value = true;
    try {
      questions.value = await loadActivityQuestions(props.activity.activity_id);
    } catch (error) {
      console.error('Failed to load questions:', error);
    } finally {
      isLoadingQuestions.value = false;
    }
  }
  
  // Intercept PDF links after content loads
  interceptPdfLinks();
});

// Re-intercept when switching to content tab
const handleTabChange = (tab) => {
  activeTab.value = tab;
  if (tab === 'content') {
    interceptPdfLinks();
  }
};

const saveFeedback = async () => {
  if (!feedbackText.value.trim()) {
    alert('Please enter feedback before saving');
    return;
  }

  isSaving.value = true;

  try {
    await saveFeedbackAPI(
      props.activity.id,
      feedbackText.value,
      getStaffEmail(),
      props.staffContext.schoolId  // Add schoolId for RPC
    );

    alert('Feedback saved successfully! Student will be notified.');
    emit('feedback-saved');

  } catch (error) {
    console.error('Failed to save feedback:', error);
    alert('Failed to save feedback. Please try again.');
  } finally {
    isSaving.value = false;
  }
};

const markComplete = async () => {
  if (!confirm('Mark this activity as complete for the student?')) return;

  isSaving.value = true;

  try {
    await markCompleteAPI(
      props.activity.id,
      props.activity.student_email,
      props.activity.activity_id,
      getStaffEmail()
    );

    alert('Activity marked as complete');
    emit('status-changed');

  } catch (error) {
    console.error('Failed to mark complete:', error);
    alert('Failed to update status. Please try again.');
  } finally {
    isSaving.value = false;
  }
};

const markIncomplete = async () => {
  if (!confirm('Mark this activity as incomplete? Student will need to complete it again.')) return;

  isSaving.value = true;

  try {
    await markIncompleteAPI(
      props.activity.id,
      props.activity.student_email,
      props.activity.activity_id,
      getStaffEmail()
    );

    alert('Activity marked as incomplete');
    emit('status-changed');

  } catch (error) {
    console.error('Failed to mark incomplete:', error);
    alert('Failed to update status. Please try again.');
  } finally {
    isSaving.value = false;
  }
};

const showConfirmModal = (config) => {
  confirmModalConfig.value = config;
  confirmModalOpen.value = true;
};

const clearAndRemove = async () => {
  const activityName = props.activity.activities?.name || 'this activity';
  const studentName = props.student.full_name;
  
  // Show beautiful modal instead of browser confirm
  showConfirmModal({
    title: '⚠️ Clear All Answers?',
    message: `Clear all answers for "${activityName}"?\n\nThis will:\n• Remove the activity from ${studentName}\n• Clear ALL student responses\n• Delete any staff feedback\n\nThis CANNOT be undone!\n\n(The activity can be reassigned later, but will start blank)`,
    confirmText: 'Yes, Clear Answers',
    cancelText: 'Cancel',
    isDanger: true,
    icon: 'fas fa-eraser',
    onConfirm: async () => {
      confirmModalOpen.value = false;
      isSaving.value = true;

      try {
        await deleteAPI(
          props.activity.student_email,
          props.activity.activity_id,
          props.activity.cycle_number,
          getStaffEmail(),
          props.staffContext.schoolId
        );

        // Success modal
        showConfirmModal({
          title: 'Success',
          message: `All answers cleared and "${activityName}" removed from ${studentName}`,
          confirmText: 'OK',
          isDanger: false,
          icon: 'fas fa-check-circle',
          onConfirm: () => {
            confirmModalOpen.value = false;
            emit('status-changed');
          }
        });

      } catch (error) {
        console.error('Failed to clear and remove:', error);
        showConfirmModal({
          title: 'Error',
          message: 'Failed to clear answers. Please try again.',
          confirmText: 'OK',
          isDanger: true,
          icon: 'fas fa-times-circle',
          onConfirm: () => {
            confirmModalOpen.value = false;
          }
        });
      } finally {
        isSaving.value = false;
      }
    }
  });
};

const formatDate = (dateString) => {
  if (!dateString) return '';
  const date = new Date(dateString);
  return date.toLocaleDateString('en-GB', {
    day: 'numeric',
    month: 'short',
    year: 'numeric',
    hour: '2-digit',
    minute: '2-digit'
  });
};
</script>

<style scoped>
/* Enhanced Modal Styling - Matching V2 Professional Design */
.modal-large {
  max-width: 900px;
  width: 90%;
  max-height: 90vh;
  border-radius: 12px;
  overflow: hidden;
  box-shadow: 0 20px 60px rgba(0, 0, 0, 0.3);
  background: white;
}

/* Modal Header - Match V2 Design */
.modal-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  padding: 24px;
  border-bottom: 1px solid #dee2e6;
  background: #f8f9fa;
  border-radius: 12px 12px 0 0;
}

.header-content {
  flex: 1;
}

.modal-title {
  font-size: 24px;
  font-weight: 600;
  color: #343a40;
  margin: 0 0 12px 0;
  line-height: 1.2;
}

.activity-meta-header {
  display: flex;
  gap: 12px;
  flex-wrap: wrap;
  align-items: center;
}

.student-badge {
  padding: 4px 10px;
  background: #e3f2fd;
  border-radius: 12px;
  font-size: 12px;
  color: #0d47a1;
  display: inline-flex;
  align-items: center;
  gap: 4px;
}

.category-badge {
  padding: 4px 10px;
  border-radius: 12px;
  font-size: 12px;
  color: white;
  font-weight: 600;
}

.category-badge.vision { background: #ff8f00; }
.category-badge.effort { background: #86b4f0; }
.category-badge.systems { background: #84cc16; }
.category-badge.practice { background: #7f31a4; }
.category-badge.attitude { background: #f032e6; }

.level-badge {
  padding: 4px 10px;
  background: #e9ecef;
  border-radius: 12px;
  font-size: 12px;
  color: #495057;
  font-weight: 500;
}

.status-badge {
  padding: 4px 10px;
  border-radius: 12px;
  font-size: 12px;
  font-weight: 600;
  display: inline-flex;
  align-items: center;
  gap: 4px;
}

.status-badge.completed {
  background: #d1fae5;
  color: #065f46;
}

.status-badge.incomplete {
  background: #fef3c7;
  color: #92400e;
}

/* Tab System - Enhanced from V2 */
.content-tabs {
  display: flex;
  gap: 4px;
  border-bottom: 2px solid #dee2e6;
  margin-bottom: 24px;
  background: #f8f9fa;
  padding: 4px;
  border-radius: 8px 8px 0 0;
}

.tab-btn {
  padding: 12px 20px;
  background: transparent;
  border: none;
  border-radius: 6px 6px 0 0;
  color: #6c757d;
  font-size: 14px;
  font-weight: 600;
  cursor: pointer;
  transition: all 0.2s;
  display: flex;
  align-items: center;
  gap: 8px;
  position: relative;
}

.tab-btn:hover {
  color: #079baa;
  background: rgba(7, 155, 170, 0.05);
}

.tab-btn.active {
  color: #079baa;
  background: white;
  box-shadow: 0 -2px 4px rgba(0,0,0,0.05);
  border-bottom: 2px solid #079baa;
}

.notification-dot {
  width: 8px;
  height: 8px;
  background: #dc3545;
  border-radius: 50%;
  animation: pulse 2s infinite;
}

.tab-content {
  animation: fadeIn 0.3s;
}

@keyframes fadeIn {
  from { opacity: 0; }
  to { opacity: 1; }
}

/* Two-column layout for responses + feedback */
.responses-with-feedback-layout {
  display: grid;
  grid-template-columns: 2fr 1fr;  /* 2/3 responses, 1/3 feedback */
  gap: 20px;
  min-height: 400px;
}

@media (max-width: 1200px) {
  .responses-with-feedback-layout {
    grid-template-columns: 1fr;  /* Stack on smaller screens */
  }
}

/* Response Display - Enhanced from V2 */
.responses-section {
  display: flex;
  flex-direction: column;
  gap: 16px;
  background: #e8f4fd;
  padding: 20px;
  border-radius: 8px;
  border-left: 4px solid #17a2b8;
  overflow-y: auto;
  max-height: 600px;
}

.response-context {
  background: #f8f9fa;
  padding: 12px 16px;
  margin-bottom: 8px;
  border-left: 3px solid #079baa;
  border-radius: 6px;
  font-size: 0.9em;
  color: #666;
  line-height: 1.4;
}

.response-context h4 {
  margin: 0 0 4px 0;
  color: #079baa;
  font-size: 16px;
  font-weight: 600;
  display: flex;
  align-items: center;
  gap: 8px;
}

.response-context p {
  margin: 0;
  color: #6c757d;
  font-size: 13px;
}

.response-item {
  background: white;
  border-radius: 6px;
  padding: 16px;
  border: 1px solid #b8daff;
  box-shadow: 0 2px 4px rgba(0,0,0,0.05);
  transition: all 0.2s;
}

.response-item:not(:last-child) {
  margin-bottom: 14px;
  padding-bottom: 14px;
  border-bottom: 1px solid #b8daff;
}

/* Inline Feedback Panel */
.inline-feedback-panel {
  background: white;
  border: 2px solid #079baa;
  border-radius: 12px;
  padding: 20px;
  display: flex;
  flex-direction: column;
  gap: 16px;
  position: sticky;
  top: 20px;
  max-height: 600px;
  overflow-y: auto;
}

.feedback-panel-header {
  display: flex;
  align-items: center;
  gap: 10px;
  padding-bottom: 12px;
  border-bottom: 2px solid #e9ecef;
  color: #079baa;
}

.feedback-panel-header i {
  font-size: 22px;
}

.feedback-panel-header h5 {
  margin: 0;
  font-size: 16px;
  font-weight: 600;
  color: #23356f;
}

.your-previous-feedback {
  background: #f8f9fa;
  padding: 12px;
  border-radius: 6px;
  border-left: 3px solid #079baa;
}

.previous-badge {
  font-size: 11px;
  color: #6c757d;
  font-weight: 600;
  text-transform: uppercase;
  margin-bottom: 6px;
}

.previous-text {
  color: #495057;
  font-size: 13px;
  line-height: 1.5;
  margin-bottom: 6px;
  white-space: pre-wrap;
}

.previous-meta {
  font-size: 11px;
  color: #6c757d;
}

.feedback-textarea-inline {
  width: 100%;
  padding: 12px;
  border: 2px solid #dee2e6;
  border-radius: 8px;
  font-size: 14px;
  font-family: inherit;
  resize: vertical;
  min-height: 150px;
  transition: border-color 0.2s;
}

.feedback-textarea-inline:focus {
  outline: none;
  border-color: #079baa;
  box-shadow: 0 0 0 3px rgba(7, 155, 170, 0.1);
}

.btn-block {
  width: 100%;
  padding: 12px;
  font-size: 14px;
  font-weight: 600;
}

.feedback-hint-inline {
  display: flex;
  align-items: center;
  gap: 6px;
  font-size: 12px;
  color: #6c757d;
  text-align: center;
  justify-content: center;
}

.response-item:hover {
  box-shadow: 0 4px 8px rgba(0,0,0,0.08);
  transform: translateY(-1px);
}

.response-question {
  font-weight: 600;
  color: #495057;
  margin-bottom: 12px;
  font-size: 15px;
}

.response-question strong {
  color: #079baa;
  margin-right: 4px;
}

.question-note {
  font-size: 11px;
  color: #6c757d;
  font-style: italic;
  font-weight: normal;
  margin-left: 8px;
}

.response-answer {
  color: #212529;
  line-height: 1.7;
  white-space: pre-wrap;
  background: white;
  padding: 12px;
  border-radius: 4px;
  border: 1px solid #e1e5e9;
  font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
}

/* Empty States - Enhanced */
.empty-responses,
.empty-content {
  text-align: center;
  padding: 60px 20px;
  color: #6c757d;
  background: #f8f9fa;
  border-radius: 8px;
  border: 2px dashed #dee2e6;
}

.empty-icon {
  font-size: 56px;
  color: #cbd5e1;
  margin-bottom: 20px;
  display: block;
  filter: grayscale(0.3);
}

/* Activity Content - Clean Minimal Design */
.activity-content-clean {
  display: flex;
  flex-direction: column;
  gap: 16px;  /* Much tighter spacing */
  padding: 4px;
  max-height: 650px;
  overflow-y: auto;
}

.content-block {
  background: white;
  padding: 16px 20px;  /* Reduced from 32px */
  border-radius: 8px;  /* Smaller radius */
  border-left: 3px solid #079baa;  /* Subtle indicator */
  transition: all 0.2s;
}

.content-block:hover {
  box-shadow: 0 2px 8px rgba(0,0,0,0.06);
  border-left-width: 4px;
}

/* HTML Content - Clean Compact Typography */
.html-content {
  line-height: 1.6;
  color: #495057;
  font-size: 14px;
  max-width: 100%;
  margin: 0;
  text-align: left;
}

/* HIDE old Knack section titles from imported HTML */
.html-content :deep(h1:contains("DO")),
.html-content :deep(h2:contains("DO")),
.html-content :deep(h3:contains("DO")),
.html-content :deep(h1:contains("THINK")),
.html-content :deep(h2:contains("THINK")),
.html-content :deep(h3:contains("THINK")),
.html-content :deep(h1:contains("LEARN")),
.html-content :deep(h2:contains("LEARN")),
.html-content :deep(h3:contains("LEARN")),
.html-content :deep(h1:contains("REFLECT")),
.html-content :deep(h2:contains("REFLECT")),
.html-content :deep(h3:contains("REFLECT")) {
  display: none !important;
}

/* Hide any heading that's JUST "DO", "THINK", etc. with no other text */
.html-content :deep(h1),
.html-content :deep(h2),
.html-content :deep(h3),
.html-content :deep(h4) {
  /* Check if text is just section names */
}

/* Hide horizontal rules that separate sections */
.html-content :deep(hr) {
  margin: 8px 0;  /* Minimal */
  border: none;
  border-top: 1px solid #e9ecef;
}

/* Rich Text Content - Compact Styling */
.html-content :deep(h1),
.html-content :deep(h2),
.html-content :deep(h3) {
  color: #23356f;
  margin-top: 12px;  /* Reduced */
  margin-bottom: 8px;  /* Reduced */
  font-weight: 600;
  line-height: 1.3;
}

.html-content :deep(h1) {
  font-size: 20px;  /* Smaller */
}

.html-content :deep(h2) {
  font-size: 18px;  /* Smaller */
}

.html-content :deep(h3) {
  font-size: 16px;  /* Smaller */
}

.html-content :deep(p) {
  margin-bottom: 10px;  /* Reduced */
  line-height: 1.5;  /* Tighter */
}

.html-content :deep(ul),
.html-content :deep(ol) {
  margin: 10px 0 10px 20px;  /* Tighter */
}

.html-content :deep(li) {
  margin-bottom: 4px;  /* Reduced */
}

.html-content :deep(img) {
  max-width: 100%;
  max-height: 300px;  /* Smaller */
  height: auto;
  border-radius: 8px;
  margin: 16px auto;  /* Less margin */
  display: block;
  box-shadow: 0 2px 8px rgba(0,0,0,0.1);
  transition: transform 0.2s;
}

.html-content :deep(img):hover {
  transform: scale(1.01);  /* Subtle */
}

/* Centered Media Links - Professional Style */
.html-content :deep(a) {
  color: #079baa;
  font-weight: 600;
  text-decoration: none;
  transition: all 0.2s;
}

.html-content :deep(a:hover) {
  color: #00e5db;
  text-decoration: underline;
}

/* PDF & Video Links - Compact Button Style */
.html-content :deep(p:has(a[href*=".pdf"])),
.html-content :deep(p:has(a[href*="youtube"])),
.html-content :deep(p:has(a[href*="vimeo"])),
.html-content :deep(p:has(a[href*="docs.google.com"])) {
  text-align: center;
  margin: 12px 0;  /* Much less margin */
}

.html-content :deep(a[href*=".pdf"]),
.html-content :deep(a[href*="youtube"]),
.html-content :deep(a[href*="vimeo"]),
.html-content :deep(a[href*="docs.google.com"]) {
  display: inline-flex;
  align-items: center;
  gap: 6px;
  padding: 8px 16px;  /* Much smaller */
  background: #079baa;
  color: white !important;
  border-radius: 6px;  /* Less rounded */
  font-size: 13px;  /* Smaller text */
  font-weight: 600;
  text-decoration: none !important;
  box-shadow: 0 2px 6px rgba(7, 155, 170, 0.2);
  transition: all 0.2s;
}

.html-content :deep(a[href*=".pdf"])::before {
  content: '📄';
  font-size: 14px;
}

/* Change text via CSS */
.html-content :deep(a[href*=".pdf"]) {
  font-size: 0;  /* Hide original text */
}

.html-content :deep(a[href*=".pdf"])::after {
  content: 'VIEW PDF';
  font-size: 13px;
  font-weight: 600;
}

.html-content :deep(a[href*="youtube"])::before,
.html-content :deep(a[href*="vimeo"])::before {
  content: '▶️';
  font-size: 14px;
}

.html-content :deep(a[href*=".pdf"]):hover,
.html-content :deep(a[href*="youtube"]):hover,
.html-content :deep(a[href*="vimeo"]):hover,
.html-content :deep(a[href*="docs.google.com"]):hover {
  background: #006b77;
  box-shadow: 0 4px 10px rgba(7, 155, 170, 0.3);
  transform: translateY(-1px);
  color: white !important;
}

/* YouTube/Video Embeds - Compact */
.html-content :deep(iframe) {
  max-width: 100%;
  width: 100%;
  height: 350px;  /* Smaller */
  border: none;
  border-radius: 8px;
  margin: 16px auto;  /* Less margin */
  display: block;
  box-shadow: 0 4px 12px rgba(0,0,0,0.1);
}

.html-content :deep(blockquote) {
  border-left: 3px solid #079baa;
  padding: 12px 16px;  /* Tighter */
  margin: 12px 0;  /* Less margin */
  font-style: italic;
  color: #6c757d;
  background: #f8f9fa;
  border-radius: 6px;
  font-size: 14px;  /* Smaller */
}

/* Special Text Formatting */
.html-content :deep(strong) {
  color: #23356f;
  font-weight: 700;
}

.html-content :deep(em) {
  color: #079baa;
  font-style: italic;
}

/* Modal Body - Enhanced Scrolling */
.modal-body {
  padding: 24px;
  overflow-y: auto;
  max-height: calc(90vh - 200px);
}

/* Modal Close Button - Match V2 */
.modal-close {
  background: transparent;
  border: none;
  font-size: 28px;
  color: #6c757d;
  cursor: pointer;
  padding: 8px;
  border-radius: 50%;
  width: 44px;
  height: 44px;
  display: flex;
  align-items: center;
  justify-content: center;
  transition: all 0.2s ease;
  flex-shrink: 0;
}

.modal-close:hover {
  background: #e9ecef;
  color: #495057;
  transform: scale(1.1);
}

/* Feedback Section - Enhanced from V2 */
.feedback-section {
  display: flex;
  flex-direction: column;
  gap: 24px;
  background: #f1f8ff;
  padding: 24px;
  border-radius: 12px;
  border: 2px solid #007bff;
}

.existing-feedback {
  background: white;
  border-radius: 8px;
  padding: 20px;
  border-left: 4px solid #079baa;
  box-shadow: 0 2px 4px rgba(0,0,0,0.05);
}

.feedback-meta {
  display: flex;
  gap: 16px;
  margin-bottom: 12px;
  font-size: 13px;
  color: #6c757d;
  flex-wrap: wrap;
}

.feedback-meta span {
  display: flex;
  align-items: center;
  gap: 4px;
}

.read-status {
  padding: 2px 8px;
  border-radius: 12px;
  font-size: 11px;
  font-weight: 600;
}

.read-status.read {
  background: #d1fae5;
  color: #065f46;
}

.read-status.unread {
  background: #fef3c7;
  color: #92400e;
}

.feedback-display {
  color: #212529;
  line-height: 1.6;
  white-space: pre-wrap;
}

.feedback-editor label {
  display: flex;
  align-items: center;
  gap: 8px;
  font-weight: 600;
  color: #495057;
  margin-bottom: 8px;
}

.feedback-textarea {
  width: 100%;
  padding: 12px;
  border: 2px solid #dee2e6;
  border-radius: 8px;
  font-size: 14px;
  font-family: inherit;
  resize: vertical;
  transition: border-color 0.2s;
}

.feedback-textarea:focus {
  outline: none;
  border-color: #079baa;
  box-shadow: 0 0 0 3px rgba(7, 155, 170, 0.1);
}

.feedback-hint {
  display: flex;
  align-items: center;
  gap: 6px;
  margin-top: 8px;
  font-size: 12px;
  color: #6c757d;
}

.modal-footer {
  padding: 16px 24px;
  border-top: 1px solid #dee2e6;
  display: flex;
  justify-content: space-between;
}

.footer-actions-left,
.footer-actions-right {
  display: flex;
  gap: 12px;
}

.btn-success {
  background: #28a745;
  color: white;
}

.btn-success:hover:not(:disabled) {
  background: #218838;
}

.btn-warning {
  background: #ffc107;
  color: #212529;
}

.btn-warning:hover:not(:disabled) {
  background: #e0a800;
}

.btn-danger {
  background: #dc3545;
  color: white;
  border: 1px solid #dc3545;
}

.btn-danger:hover:not(:disabled) {
  background: #c82333;
  border-color: #bd2130;
}

.btn-danger:disabled {
  opacity: 0.5;
  cursor: not-allowed;
}
</style>

