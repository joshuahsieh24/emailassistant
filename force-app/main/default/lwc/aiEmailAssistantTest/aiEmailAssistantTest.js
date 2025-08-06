import { LightningElement, api, track } from 'lwc';
import generateDraft from '@salesforce/apex/AIEmailServiceTest.generateDraft';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

export default class AiEmailAssistantTest extends LightningElement {
    @api recordId;
    @track emailType = 'Renewal';
    @track emailDraft = '';
    @track isGenerating = false;
    @track showDraft = false;
    @track isReadOnly = true;

    get emailTypeOptions() {
        return [
            { label: 'Renewal', value: 'Renewal' },
            { label: 'Onboarding', value: 'Onboarding' },
            { label: 'Follow-up', value: 'Follow-up' },
            { label: 'Support', value: 'Support' },
            { label: 'Sales', value: 'Sales' }
        ];
    }

    handleEmailTypeChange(event) {
        this.emailType = event.detail.value;
    }

    handleDraftChange(event) {
        this.emailDraft = event.target.value;
    }

    handleReadOnlyToggle(event) {
        this.isReadOnly = event.target.checked;
    }

    async generateDraft() {
        this.isGenerating = true;
        this.showDraft = false;
        console.log('TEST: Generating draft for:', this.recordId, this.emailType);

        try {
            const result = await generateDraft({
                recordId: this.recordId,
                emailType: this.emailType
            });
            console.log('TEST: Apex result:', result);

            if (result.success) {
                this.emailDraft = result.draftContent;
                this.showDraft = true;
                console.log('TEST: Draft content set:', this.emailDraft);
                this.showToast('Success', 'Email draft generated successfully! (Gateway Test)', 'success');
            } else {
                console.error('TEST: Apex returned error:', result.errorMessage);
                this.showToast('Error', result.errorMessage, 'error');
            }
        } catch (error) {
            console.error('TEST: Apex call failed:', error);
            this.showToast('Error', 'Failed to generate draft: ' + (error.body?.message || error.message), 'error');
        } finally {
            this.isGenerating = false;
            console.log('TEST: isGenerating set to false');
        }
    }

    copyToClipboard() {
        const textarea = this.template.querySelector('textarea');
        if (textarea) {
            textarea.select();
            document.execCommand('copy');
            this.showToast('Success', 'Copied to clipboard!', 'success');
        }
    }

    showToast(title, message, variant) {
        const evt = new ShowToastEvent({
            title: title,
            message: message,
            variant: variant,
        });
        this.dispatchEvent(evt);
    }
} 