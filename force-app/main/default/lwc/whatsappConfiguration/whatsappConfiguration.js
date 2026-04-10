import { LightningElement, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getConfiguration from '@salesforce/apex/WhatsAppConfigurationController.getConfiguration';
import saveConfiguration from '@salesforce/apex/WhatsAppConfigurationController.saveConfiguration';
import testConnection from '@salesforce/apex/WhatsAppConfigurationController.testConnection';
import getWebhookUrl from '@salesforce/apex/WhatsAppConfigurationController.getWebhookUrl';

const SECRET_MASK = '\u2022\u2022\u2022\u2022\u2022\u2022\u2022\u2022\u2022\u2022\u2022\u2022\u2022\u2022\u2022\u2022';

export default class WhatsappConfiguration extends LightningElement {
    @track config = {};
    @track isLoading = false;
    @track isSaving = false;
    @track isTesting = false;

    @track showApiKey = false;
    @track showWebhookToken = false;

    @track sections = {
        apiCredentials: true,
        phoneSettings: false,
        webhookSettings: false,
        agentforceSettings: false
    };

    connectedCallback() {
        this.loadConfiguration();
    }

    loadConfiguration() {
        this.isLoading = true;
        const promises = [getConfiguration(), getWebhookUrl()];

        Promise.all(promises)
            .then(([configResult, webhookUrlResult]) => {
                console.log('configResult', configResult);
                if (configResult) {
                    this.config = { ...configResult };
                } else {
                    this.config = {
                        API_Base_URL__c: 'https://graph.facebook.com',
                        WhatsApp_API_Version__c: 'v21.0',
                        Session_Timeout_Minutes__c: 1440,
                        HMAC_Validation_Enabled__c: false,
                        Auto_Download_Media__c: false,
                        Is_Active__c: true
                    };
                }
                if (webhookUrlResult && !this.config.Webhook_URL__c) {
                    this.config.Webhook_URL__c = webhookUrlResult;
                }
            })
            .catch(error => {
                const msg = error.body ? error.body.message : error.message;
                this.showToast('Error', 'Failed to load configuration: ' + msg, 'error');
            })
            .finally(() => {
                this.isLoading = false;
            });
    }

    // --- Input handlers ---

    handleInputChange(event) {
        const field = event.target.dataset.field;
        const value = event.target.value;
        this.config = { ...this.config, [field]: value };
    }

    handleCheckboxChange(event) {
        const field = event.target.dataset.field;
        const value = event.target.checked;
        this.config = { ...this.config, [field]: value };
    }

    // --- Save ---

    handleSave() {
        this.isSaving = true;
        saveConfiguration({ configData: this.config })
            .then(result => {
                this.config = { ...this.config, Id: result };
                console.log('saved this.config', this.config);
                this.showToast('Success', 'Configuration saved successfully', 'success');
                // Reload to get fresh masked values
                return getConfiguration();
            })
            .then(configResult => {
                if (configResult) {
                    this.config = { ...configResult };
                }
                console.log('configResult', configResult);
                this.showApiKey = false;
                this.showWebhookToken = false;
            })
            .catch(error => {
                const msg = error.body ? error.body.message : error.message;
                this.showToast('Error', 'Failed to save configuration: ' + msg, 'error');
            })
            .finally(() => {
                this.isSaving = false;
            });
    }

    // --- Test Connection ---

    handleTestConnection() {
        if (!this.config.Id) {
            this.showToast('Warning', 'Please save the configuration first', 'warning');
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
            })
            .catch(error => {
                const msg = error.body ? error.body.message : error.message;
                this.showToast('Error', 'Test failed: ' + msg, 'error');
            })
            .finally(() => {
                this.isTesting = false;
            });
    }

    get disableTestConnection() {
        return !this.config.Id || this.isTesting;
    }

    // --- Section toggling ---

    toggleSection(event) {
        const section = event.currentTarget.dataset.section;
        this.sections = {
            ...this.sections,
            [section]: !this.sections[section]
        };
    }

    // --- API Key visibility toggle ---

    toggleApiKeyVisibility() {
        this.showApiKey = !this.showApiKey;
    }

    get apiKeyInputType() {
        return this.showApiKey ? 'text' : 'password';
    }

    get apiKeyToggleIcon() {
        return this.showApiKey ? 'utility:hide' : 'utility:preview';
    }

    get apiKeyToggleAlt() {
        return this.showApiKey ? 'Hide API Key' : 'Show API Key';
    }

    // --- Webhook Token visibility toggle ---

    toggleWebhookTokenVisibility() {
        this.showWebhookToken = !this.showWebhookToken;
    }

    get webhookTokenInputType() {
        return this.showWebhookToken ? 'text' : 'password';
    }

    get webhookTokenToggleIcon() {
        return this.showWebhookToken ? 'utility:hide' : 'utility:preview';
    }

    get webhookTokenToggleAlt() {
        return this.showWebhookToken ? 'Hide Webhook Token' : 'Show Webhook Token';
    }

    // --- Copy Webhook URL ---

    handleCopyWebhookUrl() {
        const url = this.config.Webhook_URL__c;
        if (!url) {
            this.showToast('Warning', 'No webhook URL to copy', 'warning');
            return;
        }

        if (navigator.clipboard && navigator.clipboard.writeText) {
            navigator.clipboard.writeText(url)
                .then(() => {
                    this.showToast('Success', 'Webhook URL copied to clipboard', 'success');
                })
                .catch(() => {
                    this._fallbackCopy(url);
                });
        } else {
            this._fallbackCopy(url);
        }
    }

    _fallbackCopy(text) {
        const textArea = document.createElement('textarea');
        textArea.value = text;
        textArea.style.position = 'fixed';
        textArea.style.opacity = '0';
        document.body.appendChild(textArea);
        textArea.select();
        try {
            document.execCommand('copy');
            this.showToast('Success', 'Webhook URL copied to clipboard', 'success');
        } catch (err) {
            this.showToast('Error', 'Failed to copy URL', 'error');
        }
        document.body.removeChild(textArea);
    }

    // --- Section chevron getters ---

    get apiCredentialsChevron() {
        return this.sections.apiCredentials ? 'utility:chevrondown' : 'utility:chevronright';
    }
    get apiCredentialsChevronClass() {
        return 'chevron-icon' + (this.sections.apiCredentials ? ' chevron-expanded' : '');
    }

    get phoneSettingsChevron() {
        return this.sections.phoneSettings ? 'utility:chevrondown' : 'utility:chevronright';
    }
    get phoneSettingsChevronClass() {
        return 'chevron-icon' + (this.sections.phoneSettings ? ' chevron-expanded' : '');
    }

    get webhookSettingsChevron() {
        return this.sections.webhookSettings ? 'utility:chevrondown' : 'utility:chevronright';
    }
    get webhookSettingsChevronClass() {
        return 'chevron-icon' + (this.sections.webhookSettings ? ' chevron-expanded' : '');
    }

    get agentforceSettingsChevron() {
        return this.sections.agentforceSettings ? 'utility:chevrondown' : 'utility:chevronright';
    }
    get agentforceSettingsChevronClass() {
        return 'chevron-icon' + (this.sections.agentforceSettings ? ' chevron-expanded' : '');
    }

    // --- Toast helper ---

    showToast(title, message, variant) {
        this.dispatchEvent(
            new ShowToastEvent({ title, message, variant })
        );
    }
}
