"""
VESPA Questionnaire V2 - Backend API Endpoints
Add these endpoints to your existing DASHBOARD/DASHBOARD/app.py

These handle:
1. Validation - Check if student can take questionnaire
2. Submission - Save responses to Supabase + Knack (dual-write)
3. VESPA score calculation using production thresholds
"""

import os
import json
import requests
from datetime import datetime
from flask import request, jsonify
from supabase import create_client, Client

# ========================================
# CONFIGURATION (already in your app.py)
# ========================================
# SUPABASE_URL = os.getenv('SUPABASE_URL')
# SUPABASE_KEY = os.getenv('SUPABASE_KEY')
# supabase_client = create_client(SUPABASE_URL, SUPABASE_KEY)

# KNACK_APP_ID = '5ee90912c38ae7001510c1a9'
# KNACK_API_KEY = '8f733aa5-dd35-4464-8348-64824d1f5f0d'

# ========================================
# VESPA CALCULATION THRESHOLDS
# From reverse_vespa_calculator.py
# ========================================

VESPA_THRESHOLDS = {
    'VISION': [
        (0, 2.26), (2.26, 2.7), (2.7, 3.02), (3.02, 3.33), (3.33, 3.52),
        (3.52, 3.84), (3.84, 4.15), (4.15, 4.47), (4.47, 4.79), (4.79, 5.01)
    ],
    'EFFORT': [
        (0, 2.42), (2.42, 2.73), (2.73, 3.04), (3.04, 3.36), (3.36, 3.67),
        (3.67, 3.86), (3.86, 4.17), (4.17, 4.48), (4.48, 4.8), (4.8, 5.01)
    ],
    'SYSTEMS': [
        (0, 2.36), (2.36, 2.76), (2.76, 3.16), (3.16, 3.46), (3.46, 3.75),
        (3.75, 4.05), (4.05, 4.35), (4.35, 4.64), (4.64, 4.94), (4.94, 5.01)
    ],
    'PRACTICE': [
        (0, 1.74), (1.74, 2.1), (2.1, 2.46), (2.46, 2.74), (2.74, 3.02),
        (3.02, 3.3), (3.3, 3.66), (3.66, 3.94), (3.94, 4.3), (4.3, 5.01)
    ],
    'ATTITUDE': [
        (0, 2.31), (2.31, 2.72), (2.72, 3.01), (3.01, 3.3), (3.3, 3.53),
        (3.53, 3.83), (3.83, 4.06), (4.06, 4.35), (4.35, 4.7), (4.7, 5.01)
    ]
}

# Question category mapping (from questions.js)
QUESTION_CATEGORIES = {
    'q1': 'VISION', 'q2': 'SYSTEMS', 'q3': 'VISION', 'q4': 'SYSTEMS', 'q5': 'ATTITUDE',
    'q6': 'EFFORT', 'q7': 'PRACTICE', 'q8': 'ATTITUDE', 'q9': 'EFFORT', 'q10': 'ATTITUDE',
    'q11': 'SYSTEMS', 'q12': 'PRACTICE', 'q13': 'ATTITUDE', 'q14': 'VISION', 'q15': 'PRACTICE',
    'q16': 'VISION', 'q17': 'EFFORT', 'q18': 'SYSTEMS', 'q19': 'PRACTICE', 'q20': 'ATTITUDE',
    'q21': 'EFFORT', 'q22': 'SYSTEMS', 'q23': 'PRACTICE', 'q24': 'ATTITUDE', 'q25': 'PRACTICE',
    'q26': 'ATTITUDE', 'q27': 'ATTITUDE', 'q28': 'ATTITUDE', 'q29': 'VISION',
    'q30': 'OUTCOME', 'q31': 'OUTCOME', 'q32': 'OUTCOME'
}

