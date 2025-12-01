<template>
  <div class="modal-overlay" @click.self="$emit('close')">
    <div class="modal modal-large">
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
            @click="activeTab = 'responses'"
          >
            <i class="fas fa-comments"></i> Student Responses
          </button>
          <button
            :class="['tab-btn', { active: activeTab === 'content' }]"
            @click="activeTab = 'content'"
          >
            <i class="fas fa-book"></i> Activity Content
          </button>
          <button
            :class="['tab-btn', { active: activeTab === 'feedback' }]"
            @click="activeTab = 'feedback'"
          >
            <i class="fas fa-comment-alt"></i>
            Feedback
            <span v-if="hasUnreadFeedback" class="notification-dot"></span>
          </button>
        </div>

        <!-- Tab: Student Responses -->
        <div v-show="activeTab === 'responses'" class="tab-content">
          <div v-if="isCompleted && parsedResponses.length > 0" class="responses-section">
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
                <strong>Q{{ index + 1 }}:</strong> {{ resp.question }}
              </div>
              <div class="response-answer">
                <strong style="color: #495057; font-size: 13px; display: block; margin-bottom: 8px;">Answer:</strong>
                {{ resp.answer }}
              </div>
            </div>
          </div>
          <div v-else class="empty-responses">
            <i class="fas fa-inbox empty-icon"></i>
            <p>{{ isCompleted ? 'No responses recorded' : 'Student has not completed this activity yet' }}</p>
          </div>
        </div>

        <!-- Tab: Activity Content -->
        <div v-show="activeTab === 'content'" class="tab-content">
          <div class="activity-content-preview">
            <div v-if="activity.activities?.do_section_html" class="content-section">
              <h4><i class="fas fa-tasks"></i> DO</h4>
              <div class="html-content" v-html="activity.activities.do_section_html"></div>
            </div>
            
            <div v-if="activity.activities?.think_section_html" class="content-section">
              <h4><i class="fas fa-lightbulb"></i> THINK</h4>
              <div class="html-content" v-html="activity.activities.think_section_html"></div>
            </div>
            
            <div v-if="activity.activities?.learn_section_html" class="content-section">
              <h4><i class="fas fa-graduation-cap"></i> LEARN</h4>
              <div class="html-content" v-html="activity.activities.learn_section_html"></div>
            </div>
            
            <div v-if="activity.activities?.reflect_section_html" class="content-section">
              <h4><i class="fas fa-mirror"></i> REFLECT</h4>
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
  </div>
</template>

<script setup>
import { ref, computed, onMounted } from 'vue';
import { useActivities } from '../composables/useActivities';
import { useFeedback } from '../composables/useFeedback';
import { useAuth } from '../composables/useAuth';

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
const { loadActivityQuestions, markActivityComplete: markCompleteAPI, markActivityIncomplete: markIncompleteAPI } = useActivities();
const { saveFeedback: saveFeedbackAPI } = useFeedback();
const { getStaffEmail } = useAuth();

// State
const activeTab = ref('responses');
const feedbackText = ref(props.activity.staff_feedback || '');
const questions = ref([]);
const isLoadingQuestions = ref(false);
const isSaving = ref(false);

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

    // Match responses with questions
    return Object.entries(responsesData).map(([questionId, answer]) => {
      const question = questions.value.find(q => q.id === questionId);
      return {
        question: question?.question_text || 'Question not found',
        answer: typeof answer === 'object' ? answer.value || JSON.stringify(answer) : answer
      };
    });
  } catch (e) {
    console.error('Error parsing responses:', e);
    return [];
  }
});

// Methods
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
});

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
      getStaffEmail()
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

/* Response Display - Enhanced from V2 */
.responses-section {
  display: flex;
  flex-direction: column;
  gap: 20px;
  background: #e8f4fd;
  padding: 20px;
  border-radius: 8px;
  border-left: 4px solid #17a2b8;
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
  margin-bottom: 16px;
  padding-bottom: 16px;
  border-bottom: 1px solid #b8daff;
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

/* Activity Content Preview - Enhanced */
.activity-content-preview {
  display: flex;
  flex-direction: column;
  gap: 24px;
}

.content-section {
  background: #f8f9fa;
  padding: 20px;
  border-radius: 8px;
  border-left: 4px solid #079baa;
  transition: all 0.2s;
}

.content-section:hover {
  box-shadow: 0 2px 8px rgba(0,0,0,0.05);
}

.content-section h4 {
  margin: 0 0 16px 0;
  font-size: 18px;
  font-weight: 600;
  color: #23356f;
  display: flex;
  align-items: center;
  gap: 10px;
  padding-bottom: 12px;
  border-bottom: 2px solid #dee2e6;
}

.content-section h4 i {
  color: #079baa;
  font-size: 20px;
}

.html-content {
  line-height: 1.8;
  color: #495057;
  font-size: 15px;
}

/* Rich Text Content Styling */
.html-content :deep(h1),
.html-content :deep(h2),
.html-content :deep(h3) {
  color: #23356f;
  margin-top: 24px;
  margin-bottom: 12px;
  font-weight: 600;
}

.html-content :deep(h1) {
  font-size: 24px;
}

.html-content :deep(h2) {
  font-size: 20px;
}

.html-content :deep(h3) {
  font-size: 18px;
}

.html-content :deep(p) {
  margin-bottom: 16px;
  line-height: 1.7;
}

.html-content :deep(ul),
.html-content :deep(ol) {
  margin: 16px 0 16px 24px;
}

.html-content :deep(li) {
  margin-bottom: 8px;
}

.html-content :deep(img) {
  max-width: 100%;
  max-height: 400px;
  height: auto;
  border-radius: 8px;
  margin: 20px auto;
  display: block;
  box-shadow: 0 2px 8px rgba(0,0,0,0.1);
}

.html-content :deep(blockquote) {
  border-left: 4px solid #079baa;
  padding-left: 20px;
  margin: 20px 0;
  font-style: italic;
  color: #6c757d;
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
</style>

