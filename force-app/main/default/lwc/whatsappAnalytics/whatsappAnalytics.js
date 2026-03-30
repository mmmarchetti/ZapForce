import { LightningElement, track, wire } from 'lwc';
import getStatistics from '@salesforce/apex/WhatsAppConversationController.getStatistics';

export default class WhatsappAnalytics extends LightningElement {
    @track stats = {};
    @track isLoading = true;

    @wire(getStatistics)
    wiredStats({ data, error }) {
        if (data) {
            this.stats = data;
            this.isLoading = false;
        } else if (error) {
            this.isLoading = false;
        }
    }

    get totalConversations() { return this.stats.totalConversations || 0; }
    get activeConversations() { return this.stats.activeConversations || 0; }
    get messagesToday() { return this.stats.messagesToday || 0; }
    get inboundToday() { return this.stats.inboundToday || 0; }
    get outboundToday() { return this.stats.outboundToday || 0; }
    get mediaCount() { return this.stats.mediaCount || 0; }
    get errorCount() { return this.stats.errorCount || 0; }
    get hasErrors() { return this.errorCount > 0; }
    get errorClass() { return this.hasErrors ? 'stat-value error' : 'stat-value'; }
}
