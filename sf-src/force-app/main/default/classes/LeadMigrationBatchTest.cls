@IsTest
private class LeadMigrationBatchTest {

    @TestSetup
    static void setup() {
        Brand__c minerva = new Brand__c(Name = 'Minerva');
        insert minerva;

        // 3件: 2ユニークメール + alpha重複（emailデデュプ検証用）
        insert new List<Lead>{
            new Lead(
                LastName = 'アルファ', FirstName = '太郎', Company = '[個人]',
                Email = 'alpha@test.com', Status = '未コンタクト',
                DesiredBrand__c = 'Minerva'
            ),
            new Lead(
                LastName = 'ベータ', FirstName = '花子', Company = '[個人]',
                Email = 'beta@test.com', Status = 'アプローチ中',
                DesiredBrand__c = '未定'
            ),
            new Lead(
                LastName = 'アルファ', FirstName = '次郎', Company = '[個人]',
                Email = 'alpha@test.com', Status = '未コンタクト',
                DesiredBrand__c = null
            )
        };
    }

    // -----------------------------------------------------------------------
    // Dry-run: DML が一切発生しないことを検証
    // -----------------------------------------------------------------------
    @IsTest
    static void testDryRunDoesNoDml() {
        Test.startTest();
        Database.executeBatch(new LeadMigrationBatch(true), 200);
        Test.stopTest();

        System.assertEquals(0, [SELECT COUNT() FROM Account],
            'Account が作成されてはいけない');
        System.assertEquals(0, [SELECT COUNT() FROM Contact],
            'Contact が作成されてはいけない');
        System.assertEquals(0, [SELECT COUNT() FROM Opportunity],
            'Opportunity が作成されてはいけない');
        System.assertEquals(0,
            [SELECT COUNT() FROM Lead WHERE MigrationDone__c = true],
            'MigrationDone__c が true になってはいけない');
    }

    // -----------------------------------------------------------------------
    // 本実行: 期待件数の Account / Contact / Opportunity が作成される
    // -----------------------------------------------------------------------
    @IsTest
    static void testLiveRunCreatesExpectedRecords() {
        Test.startTest();
        Database.executeBatch(new LeadMigrationBatch(false), 200);
        Test.stopTest();

        System.assertEquals(2,
            [SELECT COUNT() FROM Account
             WHERE PrimaryEmail__c IN ('alpha@test.com', 'beta@test.com')],
            'ユニークメール2件分の Account が作成されるはず');
        System.assertEquals(3, [SELECT COUNT() FROM Contact],     'Contact は3件のはず');
        System.assertEquals(3, [SELECT COUNT() FROM Opportunity], 'Opportunity は3件のはず');
    }

    // -----------------------------------------------------------------------
    // 同一メールの Lead は同一 Account に紐付く
    // -----------------------------------------------------------------------
    @IsTest
    static void testLiveRunAccountDedup() {
        Test.startTest();
        Database.executeBatch(new LeadMigrationBatch(false), 200);
        Test.stopTest();

        Account alphaAcc = [SELECT Id FROM Account WHERE PrimaryEmail__c = 'alpha@test.com'];
        System.assertEquals(2,
            [SELECT COUNT() FROM Opportunity WHERE AccountId = :alphaAcc.Id],
            'alpha@test.com の Lead 2件は同一 Account の Opportunity になるはず');
    }

    // -----------------------------------------------------------------------
    // Opportunity に RecordType / Brand__c / StageName がセットされている
    // -----------------------------------------------------------------------
    @IsTest
    static void testLiveRunOppHasRtAndBrand() {
        Test.startTest();
        Database.executeBatch(new LeadMigrationBatch(false), 200);
        Test.stopTest();

        for (Opportunity opp : [SELECT RecordTypeId, Brand__c, StageName FROM Opportunity]) {
            System.assertNotEquals(null, opp.RecordTypeId, 'RecordTypeId がセットされているはず');
            System.assertNotEquals(null, opp.Brand__c,     'Brand__c がセットされているはず');
            System.assertNotEquals(null, opp.StageName,    'StageName がセットされているはず');
        }
    }

    // -----------------------------------------------------------------------
    // 本実行後、Lead.MigrationDone__c = true になる
    // -----------------------------------------------------------------------
    @IsTest
    static void testLiveRunLeadMarkedMigrated() {
        Test.startTest();
        Database.executeBatch(new LeadMigrationBatch(false), 200);
        Test.stopTest();

        System.assertEquals(3,
            [SELECT COUNT() FROM Lead WHERE MigrationDone__c = true],
            '全 Lead が MigrationDone__c = true になるはず');
    }

    // -----------------------------------------------------------------------
    // resolveRtDeveloperName の単体検証（@TestVisible メソッド）
    // ※ BRAND_KW_TO_RT は static map のため、インスタンス生成のみで動作
    // -----------------------------------------------------------------------
    @IsTest
    static void testResolveRtDeveloperName() {
        LeadMigrationBatch b = new LeadMigrationBatch(true);

        System.assertEquals('Minerva_Consumer',  b.resolveRtDeveloperName(null),          'null → Minerva デフォルト');
        System.assertEquals('Minerva_Consumer',  b.resolveRtDeveloperName('未定'),         '未定 → Minerva デフォルト');
        System.assertEquals('Minerva_Consumer',  b.resolveRtDeveloperName('Minerva'),      'Minerva → Minerva_Consumer');
        System.assertEquals('LHALA_Wholesale',   b.resolveRtDeveloperName('lhala卸売'),    'lhala → LHALA_Wholesale');
        System.assertEquals('LEMELLA_Wholesale', b.resolveRtDeveloperName('lemella'),      'lemella → LEMELLA_Wholesale');
        System.assertEquals('FLOWNEE_Consumer',  b.resolveRtDeveloperName('flownee'),      'flownee → FLOWNEE_Consumer');
        System.assertEquals('Minerva_Consumer',  b.resolveRtDeveloperName('サロン名ABC'),  '不一致 → Minerva デフォルト');
    }

    // -----------------------------------------------------------------------
    // resolveStage の単体検証（@TestVisible メソッド）
    // ※ RT_STAGE_MAP は static map のため、インスタンス生成のみで動作
    // -----------------------------------------------------------------------
    @IsTest
    static void testResolveStage() {
        LeadMigrationBatch b = new LeadMigrationBatch(true);

        System.assertEquals('未コンタクト', b.resolveStage('未コンタクト', 'Minerva_Consumer'));
        System.assertEquals('アプローチ',   b.resolveStage('アプローチ中', 'Minerva_Consumer'));
        System.assertEquals('相談',         b.resolveStage('見込み',       'Minerva_Consumer'));
        System.assertEquals('資料請求',     b.resolveStage('未コンタクト', 'LHALA_Wholesale'));
        System.assertEquals('アプローチ',   b.resolveStage('アプローチ中', 'LHALA_Wholesale'));
        System.assertEquals('未コンタクト', b.resolveStage(null,           'Minerva_Consumer'));
    }
}
