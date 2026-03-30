import { LightningElement, track, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { subscribe, unsubscribe, onError } from 'lightning/empApi';
import { refreshApex } from '@salesforce/apex';
import getConversations from '@salesforce/apex/WhatsAppConversationController.getConversations';
import getConversationMessages from '@salesforce/apex/WhatsAppConversationController.getConversationMessages';
import sendMessage from '@salesforce/apex/WhatsAppConversationController.sendMessage';
import updateConversationStatus from '@salesforce/apex/WhatsAppConversationController.updateConversationStatus';
import markConversationRead from '@salesforce/apex/WhatsAppConversationController.markConversationRead';

export default class WhatsappConversationPanel extends LightningElement {
    @track conversations = [];
    @track selectedConversation = null;
    @track messages = [];
    @track newMessage = '';
    @track isLoading = false;
    @track isSending = false;

    wiredConversationsResult;
    channelName = '/event/WhatsApp_Inbound_Event__e';
    subscription = {};

    @wire(getConversations)
    wiredConversations(result) {
        this.wiredConversationsResult = result;
        if (result.data) {
            this.conversations = result.data.map(conv => ({
                ...conv,
                displayName: conv.Customer_Name__c || conv.Customer_Phone__c,
                hasUnread: conv.Unread_Count__c > 0,
                itemClass: this.selectedConversation && this.selectedConversation.Id === conv.Id
                    ? 'conversation-item selected' : 'conversation-item',
                statusBadgeClass: this.getStatusBadgeClass(conv.Status__c),
                lastMessageTime: conv.Last_Message_Time__c
                    ? new Date(conv.Last_Message_Time__c).toLocaleString([], {
                        month: 'short', day: 'numeric', hour: '2-digit', minute: '2-digit'
                    })
                    : ''
            }));
        }
    }

    connectedCallback() {
        this.subscribeToEvents();
    }

    disconnectedCallback() {
        if (this.subscription) {
            unsubscribe(this.subscription, () => {});
        }
    }

    subscribeToEvents() {
        const callback = (response) => {
            refreshApex(this.wiredConversationsResult);
            if (this.selectedConversation) {
                this.loadMessages(this.selectedConversation.Id);
            }
        };
        subscribe(this.channelName, -1, callback).then(response => {
            this.subscription = response;
        });
        onError(error => {
            console.error('EMP API error:', JSON.stringify(error));
        });
    }

    getStatusBadgeClass(status) {
        switch (status) {
            case 'Active': return 'status-badge status-active';
            case 'Idle': return 'status-badge status-idle';
            case 'Closed': return 'status-badge status-closed';
            default: return 'status-badge';
        }
    }

    handleSearchInput(event) {
        const searchTerm = event.target.value.toLowerCase();
        if (this.wiredConversationsResult && this.wiredConversationsResult.data) {
            const filtered = this.wiredConversationsResult.data.filter(conv => {
                const name = (conv.Customer_Name__c || '').toLowerCase();
                const phone = (conv.Customer_Phone__c || '').toLowerCase();
                return name.includes(searchTerm) || phone.includes(searchTerm);
            });
            this.conversations = filtered.map(conv => ({
                ...conv,
                displayName: conv.Customer_Name__c || conv.Customer_Phone__c,
                hasUnread: conv.Unread_Count__c > 0,
                itemClass: this.selectedConversation && this.selectedConversation.Id === conv.Id
                    ? 'conversation-item selected' : 'conversation-item',
                statusBadgeClass: this.getStatusBadgeClass(conv.Status__c),
                lastMessageTime: conv.Last_Message_Time__c
                    ? new Date(conv.Last_Message_Time__c).toLocaleString([], {
                        month: 'short', day: 'numeric', hour: '2-digit', minute: '2-digit'
                    })
                    : ''
            }));
        }
    }

    handleConversationSelect(event) {
        const conversationId = event.currentTarget.dataset.id;
        this.selectedConversation = this.conversations.find(c => c.Id === conversationId);
        this.loadMessages(conversationId);
        markConversationRead({ conversationId }).catch(() => {});
    }

    loadMessages(conversationId) {
        this.isLoading = true;
        getConversationMessages({ conversationId })
            .then(result => {
                this.messages = result.map(msg => this.enrichMessage(msg));
                this.isLoading = false;
                this.scrollToBottom();
            })
            .catch(error => {
                this.showToast('Error', 'Failed to load messages', 'error');
                this.isLoading = false;
            });
    }

    enrichMessage(msg) {
        return {
            ...msg,
            isInbound: msg.Direction__c === 'Inbound',
            isOutbound: msg.Direction__c === 'Outbound',
            isText: msg.Message_Type__c === 'Text',
            isMedia: ['Image', 'Video', 'Audio', 'Document', 'Sticker'].includes(msg.Message_Type__c),
            isLocation: msg.Message_Type__c === 'Location',
            isReaction: msg.Message_Type__c === 'Reaction',
            isInteractive: msg.Message_Type__c === 'Interactive',
            isTemplate: msg.Message_Type__c === 'Template',
            isContacts: msg.Message_Type__c === 'Contacts' || msg.Message_Type__c === 'Contact',
            isSystem: msg.Message_Type__c === 'System',
            isFailed: msg.Message_Status__c === 'Failed',
            bubbleClass: msg.Direction__c === 'Inbound' ? 'message-row inbound' : 'message-row outbound',
            hasMedia: msg.WhatsApp_Media__r && msg.WhatsApp_Media__r.length > 0,
            mediaIcon: this.getMediaIcon(msg.Message_Type__c),
            formattedTime: msg.Timestamp__c
                ? new Date(msg.Timestamp__c).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })
                : ''
        };
    }

    getMediaIcon(type) {
        const icons = {
            'Image': 'utility:image',
            'Video': 'utility:video',
            'Audio': 'utility:volume_high',
            'Document': 'utility:file',
            'Sticker': 'utility:emoji'
        };
        return icons[type] || 'utility:file';
    }

    handleMessageInput(event) {
        this.newMessage = event.target.value;
    }

    handleSendMessage() {
        if (!this.newMessage || !this.newMessage.trim() || !this.selectedConversation) return;
        this.isSending = true;
        sendMessage({ conversationId: this.selectedConversation.Id, messageText: this.newMessage })
            .then(() => {
                this.newMessage = '';
                this.showToast('Success', 'Message queued for sending', 'success');
                // eslint-disable-next-line @lwc/lwc/no-async-operation
                setTimeout(() => this.loadMessages(this.selectedConversation.Id), 1500);
                this.isSending = false;
            })
            .catch(error => {
                this.showToast('Error', 'Failed to send: ' + (error.body ? error.body.message : error.message), 'error');
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
        updateConversationStatus({ conversationId: this.selectedConversation.Id, status: 'Closed' })
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
        // eslint-disable-next-line @lwc/lwc/no-async-operation
        setTimeout(() => {
            const container = this.template.querySelector('.messages-body');
            if (container) container.scrollTop = container.scrollHeight;
        }, 100);
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }

    get hasConversations() {
        return this.conversations && this.conversations.length > 0;
    }

    get hasMessages() {
        return this.messages && this.messages.length > 0;
    }

    get isInputDisabled() {
        return !this.selectedConversation || this.isSending;
    }

    get conversationTitle() {
        if (!this.selectedConversation) return '';
        return this.selectedConversation.Customer_Name__c || this.selectedConversation.Customer_Phone__c;
    }
}
