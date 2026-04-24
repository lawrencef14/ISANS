@IsTest
private class ISANS_EligibilityLiteServiceTest {
    @IsTest
    static void evaluate_noRules_returnsEligibleWithMessage() {
        Program p = new Program(Name = 'Test Elig Lite Program', StartDate = Date.today(), Status = 'Active');
        insert p;

        Account a = makePersonAccount(Date.newInstance(2015, 6, 1), 40000);

        Test.startTest();
        ISANS_EligibilityLiteService.EvaluationResult r = ISANS_EligibilityLiteService.evaluate(p.Id, a.Id);
        Test.stopTest();

        System.assertEquals(true, r.overallPass, 'No rules => pass');
        System.assertEquals(1, r.ruleResults.size());
    }

    @IsTest
    static void evaluate_maxAgeExclusive_under12_passes() {
        Program p = new Program(Name = 'Test Elig Lite Program 2', StartDate = Date.today(), Status = 'Active');
        insert p;

        insert new ISANS_Program_Eligibility_Rule__c(
            Program__c = p.Id,
            Rule_Type__c = 'Max_Age_Exclusive',
            Threshold_Number__c = 12,
            Sequence__c = 10,
            Is_Active__c = true,
            Failure_Message__c = 'Must be under 12.'
        );

        Account child = makePersonAccount(Date.newInstance(2018, 1, 1), null);

        ISANS_EligibilityLiteService.EvaluationResult r = ISANS_EligibilityLiteService.evaluate(p.Id, child.Id);
        System.assertEquals(true, r.overallPass);
    }

    @IsTest
    static void evaluate_maxAgeExclusive_over12_fails() {
        Program p = new Program(Name = 'Test Elig Lite Program 3', StartDate = Date.today(), Status = 'Active');
        insert p;

        insert new ISANS_Program_Eligibility_Rule__c(
            Program__c = p.Id,
            Rule_Type__c = 'Max_Age_Exclusive',
            Threshold_Number__c = 12,
            Sequence__c = 10,
            Is_Active__c = true,
            Failure_Message__c = 'Must be under 12.'
        );

        Account teen = makePersonAccount(Date.newInstance(2008, 1, 1), null);

        ISANS_EligibilityLiteService.EvaluationResult r = ISANS_EligibilityLiteService.evaluate(p.Id, teen.Id);
        System.assertEquals(false, r.overallPass);
    }

    @IsTest
    static void evaluate_income_and_age_andTogether() {
        Program p = new Program(Name = 'Test Elig Lite Program 4', StartDate = Date.today(), Status = 'Active');
        insert p;

        insert new List<ISANS_Program_Eligibility_Rule__c>{
            new ISANS_Program_Eligibility_Rule__c(
                Program__c = p.Id,
                Rule_Type__c = 'Max_Age_Exclusive',
                Threshold_Number__c = 18,
                Sequence__c = 10,
                Is_Active__c = true,
                Failure_Message__c = 'Under 18 only.'
            ),
            new ISANS_Program_Eligibility_Rule__c(
                Program__c = p.Id,
                Rule_Type__c = 'Max_Annual_Income',
                Threshold_Number__c = 50000,
                Sequence__c = 20,
                Is_Active__c = true,
                Failure_Message__c = 'Income cap 50k.'
            )
        };

        Account ok = makePersonAccount(Date.newInstance(2010, 1, 1), 40000);
        ISANS_EligibilityLiteService.EvaluationResult rOk = ISANS_EligibilityLiteService.evaluate(p.Id, ok.Id);
        System.assertEquals(true, rOk.overallPass);

        Account highIncome = makePersonAccount(Date.newInstance(2010, 1, 1), 90000);
        ISANS_EligibilityLiteService.EvaluationResult rBad = ISANS_EligibilityLiteService.evaluate(p.Id, highIncome.Id);
        System.assertEquals(false, rBad.overallPass);
    }

    @IsTest
    static void calculateAge_helper() {
        Date dob = Date.newInstance(2012, 6, 15);
        Date asOf = Date.newInstance(2026, 6, 14);
        System.assertEquals(13, ISANS_EligibilityLiteService.calculateAgeInWholeYears(dob, asOf));
        Date asOf2 = Date.newInstance(2026, 6, 15);
        System.assertEquals(14, ISANS_EligibilityLiteService.calculateAgeInWholeYears(dob, asOf2));
    }

    private static Account makePersonAccount(Date birthdate, Decimal income) {
        Id personRt;
        for (Schema.RecordTypeInfo rti : Account.SObjectType.getDescribe().getRecordTypeInfos()) {
            if (rti.isAvailable() && rti.getName() == 'Person Account') {
                personRt = rti.getRecordTypeId();
                break;
            }
        }
        if (personRt == null) {
            for (RecordType rt : [SELECT Id FROM RecordType WHERE SObjectType = 'Account' AND IsPersonType = true LIMIT 1]) {
                personRt = rt.Id;
            }
        }
        System.assertNotEquals(null, personRt, 'Person Account record type required in test org.');

        Account a = new Account(
            RecordTypeId = personRt,
            FirstName = 'Test',
            LastName = 'EligLite' + String.valueOf(Crypto.getRandomInteger()),
            PersonBirthdate = birthdate,
            ISANS_Annual_Household_Income__c = income
        );
        insert a;
        return a;
    }
}
