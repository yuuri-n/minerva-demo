/**
 * LeadMigrationBatch
 * Lead → Account / Contact / Opportunity の移行バッチ。
 * dryRun=true の場合は DML を一切行わずカウントのみ出力する。
 *
 * 制約事項:
 *   Lead.IsConverted は Database.convertLead() 以外では更新不可のため、
 *   代替として Lead.MigrationDone__c (Checkbox) を移行済みフラグとして使用する。
 *
 * 実行方法 (Anonymous Apex):
 *   // Dry-run (カウントのみ)
 *   Database.executeBatch(new LeadMigrationBatch(true), 200);
 *   // 本実行
 *   Database.executeBatch(new LeadMigrationBatch(false), 200);
 */
public class LeadMigrationBatch implements Database.Batchable<SObject>, Database.Stateful {

    public final Boolean dryRun;

    // Stateful accumulators (Database.Stateful によりチャンク間で保持)
    @TestVisible private Integer totalProcessed  = 0;
    @TestVisible private Integer accountsCreated = 0;
    @TestVisible private Integer accountsReused  = 0;
    @TestVisible private Integer contactsCreated = 0;
    @TestVisible private Integer oppsCreated     = 0;
    @TestVisible private Integer brandMatched    = 0;
    @TestVisible private Integer brandDefaulted  = 0;

    // 参照データ (start() でロード)
    private Map<String, Id> brandNameToId       = new Map<String, Id>();
    private Map<String, Id> rtDeveloperNameToId = new Map<String, Id>();
    private Id              defaultRtId;
    private Id              defaultBrandId;

    private static final String  DEFAULT_RT       = 'Minerva_Consumer';
    private static final String  DEFAULT_STAGE    = '未コンタクト';
    private static final Integer CLOSE_DATE_DAYS  = 90;

    // DesiredBrand__c キーワード (小文字) → RecordType DeveloperName
    private static final Map<String, String> BRAND_KW_TO_RT = new Map<String, String>{
        'minerva'  => 'Minerva_Consumer',
        'lhala'    => 'LHALA_Wholesale',
        'lemella'  => 'LEMELLA_Wholesale',
        'flownee'  => 'FLOWNEE_Consumer',
        'ルメラ'   => 'LEMELLA_Wholesale',
        'フラーラ' => 'FLOWNEE_Consumer',
        'fulala'   => 'FLOWNEE_Consumer'
    };

    // Lead.Status → Opportunity.StageName (RecordType 別)
    private static final Map<String, Map<String, String>> RT_STAGE_MAP =
        new Map<String, Map<String, String>>{
            'Minerva_Consumer' => new Map<String, String>{
                '未コンタクト' => '未コンタクト',
                'アプローチ中' => 'アプローチ',
                '見込み'       => '相談'
            },
            'LHALA_Wholesale' => new Map<String, String>{
                '未コンタクト' => '資料請求',
                'アプローチ中' => 'アプローチ',
                '見込み'       => '商談'
            },
            'LEMELLA_Wholesale' => new Map<String, String>{
                '未コンタクト' => '資料請求',
                'アプローチ中' => 'アプローチ',
                '見込み'       => '商談'
            },
            'FLOWNEE_Consumer' => new Map<String, String>{
                '未コンタクト' => '未コンタクト',
                'アプローチ中' => '案内',
                '見込み'       => '相談'
            }
        };

    public LeadMigrationBatch(Boolean dryRun) {
        this.dryRun = dryRun;
    }

    // -----------------------------------------------------------------------
    public Database.QueryLocator start(Database.BatchableContext bc) {
        loadReferenceData();
        System.debug('=== LeadMigrationBatch ' + (dryRun ? '[DRY-RUN]' : '[LIVE]') + ' start ===');
        return Database.getQueryLocator([
            SELECT Id, LastName, FirstName, Email, Phone, Status,
                   DesiredBrand__c,
                   LastApproachDate__c, LastApproachMethod__c, LastApproachBy__c,
                   BusinessStatus__c, InquiryCategory__c, InquiryDate__c,
                   InquiryExternalId__c, InquiryMessage__c,
                   InquirySource__c, ResponsePreference__c, ContactMethod__c
            FROM Lead
            WHERE IsConverted = false AND MigrationDone__c = false
            ORDER BY Email ASC NULLS LAST
        ]);
    }

