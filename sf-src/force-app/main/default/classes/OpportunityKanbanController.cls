public with sharing class OpportunityKanbanController {

    @AuraEnabled(cacheable=true)
    public static List<Opportunity> getOpportunities(Id accountId, String recordTypeDeveloperName) {
        try {
            if (String.isBlank(recordTypeDeveloperName)) {
                return [
                    SELECT Id, Name, StageName,
                           Owner.Name, OwnerId,
                           NextActionDate__c, Amount, CloseDate,
                           RecordType.Name, RecordType.DeveloperName
                    FROM Opportunity
                    WHERE AccountId = :accountId
                    ORDER BY NextActionDate__c ASC NULLS LAST
                    LIMIT 200
                ];
            }
            return [
                SELECT Id, Name, StageName,
                       Owner.Name, OwnerId,
                       NextActionDate__c, Amount, CloseDate,
                       RecordType.Name, RecordType.DeveloperName
                FROM Opportunity
                WHERE AccountId = :accountId
                  AND RecordType.DeveloperName = :recordTypeDeveloperName
                ORDER BY NextActionDate__c ASC NULLS LAST
                LIMIT 200
            ];
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    @AuraEnabled
    public static void updateOpportunityStage(Id opportunityId, String newStageName) {
        if (String.isBlank(newStageName)) {
            throw new AuraHandledException('ステージ名を指定してください');
        }
        try {
            update new Opportunity(Id = opportunityId, StageName = newStageName);
        } catch (DmlException e) {
            throw new AuraHandledException(e.getMessage());
        }
    }
}
