import { LightningElement, api, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import generateDraft from '@salesforce/apex/AIEmailService.generateDraft';
import getSavedDrafts from '@salesforce/apex/AIEmailService.getSavedDrafts';
import generateDraftWithEinstein from '@salesforce/apex/EinsteinEmailService.generateDraftWithEinstein';
import getEinsteinDrafts from '@salesforce/apex/EinsteinEmailService.getEinsteinDrafts';

export default class AiEmailAssistant extends LightningElement {
    @api recordId;
    @track emailType = 'Renewal';
    @track emailDraft = '';
    @track isGenerating = false;
    @track showDraft = false;
    @track isReadOnly = true;
    @track showSavedDrafts = false;
    @track savedDrafts = [];
    @track isLoadingDrafts = false;
    @track useEinstein = true; // Default to Einstein for security

    emailTypeOptions = [
        { label: 'Renewal', value: 'Renewal' },
        { label: 'Upsell', value: 'Upsell' },
        { label: 'Welcome', value: 'Welcome' },
        { label: 'Follow-up', value: 'Follow-up' },
        { label: 'Cold Outreach', value: 'Cold Outreach' },
        { label: 'Thank You', value: 'Thank You' },
        { label: 'Proposal', value: 'Proposal' }
    ];

    handleEmailTypeChange(event) {
        this.emailType = event.detail.value;
    }

    handleDraftChange(event) {
        this.emailDraft = event.target.value;
    }

    renderedCallback() {
        // Update textarea content when emailDraft changes
        if (this.emailDraft && this.template.querySelector('#email-draft')) {
            this.template.querySelector('#email-draft').value = this.emailDraft;
        }
    }

    updateTextarea() {
        // Force update the textarea with the current emailDraft content
        const textarea = this.template.querySelector('#email-draft');
        if (textarea && this.emailDraft) {
            textarea.value = this.emailDraft;
            console.log('Textarea updated with content:', this.emailDraft);
            
            // Ensure the textarea is properly editable
            if (!this.isReadOnly) {
                textarea.focus();
                textarea.setSelectionRange(textarea.value.length, textarea.value.length);
            }
        }
    }

    handleReadOnlyToggle(event) {
        this.isReadOnly = event.target.checked;
        
        // Update textarea readonly state
        const textarea = this.template.querySelector('#email-draft');
        if (textarea) {
            textarea.readOnly = this.isReadOnly;
            if (!this.isReadOnly) {
                textarea.focus();
            }
        }
    }

    async generateDraft() {
        this.isGenerating = true;
        this.showDraft = false;
        console.log('Generating draft for:', this.recordId, this.emailType, 'using:', this.useEinstein ? 'Einstein' : 'OpenAI');

        try {
            const result = this.useEinstein 
                ? await generateDraftWithEinstein({
                    recordId: this.recordId,
                    emailType: this.emailType
                })
                : await generateDraft({
                    recordId: this.recordId,
                    emailType: this.emailType
                });
            console.log('Apex result:', result);
            console.log('Result success:', result.success);
            console.log('Result content:', result.draftContent);

            if (result.success) {
                console.log('Setting email draft to:', result.draftContent);
                
                // Set both properties immediately
                this.emailDraft = result.draftContent;
                this.showDraft = true;
                
                console.log('Draft content set:', this.emailDraft);
                console.log('Show draft set to:', this.showDraft);
                console.log('Email draft length:', this.emailDraft ? this.emailDraft.length : 0);
                
                // Force update the textarea
                this.updateTextarea();
                
                this.showToast('Success', 
                    'Email draft generated successfully!', 
                    'success');
            } else {
                console.error('Apex returned error:', result.errorMessage);
                this.showToast('Error', result.errorMessage, 'error');
            }
        } catch (error) {
            console.error('Apex call failed:', error);
            this.showToast('Error', 'Failed to generate draft: ' + (error.body?.message || error.message), 'error');
        } finally {
            this.isGenerating = false;
            console.log('Generation process completed');
        }
    }

    async loadSavedDrafts() {
        this.isLoadingDrafts = true;
        try {
            const drafts = await getSavedDrafts({ recordId: this.recordId });
            this.savedDrafts = drafts.map(draft => ({
                Id: draft.Id,
                Email_Type__c: draft.Email_Type__c,
                Generated_Content__c: draft.Generated_Content__c,
                Generated_Date__c: draft.Generated_Date__c,
                Used_By__c: draft.Used_By__c,
                formattedDate: new Date(draft.Generated_Date__c).toLocaleString(),
                preview: this.getPreview(draft.Generated_Content__c)
            }));
            this.showSavedDrafts = true;
        } catch (error) {
            console.error('Error loading saved drafts:', error);
            this.showToast('Error', 'Failed to load saved drafts', 'error');
        } finally {
            this.isLoadingDrafts = false;
        }
    }

    getPreview(content) {
        if (!content) return 'No content';
        return content.length > 100 ? content.substring(0, 100) + '...' : content;
    }

    useSavedDraft(event) {
        const draftId = event.target.dataset.draftId;
        const selectedDraft = this.savedDrafts.find(draft => draft.Id === draftId);
        if (selectedDraft) {
            this.emailDraft = selectedDraft.Generated_Content__c;
            this.showDraft = true;
            this.showSavedDrafts = false;
            this.showToast('Success', 'Draft loaded successfully', 'success');
        }
    }

    hideSavedDrafts() {
        this.showSavedDrafts = false;
    }

    copyToClipboard() {
        if (!this.emailDraft) {
            this.showToast('Warning', 'No content to copy', 'warning');
            return;
        }

        // Try to find the textarea first
        let textarea = this.template.querySelector('#email-draft');
        
        // If textarea not found, use fallback method
        if (!textarea) {
            console.log('Textarea not found, using fallback copy method');
            const tempTextArea = document.createElement('textarea');
            tempTextArea.value = this.emailDraft;
            tempTextArea.style.position = 'fixed';
            tempTextArea.style.opacity = '0';
            tempTextArea.style.left = '-9999px';
            document.body.appendChild(tempTextArea);
            tempTextArea.select();
            try {
                document.execCommand('copy');
                this.showToast('Success', 'Email draft copied to clipboard!', 'success');
            } catch (err) {
                this.showToast('Error', 'Failed to copy to clipboard', 'error');
            }
            document.body.removeChild(tempTextArea);
            return;
        }

        // Use the found textarea
        try {
            textarea.select();
            document.execCommand('copy');
            this.showToast('Success', 'Email draft copied to clipboard!', 'success');
        } catch (err) {
            // Fallback: create temporary textarea
            const tempTextArea = document.createElement('textarea');
            tempTextArea.value = this.emailDraft;
            tempTextArea.style.position = 'fixed';
            tempTextArea.style.opacity = '0';
            tempTextArea.style.left = '-9999px';
            document.body.appendChild(tempTextArea);
            tempTextArea.select();
            try {
                document.execCommand('copy');
                this.showToast('Success', 'Email draft copied to clipboard!', 'success');
            } catch (fallbackErr) {
                this.showToast('Error', 'Failed to copy to clipboard', 'error');
            }
            document.body.removeChild(tempTextArea);
        }
    }

    clearDraft() {
        this.emailDraft = '';
        this.showDraft = false;
        this.showToast('Info', 'Draft cleared', 'info');
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ 
            title, 
            message, 
            variant,
            duration: variant === 'error' ? 8000 : 4000
        }));
    }

    // Computed properties
    get hasEmailDraft() {
        return this.emailDraft && this.emailDraft.trim().length > 0;
    }

    get isEmailDraftEmpty() {
        return !this.hasEmailDraft;
    }

    get hasSavedDrafts() {
        return this.savedDrafts && this.savedDrafts.length > 0;
    }

    get draftWordCount() {
        if (!this.emailDraft) return 0;
        return this.emailDraft.trim().split(/\s+/).length;
    }

    get draftCharCount() {
        return this.emailDraft ? this.emailDraft.length : 0;
    }
}