    private void loadReferenceData() {
        for (Brand__c b : [SELECT Id, Name FROM Brand__c]) {
            brandNameToId.put(b.Name.toLowerCase(), b.Id);
        }
        for (RecordType rt : [SELECT Id, DeveloperName
                               FROM RecordType
                               WHERE SObjectType = 'Opportunity']) {
            rtDeveloperNameToId.put(rt.DeveloperName, rt.Id);
        }
        defaultRtId    = rtDeveloperNameToId.get(DEFAULT_RT);
        defaultBrandId = brandNameToId.get('minerva');
    }

    // -----------------------------------------------------------------------
    public void execute(Database.BatchableContext bc, List<Lead> scope) {

        // --- 1. このチャンク内のユニークメールを収集 ---
        Set<String> emailSet = new Set<String>();
        for (Lead l : scope) {
            if (String.isNotBlank(l.Email)) emailSet.add(l.Email.toLowerCase());
        }

        // --- 2. 既存 Account を PrimaryEmail__c で検索 ---
        Map<String, Account> emailToAcc = new Map<String, Account>();
        for (Account acc : [SELECT Id, PrimaryEmail__c
                             FROM Account
                             WHERE PrimaryEmail__c IN :emailSet]) {
            emailToAcc.put(acc.PrimaryEmail__c.toLowerCase(), acc);
        }

        // --- 3. 新規作成する Account を決定 (メール重複は1件に集約) ---
        Map<String, Account> newEmailToAcc = new Map<String, Account>();
        Map<Id, Account>     noEmailAccMap = new Map<Id, Account>();

        for (Lead l : scope) {
            totalProcessed++;
            String em = String.isNotBlank(l.Email) ? l.Email.toLowerCase() : null;

            if (em != null) {
                if (!emailToAcc.containsKey(em) && !newEmailToAcc.containsKey(em)) {
                    newEmailToAcc.put(em, buildAccount(l));
                    accountsCreated++;
                } else if (emailToAcc.containsKey(em)) {
                    accountsReused++;
                } else {
                    accountsReused++; // 同チャンク内で先に登場済み
                }
            } else {
                // Email なし: Lead ごとに別 Account
                noEmailAccMap.put(l.Id, buildAccount(l));
                accountsCreated++;
            }

            // ブランド統計
            if (resolveBrandId(l.DesiredBrand__c) != defaultBrandId) brandMatched++;
            else brandDefaulted++;
        }

        // --- 4. DML (dryRun=false のみ) ---
        if (!dryRun) {
            if (!newEmailToAcc.isEmpty()) insert newEmailToAcc.values();
            if (!noEmailAccMap.isEmpty()) insert noEmailAccMap.values();
            emailToAcc.putAll(newEmailToAcc);

            List<Contact>     contacts = new List<Contact>();
            List<Opportunity> opps     = new List<Opportunity>();
            List<Lead>        toUpdate = new List<Lead>();

            for (Lead l : scope) {
                String em  = String.isNotBlank(l.Email) ? l.Email.toLowerCase() : null;
                Account acc = em != null ? emailToAcc.get(em) : noEmailAccMap.get(l.Id);
                if (acc == null) continue;
                Id accountId = acc.Id;

                String rtDev   = resolveRtDeveloperName(l.DesiredBrand__c);
                Id     rtId    = rtDeveloperNameToId.get(rtDev);
                Id     brandId = resolveBrandId(l.DesiredBrand__c);
                String stage   = resolveStage(l.Status, rtDev);

                contacts.add(buildContact(l, accountId));
                opps.add(buildOpportunity(l, accountId, rtId, brandId, stage));
                toUpdate.add(new Lead(Id = l.Id, MigrationDone__c = true));
                contactsCreated++;
                oppsCreated++;
            }

            // 移行バッチのため重複ルールを回避して挿入
            Database.DmlOptions dmlOpts = new Database.DmlOptions();
            dmlOpts.DuplicateRuleHeader.AllowSave = true;
            if (!contacts.isEmpty()) Database.insert(contacts, dmlOpts);
            if (!opps.isEmpty())     Database.insert(opps, dmlOpts);
            if (!toUpdate.isEmpty()) update toUpdate;
        }
    }

