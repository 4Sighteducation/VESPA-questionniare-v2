<template>
  <div class="student-list-view">
    <!-- Header -->
    <div class="dashboard-header">
      <div class="header-top">
        <h1 class="dashboard-title">VESPA Activities - Staff Dashboard</h1>
        <div class="header-actions">
          <button class="btn btn-secondary" @click="exportReport">
            <i class="fas fa-download"></i> Export Report
          </button>
          <button class="btn btn-primary" @click="$emit('refresh')">
            <i class="fas fa-sync"></i> Refresh
          </button>
        </div>
      </div>
      
      <div class="header-info">
        <span class="info-badge">
          <i class="fas fa-school"></i>
          {{ staffContext.schoolName }}
        </span>
        <span class="info-badge">
          <i class="fas fa-users"></i>
          {{ filteredStudents.length }} Student{{ filteredStudents.length !== 1 ? 's' : '' }}
        </span>
        <span class="info-badge">
          <i class="fas fa-chart-line"></i>
          Avg Progress: {{ averageProgress }}%
        </span>
      </div>
    </div>

    <!-- Filters -->
    <div class="filter-bar">
      <div class="search-box">
        <i class="fas fa-search search-icon"></i>
        <input
          type="text"
          v-model="searchTerm"
          placeholder="Search students by name or email..."
          class="search-input"
        />
      </div>

      <select v-model="filterYearGroup" class="filter-select">
        <option value="all">All Year Groups</option>
        <option v-for="yg in yearGroups" :key="yg" :value="yg">{{ yg }}</option>
      </select>

      <select v-model="filterProgress" class="filter-select">
        <option value="all">All Progress</option>
        <option value="not-started">Not Started (0%)</option>
        <option value="in-progress">In Progress (1-99%)</option>
        <option value="completed">Completed (100%)</option>
      </select>

      <div class="display-toggle">
        <button
          :class="['toggle-btn', { active: displayMode === 'activities' }]"
          @click="displayMode = 'activities'"
        >
          <i class="fas fa-tasks"></i> Activities
        </button>
        <button
          :class="['toggle-btn', { active: displayMode === 'scores' }]"
          @click="displayMode = 'scores'"
        >
          <i class="fas fa-chart-bar"></i> Scores
        </button>
      </div>

      <button class="btn btn-secondary" @click="clearFilters">
        <i class="fas fa-times"></i> Clear
      </button>
    </div>

    <!-- Bulk Actions Toolbar -->
    <div v-if="selectedStudents.size > 0" class="bulk-toolbar">
      <span class="selection-count">
        {{ selectedStudents.size }} student{{ selectedStudents.size !== 1 ? 's' : '' }} selected
      </span>
      <button class="btn btn-primary" @click="openBulkAssign">
        <i class="fas fa-plus-circle"></i> Assign Activities
      </button>
      <button class="btn btn-secondary" @click="clearSelection">
        <i class="fas fa-times"></i> Clear Selection
      </button>
    </div>

    <!-- Loading State -->
    <div v-if="isLoading" class="loading-overlay">
      <div class="spinner"></div>
    </div>

    <!-- Students Table -->
    <div v-else-if="filteredStudents.length > 0" class="table-container">
      <table class="students-table">
        <thead>
          <tr>
            <th style="width: 40px">
              <input type="checkbox" @change="toggleSelectAll" :checked="allSelected" />
            </th>
            <th @click="sortBy('name')" class="sortable">
              Student Name
              <i v-if="sortColumn === 'name'" :class="sortIcon"></i>
            </th>
            <th style="width: 80px; text-align: center">View</th>
            
            <!-- VESPA Category Columns -->
            <th v-for="cat in categories" :key="cat" :class="`vespa-column ${cat.toLowerCase()}`">
              <div class="vespa-column-header">
                <span class="category-letter">{{ cat[0] }}</span>
                <span class="category-name">{{ cat }}</span>
              </div>
            </th>
          </tr>
        </thead>
        <tbody>
          <tr
            v-for="student in paginatedStudents"
            :key="student.id"
            :class="{ selected: selectedStudents.has(student.id) }"
          >
            <td>
              <input
                type="checkbox"
                :checked="selectedStudents.has(student.id)"
                @change="toggleStudent(student.id)"
              />
            </td>
            
            <td class="student-info-cell">
              <div class="student-name">{{ student.full_name }}</div>
              <div class="student-email">{{ student.email }}</div>
              <div class="student-meta">
                <span v-if="student.current_year_group" class="meta-badge">
                  {{ student.current_year_group }}
                </span>
                <span v-if="student.student_group" class="meta-badge">
                  {{ student.student_group }}
                </span>
              </div>
              <div class="progress-bar-mini" :title="`${student.completedCount}/${student.prescribedCount} completed`">
                <div class="progress-fill" :style="{ width: student.progress + '%' }"></div>
              </div>
            </td>
            
            <td style="text-align: center">
              <button class="btn-view" @click="$emit('view-student', student.id)" title="View student workspace">
                <span class="view-text">VIEW</span>
                <i class="fas fa-arrow-right"></i>
              </button>
            </td>
            
            <!-- Category Cells -->
            <td v-for="cat in categories" :key="cat" class="vespa-data-cell">
              <div v-if="displayMode === 'scores'" class="vespa-score-display" :class="cat.toLowerCase()">
                {{ getVESPAScore(student, cat) }}
              </div>
              <div v-else class="vespa-activity-display" :class="cat.toLowerCase()">
                <span class="activity-ratio">
                  {{ getCategoryCompleted(student, cat) }}/{{ getCategoryTotal(student, cat) }}
                </span>
              </div>
            </td>
          </tr>
        </tbody>
      </table>

      <!-- Pagination -->
      <div v-if="totalPages > 1" class="pagination">
        <button
          class="btn btn-sm"
          @click="currentPage--"
          :disabled="currentPage === 1"
        >
          <i class="fas fa-chevron-left"></i> Previous
        </button>
        
        <span class="pagination-info">
          Page {{ currentPage }} of {{ totalPages }} ({{ filteredStudents.length }} students)
        </span>
        
        <button
          class="btn btn-sm"
          @click="currentPage++"
          :disabled="currentPage === totalPages"
        >
          Next <i class="fas fa-chevron-right"></i>
        </button>
      </div>
    </div>

    <!-- Empty State -->
    <div v-else class="empty-state">
      <i class="fas fa-users empty-icon"></i>
      <h3>No Students Found</h3>
      <p>{{ searchTerm ? 'Try adjusting your search or filters' : 'No students available' }}</p>
    </div>

    <!-- Bulk Assign Modal -->
    <BulkAssignModal
      v-if="showBulkAssignModal"
      :selected-students="Array.from(selectedStudents)"
      :students="students"
      @close="showBulkAssignModal = false"
      @assigned="handleBulkAssigned"
    />
  </div>
