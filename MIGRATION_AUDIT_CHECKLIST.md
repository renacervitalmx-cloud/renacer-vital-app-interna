# 📋 CORRECTED Migration Audit Checklist - Renacer Vital SOAP v2

## Overview

This checklist guides you through a safe, non-destructive migration of SOAP notes from v1 to v2.

**Key Changes from Previous Version:**
- ✅ Pre-audit no longer queries `soap_notes_v2` (doesn't exist yet)
- ✅ Post-creation audit verifies tables before migration
- ✅ Quick status check uses separate COUNT queries (no CROSS JOIN)
- ✅ Proper count metrics: source, target, migrated, failed, pending
- ✅ No false PASS if tables don't exist

---

## Phase 0: PRE-MIGRATION AUDIT (001_pre_migration_audit.sql)

Run this **BEFORE** any migration code.

### Audit 1: Source Table Verification
- [ ] `soap_notes` exists
- [ ] Record count baseline established
- [ ] Required columns present

**Action:** Run `001_pre_migration_audit.sql` - "AUDIT 1" section

---

### Audit 2: Foreign Key Tables
- [ ] `patients` table exists with data
- [ ] `sessions` table exists with data
- [ ] `profiles` table exists with data

**Action:** Run `001_pre_migration_audit.sql` - "AUDIT 2" section

---

### Audit 3: Data Integrity
- [ ] No orphaned `patient_id` references
- [ ] No orphaned `session_id` references
- [ ] No orphaned `therapist_id` references
- [ ] No orphaned `created_by` references

**Expected:** All orphaned counts = 0

**Action:** Run `001_pre_migration_audit.sql` - "AUDIT 3" section

---

### Audit 4: UUID Generation
- [ ] `gen_random_uuid()` function works
- [ ] Correct format (UUID v4 standard)
- [ ] 1000 generated UUIDs all unique

**Expected:** 
- No errors
- Format valid: TRUE
- All 1000 unique: TRUE

**Action:** Run `001_pre_migration_audit.sql` - "AUDIT 4" section

---

### Audit 5: Enum Creation (Idempotent)
- [ ] `patient_status_enum` can be created
- [ ] Safe to create multiple times
- [ ] All 5 values present: active, follow_up, at_risk, inactive, discharged

**Expected:**
- "successfully created" OR "already exists - SAFE TO RETRY"

**Action:** Run `001_pre_migration_audit.sql` - "AUDIT 5" section

---

### Audit 6: RLS Configuration
- [ ] RLS enabled on `soap_notes`
- [ ] Policies exist

**Action:** Run `001_pre_migration_audit.sql` - "AUDIT 6" section

---

### Audit 7: Therapist Role
- [ ] `therapist` role exists
- [ ] Therapists have created SOAP notes

**Action:** Run `001_pre_migration_audit.sql` - "AUDIT 7" section

---

### Audit 8: Reception Role
- [ ] `reception` role exists
- [ ] Reception has NOT created SOAP notes

**Expected:** Reception SOAP creators = 0

**Action:** Run `001_pre_migration_audit.sql` - "AUDIT 8" section

---

### Audit 9: Data Quality
- [ ] No NULL in critical fields
- [ ] All records have creators

**Action:** Run `001_pre_migration_audit.sql` - "AUDIT 9" section

---

### Audit 10: Session ID Uniqueness
- [ ] All `session_id` are unique in source
- [ ] No duplicates exist
- [ ] 1:1 mapping is intact

**Expected:** total_records = unique_sessions

**Action:** Run `001_pre_migration_audit.sql` - "AUDIT 10" section

---

## ✅ Pre-Migration Complete

If all audits PASS:
- Proceed to MIGRATION_GUIDE.md Phase 1

If any audit FAILS:
- STOP and investigate
- Do not proceed to migration

---

## Phase 1: POST-TABLE CREATION AUDIT (002_post_creation_audit.sql)

Run this **AFTER** running MIGRATION_GUIDE.md Phases 1-7.

Do NOT run data migration function yet.

### Check: Tables Created
- [ ] `soap_notes_v2` exists
- [ ] `soap_notes_v2` is empty (0 records)
- [ ] All required columns present

**Action:** Run `002_post_creation_audit.sql` - "POST-CREATION AUDIT: Table Structure"

---

### Check: Migration Tracking
- [ ] `migration_tracking` table exists
- [ ] All steps completed

**Action:** Run `002_post_creation_audit.sql` - "POST-CREATION AUDIT: Migration Tracking"

---

### Check: Wellbeing History
- [ ] `wellbeing_history` table created
- [ ] Currently empty

**Action:** Run `002_post_creation_audit.sql` - "POST-CREATION AUDIT: Wellbeing History"

---

### Check: Enums
- [ ] `patient_status_enum` exists
- [ ] All 5 values present

**Action:** Run `002_post_creation_audit.sql` - "POST-CREATION AUDIT: Enum Verification"

---

### Check: Indexes
- [ ] Indexes created (8+)
- [ ] Named properly

**Action:** Run `002_post_creation_audit.sql` - "POST-CREATION AUDIT: Index Creation"

---

### Check: RLS Policies
- [ ] RLS enabled
- [ ] 4+ policies created
- [ ] All expected policies listed

**Action:** Run `002_post_creation_audit.sql` - "POST-CREATION AUDIT: RLS Policies"

---

### Check: Triggers
- [ ] Triggers created (2+)
- [ ] Trend calculation trigger
- [ ] Wellbeing history trigger

**Action:** Run `002_post_creation_audit.sql` - "POST-CREATION AUDIT: Triggers"

---

### Check: Functions
- [ ] `migrate_soap_notes_safely()` exists
- [ ] `rollback_soap_notes_migration()` exists

**Action:** Run `002_post_creation_audit.sql` - "POST-CREATION AUDIT: Migration Function"

---

### Check: Constraints
- [ ] Foreign key constraints defined
- [ ] Check constraints defined

**Action:** Run `002_post_creation_audit.sql` - "POST-CREATION AUDIT: FK/Check Constraints"

---

## ✅ Post-Creation Complete

If all checks PASS:
- Proceed to MIGRATION_GUIDE.md Phase 8A

If any check FAILS:
- STOP - Review MIGRATION_GUIDE.md Phases 1-7
- Check migration_tracking table for errors
- Do not proceed to data migration

---

## Phase 2: DATA MIGRATION EXECUTION

Run MIGRATION_GUIDE.md Phase 8B:

```sql
SELECT * FROM migrate_soap_notes_safely();
```

Record the results:
- `migrated_count`: _____
- `failed_count`: _____
- `total_records`: _____

---

## Phase 3: POST-MIGRATION VALIDATION (002_post_migration_validation.sql)

Run this **AFTER** migration function completes.

This file has 7 major validation sections. Run entire file.

### Expected Results:

#### Section 1: Table Structure
- Source `soap_notes`: ✓ PASS
- Target `soap_notes_v2`: ✓ PASS
- No NULL violations: ✓ PASS

#### Section 2: Migration Accuracy
- Patient counts match: ✓ PASS
- Therapist counts match: ✓ PASS

#### Section 3: Foreign Keys
- All FK checks: ✓ PASS (0 orphaned)

#### Section 4: Data Integrity
- Wellbeing scores valid: ✓ PASS
- Pain level valid: ✓ PASS
- Overall score calculated: ✓ PASS

#### Section 5: Uniqueness
- Session ID uniqueness: ✓ PASS
- No duplicates: ✓ PASS

#### Section 6: RLS Policies
- Policies present: ✓ PASS (4+)

#### Section 7: Data Quality
- Status distribution shown
- Acknowledgment status shown
- Signature status shown

---

## Phase 4: QUICK STATUS CHECK (003_quick_status_check.sql)

Run this **FINAL** verification:

```sql
-- Copy entire file and execute in Supabase SQL Editor
```

### Expected Output Format:

```
═══════════════════════════════════════════
         MIGRATION AUDIT STATUS REPORT
═══════════════════════════════════════════

SOURCE TABLE (soap_notes): X records
TARGET TABLE (soap_notes_v2): X records
MIGRATION LOG - Successful: X records
MIGRATION LOG - Failed: 0 records
PENDING REVIEW: X records (placeholder feedback)
SUCCESSFULLY UPDATED: X records (custom feedback)

═ DATA INTEGRITY CHECKS ═
✓ PASS - Patient FK Integrity: All records valid
✓ PASS - Session FK Integrity: All records valid
✓ PASS - Therapist FK Integrity: All records valid
✓ PASS - Required Fields: All populated
✓ PASS - Wellbeing Scores: All in valid range (1-10)
✓ PASS - Pain Level: All in valid range (0-10)
✓ PASS - Session ID Uniqueness: No duplicates

═ RLS & SECURITY CHECKS ═
✓ PASS - RLS Policies: 4 policies enabled

═══════════════════════════════════════════
✓✓✓ APPROVED FOR APPLICATION SWITCH ✓✓✓
═══════════════════════════════════════════
```

### Approval Criteria:

✅ Ready if:
- All checks show: ✓ PASS
- No ✗ FAIL items
- Final status: APPROVED FOR APPLICATION SWITCH

❌ NOT ready if:
- Any check shows: ✗ FAIL
- Migration log has failures
- FK integrity issues
- Any count shows 0 when expecting > 0

---

## Count Metrics Explained

The quick status check provides:

```
SOURCE TABLE (soap_notes): 42 records
  └─ Total records in original table

TARGET TABLE (soap_notes_v2): 42 records
  └─ Total records migrated to new table

MIGRATION LOG - Successful: 40 records
  └─ Records migrated without errors (if tracking enabled)

MIGRATION LOG - Failed: 0 records
  └─ Records that failed migration

PENDING REVIEW: 2 records
  └─ Records with placeholder feedback "MIGRATED:"
  └─ These need therapist to update feedback

SUCCESSFULLY UPDATED: 40 records
  └─ Records with actual feedback (not placeholder)
```

---

## Troubleshooting

### Issue: MIGRATION LOG tables not found
**Reason:** Not created in Phases 1-7
**Solution:** Verify MIGRATION_GUIDE.md Phase 2 completed

### Issue: Some checks show ✗ FAIL
**Reason:** Data quality or FK issues
**Solution:** 
1. Review failed count in validation output
2. Check migration_tracking table for errors
3. Consider rollback if > 10% failure rate

### Issue: Counts don't match
**Source:** 50 records  
**Target:** 48 records
**Reason:** 2 records failed migration
**Solution:** 
- Check migration_log for errors
- Manual review of missing records
- Decide: retry migration or accept loss

---

## Phase 5: APPLICATION SWITCH (Not SQL)

When all validations PASS:

1. **Update Backend Code**
   ```typescript
   // Change from:
   const table = 'soap_notes';
   
   // To:
   const table = 'soap_notes_v2';
   ```

2. **Test in Staging**
   - Create test SOAP note
   - Verify reads
   - Verify writes

3. **Production Deployment**
   - Schedule maintenance window
   - Deploy updated code
   - Monitor error logs for 24 hours

4. **Monitoring**
   - Watch for 404/500 errors
   - Check response times
   - Monitor RLS policy execution

---

## Phase 6: ROLLBACK (If Needed)

Only if issues arise within 24 hours:

```sql
SELECT * FROM rollback_soap_notes_migration();
```

This:
- Deletes all migrated records from `soap_notes_v2`
- Clears recent `wellbeing_history`
- Preserves `soap_notes` (original data intact)

**Then:**
1. Revert application code to use `soap_notes`
2. Deploy immediately
3. Investigate root cause
4. Plan retry migration

---

## Sign-Off Template

```
Migration Date: ________________
Migrated By: ________________
Approved By: ________________

Pre-Audit Status: [ ] ALL PASS
Post-Creation Status: [ ] ALL PASS
Post-Migration Status: [ ] ALL PASS
Quick Status: [ ] APPROVED FOR SWITCH

Records Migrated: ______ / ______
Failed Records: ______
Success Rate: _____%

Notes:
_____________________________________
_____________________________________

Rollback Available Until: ________________
```

---

## Summary Timeline

| Phase | Task | Duration | Downtime |
|-------|------|----------|----------|
| 0 | Pre-migration audit | 5 min | None |
| 1 | Create tables | 2 min | None |
| 2 | Post-creation audit | 2 min | None |
| 3 | Data migration | 5-10 min | None |
| 4 | Validation | 5 min | None |
| 5 | App switch | 10-30 min | Brief |
| 6 | Monitoring | 24 hours | None |

**Total:** ~30-50 minutes (brief maintenance window for app switch only)

---

## No False PASS Guarantee

This audit package prevents false PASS by:

✅ Checking table existence before querying  
✅ Using separate COUNT queries (no CROSS JOIN)  
✅ Explicit PASS/FAIL status for each check  
✅ Counts comparison (source vs target)  
✅ FK validation with NULL checks  
✅ Format validation for generated UUIDs  
✅ Enum idempotence testing  
✅ RLS policy verification  
✅ Multiple validation stages  

**Result:** Cannot proceed to Phase 5 unless all checks genuinely PASS.

---

**Ready?** Start with Phase 0: `001_pre_migration_audit.sql`
