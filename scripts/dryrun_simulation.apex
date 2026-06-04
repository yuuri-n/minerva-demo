// LeadMigrationBatch - 100件 Dry-run シミュレーション (同期・DMLなし)
// sf apex run --file scripts/dryrun_simulation.apex -o minerva-demo

// ---- 参照データ読み込み ----
Map<String, Id> brandNameToId = new Map<String, Id>();
Map<String, Id> rtDevNameToId = new Map<String, Id>();
for (Brand__c b : [SELECT Id, Name FROM Brand__c]) {
    brandNameToId.put(b.Name.toLowerCase(), b.Id);
}
for (RecordType rt : [SELECT Id, DeveloperName FROM RecordType
                       WHERE SObjectType = 'Opportunity']) {
    rtDevNameToId.put(rt.DeveloperName, rt.Id);
}
Id defaultBrandId = brandNameToId.get('minerva');
String DEFAULT_RT  = 'Minerva_Consumer';

Map<String, String> brandKwToRt = new Map<String, String>{
    'minerva' => 'Minerva_Consumer',
    'lhala'   => 'LHALA_Wholesale',
    'lemella' => 'LEMELLA_Wholesale',
    'flownee' => 'FLOWNEE_Consumer',
    'ルメラ'  => 'LEMELLA_Wholesale',
    'フラーラ'=> 'FLOWNEE_Consumer',
    'fulala'  => 'FLOWNEE_Consumer'
};

Map<String, Map<String, String>> rtStageMap = new Map<String, Map<String, String>>{
    'Minerva_Consumer'  => new Map<String, String>{
        '未コンタクト' => '未コンタクト', 'アプローチ中' => 'アプローチ', '見込み' => '相談'},
    'LHALA_Wholesale'   => new Map<String, String>{
        '未コンタクト' => '資料請求',    'アプローチ中' => 'アプローチ', '見込み' => '商談'},
    'LEMELLA_Wholesale' => new Map<String, String>{
        '未コンタクト' => '資料請求',    'アプローチ中' => 'アプローチ', '見込み' => '商談'},
    'FLOWNEE_Consumer'  => new Map<String, String>{
        '未コンタクト' => '未コンタクト','アプローチ中' => '案内',       '見込み' => '相談'}
};

// ---- 対象 Lead 100件取得 ----
List<Lead> leads = [
    SELECT Id, LastName, FirstName, Email, Status, DesiredBrand__c,
           BusinessStatus__c, InquiryCategory__c, InquiryDate__c,
           InquiryExternalId__c, InquiryMessage__c,
           InquirySource__c, ResponsePreference__c, ContactMethod__c,
           LastApproachDate__c, LastApproachMethod__c
    FROM Lead
    WHERE IsConverted = false AND MigrationDone__c = false
    ORDER BY Email ASC NULLS LAST
    LIMIT 100
];

// 既存 Account (PrimaryEmail__c) を先引き
Set<String> emailSet = new Set<String>();
for (Lead l : leads) {
    if (String.isNotBlank(l.Email)) emailSet.add(l.Email.toLowerCase());
}
Map<String, Id> existingAccByEmail = new Map<String, Id>();
for (Account acc : [SELECT Id, PrimaryEmail__c FROM Account
                    WHERE PrimaryEmail__c IN :emailSet]) {
    existingAccByEmail.put(acc.PrimaryEmail__c.toLowerCase(), acc.Id);
}

// ---- シミュレーション集計 ----
Integer total = 0, accNew = 0, accReused = 0;
Integer brandMatched = 0, brandDefaulted = 0, emailNull = 0;
Map<String, Integer> rtDist    = new Map<String, Integer>();
Map<String, Integer> stageDist = new Map<String, Integer>();
Map<String, Integer> statusDist= new Map<String, Integer>();
Map<String, Integer> srcDist   = new Map<String, Integer>();
Set<String> newEmailsSeen = new Set<String>();
List<String> samples = new List<String>();

