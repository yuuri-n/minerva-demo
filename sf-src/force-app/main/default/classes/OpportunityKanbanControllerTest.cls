@IsTest
private class OpportunityKanbanControllerTest {

    @TestSetup
    static void setup() {
        Account acc = new Account(Name = 'Test Account');
        insert acc;

        Id minervaRtId = Schema.SObjectType.Opportunity
            .getRecordTypeInfosByDeveloperName().get('Minerva_Consumer').getRecordTypeId();
        Id lhalaRtId = Schema.SObjectType.Opportunity
            .getRecordTypeInfosByDeveloperName().get('LHALA_Wholesale').getRecordTypeId();

        insert new List<Opportunity>{
            new Opportunity(
                Name = 'Minerva Opp 1', AccountId = acc.Id,
                StageName = 'アプローチ', CloseDate = Date.today().addDays(30),
                RecordTypeId = minervaRtId
            ),
            new Opportunity(
                Name = 'Minerva Opp 2', AccountId = acc.Id,
                StageName = '相談', CloseDate = Date.today().addDays(60),
                RecordTypeId = minervaRtId
            ),
            new Opportunity(
                Name = 'LHALA Opp 1', AccountId = acc.Id,
                StageName = '商談', CloseDate = Date.today().addDays(30),
                RecordTypeId = lhalaRtId
            )
        };
    }

    @IsTest
    static void testGetOpportunitiesByBrand() {
        Account acc = [SELECT Id FROM Account LIMIT 1];

        Test.startTest();
        List<Opportunity> result = OpportunityKanbanController.getOpportunities(acc.Id, 'Minerva_Consumer');
        Test.stopTest();

        System.assertEquals(2, result.size(), 'Minerva 商談は2件のはず');
        for (Opportunity opp : result) {
            System.assertEquals('Minerva_Consumer', opp.RecordType.DeveloperName);
        }
    }

    @IsTest
    static void testGetOpportunitiesAll() {
        Account acc = [SELECT Id FROM Account LIMIT 1];

        Test.startTest();
        List<Opportunity> resultNull = OpportunityKanbanController.getOpportunities(acc.Id, null);
        List<Opportunity> resultEmpty = OpportunityKanbanController.getOpportunities(acc.Id, '');
        Test.stopTest();

        System.assertEquals(3, resultNull.size(), 'null 指定で全3件のはず');
        System.assertEquals(3, resultEmpty.size(), '空文字指定で全3件のはず');
    }

    @IsTest
    static void testGetOpportunitiesEmpty() {
        Account emptyAcc = new Account(Name = 'Empty Account');
        insert emptyAcc;

        Test.startTest();
        List<Opportunity> result = OpportunityKanbanController.getOpportunities(emptyAcc.Id, 'Minerva_Consumer');
        Test.stopTest();

        System.assertEquals(0, result.size(), '商談なし取引先は0件のはず');
    }

    @IsTest
    static void testUpdateOpportunityStage() {
        Opportunity opp = [SELECT Id, StageName FROM Opportunity WHERE Name = 'Minerva Opp 1' LIMIT 1];
        System.assertEquals('アプローチ', opp.StageName);

        Test.startTest();
        OpportunityKanbanController.updateOpportunityStage(opp.Id, '相談');
        Test.stopTest();

        Opportunity updated = [SELECT StageName FROM Opportunity WHERE Id = :opp.Id];
        System.assertEquals('相談', updated.StageName, 'ステージが更新されているはず');
    }

    @IsTest
    static void testUpdateOpportunityStageBlank() {
        Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];
        Boolean exceptionThrown = false;

        Test.startTest();
        try {
            // 空文字・null はコントローラが AuraHandledException をスロー
            OpportunityKanbanController.updateOpportunityStage(opp.Id, '');
        } catch (AuraHandledException e) {
            exceptionThrown = true;
        }
        Test.stopTest();

        System.assert(exceptionThrown, 'AuraHandledException がスローされるはず');
    }
}