# Knack field mappings (from questions.js and Object_29 mapping.txt)
KNACK_FIELD_MAPPING = {
    'q1': {'current': 'field_794', 'cycle1': 'field_1953', 'cycle2': 'field_1955', 'cycle3': 'field_1956'},
    'q2': {'current': 'field_795', 'cycle1': 'field_1954', 'cycle2': 'field_1957', 'cycle3': 'field_1958'},
    'q3': {'current': 'field_796', 'cycle1': 'field_1959', 'cycle2': 'field_1960', 'cycle3': 'field_1961'},
    'q4': {'current': 'field_797', 'cycle1': 'field_1962', 'cycle2': 'field_1963', 'cycle3': 'field_1964'},
    'q5': {'current': 'field_798', 'cycle1': 'field_1965', 'cycle2': 'field_1966', 'cycle3': 'field_1967'},
    'q6': {'current': 'field_799', 'cycle1': 'field_1968', 'cycle2': 'field_1969', 'cycle3': 'field_1970'},
    'q7': {'current': 'field_800', 'cycle1': 'field_1971', 'cycle2': 'field_1972', 'cycle3': 'field_1973'},
    'q8': {'current': 'field_801', 'cycle1': 'field_1974', 'cycle2': 'field_1975', 'cycle3': 'field_1976'},
    'q9': {'current': 'field_802', 'cycle1': 'field_1977', 'cycle2': 'field_1978', 'cycle3': 'field_1979'},
    'q10': {'current': 'field_803', 'cycle1': 'field_1980', 'cycle2': 'field_1981', 'cycle3': 'field_1982'},
    'q11': {'current': 'field_804', 'cycle1': 'field_1983', 'cycle2': 'field_1984', 'cycle3': 'field_1985'},
    'q12': {'current': 'field_805', 'cycle1': 'field_1986', 'cycle2': 'field_1987', 'cycle3': 'field_1988'},
    'q13': {'current': 'field_806', 'cycle1': 'field_1989', 'cycle2': 'field_1990', 'cycle3': 'field_1991'},
    'q14': {'current': 'field_807', 'cycle1': 'field_1992', 'cycle2': 'field_1993', 'cycle3': 'field_1994'},
    'q15': {'current': 'field_808', 'cycle1': 'field_1995', 'cycle2': 'field_1996', 'cycle3': 'field_1997'},
    'q16': {'current': 'field_809', 'cycle1': 'field_1998', 'cycle2': 'field_1999', 'cycle3': 'field_2000'},
    'q17': {'current': 'field_810', 'cycle1': 'field_2001', 'cycle2': 'field_2002', 'cycle3': 'field_2003'},
    'q18': {'current': 'field_811', 'cycle1': 'field_2004', 'cycle2': 'field_2005', 'cycle3': 'field_2006'},
    'q19': {'current': 'field_812', 'cycle1': 'field_2007', 'cycle2': 'field_2008', 'cycle3': 'field_2009'},
    'q20': {'current': 'field_813', 'cycle1': 'field_2010', 'cycle2': 'field_2011', 'cycle3': 'field_2012'},
    'q21': {'current': 'field_814', 'cycle1': 'field_2013', 'cycle2': 'field_2014', 'cycle3': 'field_2015'},
    'q22': {'current': 'field_815', 'cycle1': 'field_2016', 'cycle2': 'field_2017', 'cycle3': 'field_2018'},
    'q23': {'current': 'field_816', 'cycle1': 'field_2019', 'cycle2': 'field_2020', 'cycle3': 'field_2021'},
    'q24': {'current': 'field_817', 'cycle1': 'field_2022', 'cycle2': 'field_2023', 'cycle3': 'field_2024'},
    'q25': {'current': 'field_818', 'cycle1': 'field_2025', 'cycle2': 'field_2026', 'cycle3': 'field_2027'},
    'q26': {'current': 'field_819', 'cycle1': 'field_2028', 'cycle2': 'field_2029', 'cycle3': 'field_2030'},
    'q27': {'current': 'field_820', 'cycle1': 'field_2031', 'cycle2': 'field_2032', 'cycle3': 'field_2033'},
    'q28': {'current': 'field_821', 'cycle1': 'field_2034', 'cycle2': 'field_2035', 'cycle3': 'field_2036'},
    'q29': {'current': 'field_2317', 'cycle1': 'field_2927', 'cycle2': 'field_2928', 'cycle3': 'field_2929'},
    'q30': {'current': 'field_1816', 'cycle1': 'field_2037', 'cycle2': 'field_2038', 'cycle3': 'field_2039'},
    'q31': {'current': 'field_1817', 'cycle1': 'field_2040', 'cycle2': 'field_2041', 'cycle3': 'field_2042'},
    'q32': {'current': 'field_1818', 'cycle1': 'field_2043', 'cycle2': 'field_2044', 'cycle3': 'field_2045'}
}