</template>

<script setup>
import { ref, computed, watch } from 'vue';
import BulkAssignModal from './BulkAssignModal.vue';

// Props
const props = defineProps({
  students: {
    type: Array,
    required: true
  },
  isLoading: {
    type: Boolean,
    default: false
  },
  staffContext: {
    type: Object,
    required: true
  }
});

// Emits
const emit = defineEmits(['view-student', 'refresh']);

// State
const searchTerm = ref('');
const filterYearGroup = ref('all');
const filterProgress = ref('all');
const displayMode = ref('activities'); // 'activities' or 'scores'
const selectedStudents = ref(new Set());
const showBulkAssignModal = ref(false);
const sortColumn = ref('name');
const sortDirection = ref('asc');
const currentPage = ref(1);
const studentsPerPage = 50;

// Constants
const categories = ['Vision', 'Effort', 'Systems', 'Practice', 'Attitude'];

// Computed
const yearGroups = computed(() => {
  const groups = new Set(props.students.map(s => s.current_year_group).filter(Boolean));
  return Array.from(groups).sort();
});

const filteredStudents = computed(() => {
  let filtered = props.students;

  // Search filter
  if (searchTerm.value) {
    const term = searchTerm.value.toLowerCase();
    filtered = filtered.filter(s =>
      s.full_name?.toLowerCase().includes(term) ||
      s.email?.toLowerCase().includes(term) ||
      s.student_group?.toLowerCase().includes(term)
    );
  }

  // Year group filter
  if (filterYearGroup.value !== 'all') {
    filtered = filtered.filter(s => s.current_year_group === filterYearGroup.value);
  }

  // Progress filter
  if (filterProgress.value !== 'all') {
    filtered = filtered.filter(s => {
      if (filterProgress.value === 'not-started') return s.progress === 0;
      if (filterProgress.value === 'in-progress') return s.progress > 0 && s.progress < 100;
      if (filterProgress.value === 'completed') return s.progress === 100;
      return true;
    });
  }

  // Sort
  filtered.sort((a, b) => {
    let aVal, bVal;
    
    if (sortColumn.value === 'name') {
      aVal = a.full_name?.toLowerCase() || '';
      bVal = b.full_name?.toLowerCase() || '';
    } else if (sortColumn.value === 'progress') {
      aVal = a.progress;
      bVal = b.progress;
    }
    
    const comparison = aVal > bVal ? 1 : -1;
    return sortDirection.value === 'asc' ? comparison : -comparison;
  });

  return filtered;
});

