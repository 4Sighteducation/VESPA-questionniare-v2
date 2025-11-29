<template>
  <div class="modal-overlay" @click.self="$emit('close')">
    <div class="modal">
      <div class="modal-header">
        <h3 class="modal-title">{{ activity.name }}</h3>
        <button class="modal-close" @click="$emit('close')">
          <i class="fas fa-times"></i>
        </button>
      </div>

      <div class="modal-body">
        <!-- Activity Info -->
        <div class="activity-info-grid">
          <div class="info-card">
            <i class="fas fa-tag info-icon"></i>
            <div>
              <div class="info-label">Category</div>
              <div class="info-value">{{ activity.vespa_category }}</div>
            </div>
          </div>

          <div class="info-card">
            <i class="fas fa-layer-group info-icon"></i>
            <div>
              <div class="info-label">Level</div>
              <div class="info-value">{{ activity.level }}</div>
            </div>
          </div>

          <div class="info-card">
            <i class="fas fa-clock info-icon"></i>
            <div>
              <div class="info-label">Time</div>
              <div class="info-value">{{ activity.time_minutes || 20 }}min</div>
            </div>
          </div>

          <div class="info-card">
            <i class="fas fa-signal info-icon"></i>
            <div>
              <div class="info-label">Difficulty</div>
              <div class="info-value">{{ activity.difficulty || 2 }}/3</div>
            </div>
          </div>
        </div>

        <!-- Activity Content Preview -->
        <div class="content-preview">
          <div v-if="activity.do_section_html" class="content-section">
            <h4><i class="fas fa-tasks"></i> DO</h4>
            <div class="html-content" v-html="activity.do_section_html"></div>
          </div>

          <div v-if="activity.learn_section_html" class="content-section">
            <h4><i class="fas fa-graduation-cap"></i> LEARN</h4>
            <div class="html-content" v-html="activity.learn_section_html"></div>
          </div>

          <div v-if="!activity.do_section_html && !activity.learn_section_html" class="empty-content">
            <i class="fas fa-file-alt empty-icon"></i>
            <p>Activity content will be shown to students when they start this activity</p>
          </div>
        </div>
      </div>

      <div class="modal-footer">
        <button class="btn btn-secondary" @click="$emit('close')">
          Close
        </button>
      </div>
    </div>
  </div>
</template>

<script setup>
defineProps({
  activity: {
    type: Object,
    required: true
  }
});

defineEmits(['close']);
</script>

<style scoped>
.activity-info-grid {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
  gap: 16px;
  margin-bottom: 24px;
}

.info-card {
  background: #f8f9fa;
  border-radius: 8px;
  padding: 16px;
  display: flex;
  align-items: center;
  gap: 12px;
}

.info-icon {
  font-size: 24px;
  color: #079baa;
}

.info-label {
  font-size: 12px;
  color: #6c757d;
  text-transform: uppercase;
  letter-spacing: 0.5px;
}

.info-value {
  font-size: 16px;
  font-weight: 600;
  color: #212529;
}

.content-preview {
  display: flex;
  flex-direction: column;
  gap: 24px;
}

.content-section h4 {
  margin: 0 0 12px 0;
  font-size: 18px;
  font-weight: 600;
  color: #23356f;
  display: flex;
  align-items: center;
  gap: 8px;
  padding-bottom: 8px;
  border-bottom: 2px solid #f1f5f9;
}

.html-content {
  line-height: 1.8;
  color: #495057;
  font-size: 15px;
}

.empty-content {
  text-align: center;
  padding: 60px 20px;
  color: #6c757d;
}

.empty-icon {
  font-size: 48px;
  color: #cbd5e1;
  margin-bottom: 16px;
}
</style>

