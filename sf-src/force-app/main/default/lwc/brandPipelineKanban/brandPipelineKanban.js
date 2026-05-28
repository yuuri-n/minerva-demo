import { LightningElement, api, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { refreshApex } from '@salesforce/apex';
import getOpportunities from '@salesforce/apex/OpportunityKanbanController.getOpportunities';
import updateOpportunityStage from '@salesforce/apex/OpportunityKanbanController.updateOpportunityStage';

const BRAND_STAGES = {
    Minerva_Consumer:  ['未コンタクト', '新規会員登録', 'アプローチ', '相談', '提案', '受注/購入済', 'リピート'],
    LHALA_Wholesale:   ['資料請求', 'アプローチ', '商談', '提案・見積', '受注', '導入完了'],
    LEMELLA_Wholesale: ['資料請求', '説明会案内', '説明会参加', '商談', '提案・見積', '受注', '導入完了'],
    FLOWNEE_Consumer:  ['未コンタクト', '新規会員登録', '案内', '相談', '購入済', 'リピート']
};

const TABS = [
    { label: 'Minerva', value: 'Minerva_Consumer' },
    { label: 'LHALA',   value: 'LHALA_Wholesale' },
    { label: 'LEMELLA', value: 'LEMELLA_Wholesale' },
    { label: 'FLOWNEE', value: 'FLOWNEE_Consumer' },
    { label: 'すべて',  value: 'all' }
];

const TABLE_COLUMNS = [
    {
        label: '商談名', fieldName: 'nameUrl', type: 'url',
        typeAttributes: { label: { fieldName: 'name' }, target: '_self' },
        wrapText: true
    },
    { label: 'ブランド',        fieldName: 'recordTypeName' },
    { label: 'ステージ',        fieldName: 'stageName' },
    {
        label: '次回アクション', fieldName: 'nextActionDate', type: 'date',
        typeAttributes: { year: 'numeric', month: '2-digit', day: '2-digit',
                          hour: '2-digit', minute: '2-digit' }
    },
    { label: '担当者', fieldName: 'ownerName' },
    {
        label: '金額', fieldName: 'amount', type: 'currency',
        typeAttributes: { currencyCode: 'JPY', minimumFractionDigits: '0' }
    }
];

export default class BrandPipelineKanban extends LightningElement {
    @api recordId;

    _selectedTab = 'Minerva_Consumer';
    // @wire のリアクティブパラメータ: 'all' → '' (Apex で isBlank 判定)
    _rtFilter = 'Minerva_Consumer';

    _wiredResult;
    opportunities = [];
    error;
    isLoading = false;
    tableColumns = TABLE_COLUMNS;

    @wire(getOpportunities, { accountId: '$recordId', recordTypeDeveloperName: '$_rtFilter' })
    wiredOpportunities(result) {
        this._wiredResult = result;
        if (result.data) {
            this.opportunities = result.data;
            this.error = undefined;
        } else if (result.error) {
            this.error = result.error;
            this.opportunities = [];
        }
    }

    // ── getter ──────────────────────────────────────────────

    get tabs() {
        return TABS.map(t => {
            const count = t.value === 'all'
                ? null
                : this.opportunities.filter(o => o.RecordType && o.RecordType.DeveloperName === t.value).length;
            return {
                ...t,
                count: count === null ? null : count > 0 ? String(count) : null,
                cssClass: [
                    'tab-btn',
                    'slds-button',
                    t.value === this._selectedTab ? 'slds-button_brand' : 'slds-button_neutral'
                ].join(' ')
            };
        });
    }

    get activeStages() {
        return BRAND_STAGES[this._selectedTab] || [];
    }

    get isKanbanView() {
        return this._selectedTab !== 'all' && !this.isLoading && !this.hasError;
    }

    get isTableView() {
        return this._selectedTab === 'all' && !this.isLoading && !this.hasError;
    }

    get hasOpportunities() {
        return this.opportunities.length > 0;
    }

    get hasError() {
        return !!this.error;
    }

    get errorMessage() {
        if (!this.error) return '';
        return this.error.body ? this.error.body.message : this.error.message || '予期せぬエラーが発生しました';
    }

    get tableData() {
        return this.opportunities.map(opp => ({
            id: opp.Id,
            nameUrl: '/lightning/r/Opportunity/' + opp.Id + '/view',
            name: opp.Name,
            recordTypeName: opp.RecordType ? opp.RecordType.Name : '',
            stageName: opp.StageName,
            nextActionDate: opp.NextActionDate__c,
            ownerName: opp.Owner ? opp.Owner.Name : '',
            amount: opp.Amount
        }));
    }

    // ── ハンドラ ────────────────────────────────────────────

    handleTabClick(event) {
        const value = event.currentTarget.dataset.value;
        this._selectedTab = value;
        this._rtFilter = value === 'all' ? '' : value;
    }

    handleStageChange(event) {
        const { opportunityId, newStageName } = event.detail;
        this.isLoading = true;
        updateOpportunityStage({ opportunityId, newStageName })
            .then(() => refreshApex(this._wiredResult))
            .then(() => {
                this.dispatchEvent(new ShowToastEvent({
                    title: '更新完了',
                    message: 'ステージを「' + newStageName + '」に更新しました',
                    variant: 'success'
                }));
            })
            .catch(err => {
                const msg = err && err.body ? err.body.message : 'ステージ更新に失敗しました';
                this.dispatchEvent(new ShowToastEvent({ title: 'エラー', message: msg, variant: 'error' }));
            })
            .finally(() => {
                this.isLoading = false;
            });
    }
}
