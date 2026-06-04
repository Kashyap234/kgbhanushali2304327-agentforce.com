/**
 * @component     oppCardRenderer
 * @description   Custom Lightning Type renderer LWC for the Opportunity Display Agentforce action.
 *                Receives the output of OppFilterAction (a JSON-serialised list of Opportunity
 *                records + an empty userNotes string) and renders each opportunity as a rich
 *                summary card.  The embedded text-area at the bottom lets the user type notes
 *                or instructions; every keystroke dispatches a `valuechange` event so the
 *                Agentforce planner can route the text to the next action in the conversation.
 *
 * @target        lightning__AgentforceOutput
 * @sourceType    c__oppResult          (must match LightningTypeBundle folder name)
 *
 * Agentforce wiring:
 *   • The platform passes action output to this component via the `value` @api setter.
 *     Shape: { oppsJson: '[{…}]', userNotes: '' }  (matches OppResultWrapper fields)
 *   • Mutations (notes typed by the user) are surfaced via `valuechange` CustomEvent
 *     carrying `{ value: { oppsJson, userNotes } }` so the planner can use userNotes
 *     as input to the next chained action.
 */

import { LightningElement, api, track } from 'lwc';

/* ── Stage → colour map (matches oppFilterEditor) ────────────────────────── */
const STAGE_COLORS = {
    'Prospecting':          { bg: '#ede9fe', text: '#5b21b6', bar: '#7C83FD' },
    'Qualification':        { bg: '#ccfbf1', text: '#0f766e', bar: '#50C9C3' },
    'Needs Analysis':       { bg: '#fef9c3', text: '#854d0e', bar: '#F9C74F' },
    'Value Proposition':    { bg: '#ffedd5', text: '#9a3412', bar: '#F4845F' },
    'Id. Decision Makers':  { bg: '#fce7f3', text: '#9d174d', bar: '#F26CA7' },
    'Perception Analysis':  { bg: '#f3e8ff', text: '#6b21a8', bar: '#C77DFF' },
    'Proposal/Price Quote': { bg: '#cffafe', text: '#155e75', bar: '#4CC9F0' },
    'Negotiation/Review':   { bg: '#ffedd5', text: '#7c2d12', bar: '#F77F00' },
    'Closed Won':           { bg: '#dcfce7', text: '#14532d', bar: '#43AA8B' },
    'Closed Lost':          { bg: '#fee2e2', text: '#7f1d1d', bar: '#EF233C' },
};

const MAX_DISPLAY   = 20;       // Maximum cards rendered at once
const MAX_NOTES_LEN = 1000;     // Character limit for the notes textarea

/**
 * Format a currency amount (USD assumed; adjust locale/currency for your org).
 * Returns an em-dash for null / zero amounts.
 */
function formatAmount(amount) {
    if (amount == null || amount === 0) return '—';
    return new Intl.NumberFormat('en-US', {
        style:    'currency',
        currency: 'USD',
        notation: amount >= 1_000_000 ? 'compact' : 'standard',
        maximumFractionDigits: amount >= 1_000_000 ? 1 : 0,
    }).format(amount);
}

/**
 * Format a Salesforce date string (YYYY-MM-DD) into a human-friendly label.
 * Returns '—' for missing values.
 */
function formatDate(dateStr) {
    if (!dateStr) return '—';
    // Parse as UTC noon to avoid timezone date-shift
    const d = new Date(dateStr + 'T12:00:00Z');
    return d.toLocaleDateString('en-US', { month: 'short', day: 'numeric', year: 'numeric' });
}

/**
 * Determine if a close date is in the past (overdue / already closed).
 */
function isOverdue(dateStr) {
    if (!dateStr) return false;
    const closeDate = new Date(dateStr + 'T23:59:59');
    return closeDate < new Date();
}

export default class OppCardRenderer extends LightningElement {

    /* ── Public API (Agentforce platform sets this) ───────────────────────── */
    @api sourceType;

    @api
    get value() {
        return this._value;
    }
    set value(incoming) {
        this._value = incoming;
        this._parseAndBuild(incoming);
    }

    /* ── Internal reactive state ──────────────────────────────────────────── */
    @track opportunities  = [];
    @track isLoading      = false;
    @track hasError       = false;
    @track errorMessage   = '';
    @track notesValue     = '';
    @track notesFocused   = false;

    _value                = null;
    _rawOppsJson          = '';
    _totalCount           = 0;
    _activeStages         = [];

    /* ── Computed getters ─────────────────────────────────────────────────── */
    get showContent() {
        return !this.isLoading && !this.hasError;
    }

    get isEmpty() {
        return this.opportunities.length === 0;
    }

    get totalCount() {
        return this._totalCount;
    }

    get recordLabel() {
        return this._totalCount === 1 ? 'opportunity' : 'opportunities';
    }

