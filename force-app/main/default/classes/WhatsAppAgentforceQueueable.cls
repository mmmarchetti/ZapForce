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
            WhatsAppLogService.logInfo(
                'AGENTFORCE_QUEUEABLE_COMPLETED',
                'WhatsAppAgentforceQueueable.execute',
                'Completed async Agentforce processing. conversationId=' + conversationId +
                ', messageId=' + messageId +
                ', queueableJobId=' + context.getJobId()
            );
        } catch (Exception e) {
            WhatsAppLogService.logError(
                'AGENTFORCE_QUEUEABLE_EXCEPTION',
                'WhatsAppAgentforceQueueable.execute',
                'Async Agentforce processing failed: ' + e.getMessage(),
                null,
                null,
                e.getStackTraceString(),
                null
            );
            WhatsAppErrorLogger.logAgentforceError(
                'Async Agentforce processing failed', conversationId, e
            );
        }
    }
}