    // -----------------------------------------------------------------------
    public void finish(Database.BatchableContext bc) {
        String mode = dryRun ? '[DRY-RUN]' : '[LIVE]';
        System.debug('');
        System.debug('===================================================');
        System.debug('LeadMigrationBatch ' + mode + ' COMPLETE');
        System.debug('===================================================');
        System.debug('Total Leads Processed    : ' + totalProcessed);
        System.debug('Accounts Reused          : ' + accountsReused);
        System.debug('Accounts Created         : ' + accountsCreated);
        System.debug('Contacts Created         : ' + contactsCreated);
        System.debug('Opportunities Created    : ' + oppsCreated);
        System.debug('Brand Matched            : ' + brandMatched);
        System.debug('Brand Defaulted (Minerva): ' + brandDefaulted);
        System.debug('===================================================');
    }

    // -----------------------------------------------------------------------
    // Builders
    // -----------------------------------------------------------------------

    private Account buildAccount(Lead l) {
        String name = (String.isNotBlank(l.LastName)  ? l.LastName  : '') +
                      (String.isNotBlank(l.FirstName) ? l.FirstName : '');
        if (String.isBlank(name)) name = '（不明）';
        return new Account(Name = name, PrimaryEmail__c = l.Email);
    }

    private Contact buildContact(Lead l, Id accountId) {
        return new Contact(
            LastName  = String.isNotBlank(l.LastName) ? l.LastName : '（不明）',
            FirstName = l.FirstName,
            Email     = l.Email,
            Phone     = l.Phone,
            AccountId = accountId
        );
    }

    private Opportunity buildOpportunity(
        Lead l, Id accountId, Id rtId, Id brandId, String stageName
    ) {
        String name = (String.isNotBlank(l.LastName)  ? l.LastName  : '') +
                      (String.isNotBlank(l.FirstName) ? l.FirstName : '') + ' 商談';
        Opportunity opp = new Opportunity(
            Name          = name,
            AccountId     = accountId,
            RecordTypeId  = rtId,
            Brand__c      = brandId,
            StageName     = stageName,
            CloseDate     = Date.today().addDays(CLOSE_DATE_DAYS),
            // Lead → Opportunity 既存同名フィールドの引き継ぎ
            LastApproachDate__c   = l.LastApproachDate__c,
            LastApproachMethod__c = l.LastApproachMethod__c,
            LastApproachBy__c     = l.LastApproachBy__c,
            // Lead → Opportunity 新規追加 8項目の引き継ぎ (Step 3 で有効化)
            BusinessStatus__c     = l.BusinessStatus__c,
            InquiryCategory__c    = l.InquiryCategory__c,
            InquiryDate__c        = l.InquiryDate__c,
            InquiryExternalId__c  = l.InquiryExternalId__c,
            InquiryMessage__c     = l.InquiryMessage__c,
            InquirySource__c      = l.InquirySource__c,
            ResponsePreference__c = l.ResponsePreference__c,
            ContactMethod__c      = l.ContactMethod__c
        );
        return opp;
    }

    // -----------------------------------------------------------------------
    // Resolution helpers
    // -----------------------------------------------------------------------

    @TestVisible
    private String resolveRtDeveloperName(String desiredBrand) {
        if (String.isBlank(desiredBrand)) return DEFAULT_RT;
        String lower = desiredBrand.trim().toLowerCase();
        if (lower == '未定' || lower == 'テスト') return DEFAULT_RT;
        for (String kw : BRAND_KW_TO_RT.keySet()) {
            if (lower.contains(kw.toLowerCase())) return BRAND_KW_TO_RT.get(kw);
        }
        return DEFAULT_RT;
    }

    @TestVisible
    private Id resolveBrandId(String desiredBrand) {
        if (String.isBlank(desiredBrand)) return defaultBrandId;
        String lower = desiredBrand.trim().toLowerCase();
        if (lower == '未定' || lower == 'テスト') return defaultBrandId;
        // 完全一致
        if (brandNameToId.containsKey(lower)) return brandNameToId.get(lower);
        // 部分一致 (誤検知防止のため3文字以上のキーのみ)
        for (String key : brandNameToId.keySet()) {
            if (key.length() >= 3 && lower.contains(key)) return brandNameToId.get(key);
        }
        return defaultBrandId;
    }

    @TestVisible
    private String resolveStage(String status, String rtDev) {
        Map<String, String> stageMap = RT_STAGE_MAP.get(rtDev);
        if (stageMap == null || String.isBlank(status)) return DEFAULT_STAGE;
        String mapped = stageMap.get(status);
        return mapped != null ? mapped : DEFAULT_STAGE;
    }
}
