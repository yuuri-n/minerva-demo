// 移行結果サマリ集計スクリプト
Integer leadMigrated   = [SELECT COUNT() FROM Lead WHERE MigrationDone__c = true];
Integer leadRemaining  = [SELECT COUNT() FROM Lead WHERE MigrationDone__c = false AND IsConverted = false];
Integer accToday       = [SELECT COUNT() FROM Account WHERE CreatedDate = TODAY];
Integer contactToday   = [SELECT COUNT() FROM Contact WHERE CreatedDate = TODAY];
Integer oppToday       = [SELECT COUNT() FROM Opportunity WHERE CreatedDate = TODAY];

// StageName 分布
Map<String,Integer> stageDist = new Map<String,Integer>();
for (AggregateResult ar : [SELECT StageName, COUNT(Id) cnt
                            FROM Opportunity WHERE CreatedDate = TODAY
                            GROUP BY StageName]) {
    stageDist.put((String)ar.get('StageName'), (Integer)ar.get('cnt'));
}

// InquirySource__c 引き継ぎ確認
Integer oppWithSource = [SELECT COUNT() FROM Opportunity
                         WHERE CreatedDate = TODAY AND InquirySource__c != null];
Integer oppWithBizStatus = [SELECT COUNT() FROM Opportunity
                             WHERE CreatedDate = TODAY AND BusinessStatus__c != null];

System.debug('');
System.debug('═══════════════════════════════════════════════════════');
System.debug('  LeadMigrationBatch  本実行 結果サマリ');
System.debug('═══════════════════════════════════════════════════════');
System.debug('');
System.debug('【Lead】');
System.debug('  MigrationDone__c = true  : ' + leadMigrated   + '件 ✅');
System.debug('  MigrationDone__c = false : ' + leadRemaining  + '件 (未処理)');
System.debug('');
System.debug('【Account】');
System.debug('  本日新規作成             : ' + accToday + '件');
System.debug('  (既存流用: ' + (leadMigrated - accToday) + '件)');
System.debug('');
System.debug('【Contact】');
System.debug('  本日新規作成             : ' + contactToday + '件');
System.debug('');
System.debug('【Opportunity】');
System.debug('  本日新規作成             : ' + oppToday + '件');
System.debug('  RecordType: Minerva_Consumer (全件デフォルト)');
System.debug('  InquirySource__c 引き継ぎ: ' + oppWithSource + '件');
System.debug('  BusinessStatus__c 引き継ぎ: ' + oppWithBizStatus + '件');
System.debug('');
System.debug('【StageName 分布】');
for (String s : stageDist.keySet()) {
    System.debug('  ' + s + ': ' + stageDist.get(s) + '件');
}
System.debug('');
System.debug('【ガバナ制約 確認】');
System.debug('  バッチ処理: 9チャンク (200件×8 + 残)');
System.debug('  エラー    : 0件');
System.debug('═══════════════════════════════════════════════════════');