# Object_10 VESPA score field mappings
VESPA_SCORE_FIELDS = {
    'current': {
        'vision': 'field_147',
        'effort': 'field_148',
        'systems': 'field_149',
        'practice': 'field_150',
        'attitude': 'field_151',
        'overall': 'field_152'
    },
    'cycle1': {
        'vision': 'field_155',
        'effort': 'field_156',
        'systems': 'field_157',
        'practice': 'field_158',
        'attitude': 'field_159',
        'overall': 'field_160'
    },
    'cycle2': {
        'vision': 'field_161',
        'effort': 'field_162',
        'systems': 'field_163',
        'practice': 'field_164',
        'attitude': 'field_165',
        'overall': 'field_166'
    },
    'cycle3': {
        'vision': 'field_167',
        'effort': 'field_168',
        'systems': 'field_169',
        'practice': 'field_170',
        'attitude': 'field_171',
        'overall': 'field_172'
    }
}

# ========================================
# HELPER FUNCTIONS
# ========================================

def calculate_vespa_score_from_average(average, category):
    """
    Calculate VESPA score (1-10) from statement average (1-5)
    Uses production thresholds from reverse_vespa_calculator.py
    """
    thresholds = VESPA_THRESHOLDS.get(category, [])
    
    for i, (lower, upper) in enumerate(thresholds):
        if average >= lower and average < upper:
            return i + 1  # VESPA scores are 1-indexed
    
    return 10  # If >= 5.0, return 10

def calculate_all_vespa_scores(responses):
    """
    Calculate all VESPA scores from question responses
    
    Args:
        responses: dict mapping question_id to response_value (1-5)
    
    Returns:
        dict with vespaScores, categoryAverages, outcomeAverage
    """
    # Group responses by category
    category_responses = {
        'VISION': [],
        'EFFORT': [],
        'SYSTEMS': [],
        'PRACTICE': [],
        'ATTITUDE': [],
        'OUTCOME': []
    }
    
    for question_id, value in responses.items():
        category = QUESTION_CATEGORIES.get(question_id)
        if category and value is not None:
            category_responses[category].append(value)
    
    # Calculate averages
    category_averages = {}
    for category, values in category_responses.items():
        if category != 'OUTCOME' and len(values) > 0:
            category_averages[category] = sum(values) / len(values)
        elif category == 'OUTCOME' and len(values) > 0:
            category_averages['OUTCOME'] = sum(values) / len(values)
    
    # Calculate VESPA scores (1-10)
    vespa_scores = {}
    for category in ['VISION', 'EFFORT', 'SYSTEMS', 'PRACTICE', 'ATTITUDE']:
        if category in category_averages:
            vespa_scores[category] = calculate_vespa_score_from_average(
                category_averages[category], 
                category
            )
        else:
            vespa_scores[category] = 0
    
    # Calculate overall (average of 5 VESPA scores)
    if vespa_scores:
        overall = sum(vespa_scores.values()) / len(vespa_scores)
        vespa_scores['OVERALL'] = round(overall)
    
    return {
        'vespaScores': vespa_scores,
        'categoryAverages': category_averages,
        'outcomeAverage': category_averages.get('OUTCOME', 0)
    }

def parse_uk_date(date_str):
    """Parse UK format date (dd/mm/yyyy)"""
    if not date_str:
        return None
    try:
        return datetime.strptime(date_str, '%d/%m/%Y')
    except:
        try:
            return datetime.fromisoformat(date_str.replace('Z', '+00:00'))
        except:
            return None

# ========================================
# API ENDPOINT 1: VALIDATE ACCESS
# ========================================

