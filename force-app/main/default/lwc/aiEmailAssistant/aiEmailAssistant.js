import { LightningElement, api, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import generateDraft from '@salesforce/apex/AIEmailService.generateDraft';

export default class AiEmailAssistant extends LightningElement {
    @api recordId;
    @track emailType = 'Renewal';
    @track emailDraft = '';
    @track isGenerating = false;
    @track showDraft = false;
    @track isReadOnly = true;

    emailTypeOptions = [
        { label: 'Renewal', value: 'Renewal' },
        { label: 'Upsell', value: 'Upsell' },
        { label: 'Welcome', value: 'Welcome' },
        { label: 'Follow-up', value: 'Follow-up' },
        { label: 'Cold Outreach', value: 'Cold Outreach' }
    ];

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
        console.log('Generating draft for:', this.recordId, this.emailType);

        try {
            const result = await generateDraft({
                recordId: this.recordId,
                emailType: this.emailType
            });
            console.log('Apex result:', result);

            if (result.success) {
                this.emailDraft = result.draftContent;
                this.showDraft = true;
                console.log('Draft content set:', this.emailDraft);
                this.showToast('Success', 'Email draft generated successfully!', 'success');
            } else {
                console.error('Apex returned error:', result.errorMessage);
                this.showToast('Error', result.errorMessage, 'error');
            }
        } catch (error) {
            console.error('Apex call failed:', error);
            this.showToast('Error', 'Failed to generate draft: ' + (error.body?.message || error.message), 'error');
        } finally {
            this.isGenerating = false;
            console.log('isGenerating set to false');
        }
    }

    copyToClipboard() {
        navigator.clipboard.writeText(this.emailDraft).then(() => {
            this.showToast('Success', 'Email draft copied to clipboard!', 'success');
        }).catch(() => {
            this.showToast('Error', 'Failed to copy to clipboard', 'error');
        });
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}
