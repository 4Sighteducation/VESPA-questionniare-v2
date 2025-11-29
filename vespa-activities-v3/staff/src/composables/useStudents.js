/**
 * Students Data Composable
 * Handles loading and managing student data with activities
 */

import { ref, computed } from 'vue';
import supabase from '../supabaseClient';
import { useAuth } from './useAuth';

// Global state
const students = ref([]);
const isLoadingStudents = ref(false);
const studentsError = ref(null);

export function useStudents() {
  const { staffContext, currentUser, hasRole } = useAuth();

  /**
   * Load students based on staff role and connections
   */
  const loadStudents = async () => {
    isLoadingStudents.value = true;
    studentsError.value = null;

    try {
      console.log('📚 Loading students for school:', staffContext.value.schoolId);

      // Get staff member's account_id to find connections
      const { data: staffData, error: staffError } = await supabase
        .from('vespa_staff')
        .select('account_id, email, assigned_tutor_groups, assigned_year_groups')
        .eq('email', currentUser.value.email)
        .single();

      if (staffError) {
        console.warn('Staff record not found, might be super user:', staffError);
      }

      let query;

      // For super users or staff admins: get all students in school
      if (staffContext.value.isSuperUser || hasRole('staff_admin')) {
        console.log('Loading all students in school (admin access)');
        
        query = supabase
          .from('vespa_students')
          .select(`
            id,
            email,
            first_name,
            last_name,
            full_name,
            current_year_group,
            student_group,
            school_id,
            school_name,
            latest_vespa_scores,
            last_activity_at,
            total_activities_completed,
            activity_responses (
              id,
              activity_id,
              status,
              selected_via,
              completed_at,
              started_at,
              staff_feedback,
              staff_feedback_at,
              feedback_read_by_student,
              responses,
              time_spent_minutes,
              word_count,
              activities (
                id,
                name,
                vespa_category,
                level
              )
            )
          `)
          .eq('is_active', true)
          .order('last_name');
        
        // Only filter by school if schoolId is provided
        if (staffContext.value.schoolId) {
          query = query.eq('school_id', staffContext.value.schoolId);
        }

      } else {
        // For regular staff: show all students in their school
        // RLS will control what they can actually edit/assign
        console.log('Loading all students in school (regular staff)');
        
        query = supabase
          .from('vespa_students')
          .select(`
            id,
            email,
            first_name,
            last_name,
            full_name,
            current_year_group,
            student_group,
            school_id,
            school_name,
            latest_vespa_scores,
            last_activity_at,
            total_activities_completed,
            activity_responses (
              id,
              activity_id,
              status,
              selected_via,
              completed_at,
              started_at,
              staff_feedback,
              staff_feedback_at,
              feedback_read_by_student,
              responses,
              time_spent_minutes,
              word_count,
              activities (
                id,
                name,
                vespa_category,
                level
              )
            )
          `)
          .eq('is_active', true)
          .order('last_name');
        
        // Filter by school if we have schoolId
        if (staffContext.value.schoolId) {
          query = query.eq('school_id', staffContext.value.schoolId);
        }
      }

      const { data, error } = await query;

      if (error) throw error;

      // Process students and calculate progress
      const processedStudents = (data || []).map(student => {
        const responses = student.activity_responses || [];
        
        // Prescribed activities (from questionnaire or staff)
        const prescribed = responses.filter(r => 
          r.selected_via === 'questionnaire' || 
          r.selected_via === 'staff_assigned'
        );
        
        // Completed prescribed
        const completed = prescribed.filter(r => r.completed_at);
        
        // All completed (including student choice)
        const allCompleted = responses.filter(r => r.completed_at);
        
        // Calculate progress
        const progress = prescribed.length > 0 ? 
          Math.round((completed.length / prescribed.length) * 100) : 0;
        
        // Category breakdown (prescribed only)
        const categoryBreakdown = {
          vision: {
            prescribed: prescribed.filter(r => r.activities?.vespa_category === 'Vision'),
            completed: completed.filter(r => r.activities?.vespa_category === 'Vision')
          },
          effort: {
            prescribed: prescribed.filter(r => r.activities?.vespa_category === 'Effort'),
            completed: completed.filter(r => r.activities?.vespa_category === 'Effort')
          },
          systems: {
            prescribed: prescribed.filter(r => r.activities?.vespa_category === 'Systems'),
            completed: completed.filter(r => r.activities?.vespa_category === 'Systems')
          },
          practice: {
            prescribed: prescribed.filter(r => r.activities?.vespa_category === 'Practice'),
            completed: completed.filter(r => r.activities?.vespa_category === 'Practice')
          },
          attitude: {
            prescribed: prescribed.filter(r => r.activities?.vespa_category === 'Attitude'),
            completed: completed.filter(r => r.activities?.vespa_category === 'Attitude')
          }
        };
        
        // Unread feedback count
        const unreadFeedbackCount = responses.filter(r => 
          r.staff_feedback && !r.feedback_read_by_student
        ).length;
        
        return {
          ...student,
          prescribedCount: prescribed.length,
          completedCount: completed.length,
          totalCompletedCount: allCompleted.length,
          progress,
          categoryBreakdown,
          unreadFeedbackCount
        };
      });

      students.value = processedStudents;
      console.log(`✅ Loaded ${processedStudents.length} students`);

    } catch (err) {
      console.error('❌ Failed to load students:', err);
      studentsError.value = err.message;
      throw err;
    } finally {
      isLoadingStudents.value = false;
    }
  };

  /**
   * Get single student with full activity details
   */
  const getStudent = async (studentId) => {
    try {
      // First try from loaded students
      const cachedStudent = students.value.find(s => s.id === studentId);
      
      if (cachedStudent) {
        // Reload with fresh data for workspace view
        const { data, error } = await supabase
          .from('vespa_students')
          .select(`
            *,
            activity_responses (
              id,
              activity_id,
              status,
              selected_via,
              completed_at,
              started_at,
              responses,
              responses_text,
              staff_feedback,
              staff_feedback_by,
              staff_feedback_at,
              feedback_read_by_student,
              feedback_read_at,
              time_spent_minutes,
              word_count,
              cycle_number,
              academic_year,
              year_group,
              student_group,
              created_at,
              updated_at,
              activities (
                id,
                name,
                vespa_category,
                level,
                difficulty,
                time_minutes,
                do_section_html,
                think_section_html,
                learn_section_html,
                reflect_section_html,
                problem_mappings,
                curriculum_tags
              )
            )
          `)
          .eq('id', studentId)
          .single();

        if (error) throw error;

        // Process like in loadStudents
        const responses = data.activity_responses || [];
        const prescribed = responses.filter(r => 
          r.selected_via === 'questionnaire' || 
          r.selected_via === 'staff_assigned'
        );
        const completed = prescribed.filter(r => r.completed_at);
        
        return {
          ...data,
          prescribedCount: prescribed.length,
          completedCount: completed.length,
          progress: prescribed.length > 0 ? 
            Math.round((completed.length / prescribed.length) * 100) : 0
        };
      }

      return null;
    } catch (err) {
      console.error('Failed to get student:', err);
      throw err;
    }
  };

  /**
   * Filter students by search term
   */
  const filterStudents = (searchTerm) => {
    if (!searchTerm) return students.value;
    
    const term = searchTerm.toLowerCase();
    return students.value.filter(s => 
      s.full_name?.toLowerCase().includes(term) ||
      s.email?.toLowerCase().includes(term) ||
      s.student_group?.toLowerCase().includes(term)
    );
  };

  return {
    students,
    isLoadingStudents,
    studentsError,
    loadStudents,
    getStudent,
    filterStudents
  };
}