@app.route('/api/vespa/questionnaire/validate', methods=['GET'])
def validate_questionnaire_access():
    """
    Validate if student can take the questionnaire
    
    Query params:
    - email: Student email (required)
    - accountId: Knack account ID (optional)
    
    Returns eligibility status and cycle information
    """
    try:
        email = request.args.get('email')
        account_id = request.args.get('accountId')
        
        if not email:
            return jsonify({'error': 'Email is required'}), 400
        
        app.logger.info(f"[Questionnaire V2] Validating access for {email}")
        
        # 1. Fetch user's Object_10 record from Knack
        headers = {
            'X-Knack-Application-Id': '5ee90912c38ae7001510c1a9',
            'X-Knack-REST-API-Key': '8f733aa5-dd35-4464-8348-64824d1f5f0d',
            'Content-Type': 'application/json'
        }
        
        # Search by email (field_197)
        filters = json.dumps({
            'match': 'and',
            'rules': [{
                'field': 'field_197',
                'operator': 'is',
                'value': email
            }]
        })
        
        response = requests.get(
            'https://api.knack.com/v1/objects/object_10/records',
            headers=headers,
            params={'filters': filters},
            timeout=30
        )
        
        if response.status_code != 200:
            return jsonify({
                'allowed': False,
                'reason': 'error',
                'message': 'Unable to verify your account. Please try again later.'
            }), 200
        
        data = response.json()
        
        if not data.get('records'):
            return jsonify({
                'allowed': False,
                'reason': 'no_record',
                'message': 'No VESPA record found for your account. Please contact your tutor.'
            }), 200
        
        user_record = data['records'][0]
        app.logger.info(f"[Questionnaire V2] Found user record: {user_record['id']}")
        
        # 2. Check cycle completion status
        cycle1_score = user_record.get('field_155')
        cycle2_score = user_record.get('field_161')
        cycle3_score = user_record.get('field_167')
        
        has_completed_cycle1 = cycle1_score and str(cycle1_score).strip() != ''
        has_completed_cycle2 = cycle2_score and str(cycle2_score).strip() != ''
        has_completed_cycle3 = cycle3_score and str(cycle3_score).strip() != ''
        
        # 3. Check cycleUnlocked override (field_1679)
        cycle_unlocked = user_record.get('field_1679')
        has_override = cycle_unlocked in ['Yes', True, 'true']
        
        # 4. Get connected customer for cycle dates
        customer_field = user_record.get('field_133_raw', [])
        customer_id = None
        if customer_field and isinstance(customer_field, list) and len(customer_field) > 0:
            customer_item = customer_field[0]
            if isinstance(customer_item, dict):
                customer_id = customer_item.get('id')
            else:
                customer_id = customer_item
        
        # 5. Fetch cycle dates from Object_66 if customer exists
        cycle_dates = []
        if customer_id:
            cycle_filters = json.dumps({
                'match': 'and',
                'rules': [{
                    'field': 'field_1585',  # Connected customer
                    'operator': 'is',
                    'value': customer_id
                }]
            })
            
            cycle_response = requests.get(
                'https://api.knack.com/v1/objects/object_66/records',
                headers=headers,
                params={'filters': cycle_filters, 'sort_field': 'field_1579', 'sort_order': 'asc'},
                timeout=30
            )
            
            if cycle_response.status_code == 200:
                cycle_dates = cycle_response.json().get('records', [])
        
        app.logger.info(f"[Questionnaire V2] Found {len(cycle_dates)} cycle dates")
        
        # 6. Check if there's an active cycle OR use override logic
        today = datetime.now().date()
        
        # If override is enabled, check for active cycles or use progression
        if has_override:
            app.logger.info("[Questionnaire V2] cycleUnlocked override enabled")
            
            # Check for currently active cycle
            for cycle_date in cycle_dates:
                cycle_num = int(cycle_date.get('field_1579', 0))
                
                # Skip completed cycles
                if cycle_num == 1 and has_completed_cycle1: continue
                if cycle_num == 2 and has_completed_cycle2: continue
                if cycle_num == 3 and has_completed_cycle3: continue
                
                start_date = parse_uk_date(cycle_date.get('field_1678'))
                end_date = parse_uk_date(cycle_date.get('field_1580'))
                
                if start_date and end_date:
                    if start_date.date() <= today <= end_date.date():
                        # Active cycle found
                        return jsonify({
                            'allowed': True,
                            'cycle': cycle_num,
                            'reason': 'cycle_unlocked_with_active_cycle',
                            'message': f'Cycle {cycle_num} is currently active',
                            'academicYear': calculate_academic_year_from_date(today),
                            'userRecord': {'id': user_record['id'], 'email': email}
                        })
            
            # No active cycle but has override - use progression
            next_cycle = 1
            if has_completed_cycle1: next_cycle = 2
            if has_completed_cycle2: next_cycle = 3
            if has_completed_cycle3: next_cycle = 1  # Restart
            
            return jsonify({
                'allowed': True,
                'cycle': next_cycle,
                'reason': 'cycle_unlocked_override',
                'message': f'Override enabled - taking Cycle {next_cycle}',
                'academicYear': calculate_academic_year_from_date(today),
                'userRecord': {'id': user_record['id'], 'email': email}
            })
        
        # 7. Normal validation - check cycle dates
        # Determine next cycle to complete
        next_cycle = 1
        if has_completed_cycle1: next_cycle = 2
        if has_completed_cycle2: next_cycle = 3
        if has_completed_cycle3:
            return jsonify({
                'allowed': False,
                'reason': 'all_completed',
                'message': 'You have completed all three VESPA questionnaire cycles for this academic year.'
            })
        
        # If no cycle dates, allow questionnaire
        if not cycle_dates:
            app.logger.info("[Questionnaire V2] No cycle dates - allowing questionnaire")
            return jsonify({
                'allowed': True,
                'cycle': next_cycle,
                'reason': 'no_cycle_dates',
                'message': f'Taking Cycle {next_cycle}',
                'academicYear': calculate_academic_year_from_date(today),
                'userRecord': {'id': user_record['id'], 'email': email}
            })
        
        # Check if ANY uncompleted cycle is currently active
        for cycle_date in cycle_dates:
            cycle_num = int(cycle_date.get('field_1579', 0))
            
            # Skip completed cycles
            if cycle_num == 1 and has_completed_cycle1: continue
            if cycle_num == 2 and has_completed_cycle2: continue
            if cycle_num == 3 and has_completed_cycle3: continue
            
            start_date = parse_uk_date(cycle_date.get('field_1678'))
            end_date = parse_uk_date(cycle_date.get('field_1580'))
            
            if start_date and end_date:
                if start_date.date() <= today <= end_date.date():
                    # Active cycle found!
                    return jsonify({
                        'allowed': True,
                        'cycle': cycle_num,
                        'reason': f'cycle_{cycle_num}_active',
                        'message': f'Cycle {cycle_num} is currently open',
                        'academicYear': calculate_academic_year_from_date(today),
                        'userRecord': {'id': user_record['id'], 'email': email}
                    })
        
        # No active cycle - find next upcoming cycle
        nearest_future = None
        nearest_date = None
        
        for cycle_date in cycle_dates:
            cycle_num = int(cycle_date.get('field_1579', 0))
            
            # Skip completed cycles
            if cycle_num == 1 and has_completed_cycle1: continue
            if cycle_num == 2 and has_completed_cycle2: continue
            if cycle_num == 3 and has_completed_cycle3: continue
            
            start_date = parse_uk_date(cycle_date.get('field_1678'))
            
            if start_date and start_date.date() > today:
                if not nearest_date or start_date.date() < nearest_date:
                    nearest_date = start_date.date()
                    nearest_future = cycle_date
        
        if nearest_future:
            cycle_num = int(nearest_future.get('field_1579', 0))
            return jsonify({
                'allowed': False,
                'reason': 'before_start',
                'message': f'The next questionnaire cycle (Cycle {cycle_num}) will open on {nearest_date.strftime("%d %B %Y")}.',
                'nextStartDate': nearest_date.strftime('%Y-%m-%d'),
                'cycle': cycle_num
            })
        
        # All cycles have ended
        return jsonify({
            'allowed': False,
            'reason': 'no_active_cycle',
            'message': 'All questionnaire cycles have ended for this academic year. Please contact your tutor.'
        })
        
    except Exception as e:
        app.logger.error(f"[Questionnaire V2] Validation error: {e}")
        return jsonify({
            'allowed': False,
            'reason': 'error',
            'message': 'Unable to verify questionnaire access. Please try again later.',
            'error': str(e)
        }), 500

