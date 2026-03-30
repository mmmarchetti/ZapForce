trigger WhatsAppInboundEventTrigger on WhatsApp_Inbound_Event__e (after insert) {
    WhatsAppInboundEventHandler.handleEvents(Trigger.new);
}
