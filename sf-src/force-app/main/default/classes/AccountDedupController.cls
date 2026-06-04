public with sharing class AccountDedupController {

    public class DuplicateAccountResult {
        @AuraEnabled public Id accountId;
        @AuraEnabled public String accountName;
        @AuraEnabled public String email;
        @AuraEnabled public Integer oppCount;

        public DuplicateAccountResult(Account acc, Integer cnt) {
            this.accountId = acc.Id;
            this.accountName = acc.Name;
            this.email = acc.PrimaryEmail__c;
            this.oppCount = cnt;
        }
    }

    @AuraEnabled(cacheable=true)
    public static List<DuplicateAccountResult> findDuplicateAccounts(Id accountId) {
        try {
            List<Account> sourceList = [
                SELECT PrimaryEmail__c FROM Account WHERE Id = :accountId LIMIT 1
            ];
            if (sourceList.isEmpty() || String.isBlank(sourceList[0].PrimaryEmail__c)) {
                return new List<DuplicateAccountResult>();
            }
            String email = sourceList[0].PrimaryEmail__c;

            List<Account> dups = [
                SELECT Id, Name, PrimaryEmail__c,
                       (SELECT Id FROM Opportunities LIMIT 200)
                FROM Account
                WHERE PrimaryEmail__c = :email
                  AND Id != :accountId
                ORDER BY Name ASC
                LIMIT 50
            ];

            List<DuplicateAccountResult> results = new List<DuplicateAccountResult>();
            for (Account dup : dups) {
                results.add(new DuplicateAccountResult(dup, dup.Opportunities.size()));
            }
            return results;
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    @AuraEnabled
    public static void mergeOpportunities(Id fromAccountId, Id toAccountId) {
        if (fromAccountId == null || toAccountId == null) {
            throw new AuraHandledException('取引先IDを指定してください');
        }
        try {
            List<Opportunity> opps = [
                SELECT Id FROM Opportunity WHERE AccountId = :fromAccountId
            ];
            for (Opportunity opp : opps) {
                opp.AccountId = toAccountId;
            }
            update opps;
        } catch (DmlException e) {
            throw new AuraHandledException(e.getMessage());
        }
    }
}
