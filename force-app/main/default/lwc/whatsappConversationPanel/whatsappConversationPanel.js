import { LightningElement, track, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { refreshApex } from '@salesforce/apex';
import getConversations from '@salesforce/apex/WhatsAppConfigurationController.getConversations';
import getConversationMessages from '@salesforce/apex/WhatsAppAgentforceHandler.getConversationMessages';
import sendMessage from '@salesforce/apex/WhatsAppConfigurationController.sendMessage';
import updateConversationStatus from '@salesforce/apex/WhatsAppConfigurationController.updateConversationStatus';

export default class WhatsappConversationPanel extends LightningElement {
    @track conversations = [];
    @track selectedConversation = null;
    @track messages = [];
    @track newMessage = '';
    @track isLoading = false;
    @track isSending = false;

    wiredConversationsResult;

    @wire(getConversations)
    wiredConversations(result) {
        this.wiredConversationsResult = result;
        if (result.data) {
            this.conversations = result.data;
            this.isLoading = false;
        } else if (result.error) {
            this.showToast('Error', 'Failed to load conversations', 'error');
            this.isLoading = false;
        }
    }

    handleConversationSelect(event) {
        const conversationId = event.currentTarget.dataset.id;
        this.selectedConversation = this.conversations.find(c => c.Id === conversationId);
        this.loadMessages(conversationId);
    }

    loadMessages(conversationId) {
        this.isLoading = true;
        getConversationMessages({ conversationId: conversationId })
            .then(result => {
                this.messages = result;
                this.isLoading = false;
                this.scrollToBottom();
            })
            .catch(error => {
                this.showToast('Error', 'Failed to load messages', 'error');
                this.isLoading = false;
            });
    }

    handleMessageInput(event) {
        this.newMessage = event.target.value;
    }

    handleSendMessage() {
        if (!this.newMessage.trim() || !this.selectedConversation) {
            return;
        }

        this.isSending = true;
        sendMessage({
            conversationId: this.selectedConversation.Id,
            messageText: this.newMessage
        })
            .then(() => {
                this.newMessage = '';
                this.showToast('Success', 'Message sent', 'success');
                // Refresh messages after a short delay
                setTimeout(() => {
                    this.loadMessages(this.selectedConversation.Id);
                }, 1000);
                this.isSending = false;
            })
            .catch(error => {
                this.showToast('Error', 'Failed to send message: ' + error.body.message, 'error');
                this.isSending = false;
            });
    }

    handleKeyPress(event) {
        if (event.key === 'Enter' && !event.shiftKey) {
            event.preventDefault();
            this.handleSendMessage();
        }
    }

    handleCloseConversation() {
        if (!this.selectedConversation) return;

        updateConversationStatus({
            conversationId: this.selectedConversation.Id,
            status: 'Closed'
        })
            .then(() => {
                this.showToast('Success', 'Conversation closed', 'success');
                this.selectedConversation = null;
                this.messages = [];
                return refreshApex(this.wiredConversationsResult);
            })
            .catch(error => {
                this.showToast('Error', 'Failed to close conversation', 'error');
            });
    }

    scrollToBottom() {
        setTimeout(() => {
            const messagesContainer = this.template.querySelector('.messages-container');
            if (messagesContainer) {
                messagesContainer.scrollTop = messagesContainer.scrollHeight;
            }
        }, 100);
    }

    showToast(title, message, variant) {
        const event = new ShowToastEvent({
            title: title,
            message: message,
            variant: variant
        });
        this.dispatchEvent(event);
    }

    get hasConversations() {
        return this.conversations && this.conversations.length > 0;
    }

    get hasMessages() {
        return this.messages && this.messages.length > 0;
    }

    get isMessageInputDisabled() {
        return !this.selectedConversation || this.isSending;
    }

    get conversationTitle() {
        return this.selectedConversation ?
            `Conversation with ${this.selectedConversation.Customer_Phone__c}` :
            'Select a conversation';
    }

    get statusVariant() {
        if (!this.selectedConversation) return 'slds-theme_shade';

        switch(this.selectedConversation.Status__c) {
            case 'Active': return 'slds-theme_success';
            case 'Idle': return 'slds-theme_warning';
            case 'Closed': return 'slds-theme_shade';
            default: return 'slds-theme_shade';
        }
    }

    getMessageClass(message) {
        return message.Direction__c === 'Inbound' ?
            'message-bubble inbound' :
            'message-bubble outbound';
    }

    formatTimestamp(timestamp) {
        const date = new Date(timestamp);
        return date.toLocaleString();
    }
}