for (Lead l : leads) {
    total++;

    // Account 判定
    String em = String.isNotBlank(l.Email) ? l.Email.toLowerCase() : null;
    if (em == null) {
        emailNull++; accNew++;
    } else if (existingAccByEmail.containsKey(em)) {
        accReused++;
    } else if (newEmailsSeen.contains(em)) {
        accReused++;
    } else {
        accNew++;
        newEmailsSeen.add(em);
    }

    // Status 分布
    String st = String.isNotBlank(l.Status) ? l.Status : '（未設定）';
    statusDist.put(st, (statusDist.containsKey(st) ? statusDist.get(st) : 0) + 1);

    // 流入経路分布
    String src = String.isNotBlank(l.InquirySource__c) ? l.InquirySource__c : '（未設定）';
    srcDist.put(src, (srcDist.containsKey(src) ? srcDist.get(src) : 0) + 1);

    // Brand/RT 解決
    String lower  = String.isNotBlank(l.DesiredBrand__c) ? l.DesiredBrand__c.trim().toLowerCase() : '';
    String rtDev  = DEFAULT_RT;
    Boolean hit   = false;
    if (String.isNotBlank(lower) && lower != '未定' && lower != 'テスト') {
        for (String kw : brandKwToRt.keySet()) {
            if (lower.contains(kw.toLowerCase())) { rtDev = brandKwToRt.get(kw); hit = true; break; }
        }
    }
    if (hit) brandMatched++; else brandDefaulted++;
    rtDist.put(rtDev, (rtDist.containsKey(rtDev) ? rtDist.get(rtDev) : 0) + 1);

    // Stage 解決
    String stage = '未コンタクト';
    Map<String, String> sm = rtStageMap.get(rtDev);
    if (sm != null && String.isNotBlank(l.Status)) {
        String ms = sm.get(l.Status);
        if (ms != null) stage = ms;
    }
    stageDist.put(stage, (stageDist.containsKey(stage) ? stageDist.get(stage) : 0) + 1);

    // サンプル先頭 5件
    if (samples.size() < 5) {
        String accAction = (em != null && existingAccByEmail.containsKey(em)) ? '既存流用' : '新規作成';
        samples.add(
            '[' + total + '] ' + (l.LastName ?? '') + (l.FirstName ?? '') +
            ' | Email: '  + (l.Email ?? 'null') +
            ' | Account: ' + accAction +
            ' | Status: ' + l.Status +
            ' | Brand入力: ' + (String.isNotBlank(l.DesiredBrand__c) ? l.DesiredBrand__c : 'null') +
            ' → RT: ' + rtDev +
            ' / Stage: ' + stage +
            ' | 流入: ' + (l.InquirySource__c ?? 'null')
        );
    }
}

// ---- 出力 ----
System.debug('');
System.debug('═══════════════════════════════════════════════════════');
System.debug('  LeadMigrationBatch  Dry-run シミュレーション (100件)');
System.debug('═══════════════════════════════════════════════════════');
System.debug('');
System.debug('【基本集計】');
System.debug('  対象 Lead 件数            : ' + total);
System.debug('  Email なし (Account個別作成): ' + emailNull);
System.debug('  → Account 新規作成予定    : ' + accNew);
System.debug('  → Account 既存流用予定    : ' + accReused);
System.debug('  → Contact 新規作成予定    : ' + total + '  (Lead 1件につき1件)');
System.debug('  → Opportunity 新規作成予定: ' + total);
System.debug('');
System.debug('【ブランドマッチング (DesiredBrand__c → Brand__c)】');
System.debug('  キーワード一致 (lhala/lemella/flownee/minerva 等): ' + brandMatched + '件');
System.debug('  デフォルト割当 (Minerva_Consumer)                : ' + brandDefaulted + '件');
System.debug('');
System.debug('【RecordType 分布 (Opportunity)】');
for (String rt : new List<String>(rtDist.keySet())) {
    System.debug('  ' + rt + ': ' + rtDist.get(rt) + '件');
}
System.debug('');
System.debug('【Lead.Status 分布】');
for (String s : new List<String>(statusDist.keySet())) {
    System.debug('  ' + s + ': ' + statusDist.get(s) + '件');
}
System.debug('');
System.debug('【Opportunity.StageName 分布 (移行後)】');
for (String st : new List<String>(stageDist.keySet())) {
    System.debug('  ' + st + ': ' + stageDist.get(st) + '件');
}
System.debug('');
System.debug('【Lead.InquirySource__c (流入経路) 分布】');
for (String src : new List<String>(srcDist.keySet())) {
    System.debug('  ' + src + ': ' + srcDist.get(src) + '件');
}
System.debug('');
System.debug('【サンプルレコード（先頭5件）】');
for (String s : samples) {
    System.debug('  ' + s);
}
System.debug('');
System.debug('※ このスクリプトは DML を実行しません（読み取り専用）');
System.debug('全件本実行: Database.executeBatch(new LeadMigrationBatch(false), 200);');
System.debug('═══════════════════════════════════════════════════════');
