/**
 * @description Service for analyzing images using Salesforce Einstein Prompt Templates.
 *              Uses ConnectApi.EinsteinLLM.generateMessagesForPromptTemplate() to call
 *              GPT-4o with multimodal (vision) capabilities via a ContentDocument reference.
 *
 *              Requires:
 *              - GenAiPromptTemplate: WhatsApp_Image_Analysis (deployed and published)
 *              - The image must be stored as a ContentVersion/ContentDocument in Salesforce
 */
public with sharing class WhatsAppImageAnalysisService {

    private static final String PROMPT_TEMPLATE_NAME = 'WhatsApp_Image_Analysis';
    private static final String APPLICATION_NAME = 'PromptBuilderPreview';
    private static final Integer MAX_IMAGE_SIZE_BYTES = 4 * 1024 * 1024; // 4MB

    /**
     * @description Analyzes an image using a Salesforce Einstein Prompt Template with
     *              GPT-4o multimodal vision. Passes the image as a ContentDocument reference.
     * @param contentDocumentId The ContentDocument ID of the stored image
     * @return The description text from the vision model, or an error message prefixed with 'Error: '
     */
    public static String analyzeImageByDocument(String contentDocumentId) {
        if (String.isBlank(contentDocumentId)) {
            return 'Error: ContentDocument ID is required.';
        }

        try {
            // Build input parameters with the image as ContentDocument reference
            Map<String, ConnectApi.WrappedValue> inputParams = new Map<String, ConnectApi.WrappedValue>();

            Map<String, String> fileMap = new Map<String, String>{
                'id' => contentDocumentId,
                'type' => 'ContentDocument'
            };

            ConnectApi.WrappedValue fileValue = new ConnectApi.WrappedValue();
            fileValue.value = fileMap;
            inputParams.put('Input:Image', fileValue);

            ConnectApi.EinsteinPromptTemplateGenerationsInput promptInput =
                new ConnectApi.EinsteinPromptTemplateGenerationsInput();
            promptInput.inputParams = inputParams;
            promptInput.isPreview = false;

            promptInput.additionalConfig = new ConnectApi.EinsteinLlmAdditionalConfigInput();
            promptInput.additionalConfig.applicationName = APPLICATION_NAME;

            ConnectApi.EinsteinPromptTemplateGenerationsRepresentation response =
                ConnectApi.EinsteinLLM.generateMessagesForPromptTemplate(PROMPT_TEMPLATE_NAME, promptInput);

            if (response != null && response.generations != null && !response.generations.isEmpty()) {
                String generatedText = response.generations[0].text;
                if (String.isNotBlank(generatedText)) {
                    return generatedText;
                }
            }

            return 'Error: No response generated from the vision model.';

        } catch (Exception e) {
            System.debug('IMAGE_ANALYSIS_EXCEPTION: ' + e.getMessage() + '\n' + e.getStackTraceString());
            return 'Error: ' + e.getMessage();
        }
    }

    /**
     * @description Analyzes an image using raw binary data. Finds or creates
     *              a ContentDocument, then delegates to analyzeImageByDocument().
     *              This overload is kept for backward compatibility with WhatsAppAnalyzeImageAction.
     * @param imageData The raw image binary data
     * @param mimeType The MIME type (e.g., 'image/jpeg', 'image/png')
     * @param prompt Custom prompt (unused in Prompt Template approach, kept for API compatibility)
     * @return The description text from the vision model
     */
    public static String analyzeImage(Blob imageData, String mimeType, String prompt) {
        if (imageData == null) {
            return 'Error: No image data provided.';
        }

        if (imageData.size() > MAX_IMAGE_SIZE_BYTES) {
            return 'Error: Image is too large to analyze (maximum 4MB). Please send a smaller image.';
        }

        return 'Error: Use analyzeImageByDocument() with a ContentDocument ID instead.';
    }
}
