import { LightningElement, api } from 'lwc';

export default class KanbanBoard extends LightningElement {
    @api opportunities = [];
    @api stages = [];

    get stageColumns() {
        return this.stages.map(stageName => {
            const cards = this.opportunities.filter(opp => opp.StageName === stageName);
            return {
                stageName,
                cards,
                count: String(cards.length),
                hasCards: cards.length > 0
            };
        });
    }

    get isEmpty() {
        return this.opportunities.length === 0;
    }

    handleStageChange(event) {
        // opportunityCard → kanbanBoard → brandPipelineKanban へ伝播
        this.dispatchEvent(new CustomEvent('stagechange', { detail: event.detail }));
    }
}