const paginatedStudents = computed(() => {
  const start = (currentPage.value - 1) * studentsPerPage;
  const end = start + studentsPerPage;
  return filteredStudents.value.slice(start, end);
});

const totalPages = computed(() => {
  return Math.ceil(filteredStudents.value.length / studentsPerPage);
});

const averageProgress = computed(() => {
  if (filteredStudents.value.length === 0) return 0;
  const sum = filteredStudents.value.reduce((acc, s) => acc + s.progress, 0);
  return Math.round(sum / filteredStudents.value.length);
});

const allSelected = computed(() => {
  return paginatedStudents.value.length > 0 &&
    paginatedStudents.value.every(s => selectedStudents.value.has(s.id));
});

const sortIcon = computed(() => {
  return sortDirection.value === 'asc' ? 'fas fa-sort-up' : 'fas fa-sort-down';
});

// Methods
const sortBy = (column) => {
  if (sortColumn.value === column) {
    sortDirection.value = sortDirection.value === 'asc' ? 'desc' : 'asc';
  } else {
    sortColumn.value = column;
    sortDirection.value = 'asc';
  }
};

const toggleSelectAll = (event) => {
  if (event.target.checked) {
    paginatedStudents.value.forEach(s => selectedStudents.value.add(s.id));
  } else {
    paginatedStudents.value.forEach(s => selectedStudents.value.delete(s.id));
  }
};

const toggleStudent = (studentId) => {
  if (selectedStudents.value.has(studentId)) {
    selectedStudents.value.delete(studentId);
  } else {
    selectedStudents.value.add(studentId);
  }
};

const clearSelection = () => {
  selectedStudents.value.clear();
};

const clearFilters = () => {
  searchTerm.value = '';
  filterYearGroup.value = 'all';
  filterProgress.value = 'all';
  currentPage.value = 1;
};

const openBulkAssign = () => {
  if (selectedStudents.value.size === 0) {
    alert('Please select at least one student');
    return;
  }
  showBulkAssignModal.value = true;
};

const handleBulkAssigned = () => {
  showBulkAssignModal.value = false;
  clearSelection();
  emit('refresh');
};

const getVESPAScore = (student, category) => {
  const cat = category.toLowerCase();
  const score = student.latest_vespa_scores?.[cat];
  return score ? Math.round(score) : 0;
};

const getCategoryTotal = (student, category) => {
  return student.categoryBreakdown?.[category.toLowerCase()]?.prescribed?.length || 0;
};

const getCategoryCompleted = (student, category) => {
  return student.categoryBreakdown?.[category.toLowerCase()]?.completed?.length || 0;
};

const exportReport = () => {
  // Generate CSV
  const headers = [
    'Student Name',
    'Email',
    'Year Group',
    'Group',
    'Progress %',
    'Prescribed',
    'Completed',
    'Vision',
    'Effort',
    'Systems',
    'Practice',
    'Attitude'
  ];

  const rows = filteredStudents.value.map(s => [
    s.full_name,
    s.email,
    s.current_year_group || '',
    s.student_group || '',
    s.progress,
    s.prescribedCount,
    s.completedCount,
    getVESPAScore(s, 'Vision'),
    getVESPAScore(s, 'Effort'),
    getVESPAScore(s, 'Systems'),
    getVESPAScore(s, 'Practice'),
    getVESPAScore(s, 'Attitude')
  ]);

  const csv = [headers, ...rows].map(row => row.join(',')).join('\n');
  const blob = new Blob([csv], { type: 'text/csv' });
  const url = URL.createObjectURL(blob);
  const a = document.createElement('a');
  a.href = url;
  a.download = `vespa-progress-${new Date().toISOString().split('T')[0]}.csv`;
  a.click();
  URL.revokeObjectURL(url);
};

// Reset to page 1 when filters change
watch([searchTerm, filterYearGroup, filterProgress], () => {
  currentPage.value = 1;
});
</script>

<style scoped>
.student-list-view {
  padding: 20px;
  max-width: 1800px;
  margin: 0 auto;
}

.dashboard-header {
  background: white;
  border-radius: 12px;
  padding: 24px;
  margin-bottom: 20px;
  box-shadow: 0 2px 8px rgba(0,0,0,0.08);
  border-left: 4px solid #079baa;
}

.header-top {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 16px;
}

.dashboard-title {
  font-size: 24px;
  font-weight: 600;
  color: #23356f;
  margin: 0;
}

.header-actions {
  display: flex;
  gap: 12px;
}

