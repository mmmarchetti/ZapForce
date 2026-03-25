import { LightningElement, track, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getConfiguration from '@salesforce/apex/WhatsAppConfigurationController.getConfiguration';
import saveConfiguration from '@salesforce/apex/WhatsAppConfigurationController.saveConfiguration';
import testConnection from '@salesforce/apex/WhatsAppConfigurationController.testConnection';
import getWebhookUrl from '@salesforce/apex/WhatsAppConfigurationController.getWebhookUrl';

export default class WhatsappConfiguration extends LightningElement {
    @track config = {};
    @track webhookUrl = '';
    @track isLoading = false;
    @track isTesting = false;

    connectedCallback() {
        this.loadConfiguration();
        this.loadWebhookUrl();
    }

    loadConfiguration() {
        this.isLoading = true;
        getConfiguration()
            .then(result => {
                if (result) {
                    this.config = { ...result };
                } else {
                    this.config = {
                        API_Base_URL__c: 'https://graph.facebook.com/v18.0',
                        Is_Active__c: true
                    };
                }
                this.isLoading = false;
            })
            .catch(error => {
                this.showToast('Error', 'Failed to load configuration: ' + error.body.message, 'error');
                this.isLoading = false;
            });
    }

    loadWebhookUrl() {
        getWebhookUrl()
            .then(result => {
                this.webhookUrl = result;
            })
            .catch(error => {
                console.error('Error loading webhook URL:', error);
            });
    }

    handleInputChange(event) {
        const field = event.target.dataset.field;
        this.config[field] = event.target.value;
    }

    handleCheckboxChange(event) {
        const field = event.target.dataset.field;
        this.config[field] = event.target.checked;
    }

    handleSave() {
        this.isLoading = true;
        saveConfiguration({ config: this.config })
            .then(result => {
                this.config.Id = result;
                this.showToast('Success', 'Configuration saved successfully', 'success');
                this.isLoading = false;
            })
            .catch(error => {
                this.showToast('Error', 'Failed to save configuration: ' + error.body.message, 'error');
                this.isLoading = false;
            });
    }

    handleTestConnection() {
        if (!this.config.Id) {
            this.showToast('Error', 'Please save the configuration first', 'error');
            return;
        }

        this.isTesting = true;
        testConnection({ configId: this.config.Id })
            .then(result => {
                if (result.success) {
                    this.showToast('Success', result.message, 'success');
                } else {
                    this.showToast('Error', result.message, 'error');
                }
                this.isTesting = false;
            })
            .catch(error => {
                this.showToast('Error', 'Test failed: ' + error.body.message, 'error');
                this.isTesting = false;
            });
    }

    copyWebhookUrl() {
        const textArea = document.createElement('textarea');
        textArea.value = this.webhookUrl;
        document.body.appendChild(textArea);
        textArea.select();
        document.execCommand('copy');
        document.body.removeChild(textArea);
        this.showToast('Success', 'Webhook URL copied to clipboard', 'success');
    }

    showToast(title, message, variant) {
        const event = new ShowToastEvent({
            title: title,
            message: message,
            variant: variant
        });
        this.dispatchEvent(event);
    }

    get isConfigValid() {
        return this.config.API_Key__c && this.config.Phone_Number__c && this.config.API_Base_URL__c;
    }
}
