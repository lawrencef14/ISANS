import { LightningElement, api, wire } from 'lwc';
import { getRecord, getFieldValue } from 'lightning/uiRecordApi';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

import ACCOUNT_ID_FIELD from '@salesforce/schema/Case.AccountId';

import listPrograms from '@salesforce/apex/ISANS_EligibilityLiteService.listProgramsForPicker';
import evaluate from '@salesforce/apex/ISANS_EligibilityLiteService.evaluate';

const CASE_FIELDS = [ACCOUNT_ID_FIELD];

export default class IsansEligibilityLite extends LightningElement {
    @api recordId;
    /** When set from a Flow Screen (e.g. after Add Participant), overrides Case.AccountId for evaluate(). */
    @api clientAccountId;

    programOptions = [];
    selectedProgramId;
    loadingPrograms = false;
    evaluating = false;
    result;
    caseAccountId;

    @wire(getRecord, { recordId: '$recordId', fields: CASE_FIELDS })
    wiredCase({ data, error }) {
        if (data) {
            this.caseAccountId = getFieldValue(data, ACCOUNT_ID_FIELD);
        } else if (error) {
            this.toast('Case', this.reduceError(error), 'error');
        }
    }

    connectedCallback() {
        this.loadPrograms();
    }

    loadPrograms() {
        this.loadingPrograms = true;
        listPrograms()
            .then((rows) => {
                this.programOptions = rows || [];
            })
            .catch((e) => {
                this.toast('Programs', this.reduceError(e), 'error');
            })
            .finally(() => {
                this.loadingPrograms = false;
            });
    }

    handleProgramChange(event) {
        this.selectedProgramId = event.detail.value;
    }

    async handleEvaluate() {
        this.result = null;
        if (!this.selectedProgramId) {
            this.toast('Program required', 'Choose a program.', 'warning');
            return;
        }

        this.evaluating = true;
        try {
            const fromFlow = this.clientAccountId && String(this.clientAccountId).trim();
            const accId = fromFlow || this.caseAccountId;
            if (!accId) {
                this.toast(
                    'Client Account required',
                    'Populate Case.Account, or pass Participant Account Id from the Flow after Add Participant.',
                    'warning'
                );
                this.evaluating = false;
                return;
            }
            const evalResult = await evaluate({ programId: this.selectedProgramId, accountId: accId });
            this.result = evalResult;
        } catch (e) {
            this.toast('Evaluate failed', this.reduceError(e), 'error');
        } finally {
            this.evaluating = false;
        }
    }

    reduceError(error) {
        if (Array.isArray(error?.body)) {
            return error.body.map((e) => e.message).join(', ');
        }
        if (typeof error?.body?.message === 'string') {
            return error.body.message;
        }
        return error?.message || String(error);
    }

    toast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}