.header-info {
  display: flex;
  gap: 16px;
  flex-wrap: wrap;
}

.info-badge {
  display: inline-flex;
  align-items: center;
  gap: 6px;
  padding: 6px 12px;
  background: #f8f9fa;
  border-radius: 20px;
  font-size: 14px;
  color: #495057;
}

.info-badge i {
  color: #079baa;
}

.filter-bar {
  background: white;
  border-radius: 8px;
  padding: 16px;
  margin-bottom: 20px;
  display: flex;
  gap: 12px;
  align-items: center;
  flex-wrap: wrap;
  box-shadow: 0 1px 3px rgba(0,0,0,0.08);
}

.search-box {
  position: relative;
  flex: 1;
  min-width: 250px;
}

.search-icon {
  position: absolute;
  left: 12px;
  top: 50%;
  transform: translateY(-50%);
  color: #6c757d;
}

.search-input {
  width: 100%;
  padding: 10px 12px 10px 38px;
  border: 1px solid #dee2e6;
  border-radius: 6px;
  font-size: 14px;
}

.search-input:focus {
  outline: none;
  border-color: #079baa;
  box-shadow: 0 0 0 3px rgba(7, 155, 170, 0.1);
}

.filter-select {
  padding: 10px 12px;
  border: 1px solid #dee2e6;
  border-radius: 6px;
  font-size: 14px;
  background: white;
  cursor: pointer;
}

.display-toggle {
  display: flex;
  background: #f1f5f9;
  border-radius: 8px;
  padding: 3px;
}

.toggle-btn {
  padding: 8px 16px;
  border: none;
  background: transparent;
  border-radius: 6px;
  cursor: pointer;
  font-size: 13px;
  font-weight: 500;
  color: #64748b;
  transition: all 0.2s;
  display: flex;
  align-items: center;
  gap: 6px;
}

.toggle-btn:hover {
  background: #e2e8f0;
}

