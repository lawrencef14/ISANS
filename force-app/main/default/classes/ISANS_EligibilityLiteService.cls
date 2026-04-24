/**
 * Data-driven "Eligibility Lite" for demo: rules on ISANS_Program_Eligibility_Rule__c (AND together).
 * See docs/09-demo-eligibility-lite-architecture.md
 */
public with sharing class ISANS_EligibilityLiteService {
    public class RuleResult {
        @AuraEnabled public Id ruleId;
        @AuraEnabled public String ruleType;
        @AuraEnabled public Boolean passed;
        @AuraEnabled public String message;
    }

    public class EvaluationResult {
        @AuraEnabled public Boolean overallPass;
        @AuraEnabled public List<RuleResult> ruleResults;
        @AuraEnabled public String summary;
    }

    public class InvocableInput {
        @InvocableVariable(required=true label='Program Id')
        public Id programId;
        @InvocableVariable(required=true label='Account Id (Person Account recommended)')
        public Id accountId;
    }

    public class InvocableOutput {
        @InvocableVariable(label='Overall Pass')
        public Boolean overallPass;
        @InvocableVariable(label='Summary')
        public String summary;
    }

    @AuraEnabled(cacheable=true)
    public static List<ProgramOption> listProgramsForPicker() {
        List<ProgramOption> out = new List<ProgramOption>();
        for (Program p : [
            SELECT Id, Name
            FROM Program
            WHERE Name LIKE 'ISANS%'
            ORDER BY Name
            LIMIT 50
        ]) {
            out.add(new ProgramOption(p.Id, p.Name));
        }
        if (out.isEmpty()) {
            for (Program p2 : [SELECT Id, Name FROM Program ORDER BY Name LIMIT 50]) {
                out.add(new ProgramOption(p2.Id, p2.Name));
            }
        }
        return out;
    }

    public class ProgramOption {
        @AuraEnabled public String label;
        @AuraEnabled public String value;
        public ProgramOption(Id idVal, String nameVal) {
            this.value = (String) idVal;
            this.label = nameVal;
        }
    }

    @AuraEnabled(cacheable=false)
    public static EvaluationResult evaluate(Id programId, Id accountId) {
        if (programId == null || accountId == null) {
            throw new AuraHandledException('Program and Account are required.');
        }
        return evaluateInternal(programId, accountId);
    }

    @InvocableMethod(
        label='ISANS Eligibility Lite Evaluate'
        description='Runs AND of all active ISANS_Program_Eligibility_Rule__c rows for the program against the Account.'
    )
    public static List<InvocableOutput> evaluateInvocable(List<InvocableInput> inputs) {
        List<InvocableOutput> outs = new List<InvocableOutput>();
        if (inputs == null) {
            return outs;
        }
        for (InvocableInput inRow : inputs) {
            InvocableOutput o = new InvocableOutput();
            if (inRow == null || inRow.programId == null || inRow.accountId == null) {
                o.overallPass = false;
                o.summary = 'Missing programId or accountId.';
            } else {
                EvaluationResult er = evaluateInternal(inRow.programId, inRow.accountId);
                o.overallPass = er.overallPass;
                o.summary = er.summary;
            }
            outs.add(o);
        }
        return outs;
    }

    private static EvaluationResult evaluateInternal(Id programId, Id accountId) {
        List<ISANS_Program_Eligibility_Rule__c> rules = [
            SELECT Id, Rule_Type__c, Threshold_Number__c, Failure_Message__c, Sequence__c
            FROM ISANS_Program_Eligibility_Rule__c
            WHERE Program__c = :programId AND Is_Active__c = TRUE
            ORDER BY Sequence__c ASC NULLS LAST, CreatedDate ASC
        ];

        Account acc = [
            SELECT Id, IsPersonAccount, PersonBirthdate, ISANS_Annual_Household_Income__c
            FROM Account
            WHERE Id = :accountId
            LIMIT 1
        ];

        Integer ageYears = null;
        if (acc.PersonBirthdate != null) {
            ageYears = calculateAgeInWholeYears(acc.PersonBirthdate, Date.today());
        }

        Decimal income = acc.ISANS_Annual_Household_Income__c;

        List<RuleResult> details = new List<RuleResult>();
        Boolean allPass = true;

        if (rules.isEmpty()) {
            allPass = true;
            RuleResult r0 = new RuleResult();
            r0.passed = true;
            r0.message = 'No active rules configured for this program.';
            r0.ruleType = '(none)';
            details.add(r0);
        } else {
            for (ISANS_Program_Eligibility_Rule__c rule : rules) {
                RuleResult rr = new RuleResult();
                rr.ruleId = rule.Id;
                rr.ruleType = rule.Rule_Type__c;
                Boolean pass = evaluateRule(rule.Rule_Type__c, rule.Threshold_Number__c, ageYears, income);
                rr.passed = pass;
                if (!pass) {
                    allPass = false;
                    rr.message = String.isNotBlank(rule.Failure_Message__c)
                        ? rule.Failure_Message__c
                        : defaultFailureMessage(rule.Rule_Type__c);
                } else {
                    rr.message = 'OK';
                }
                details.add(rr);
            }
        }

        EvaluationResult er = new EvaluationResult();
        er.overallPass = allPass;
        er.ruleResults = details;
        er.summary = allPass ? 'Eligible' : 'Not eligible — see rule results.';
        return er;
    }

    @TestVisible
    private static Boolean evaluateRule(String ruleType, Decimal threshold, Integer ageYears, Decimal income) {
        if (ruleType == 'Max_Age_Exclusive') {
            if (ageYears == null) {
                return false;
            }
            return ageYears < threshold.intValue();
        }
        if (ruleType == 'Min_Age_Inclusive') {
            if (ageYears == null) {
                return false;
            }
            return ageYears >= threshold.intValue();
        }
        if (ruleType == 'Max_Annual_Income') {
            if (income == null) {
                return false;
            }
            return income <= threshold;
        }
        return false;
    }

    private static String defaultFailureMessage(String ruleType) {
        if (ruleType == 'Max_Age_Exclusive') {
            return 'Age requirement not met (maximum age exclusive), or birth date missing.';
        }
        if (ruleType == 'Min_Age_Inclusive') {
            return 'Minimum age not met, or birth date missing.';
        }
        if (ruleType == 'Max_Annual_Income') {
            return 'Income above maximum, or annual household income not captured.';
        }
        return 'Rule failed.';
    }

    @TestVisible
    static Integer calculateAgeInWholeYears(Date birthDate, Date asOf) {
        if (birthDate == null || asOf == null) {
            return null;
        }
        Integer age = asOf.year() - birthDate.year();
        if (asOf < birthDate.addYears(age)) {
            age--;
        }
        return age;
    }
}