def calculate_academic_year_from_date(date_obj, is_australian=False):
    """Calculate academic year from date"""
    year = date_obj.year
    month = date_obj.month
    
    if is_australian:
        return f"{year}/{year}"
    else:
        # UK: Aug-Jul
        if month >= 8:
            return f"{year}/{year + 1}"
        else:
            return f"{year - 1}/{year}"

# ========================================
# API ENDPOINT 2: SUBMIT QUESTIONNAIRE
# ========================================

@app.route('/api/vespa/questionnaire/submit', methods=['POST'])
def submit_questionnaire():
    """
    Submit completed questionnaire
    
    Body: {
        studentEmail, studentName, cycle, responses, 
        vespaScores, categoryAverages, knackRecordId, academicYear
    }
    
    Process:
    1. Write to Supabase (question_responses + vespa_scores)
    2. Dual-write to Knack (Object_29 + Object_10)
    3. Lock academic year if this is Cycle 1
    """
    try:
        data = request.json
        
        student_email = data.get('studentEmail')
        student_name = data.get('studentName')
        cycle = data.get('cycle')
        responses = data.get('responses', {})
        vespa_scores = data.get('vespaScores', {})
        knack_record_id = data.get('knackRecordId')
        academic_year_provided = data.get('academicYear')
        
        app.logger.info(f"[Questionnaire V2] Submission from {student_email}, Cycle {cycle}")
        
        # Validate required fields
        if not all([student_email, cycle, responses, vespa_scores]):
            return jsonify({'error': 'Missing required fields'}), 400
        
        # Re-calculate scores server-side for security
        calculation = calculate_all_vespa_scores(responses)
        vespa_scores = calculation['vespaScores']
        category_averages = calculation['categoryAverages']
        
        app.logger.info(f"[Questionnaire V2] Calculated VESPA scores: {vespa_scores}")
        
        # ========================================
        # STEP 1: GET/CREATE STUDENT IN SUPABASE
        # ========================================
        
        # Find student by email
        student_query = supabase_client.table('students')\
            .select('*')\
            .eq('email', student_email)\
            .execute()
        
        if student_query.data and len(student_query.data) > 0:
            # Student exists - get their ID and check for locked academic year
            student_id = student_query.data[0]['id']
            establishment_id = student_query.data[0].get('establishment_id')
            app.logger.info(f"[Questionnaire V2] Found existing student: {student_id}")
        else:
            # Student doesn't exist in Supabase yet - shouldn't happen but handle gracefully
            app.logger.warning(f"[Questionnaire V2] Student not found in Supabase: {student_email}")
            return jsonify({
                'error': 'Student record not found. Please ensure you have been enrolled in the system.'
            }), 404
        
        # ========================================
        # STEP 2: DETERMINE/LOCK ACADEMIC YEAR
        # ========================================
        
        # Check if student has Cycle 1 data (locked academic year)
        locked_year_query = supabase_client.table('vespa_scores')\
            .select('academic_year')\
            .eq('student_id', student_id)\
            .eq('cycle', 1)\
            .order('completion_date', desc=True)\
            .limit(1)\
            .execute()
        
        if cycle == 1:
            # This IS Cycle 1 - calculate and lock the academic year
            # Get establishment to determine if Australian
            est_query = supabase_client.table('establishments')\
                .select('is_australian, use_standard_year')\
                .eq('id', establishment_id)\
                .execute()
            
            is_australian = False
            use_standard_year = None
            if est_query.data and len(est_query.data) > 0:
                is_australian = est_query.data[0].get('is_australian', False)
                use_standard_year = est_query.data[0].get('use_standard_year')
            
            # Calculate academic year based on today's date
            today = datetime.now()
            
            # Priority: use_standard_year overrides is_australian
            if use_standard_year is None or use_standard_year == True:
                # Use UK calculation
                academic_year = calculate_academic_year_from_date(today, False)
            elif is_australian:
                # Australian calendar year
                academic_year = calculate_academic_year_from_date(today, True)
            else:
                # UK academic year
                academic_year = calculate_academic_year_from_date(today, False)
            
            app.logger.info(f"[Questionnaire V2] Cycle 1 - LOCKING academic year to: {academic_year}")
        else:
            # This is Cycle 2 or 3 - use locked academic year from Cycle 1
            if locked_year_query.data and len(locked_year_query.data) > 0:
                academic_year = locked_year_query.data[0]['academic_year']
                app.logger.info(f"[Questionnaire V2] Cycle {cycle} - Using locked year: {academic_year}")
            else:
                # No Cycle 1 found - shouldn't happen but use provided or calculate
                academic_year = academic_year_provided or calculate_academic_year_from_date(datetime.now())
                app.logger.warning(f"[Questionnaire V2] No Cycle 1 found, using: {academic_year}")
        
        # ========================================
        # STEP 3: WRITE TO SUPABASE
        # ========================================
        
        supabase_success = False
        try:
            # Write question responses
            question_response_rows = []
            for question_id, response_value in responses.items():
                if response_value is not None:
                    question_response_rows.append({
                        'student_id': student_id,
                        'cycle': cycle,
                        'question_id': question_id,
                        'response_value': response_value,
                        'academic_year': academic_year
                    })
            
            if question_response_rows:
                supabase_client.table('question_responses').upsert(
                    question_response_rows,
                    on_conflict='student_id,cycle,academic_year,question_id'
                ).execute()
                app.logger.info(f"[Questionnaire V2] Wrote {len(question_response_rows)} responses to Supabase")
            
            # Write VESPA scores
            vespa_score_row = {
                'student_id': student_id,
                'cycle': cycle,
                'vision': vespa_scores.get('VISION', 0),
                'effort': vespa_scores.get('EFFORT', 0),
                'systems': vespa_scores.get('SYSTEMS', 0),
                'practice': vespa_scores.get('PRACTICE', 0),
                'attitude': vespa_scores.get('ATTITUDE', 0),
                'overall': vespa_scores.get('OVERALL', 0),
                'completion_date': datetime.now().strftime('%Y-%m-%d'),
                'academic_year': academic_year
            }
            
            supabase_client.table('vespa_scores').upsert(
                vespa_score_row,
                on_conflict='student_id,cycle,academic_year'
            ).execute()
            
            app.logger.info(f"[Questionnaire V2] Wrote VESPA scores to Supabase")
            supabase_success = True
            
        except Exception as e:
            app.logger.error(f"[Questionnaire V2] Supabase write error: {e}")
            # Continue to Knack write even if Supabase fails
        
        # ========================================
        # STEP 4: DUAL-WRITE TO KNACK
        # ========================================
        
        knack_success = False
        try:
            if not knack_record_id:
                app.logger.error("[Questionnaire V2] No Knack record ID provided")
                return jsonify({
                    'error': 'Missing Knack record ID'
                }), 400
            
            # Prepare Object_29 update (question responses)
            object_29_update = {}
            
            for question_id, response_value in responses.items():
                if question_id in KNACK_FIELD_MAPPING:
                    fields = KNACK_FIELD_MAPPING[question_id]
                    
                    # Write to CURRENT field
                    object_29_update[fields['current']] = response_value
                    
                    # Write to HISTORICAL field based on cycle
                    cycle_key = f'cycle{cycle}'
                    if cycle_key in fields:
                        object_29_update[fields[cycle_key]] = response_value
            
            # Update cycle field (field_863)
            object_29_update['field_863'] = str(cycle)
            
            app.logger.info(f"[Questionnaire V2] Updating Object_29 with {len(object_29_update)} fields")
            
            # Find Object_29 record connected to this Object_10
            # Object_29 is connected via field_792 to Object_10
            object_29_search = requests.get(
                'https://api.knack.com/v1/objects/object_29/records',
                headers=headers,
                params={
                    'filters': json.dumps({
                        'match': 'and',
                        'rules': [{
                            'field': 'field_792',
                            'operator': 'is',
                            'value': knack_record_id
                        }]
                    })
                },
                timeout=30
            )
            
            if object_29_search.status_code == 200 and object_29_search.json().get('records'):
                object_29_id = object_29_search.json()['records'][0]['id']
                
                # Update Object_29
                object_29_response = requests.put(
                    f'https://api.knack.com/v1/objects/object_29/records/{object_29_id}',
                    headers=headers,
                    json=object_29_update,
                    timeout=30
                )
                
                if object_29_response.status_code == 200:
                    app.logger.info("[Questionnaire V2] Updated Object_29 successfully")
                else:
                    app.logger.error(f"[Questionnaire V2] Object_29 update failed: {object_29_response.text}")
            
            # Prepare Object_10 update (VESPA scores)
            object_10_update = {}
            
            # Write to CURRENT fields (field_147-152)
            object_10_update['field_147'] = vespa_scores.get('VISION', 0)
            object_10_update['field_148'] = vespa_scores.get('EFFORT', 0)
            object_10_update['field_149'] = vespa_scores.get('SYSTEMS', 0)
            object_10_update['field_150'] = vespa_scores.get('PRACTICE', 0)
            object_10_update['field_151'] = vespa_scores.get('ATTITUDE', 0)
            object_10_update['field_152'] = vespa_scores.get('OVERALL', 0)
            
            # Write to HISTORICAL fields based on cycle
            cycle_fields = VESPA_SCORE_FIELDS[f'cycle{cycle}']
            object_10_update[cycle_fields['vision']] = vespa_scores.get('VISION', 0)
            object_10_update[cycle_fields['effort']] = vespa_scores.get('EFFORT', 0)
            object_10_update[cycle_fields['systems']] = vespa_scores.get('SYSTEMS', 0)
            object_10_update[cycle_fields['practice']] = vespa_scores.get('PRACTICE', 0)
            object_10_update[cycle_fields['attitude']] = vespa_scores.get('ATTITUDE', 0)
            object_10_update[cycle_fields['overall']] = vespa_scores.get('OVERALL', 0)
            
            # Update currentMCycle (field_146)
            object_10_update['field_146'] = str(cycle)
            
            # Update completion date (field_855)
            object_10_update['field_855'] = datetime.now().strftime('%d/%m/%Y')
            
            app.logger.info(f"[Questionnaire V2] Updating Object_10 with {len(object_10_update)} fields")
            
            # Update Object_10
            object_10_response = requests.put(
                f'https://api.knack.com/v1/objects/object_10/records/{knack_record_id}',
                headers=headers,
                json=object_10_update,
                timeout=30
            )
            
            if object_10_response.status_code == 200:
                app.logger.info("[Questionnaire V2] Updated Object_10 successfully")
                knack_success = True
            else:
                app.logger.error(f"[Questionnaire V2] Object_10 update failed: {object_10_response.text}")
        
        except Exception as e:
            app.logger.error(f"[Questionnaire V2] Knack write error: {e}")
            # Continue even if Knack fails - Supabase is source of truth
        
        # ========================================
        # RETURN SUCCESS
        # ========================================
        
        return jsonify({
            'success': True,
            'supabaseWritten': supabase_success,
            'knackWritten': knack_success,
            'scores': vespa_scores,
            'academicYear': academic_year,
            'cycle': cycle,
            'message': 'Questionnaire submitted successfully' if (supabase_success or knack_success) else 'Partial success - some writes failed'
        })
        
    except Exception as e:
        app.logger.error(f"[Questionnaire V2] Submission error: {e}")
        return jsonify({
            'error': 'Failed to submit questionnaire',
            'message': str(e)
        }), 500

# ========================================
# HELPER: GET STUDENT STATUS (Optional)
# ========================================

@app.route('/api/vespa/questionnaire/status', methods=['GET'])
def get_questionnaire_status():
    """
    Get student's current questionnaire status
    Uses the student_questionnaire_status view in Supabase
    """
    try:
        email = request.args.get('email')
        
        if not email:
            return jsonify({'error': 'Email is required'}), 400
        
        # Find student in Supabase
        student = supabase_client.table('students')\
            .select('id')\
            .eq('email', email)\
            .limit(1)\
            .execute()
        
        if not student.data:
            return jsonify({
                'found': False,
                'message': 'No student record found'
            })
        
        student_id = student.data[0]['id']
        
        # Get status from view
        status = supabase_client.table('student_questionnaire_status')\
            .select('*')\
            .eq('student_id', student_id)\
            .execute()
        
        if status.data:
            return jsonify({
                'found': True,
                'status': status.data[0]
            })
        else:
            return jsonify({
                'found': False,
                'message': 'No status data found'
            })
        
    except Exception as e:
        app.logger.error(f"[Questionnaire V2] Status check error: {e}")
        return jsonify({'error': str(e)}), 500