.toggle-btn.active {
  background: linear-gradient(135deg, #0891b2 0%, #0e7490 100%);
  color: white;
  box-shadow: 0 2px 4px rgba(8, 145, 178, 0.2);
}

.bulk-toolbar {
  background: #e3f2fd;
  border: 1px solid #90caf9;
  border-radius: 8px;
  padding: 12px 16px;
  margin-bottom: 20px;
  display: flex;
  align-items: center;
  gap: 12px;
}

.selection-count {
  font-weight: 600;
  color: #0d47a1;
  margin-right: auto;
}

.table-container {
  background: white;
  border-radius: 12px;
  box-shadow: 0 2px 8px rgba(0,0,0,0.08);
  overflow: hidden;
}

.students-table {
  width: 100%;
  border-collapse: collapse;
}

.students-table thead {
  background: linear-gradient(135deg, #f8fafc 0%, #f1f5f9 100%);
  position: sticky;
  top: 0;
  z-index: 10;
}

.students-table th {
  padding: 16px 12px;
  text-align: left;
  font-weight: 700;
  font-size: 11px;
  text-transform: uppercase;
  letter-spacing: 0.5px;
  color: #64748b;
  border-bottom: 2px solid #e2e8f0;
  cursor: pointer;
  user-select: none;
}

.students-table th.sortable:hover {
  background: #e2e8f0;
}

.students-table tbody tr {
  border-bottom: 1px solid #f1f5f9;
  transition: all 0.2s;
}

.students-table tbody tr:hover {
  background: linear-gradient(90deg, #f0f9ff 0%, #e0f2fe 100%);
  transform: translateX(2px);
}

.students-table tbody tr.selected {
  background: #e0f2fe;
}

.student-info-cell {
  padding: 12px;
}

.student-name {
  font-weight: 600;
  font-size: 14px;
  color: #212529;
  margin-bottom: 4px;
}

.student-email {
  font-size: 12px;
  color: #6c757d;
  margin-bottom: 6px;
}

.student-meta {
  display: flex;
  gap: 6px;
  margin-bottom: 8px;
}

.meta-badge {
  padding: 2px 8px;
  background: #e9ecef;
  border-radius: 12px;
  font-size: 11px;
  color: #495057;
}

.progress-bar-mini {
  width: 100%;
  height: 6px;
  background: #e9ecef;
  border-radius: 3px;
  overflow: hidden;
}

.progress-fill {
  height: 100%;
  background: linear-gradient(90deg, #10b981 0%, #059669 100%);
  transition: width 0.3s;
}

.btn-view {
  width: 56px;
  height: 56px;
  border-radius: 8px;
  background: linear-gradient(135deg, #0891b2 0%, #0e7490 100%);
  color: white;
  border: none;
  cursor: pointer;
  transition: all 0.2s;
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  font-size: 11px;
  font-weight: 700;
  box-shadow: 0 2px 6px rgba(8, 145, 178, 0.3);
}

.btn-view:hover {
  background: linear-gradient(135deg, #0e7490 0%, #164e63 100%);
  transform: translateY(-2px);
  box-shadow: 0 6px 20px rgba(8, 145, 178, 0.4);
}

.view-text {
  font-size: 11px;
  letter-spacing: 0.5px;
}

.vespa-data-cell {
  text-align: center;
  padding: 8px 4px;
}

.vespa-score-display,
.vespa-activity-display {
  width: 56px;
  height: 56px;
  border-radius: 50%;
  display: flex;
  align-items: center;
  justify-content: center;
  margin: 0 auto;
  font-weight: 700;
  font-size: 16px;
  color: white;
  box-shadow: 0 2px 6px rgba(0,0,0,0.1);
  cursor: pointer;
  transition: all 0.2s;
}

.vespa-score-display:hover,
.vespa-activity-display:hover {
  transform: translateY(-2px);
  box-shadow: 0 4px 12px rgba(0,0,0,0.2);
}

/* Category Colors - VESPA Brand Theme */
.vision {
  background: linear-gradient(135deg, #ff8f00 0%, #f57c00 100%);
}

.effort {
  background: linear-gradient(135deg, #86b4f0 0%, #5e9de8 100%);
}

.systems {
  background: linear-gradient(135deg, #84cc16 0%, #65a30d 100%);
}

.practice {
  background: linear-gradient(135deg, #7f31a4 0%, #6b2589 100%);
}

.attitude {
  background: linear-gradient(135deg, #f032e6 0%, #d91ad9 100%);
}

.vespa-column-header {
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 6px;
}

.category-letter {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  width: 22px;
  height: 22px;
  border-radius: 50%;
  color: white;
  font-weight: 700;
  font-size: 12px;
}

.vespa-column.vision .category-letter {
  background: linear-gradient(135deg, #ff8f00 0%, #f57c00 100%);
}

.vespa-column.effort .category-letter {
  background: linear-gradient(135deg, #86b4f0 0%, #5e9de8 100%);
}

.vespa-column.systems .category-letter {
  background: linear-gradient(135deg, #84cc16 0%, #65a30d 100%);
}

.vespa-column.practice .category-letter {
  background: linear-gradient(135deg, #7f31a4 0%, #6b2589 100%);
}

.vespa-column.attitude .category-letter {
  background: linear-gradient(135deg, #f032e6 0%, #d91ad9 100%);
}

.pagination {
  display: flex;
  justify-content: space-between;
  align-items: center;
  padding: 16px 20px;
  border-top: 1px solid #f1f5f9;
}

.pagination-info {
  color: #6c757d;
  font-size: 14px;
}

.empty-state {
  text-align: center;
  padding: 60px 20px;
  background: white;
  border-radius: 12px;
  box-shadow: 0 2px 8px rgba(0,0,0,0.08);
}

.empty-icon {
  font-size: 48px;
  color: #cbd5e1;
  margin-bottom: 16px;
}

.empty-state h3 {
  color: #475569;
  margin: 0 0 8px 0;
}

.empty-state p {
  color: #94a3b8;
  margin: 0;
}

/* Button Styles */
.btn {
  padding: 10px 16px;
  border: none;
  border-radius: 6px;
  font-size: 14px;
  font-weight: 500;
  cursor: pointer;
  transition: all 0.2s;
  display: inline-flex;
  align-items: center;
  gap: 6px;
}

.btn-primary {
  background: linear-gradient(135deg, #079baa 0%, #057a87 100%);
  color: white;
}

.btn-primary:hover {
  transform: translateY(-1px);
  box-shadow: 0 4px 12px rgba(7, 155, 170, 0.3);
}

.btn-secondary {
  background: white;
  color: #079baa;
  border: 1px solid #079baa;
}

.btn-secondary:hover {
  background: #f0f9ff;
}

.btn-sm {
  padding: 6px 12px;
  font-size: 13px;
}

.btn:disabled {
  opacity: 0.5;
  cursor: not-allowed;
}

.loading-overlay {
  display: flex;
  justify-content: center;
  align-items: center;
  padding: 60px;
  background: white;
  border-radius: 12px;
}

.spinner {
  width: 40px;
  height: 40px;
  border: 3px solid #f3f3f3;
  border-top: 3px solid #079baa;
  border-radius: 50%;
  animation: spin 1s linear infinite;
}

@keyframes spin {
  to { transform: rotate(360deg); }
}
</style>

