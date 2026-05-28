import { LightningElement, api } from 'lwc';

export default class OpportunityCard extends LightningElement {
    @api opportunity;
    @api stages = [];

    // ── getter ──────────────────────────────────────────────

    get oppName() {
        return this.opportunity ? this.opportunity.Name : '';
    }

    get oppUrl() {
        return this.opportunity ? '/lightning/r/Opportunity/' + this.opportunity.Id + '/view' : '#';
    }

    get ownerName() {
        return this.opportunity && this.opportunity.Owner ? this.opportunity.Owner.Name : '';
    }

    get currentStage() {
        return this.opportunity ? this.opportunity.StageName : '';
    }

    get stageOptions() {
        return this.stages.map(s => ({ label: s, value: s }));
    }

    get hasNextAction() {
        return !!(this.opportunity && this.opportunity.NextActionDate__c);
    }

    get formattedNextAction() {
        if (!this.opportunity || !this.opportunity.NextActionDate__c) return '';
        const d = new Date(this.opportunity.NextActionDate__c);
        return d.toLocaleString('ja-JP', {
            month: '2-digit', day: '2-digit',
            hour: '2-digit', minute: '2-digit'
        });
    }

    get nextActionClass() {
        const base = 'card-row';
        if (!this.opportunity || !this.opportunity.NextActionDate__c) return base;
        const isPast = new Date(this.opportunity.NextActionDate__c) < new Date();
        return isPast ? base + ' overdue' : base;
    }

    // ── ハンドラ ────────────────────────────────────────────

    handleStageChange(event) {
        const newStageName = event.detail.value;
        if (this.opportunity && newStageName !== this.opportunity.StageName) {
            this.dispatchEvent(new CustomEvent('stagechange', {
                detail: { opportunityId: this.opportunity.Id, newStageName }
            }));
        }
    }
}
