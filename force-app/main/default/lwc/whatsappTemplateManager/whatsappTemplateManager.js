import { LightningElement, track, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { refreshApex } from '@salesforce/apex';
import getTemplates from '@salesforce/apex/WhatsAppTemplateController.getTemplates';
import syncTemplatesFromApi from '@salesforce/apex/WhatsAppTemplateController.syncTemplatesFromApi';
import sendTemplateMessage from '@salesforce/apex/WhatsAppTemplateController.sendTemplateMessage';
import getConversations from '@salesforce/apex/WhatsAppConversationController.getConversations';

export default class WhatsappTemplateManager extends LightningElement {
    @track templates = [];
    @track selectedTemplate = null;
    @track isSyncing = false;
    @track showSendModal = false;
    @track selectedConversationId = '';
    @track conversations = [];
    @track variableValues = [];

    wiredTemplatesResult;

    columns = [
        { label: 'Template Name', fieldName: 'Template_Name__c', type: 'text', sortable: true },
        { label: 'Language', fieldName: 'Language__c', type: 'text' },
        { label: 'Category', fieldName: 'Category__c', type: 'text' },
        { label: 'Status', fieldName: 'Status__c', type: 'text' },
        { label: 'Variables', fieldName: 'Variable_Count__c', type: 'number' },
        { label: 'Last Synced', fieldName: 'Last_Synced__c', type: 'date', typeAttributes: { month: 'short', day: 'numeric', hour: '2-digit', minute: '2-digit' } }
    ];

    @wire(getTemplates)
    wiredTemplates(result) {
        this.wiredTemplatesResult = result;
        if (result.data) {
            this.templates = result.data;
        }
    }

    handleSync() {
        this.isSyncing = true;
        syncTemplatesFromApi()
            .then(result => {
                this.showToast('Success', result, 'success');
                this.isSyncing = false;
                return refreshApex(this.wiredTemplatesResult);
            })
            .catch(error => {
                this.showToast('Error', 'Sync failed: ' + (error.body ? error.body.message : error.message), 'error');
                this.isSyncing = false;
            });
    }

    handleRowSelection(event) {
        const selected = event.detail.selectedRows;
        if (selected.length > 0) {
            this.selectedTemplate = selected[0];
            // Build variable inputs based on Variable_Count__c
            this.variableValues = [];
            for (let i = 0; i < (this.selectedTemplate.Variable_Count__c || 0); i++) {
                this.variableValues.push({ index: i, label: 'Variable {{' + (i + 1) + '}}', value: '' });
            }
        } else {
            this.selectedTemplate = null;
        }
    }

    handleOpenSendModal() {
        // Load conversations for the dropdown
        getConversations()
            .then(result => {
                this.conversations = result.map(c => ({
                    label: (c.Customer_Name__c || c.Customer_Phone__c) + ' (' + c.Status__c + ')',
                    value: c.Id
                }));
                this.showSendModal = true;
            })
            .catch(error => {
                this.showToast('Error', 'Failed to load conversations', 'error');
            });
    }

    handleCloseSendModal() {
        this.showSendModal = false;
        this.selectedConversationId = '';
    }

    handleConversationChange(event) {
        this.selectedConversationId = event.detail.value;
    }

    handleVariableChange(event) {
        const idx = parseInt(event.target.dataset.index, 10);
        this.variableValues[idx].value = event.target.value;
    }

    handleSendTemplate() {
        if (!this.selectedConversationId || !this.selectedTemplate) {
            this.showToast('Error', 'Please select a conversation', 'error');
            return;
        }

        // Build components JSON with variable values
        const bodyParams = this.variableValues.map(v => ({
            type: 'text',
            text: v.value || ''
        }));

        const components = bodyParams.length > 0 ? JSON.stringify([{
            type: 'body',
            parameters: bodyParams
        }]) : '';

        sendTemplateMessage({
            conversationId: this.selectedConversationId,
            templateId: this.selectedTemplate.Id,
            variablesJson: components
        })
            .then(() => {
                this.showToast('Success', 'Template message queued for sending', 'success');
                this.handleCloseSendModal();
            })
            .catch(error => {
                this.showToast('Error', 'Failed to send template: ' + (error.body ? error.body.message : error.message), 'error');
            });
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }

    get hasTemplates() { return this.templates && this.templates.length > 0; }
    get hasSelectedTemplate() { return this.selectedTemplate != null; }
    get hasVariables() { return this.variableValues && this.variableValues.length > 0; }
    get previewBody() {
        if (!this.selectedTemplate || !this.selectedTemplate.Body_Text__c) return '';
        let body = this.selectedTemplate.Body_Text__c;
        this.variableValues.forEach((v, i) => {
            body = body.replace('{{' + (i + 1) + '}}', v.value || '{{' + (i + 1) + '}}');
        });
        return body;
    }
}
