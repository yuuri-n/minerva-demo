@IsTest
private class AccountDedupControllerTest {

    @TestSetup
    static void setup() {
        Id minervaRtId = Schema.SObjectType.Opportunity
            .getRecordTypeInfosByDeveloperName().get('Minerva_Consumer').getRecordTypeId();

        List<Account> accounts = new List<Account>{
            new Account(Name = 'Account Alpha', PrimaryEmail__c = 'same@test.com'),
            new Account(Name = 'Account Beta',  PrimaryEmail__c = 'same@test.com'),
            new Account(Name = 'Account Gamma', PrimaryEmail__c = 'same@test.com'),
            new Account(Name = 'Account Delta', PrimaryEmail__c = 'unique@test.com'),
            new Account(Name = 'Account Epsilon')
        };
        insert accounts;

        insert new List<Opportunity>{
            new Opportunity(
                Name = 'Alpha Opp 1', AccountId = accounts[0].Id, RecordTypeId = minervaRtId,
                StageName = 'アプローチ', CloseDate = Date.today().addDays(30)
            ),
            new Opportunity(
                Name = 'Alpha Opp 2', AccountId = accounts[0].Id, RecordTypeId = minervaRtId,
                StageName = 'アプローチ', CloseDate = Date.today().addDays(30)
            ),
            new Opportunity(
                Name = 'Beta Opp 1', AccountId = accounts[1].Id, RecordTypeId = minervaRtId,
                StageName = 'アプローチ', CloseDate = Date.today().addDays(30)
            )
        };
    }

    @IsTest
    static void testFindDuplicatesFound() {
        Account alpha = [SELECT Id FROM Account WHERE Name = 'Account Alpha' LIMIT 1];

        Test.startTest();
        List<AccountDedupController.DuplicateAccountResult> results =
            AccountDedupController.findDuplicateAccounts(alpha.Id);
        Test.stopTest();

        System.assertEquals(2, results.size(), '同一email×3から自分を除いた2件が返るはず');
        for (AccountDedupController.DuplicateAccountResult r : results) {
            System.assertEquals('same@test.com', r.email, 'メールアドレスが一致するはず');
        }
    }

    @IsTest
    static void testFindDuplicatesUniqueEmail() {
        Account delta = [SELECT Id FROM Account WHERE Name = 'Account Delta' LIMIT 1];

        Test.startTest();
        List<AccountDedupController.DuplicateAccountResult> results =
            AccountDedupController.findDuplicateAccounts(delta.Id);
        Test.stopTest();

        System.assertEquals(0, results.size(), 'ユニークメールは重複なし');
    }

    @IsTest
    static void testFindDuplicatesBlankEmail() {
        Account epsilon = [SELECT Id FROM Account WHERE Name = 'Account Epsilon' LIMIT 1];

        Test.startTest();
        List<AccountDedupController.DuplicateAccountResult> results =
            AccountDedupController.findDuplicateAccounts(epsilon.Id);
        Test.stopTest();

        System.assertEquals(0, results.size(), 'email未設定は0件');
    }

    @IsTest
    static void testMergeOpportunities() {
        Account alpha = [SELECT Id FROM Account WHERE Name = 'Account Alpha' LIMIT 1];
        Account beta  = [SELECT Id FROM Account WHERE Name = 'Account Beta'  LIMIT 1];

        Test.startTest();
        AccountDedupController.mergeOpportunities(beta.Id, alpha.Id);
        Test.stopTest();

        System.assertEquals(0,
            [SELECT Id FROM Opportunity WHERE AccountId = :beta.Id].size(),
            'fromAccountの商談は0件になるはず');
        System.assertEquals(3,
            [SELECT Id FROM Opportunity WHERE AccountId = :alpha.Id].size(),
            'toAccountに全3件集まるはず (2+1)');
    }

    @IsTest
    static void testMergeOpportunitiesNullId() {
        Boolean thrown = false;
        Test.startTest();
        try {
            AccountDedupController.mergeOpportunities(null, null);
        } catch (AuraHandledException e) {
            thrown = true;
        }
        Test.stopTest();
        System.assert(thrown, 'null IDはAuraHandledExceptionがスローされるはず');
    }
}
