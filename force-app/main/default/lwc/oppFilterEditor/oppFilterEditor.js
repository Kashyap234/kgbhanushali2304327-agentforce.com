/**
 * @component     oppFilterEditor
 * @description   Custom Lightning Type editor LWC for the Opportunity Filter Agentforce action.
 *                Renders a multiselect picklist of Opportunity stages. When the user confirms
 *                their selection the component dispatches a `valuechange` event so that the
 *                Agentforce planner picks up the chosen stages and passes them to the next
 *                Apex action (OppFilterAction).
 *
 * @target        lightning__AgentforceInput
 * @targetType    c__oppFilter          (must match LightningTypeBundle folder name)
 *
 * Agentforce wiring:
 *   • The platform injects the current value via the `value` @api setter before the
 *     component renders.  Hydrate local state from it if a previous selection exists.
 *   • Every mutation that the user makes MUST be surfaced immediately via a `valuechange`
 *     CustomEvent carrying `{ value: { selectedStages: '<comma-separated>' } }` in detail.
 *   • The handleSubmit() method fires the final valuechange that the planner acts on,
 *     but intermediate onChange calls keep the planner in sync for streaming UIs.
 */

import { LightningElement, api, track } from 'lwc';

/* ── Stage master list ─────────────────────────────────────────────────────── */
// Mirrors the standard Salesforce Opportunity Stage picklist values.
// Adjust labels / colours / order to match your org's configuration.
const STAGE_DEFINITIONS = [
    { value: 'Prospecting',        label: 'Prospecting',         color: '#7C83FD' },
    { value: 'Qualification',      label: 'Qualification',       color: '#50C9C3' },
    { value: 'Needs Analysis',     label: 'Needs Analysis',      color: '#F9C74F' },
    { value: 'Value Proposition',  label: 'Value Proposition',   color: '#F4845F' },
    { value: 'Id. Decision Makers',label: 'Id. Decision Makers', color: '#F26CA7' },
    { value: 'Perception Analysis',label: 'Perception Analysis', color: '#C77DFF' },
    { value: 'Proposal/Price Quote',label: 'Proposal/Quote',     color: '#4CC9F0' },
    { value: 'Negotiation/Review', label: 'Negotiation',         color: '#F77F00' },
    { value: 'Closed Won',         label: 'Closed Won',          color: '#43AA8B' },
    { value: 'Closed Lost',        label: 'Closed Lost',         color: '#EF233C' },
];

export default class OppFilterEditor extends LightningElement {

    /* ── Public API (Agentforce planner writes this before render) ────────── */
    @api targetType;

    @api
    get value() {
        return this._value;
    }
    set value(incoming) {
        // Incoming shape: { selectedStages: 'Prospecting,Qualification' }
        this._value = incoming;
        if (incoming && incoming.selectedStages) {
            const pre = incoming.selectedStages.split(',').map(s => s.trim()).filter(Boolean);
            this._selectedValues = new Set(pre);
        } else {
            this._selectedValues = new Set();
        }
        this._buildOptions();
    }

    /* ── Internal reactive state ──────────────────────────────────────────── */
    @track stageOptions  = [];          // Full list with derived CSS/state
    _value               = null;
    _selectedValues      = new Set();   // Set<string> of currently selected stage values

    /* ── Lifecycle ────────────────────────────────────────────────────────── */
    connectedCallback() {
        // If value was never injected by the platform, initialise with empty selection
        if (!this._value) {
            this._selectedValues = new Set();
            this._buildOptions();
        }
    }

    /* ── Computed getters ─────────────────────────────────────────────────── */
    get selectedStages() {
        // Returns array of { value, label, removeLabel } for selected chips
        return this.stageOptions
            .filter(o => o.selected)
            .map(o => ({
                value:       o.value,
                label:       o.label,
                removeLabel: `Remove ${o.label}`,
            }));
    }

    get selectedCount() {
        return this._selectedValues.size;
    }

    get hasSelection() {
        return this._selectedValues.size > 0;
    }

    get selectionText() {
        return this._selectedValues.size === 1 ? 'stage' : 'stages';
    }

    get isSubmitDisabled() {
        return this._selectedValues.size === 0;
    }

    get submitLabel() {
        return this.hasSelection
            ? `Apply ${this._selectedValues.size} ${this.selectionText}`
            : 'Select a stage to continue';
    }

    get submitClass() {
        return this.hasSelection
            ? 'submit-btn submit-btn--active'
            : 'submit-btn submit-btn--disabled';
    }

    /* ── Event handlers ───────────────────────────────────────────────────── */

    /**
     * Toggle a stage pill on / off.
     * Fires a valuechange immediately so the planner stays in sync.
     */
    handleStageToggle(event) {
        event.stopPropagation();
        const stage = event.currentTarget.dataset.value;
        if (this._selectedValues.has(stage)) {
            this._selectedValues.delete(stage);
        } else {
            this._selectedValues.add(stage);
        }
        this._buildOptions();
        this._dispatchValueChange();
    }

    /**
     * Remove a single chip from the summary row.
     */
    handleRemoveChip(event) {
        event.stopPropagation();
        const stage = event.currentTarget.dataset.value;
        this._selectedValues.delete(stage);
        this._buildOptions();
        this._dispatchValueChange();
    }

    /**
     * Clear all selected stages at once.
     */
    handleClearAll(event) {
        event.stopPropagation();
        this._selectedValues.clear();
        this._buildOptions();
        this._dispatchValueChange();
    }

    /**
     * Confirm the selection.  The Agentforce planner will trigger the next
     * action (OppFilterAction Apex) with the accumulated valuechange payload.
     * We fire a final valuechange here to guarantee the latest value is sent.
     */
    handleSubmit(event) {
        event.stopPropagation();
        if (this._selectedValues.size === 0) return;
        this._dispatchValueChange();
    }

    /* ── Private helpers ──────────────────────────────────────────────────── */

    /**
     * Rebuild the stageOptions array whenever selection changes.
     * Derives all properties needed by the template so the template
     * itself stays free of conditional logic.
     */
    _buildOptions() {
        this.stageOptions = STAGE_DEFINITIONS.map(def => {
            const selected = this._selectedValues.has(def.value);
            return {
                value:     def.value,
                label:     def.label,
                selected,
                dotStyle:  `background-color: ${def.color};`,
                pillClass: selected
                    ? 'stage-pill stage-pill--selected'
                    : 'stage-pill',
            };
        });
    }

    /**
     * Dispatch the Agentforce-required `valuechange` event.
     * The payload MUST match the Apex CaseFilterWrapper / OppFilterWrapper
     * field names exactly.
     *
     * Shape expected by OppFilterAction:
     *   { selectedStages: 'Prospecting,Closed Won' }
     */
    _dispatchValueChange() {
        const selectedStages = [...this._selectedValues].join(',');
        this.dispatchEvent(
            new CustomEvent('valuechange', {
                bubbles:  true,
                composed: true,      // must cross shadow-DOM boundary to reach planner
                detail: {
                    value: {
                        selectedStages,
                    },
                },
            })
        );
    }
}