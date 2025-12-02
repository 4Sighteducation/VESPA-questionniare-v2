/**
 * Shared Constants for VESPA Activities V3
 */

// VESPA Categories
export const VESPA_CATEGORIES = [
  'Vision',
  'Effort',
  'Systems',
  'Practice',
  'Attitude'
];

// Category Colors (VESPA Brand Colors - matching staff dashboard)
export const CATEGORY_COLORS = {
  Vision: '#fc8900',      // Orange
  Effort: '#78aced',      // Blue
  Systems: '#7bc114',     // Green
  Practice: '#792e9c',    // Purple
  Attitude: '#eb2de3'     // Pink/Magenta
};

// Activity Status
export const ACTIVITY_STATUS = {
  ASSIGNED: 'assigned',
  STARTED: 'started',
  IN_PROGRESS: 'in_progress',
  COMPLETED: 'completed',
  REMOVED: 'removed'
};

// Selection Methods
export const SELECTION_METHODS = {
  AUTO: 'auto',
  STUDENT_CHOICE: 'student_choice',
  STAFF_ASSIGNED: 'staff_assigned',
  RECOMMENDED: 'recommended'
};

// Question Types
export const QUESTION_TYPES = {
  SHORT_TEXT: 'Short Text',
  PARAGRAPH_TEXT: 'Paragraph Text',
  DROPDOWN: 'Dropdown',
  CHECKBOXES: 'Checkboxes',
  DATE: 'Date',
  SINGLE_CHECKBOX: 'Single Checkbox'
};

// Notification Types
export const NOTIFICATION_TYPES = {
  FEEDBACK_RECEIVED: 'feedback_received',
  ACTIVITY_ASSIGNED: 'activity_assigned',
  ACHIEVEMENT_EARNED: 'achievement_earned',
  REMINDER: 'reminder',
  MILESTONE: 'milestone',
  STAFF_NOTE: 'staff_note',
  ENCOURAGEMENT: 'encouragement'
};

// Staff Roles
export const STAFF_ROLES = {
  TUTOR: 'tutor',
  STAFF_ADMIN: 'staff_admin',
  HEAD_OF_YEAR: 'head_of_year',
  SUBJECT_TEACHER: 'subject_teacher'
};

// API Endpoints
export const API_BASE_URL = import.meta.env.VITE_API_URL || 'https://vespa-dashboard-9a1f84ee5341.herokuapp.com';

export const API_ENDPOINTS = {
  // Student Activities
  RECOMMENDED_ACTIVITIES: '/api/activities/recommended',
  ACTIVITIES_BY_PROBLEM: '/api/activities/by-problem',
  ASSIGNED_ACTIVITIES: '/api/activities/assigned',
  ACTIVITY_QUESTIONS: '/api/activities/questions',
  START_ACTIVITY: '/api/activities/start',
  SAVE_PROGRESS: '/api/activities/save',
  COMPLETE_ACTIVITY: '/api/activities/complete',
  REMOVE_ACTIVITY: '/api/activities/remove',  // Student remove endpoint
  
  // Staff
  STAFF_STUDENTS: '/api/staff/students',
  STUDENT_ACTIVITIES: '/api/staff/student-activities',
  ASSIGN_ACTIVITY: '/api/staff/assign-activity',
  GIVE_FEEDBACK: '/api/staff/feedback',
  STAFF_REMOVE_ACTIVITY: '/api/staff/remove-activity',
  AWARD_ACHIEVEMENT: '/api/staff/award-achievement',
  
  // Notifications
  NOTIFICATIONS: '/api/notifications',
  MARK_READ: '/api/notifications/mark-read',
  
  // Achievements
  CHECK_ACHIEVEMENTS: '/api/achievements/check'
};

// Auto-save interval (30 seconds)
export const AUTO_SAVE_INTERVAL = 30000;

// Theme Colors (from memory: user prefers blues/turquoises)
export const THEME_COLORS = {
  primary: '#079baa',
  primaryLight: '#7bd8d0',
  secondary: '#62d1d2',
  accent: '#00e5db',
  blue: '#5899a8',
  darkBlue: '#23356f',
  darkerBlue: '#2a3c7a'
};

export default {
  VESPA_CATEGORIES,
  CATEGORY_COLORS,
  ACTIVITY_STATUS,
  SELECTION_METHODS,
  QUESTION_TYPES,
  NOTIFICATION_TYPES,
  STAFF_ROLES,
  API_BASE_URL,
  API_ENDPOINTS,
  AUTO_SAVE_INTERVAL,
  THEME_COLORS
};