    get activeStages() {
        return this._activeStages;
    }

    get showOverflow() {
        return this._totalCount > MAX_DISPLAY;
    }

    get charCountText() {
        const remaining = MAX_NOTES_LEN - (this.notesValue || '').length;
        return remaining <= 100 ? `${remaining} characters remaining` : '';
    }

    get notesAreaClass() {
        return this.notesFocused
            ? 'notes-textarea notes-textarea--focused'
            : 'notes-textarea';
    }

    /* ── Event handlers ───────────────────────────────────────────────────── */

    handleNotesInput(event) {
        let val = event.target.value;
        // Enforce character limit client-side
        if (val.length > MAX_NOTES_LEN) {
            val = val.substring(0, MAX_NOTES_LEN);
            event.target.value = val;
        }
        this.notesValue = val;
        this._dispatchValueChange();
    }

    handleNotesFocus() {
        this.notesFocused = true;
    }

    handleNotesBlur() {
        this.notesFocused = false;
    }

    /**
     * Explicit "Send to agent" button — fires valuechange once more so the
     * planner picks up the final notes value and can trigger the next action.
     */
    handleNotesSend(event) {
        event.stopPropagation();
        this._dispatchValueChange();
    }

    /* ── Private helpers ──────────────────────────────────────────────────── */

    /**
     * Parse the incoming value object from the Apex OppResultWrapper
     * and derive the display-ready opportunity array.
     *
     * Expected shape:
     *   {
     *     oppsJson:  '[{"Id":"...", "Name":"...", "StageName":"...",
     *                   "Amount":50000, "CloseDate":"2025-12-31",
     *                   "Probability":75, "Account":{"Name":"Acme"} }]',
     *     userNotes: ''
     *   }
     */
    _parseAndBuild(incoming) {
        // Reset error state
        this.hasError    = false;
        this.errorMessage = '';

        if (!incoming) {
            this.opportunities = [];
            this._totalCount   = 0;
            return;
        }

        // Hydrate notes if the planner has previously stored a value
        if (incoming.userNotes) {
            this.notesValue = incoming.userNotes;
        }

        // Store raw JSON for later dispatch
        this._rawOppsJson = incoming.oppsJson || '[]';

        let raw = [];
        try {
            raw = JSON.parse(this._rawOppsJson);
        } catch (e) {
            this.hasError     = true;
            this.errorMessage = 'Unable to parse opportunity data. Please try again.';
            return;
        }

        this._totalCount = raw.length;

        // Collect unique stages present in the result (for the header chips)
        this._activeStages = [...new Set(raw.map(o => o.StageName).filter(Boolean))];

        // Slice for display and decorate each record
        this.opportunities = raw.slice(0, MAX_DISPLAY).map(opp => this._decorateOpp(opp));
    }

    /**
     * Enrich a plain Apex-serialised Opportunity object with display properties.
     */
    _decorateOpp(opp) {
        const stage      = opp.StageName || '';
        const colors     = STAGE_COLORS[stage] || { bg: '#f1f5f9', text: '#334155', bar: '#94a3b8' };
        const closedWon  = stage === 'Closed Won';
        const closedLost = stage === 'Closed Lost';
        const overdue    = !closedWon && !closedLost && isOverdue(opp.CloseDate);
        const prob       = opp.Probability != null ? Number(opp.Probability) : null;

        return {
            ...opp,
            accountName:       opp.Account ? opp.Account.Name : (opp.AccountName || null),
            formattedAmount:   formatAmount(opp.Amount),
            formattedCloseDate: formatDate(opp.CloseDate),
            badgeStyle:        `background:${colors.bg}; color:${colors.text};`,
            probBarStyle:      `width:${prob ?? 0}%; background:${colors.bar};`,
            closeDateClass:    overdue ? 'close-date close-date--overdue' : 'close-date',
            showProbability:   prob != null && !closedWon && !closedLost,
            isClosedWon:       closedWon,
            isClosedLost:      closedLost,
            cardClass:         closedWon
                ? 'opp-card opp-card--won'
                : closedLost
                    ? 'opp-card opp-card--lost'
                    : 'opp-card',
        };
    }

    /**
     * Dispatch the Agentforce-required `valuechange` event.
     *
     * Payload shape expected by the Agentforce planner (matches OppResultWrapper):
     *   {
     *     oppsJson:  '...',        // Pass through unchanged
     *     userNotes: 'text typed'  // Updated by the user
     *   }
     */
    _dispatchValueChange() {
        this.dispatchEvent(
            new CustomEvent('valuechange', {
                bubbles:  true,
                composed: true,
                detail: {
                    value: {
                        oppsJson:  this._rawOppsJson,
                        userNotes: this.notesValue,
                    },
                },
            })
        );
    }
}