/**
 * @description Queueable class for asynchronous Agentforce message processing.
 *              Wraps WhatsAppAgentforceService.processMessage() to allow
 *              callouts from Platform Event trigger context.
 */
public class WhatsAppAgentforceQueueable implements Queueable, Database.AllowsCallouts {

    private Id conversationId;
    private Id messageId;

    public WhatsAppAgentforceQueueable(Id conversationId, Id messageId) {
        this.conversationId = conversationId;
        this.messageId = messageId;
    }

    public void execute(QueueableContext context) {
        try {
            WhatsAppAgentforceService.processMessage(conversationId, messageId);
        } catch (Exception e) {
            WhatsAppErrorLogger.logAgentforceError(
                'Async Agentforce processing failed', conversationId, e
            );
        }
    }
}
