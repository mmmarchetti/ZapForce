import { LightningElement, track } from 'lwc';

export default class WhatsappDashboard extends LightningElement {
    @track activeTab = 'configuration';

    handleTabChange(event) {
        this.activeTab = event.target.value;
    }
}
