// LeadMigrationBatch 本実行 (dryRun=false)
Id jobId = Database.executeBatch(new LeadMigrationBatch(false), 200);
System.debug('JobId: ' + jobId);
