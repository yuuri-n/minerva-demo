import { LightningElement, api, wire } from 'lwc';
import { getRecord, updateRecord } from 'lightning/uiRecordApi';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import ACCOUNT_ID_FIELD from '@salesforce/schema/Opportunity.AccountId';
import findDuplicateAccounts from '@salesforce/apex/AccountDedupController.findDuplicateAccounts';
import mergeOpportunities from '@salesforce/apex/AccountDedupController.mergeOpportunities';

const OPP_FIELDS = [ACCOUNT_ID_FIELD];

export default class AccountDedupPanel extends LightningElement {
    @api recordId;

    _accountId = null;
    duplicates = [];
    isLoading = false;
    error = null;

    @wire(getRecord, { recordId: '$recordId', fields: OPP_FIELDS })
    wiredOpp({ data, error }) {
        if (data) {
            const newAccountId = data.fields.AccountId.value;
            if (newAccountId !== this._accountId) {
                this._accountId = newAccountId;
                this._loadDuplicates();
            }
        } else if (error) {
            this.error = error.body?.message ?? '取得エラー';
        }
    }

    async _loadDuplicates() {
        if (!this._accountId) {
            this.duplicates = [];
            return;
        }
        this.isLoading = true;
        this.error = null;
        try {
            this.duplicates = await findDuplicateAccounts({ accountId: this._accountId });
        } catch (e) {
            this.error = e.body?.message ?? e.message;
        } finally {
            this.isLoading = false;
        }
    }

    get showPanel() {
        return this.isLoading || this.hasDuplicates || !!this.error;
    }

    get hasDuplicates() {
        return this.duplicates.length > 0;
    }

    get duplicateCount() {
        return this.duplicates.length;
    }

    get duplicateEmail() {
        return this.duplicates.length > 0 ? this.duplicates[0].email : '';
    }

    async handleMerge(event) {
        const targetAccountId = event.currentTarget.dataset.accountId;
        this.isLoading = true;
        try {
            await mergeOpportunities({
                fromAccountId: this._accountId,
                toAccountId: targetAccountId
            });
            await updateRecord({ fields: { Id: this.recordId, AccountId: targetAccountId } });
            this.dispatchEvent(new ShowToastEvent({
                title: '統合完了',
                message: 'この商談の取引先を付け替えました。',
                variant: 'success'
            }));
        } catch (e) {
            this.dispatchEvent(new ShowToastEvent({
                title: 'エラー',
                message: e.body?.message ?? e.message,
                variant: 'error'
            }));
            this.isLoading = false;
        }
    }
}
